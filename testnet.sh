#!/bin/bash

# TestNet 管理工具 (testnet.sh)
# 支持: install | start | stop | restart | update | reset-password | logs | status

# 1. 确保工作目录始终为脚本所在目录 (支持从任意路径执行)
cd "$(dirname "$(readlink -f "$0")")" || exit 1

VERSION="v3.0.0beta" # 默认显示版本号，实际会从远程获取
VERSION_URL=""
DOWNLOAD_BASE_URL=""
SELECTED_REGISTRY_URL="testnet0/"
OS_TYPE=$(uname)

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 探测最优下载源和镜像源
detect_sources() {
    local CNB_BASE_URL="https://cnb.cool/testnet0/testnet-public/-/git/raw/main"
    local GITHUB_BASE_URL="https://raw.githubusercontent.com/testnet0/testnet/main"
    
    echo -e "${CYAN}正在通过网络探测选择最优源...${NC}"
    
    local cnb_status=""
    if command -v curl >/dev/null 2>&1; then
        cnb_status=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 5 -m 8 "$CNB_BASE_URL/version.yml")
    elif command -v wget >/dev/null 2>&1; then
        cnb_status=$(wget --spider --timeout=5 --tries=1 "$CNB_BASE_URL/version.yml" >/dev/null 2>&1 && echo "200" || echo "000")
    fi

    if [ "$cnb_status" = "200" ]; then
        DOWNLOAD_BASE_URL="$CNB_BASE_URL"
        VERSION_URL="$CNB_BASE_URL/version.yml"
        SELECTED_REGISTRY_URL="registry.cn-hangzhou.aliyuncs.com/testnet0/"
        echo -e "${GREEN}[√] 已选择国内节点 (CNB)，将自动使用阿里云镜像源。${NC}"
    else
        DOWNLOAD_BASE_URL="$GITHUB_BASE_URL"
        VERSION_URL="$GITHUB_BASE_URL/version.yml"
        SELECTED_REGISTRY_URL="testnet0/"
        echo -e "${GREEN}[√] 已选择国际节点 (GitHub)，将自动使用 DockerHub 默认源。${NC}"
    fi
}

# 获取远程最新版本号 (兼容 YAML 冒号格式)
fetch_latest_version() {
    echo -e "${CYAN}正在从远程获取最新版本号...${NC}"
    local remote_version=""
    if [ -z "$VERSION_URL" ]; then
        detect_sources
    fi
    
    if command -v curl >/dev/null 2>&1; then
        remote_version=$(curl -s -L --connect-timeout 5 -m 10 "$VERSION_URL" | grep -E "^version[:=]" | sed -E 's/^version[:=][[:space:]]*//' | tr -d '\r')
    elif command -v wget >/dev/null 2>&1; then
        remote_version=$(wget -qO- --timeout=5 -t 2 "$VERSION_URL" | grep -E "^version[:=]" | sed -E 's/^version[:=][[:space:]]*//' | tr -d '\r')
    fi

    if [ -n "$remote_version" ]; then
        VERSION="$remote_version"
        export TESTNET_VERSION="$VERSION"
        echo -e "${GREEN}获取成功，当前最新版本: ${VERSION}${NC}"
    else
        echo -e "${YELLOW}警告: 无法获取远程版本号，将使用默认版本: ${VERSION}${NC}"
        export TESTNET_VERSION="$VERSION"
    fi
}

# 检查并自动生成 SSL 自签名证书 (防止 Nginx 启动崩溃)
check_certs() {
    if [ ! -f "certs/server.crt" ] || [ ! -f "certs/server.key" ]; then
        echo -e "${YELLOW}检测到 SSL 证书缺失，正在自动生成自签名证书...${NC}"
        if [ -f "gen-certs.sh" ]; then
            bash gen-certs.sh
        else
            mkdir -p certs
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
              -keyout "certs/server.key" \
              -out "certs/server.crt" \
              -subj "/C=CN/ST=Beijing/L=Beijing/O=TestNet/OU=Dev/CN=localhost" >/dev/null 2>&1
        fi
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[√] SSL 证书已成功自动生成。${NC}"
        else
            echo -e "${RED}警告: SSL 证书生成失败，Nginx 容器可能无法正常启动。${NC}"
        fi
    fi
}

# 同步最新配置文件并执行脚本自更新
sync_latest_files() {
    echo -e "${CYAN}正在同步最新配置文件与管理脚本...${NC}"
    local tmp_version_file="version.yml.tmp"
    
    if command -v curl >/dev/null 2>&1; then
        curl -s -L --connect-timeout 5 -m 10 "$VERSION_URL" -o "$tmp_version_file"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$tmp_version_file" --timeout=5 -t 2 "$VERSION_URL"
    fi

    if [ ! -f "$tmp_version_file" ] || grep -qE "^\{|^<html>" "$tmp_version_file"; then
        echo -e "${YELLOW}警告: 无法获取远程版本清单，跳过配置文件同步。${NC}"
        rm -f "$tmp_version_file"
        return 0
    fi

    local files_to_sync
    files_to_sync=($(grep -A 50 "^files:" "$tmp_version_file" | grep "^  -" | sed 's/^  - //'))
    rm -f "$tmp_version_file"

    if [ ${#files_to_sync[@]} -eq 0 ]; then
        echo -e "${YELLOW}警告: 解析文件列表失败，跳过同步。${NC}"
        return 0
    fi

    local self_updated=false
    for entry in "${files_to_sync[@]}"; do
        local file=$(echo "$entry" | cut -d':' -f1)
        local expected_md5=$(echo "$entry" | cut -d':' -f2)

        local dir_part=$(dirname "$file")
        if [ "$dir_part" != "." ]; then
            mkdir -p "$dir_part"
        fi

        echo -n -e "正在拉取 $file ... "
        local download_success=false
        if command -v curl >/dev/null 2>&1; then
            curl -s -L --connect-timeout 5 -m 10 "$DOWNLOAD_BASE_URL/$file" -o "${file}.tmp" && download_success=true
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "${file}.tmp" --timeout=5 -t 2 "$DOWNLOAD_BASE_URL/$file" && download_success=true
        fi

        if [ "$download_success" = "true" ] && [ -f "${file}.tmp" ] && ! grep -qE "^\{|^<html>" "${file}.tmp"; then
            # 校验 MD5 哈希 (如果清单提供了哈希值)
            if [ -n "$expected_md5" ] && [ "$expected_md5" != "$file" ]; then
                local downloaded_md5=""
                if command -v md5sum >/dev/null 2>&1; then
                    downloaded_md5=$(md5sum "${file}.tmp" | cut -d' ' -f1)
                elif command -v md5 >/dev/null 2>&1; then
                    downloaded_md5=$(md5 -q "${file}.tmp")
                fi
                
                if [ -n "$downloaded_md5" ] && [ "$downloaded_md5" != "$expected_md5" ]; then
                    echo -e "${RED}失败 (MD5 不匹配: 期望 $expected_md5，实际 $downloaded_md5)${NC}"
                    rm -f "${file}.tmp"
                    continue
                fi
            fi

            mv "${file}.tmp" "$file"
            if [ "$file" = "testnet.sh" ]; then
                chmod +x testnet.sh
                self_updated=true
            fi
            echo -e "${GREEN}完成${NC}"
        else
            echo -e "${RED}失败 (跳过)${NC}"
            rm -f "${file}.tmp"
        fi
    done

    # 更新本地 .env 文件中的版本号
    if [ -f .env ]; then
        if grep -q "TESTNET_VERSION" .env; then
            if [ "$OS_TYPE" == "Darwin" ]; then
                sed -i "" "s|TESTNET_VERSION=.*|TESTNET_VERSION=$VERSION|" .env
            else
                sed -i "s|TESTNET_VERSION=.*|TESTNET_VERSION=$VERSION|" .env
            fi
        else
            echo "TESTNET_VERSION=$VERSION" >> .env
        fi
    fi

    # 如果自身脚本被更新，立即重载执行
    if [ "$self_updated" = "true" ]; then
        echo -e "${GREEN}管理脚本已完成自我更新，正在重新加载执行...${NC}"
        exec bash "$0" "$@"
    fi
}

# 生成随机字符串的函数
generate_random_string() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 32
    else
        LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c 64
    fi
}

# 生成随机密码的函数 (包含大小写字母、数字、特殊字符)
generate_admin_password() {
    local length=${1:-16}
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 32 | LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' | head -c "$length"
    else
        LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$length"
    fi
}

# 检查环境函数
check_env() {
    echo -e "${CYAN}Checking environment...${NC}"
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not installed.${NC}"
        exit 1
    fi
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}Error: Docker daemon is not running.${NC}"
        exit 1
    fi
    DOCKER_COMPOSE_CMD=""
    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        echo -e "${RED}Error: Docker Compose is not installed.${NC}"
        exit 1
    fi
}

# 检查上一条指令的状态，失败时可选打印日志
check_status() {
    local status=$?
    local msg=$1
    local show_logs=$2

    if [ $status -ne 0 ]; then
        echo -e "${RED}Error: $msg failed.${NC}"
        if [ "$show_logs" == "true" ]; then
            echo -e "${YELLOW}Collecting last 20 lines of logs for troubleshooting...${NC}"
            $DOCKER_COMPOSE_CMD logs --tail=20
        else
            echo -e "${YELLOW}Please check the logs or run './testnet.sh logs' for more details.${NC}"
        fi
        exit 1
    fi
}

# 自动加载环境变量 (采用更健壮的 set -a 导入)
load_env_vars() {
    if [ -f .env ]; then
        # 自动补全/修复缺失的 REDIS_PASSWORD (防止 Redis 启动因参数为空崩溃)
        if ! grep -q "^REDIS_PASSWORD=" .env || grep -E -q "^REDIS_PASSWORD=['\"]?['\"]?$" .env; then
            echo -e "${YELLOW}检测到 REDIS_PASSWORD 缺失或为空，正在为您自动生成...${NC}"
            local new_redis_pass=$(generate_random_string)
            if grep -q "^REDIS_PASSWORD=" .env; then
                if [ "$OS_TYPE" == "Darwin" ]; then
                    sed -i "" "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$new_redis_pass|" .env
                else
                    sed -i "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$new_redis_pass|" .env
                fi
            else
                echo "REDIS_PASSWORD=$new_redis_pass" >> .env
            fi
        fi

        set -a
        source .env
        set +a
        
        export DOCKER_REGISTRY="${DOCKER_REGISTRY:-testnet0/}"
        
        # 根据 DOCKER_REGISTRY 设置 OFFICIAL_REGISTRY (国内阿里云源加速模式下从阿里云拉取 postgres/redis)
        if [ "$DOCKER_REGISTRY" = "testnet0/" ]; then
            export OFFICIAL_REGISTRY=""
        else
            export OFFICIAL_REGISTRY="$DOCKER_REGISTRY"
        fi
        
        if [ -z "$TESTNET_VERSION" ] && [ "$1" != "install" ] && [ "$1" != "update" ]; then
            echo -e "${YELLOW}检测到 .env 中缺少版本号，正在尝试补全...${NC}"
            fetch_latest_version
        fi
    else
        if [ "$1" != "install" ]; then
            echo -e "${RED}Error: .env file not found. Have you run 'install' yet?${NC}"
            exit 1
        fi
    fi
}

# 显示帮助信息
show_help() {
    echo "Usage: $0 {install|start|stop|restart|update|reset-password|logs|status}"
    echo ""
    echo "Commands:"
    echo "  install        Perform initial setup and launch containers"
    echo "  start          Start existing TestNet containers"
    echo "  stop           Stop TestNet containers"
    echo "  restart        Restart TestNet containers"
    echo "  update         Rebuild and update containers to latest version"
    echo "  reset-password Regenerate all secrets in .env and restart"
    echo "  logs           View streaming logs from all services"
    echo "  status         Check the status of TestNet services"
}

# 核心逻辑
case "$1" in
    install)
        fetch_latest_version
        check_env
        check_certs

        # 镜像源选择
        if [ -n "$SELECTED_REGISTRY" ]; then
            case "$SELECTED_REGISTRY" in
                2)
                    REGISTRY_URL="registry.cn-hangzhou.aliyuncs.com/testnet0/"
                    echo -e "${GREEN}已通过引导脚本自动选择阿里云镜像源。${NC}"
                    ;;
                *)
                    REGISTRY_URL="testnet0/"
                    echo -e "${GREEN}已通过引导脚本自动选择 DockerHub 默认源。${NC}"
                    ;;
            esac
            SELECTED_REGISTRY_URL="$REGISTRY_URL"
        else
            local default_choice="1"
            if [ "$SELECTED_REGISTRY_URL" = "registry.cn-hangzhou.aliyuncs.com/testnet0/" ]; then
                default_choice="2"
            fi
            
            echo -e "${CYAN}请选择镜像源 (Choose Mirror Source):${NC}"
            echo "1) DockerHub (默认 - 官方同步最及时)"
            echo "2) 阿里云 (Alibaba Cloud - 中国加速)"
            read -p "请输入选项 [1-2, 默认$default_choice]: " registry_choice
            registry_choice="${registry_choice:-$default_choice}"
            
            case "$registry_choice" in
                2)
                    SELECTED_REGISTRY_URL="registry.cn-hangzhou.aliyuncs.com/testnet0/"
                    echo -e "${GREEN}已选择阿里云镜像源。${NC}"
                    ;;
                *)
                    SELECTED_REGISTRY_URL="testnet0/"
                    echo -e "${GREEN}已选择 DockerHub 默认源 (testnet0/)。${NC}"
                    ;;
            esac
        fi

        if [ ! -f .env ]; then
            echo -e "${YELLOW}Creating .env file with dynamic secrets...${NC}"
            ADMIN_PASSWORD=$(generate_admin_password 16)
            echo "DB_ROOT_PASSWORD=$(generate_random_string)" > .env
            echo "REDIS_PASSWORD=$(generate_random_string)" >> .env
            echo "JWT_SECRET=$(generate_random_string)" >> .env
            echo "TESTNET_CLIENT_SECRET=$(generate_random_string)" >> .env
            echo "ADMIN_INIT_PASSWORD=${ADMIN_PASSWORD}" >> .env
            echo "DOCKER_REGISTRY=$SELECTED_REGISTRY_URL" >> .env
            echo "CORS_ALLOWED_ORIGINS=*" >> .env
            echo "TESTNET_VERSION=$VERSION" >> .env
            echo -e "${GREEN}New secrets and version generated.${NC}"
        else
            echo -e "${CYAN}Using existing .env configuration.${NC}"
            if grep -q "DOCKER_REGISTRY" .env; then
                if [ "$OS_TYPE" == "Darwin" ]; then
                    sed -i "" "s|DOCKER_REGISTRY=.*|DOCKER_REGISTRY=$SELECTED_REGISTRY_URL|" .env
                else
                    sed -i "s|DOCKER_REGISTRY=.*|DOCKER_REGISTRY=$SELECTED_REGISTRY_URL|" .env
                fi
            else
                echo "DOCKER_REGISTRY=$SELECTED_REGISTRY_URL" >> .env
            fi
            if grep -q "TESTNET_VERSION" .env; then
                if [ "$OS_TYPE" == "Darwin" ]; then
                    sed -i "" "s|TESTNET_VERSION=.*|TESTNET_VERSION=$VERSION|" .env
                else
                    sed -i "s|TESTNET_VERSION=.*|TESTNET_VERSION=$VERSION|" .env
                fi
            else
                echo "TESTNET_VERSION=$VERSION" >> .env
            fi
            if ! grep -q "CORS_ALLOWED_ORIGINS" .env; then
                echo "CORS_ALLOWED_ORIGINS=*" >> .env
                echo -e "${GREEN}Added CORS_ALLOWED_ORIGINS to .env (default: *).${NC}"
                echo -e "${YELLOW}  如果通过域名访问，请编辑 .env 中的 CORS_ALLOWED_ORIGINS 为实际地址。${NC}"
            fi
            if ! grep -q "ADMIN_INIT_PASSWORD" .env; then
                ADMIN_PASSWORD=$(generate_admin_password 16)
                echo "ADMIN_INIT_PASSWORD=${ADMIN_PASSWORD}" >> .env
                echo -e "${GREEN}Generated new admin password.${NC}"
            else
                ADMIN_PASSWORD=$(grep ADMIN_INIT_PASSWORD .env | cut -d'=' -f2)
            fi
        fi
        
        export DOCKER_REGISTRY=$SELECTED_REGISTRY_URL
        if [ "$DOCKER_REGISTRY" = "testnet0/" ]; then
            export OFFICIAL_REGISTRY=""
        else
            export OFFICIAL_REGISTRY="$DOCKER_REGISTRY"
        fi

        if docker images --format '{{.Repository}}' | grep -q "testnet-"; then
            echo -e "${CYAN}检测到本地已存在 TestNet 镜像，正在尝试拉取更新...${NC}"
            $DOCKER_COMPOSE_CMD pull
            if [ $? -ne 0 ]; then
                echo -e "${YELLOW}警告: 拉取最新镜像失败，将尝试使用本地现有镜像启动。${NC}"
            fi
        fi

        echo -e "${CYAN}Launching containers...${NC}"
        $DOCKER_COMPOSE_CMD up -d
        check_status "Container launch" "true"
        
        echo -e "${GREEN}TestNet installed successfully!${NC}"
        echo -e "${CYAN}Access URL: https://localhost:3100${NC}"
        echo ""
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${YELLOW}  Admin Account Credentials${NC}"
        echo -e "${YELLOW}========================================${NC}"
        if [ -n "$ADMIN_PASSWORD" ]; then
            echo -e "${GREEN}  Username: admin${NC}"
            echo -e "${GREEN}  Password: ${ADMIN_PASSWORD}${NC}"
        else
            echo -e "${GREEN}  Username: admin${NC}"
            echo -e "${GREEN}  Password: $(grep ADMIN_INIT_PASSWORD .env | cut -d'=' -f2)${NC}"
        fi
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${CYAN}  Please save this password securely!${NC}"
        echo -e "${YELLOW}========================================${NC}"
        echo ""
        ;;
    start)
        check_env
        load_env_vars "$1"
        echo -e "${CYAN}Using Registry: ${DOCKER_REGISTRY}${NC}"
        $DOCKER_COMPOSE_CMD up -d
        echo -e "${GREEN}TestNet started.${NC}"
        ;;
    stop)
        check_env
        load_env_vars "$1"
        $DOCKER_COMPOSE_CMD stop
        echo -e "${YELLOW}TestNet stopped.${NC}"
        ;;
    restart)
        check_env
        load_env_vars "$1"
        $DOCKER_COMPOSE_CMD restart
        echo -e "${GREEN}TestNet restarted.${NC}"
        ;;
    update)
        load_env_vars "$1"
        fetch_latest_version
        check_env
        check_certs

        # 自动同步配置文件并更新脚本
        local_version="${TESTNET_VERSION:-}"
        if [ "$VERSION" != "$local_version" ]; then
            sync_latest_files "$@"
        fi

        load_env_vars "$1" # 同步后再次加载可能被修改的环境变量

        echo -e "${CYAN}Updating Registry: ${DOCKER_REGISTRY}${NC}"
        echo -e "${CYAN}Target Version: ${VERSION}${NC}"
        
        if grep -q "TESTNET_VERSION" .env; then
            if [ "$OS_TYPE" == "Darwin" ]; then
                sed -i "" "s|TESTNET_VERSION=.*|TESTNET_VERSION=$VERSION|" .env
            else
                sed -i "s|TESTNET_VERSION=.*|TESTNET_VERSION=$VERSION|" .env
            fi
        else
            echo "TESTNET_VERSION=$VERSION" >> .env
        fi
        export TESTNET_VERSION="$VERSION"

        echo -e "${CYAN}Pulling latest images...${NC}"
        $DOCKER_COMPOSE_CMD pull
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}Warning: Pull failed. Trying to start with local images...${NC}"
        fi
        
        echo -e "${CYAN}Updating and rebuilding...${NC}"
        $DOCKER_COMPOSE_CMD up -d --remove-orphans
        check_status "Update"
        
        echo -e "${GREEN}TestNet updated and started.${NC}"
        ;;
    reset-password)
        check_env
        load_env_vars "$1"
        
        DEFAULT_PASS="Admin@123456"
        # NOTE: This bcrypt hash corresponds to the default password above.
        # If the default password changes, this hash MUST be regenerated using
        # Spring Boot's BCryptPasswordEncoder (10 rounds, $2a$10$).
        REAL_HASH='$2a$10$8.UnVuG9HHgffUDAlk8qfOuVGkqRzgVymGe07xd00DMxs.TVuHOnu'
        
        echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  警告：此操作将直接重置 admin 用户密码为默认值！      ║${NC}"
        echo -e "${RED}║  默认密码仅用于紧急恢复，登录后必须立即修改！          ║${NC}"
        echo -e "${RED}║  未修改默认密码将面临严重安全风险！                    ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
        echo -e "${YELLOW}此操作不会修改 JWT 密钥或重置配置，也不会导致已有扫描任务丢失。${NC}"
        read -p "请输入完整默认密码 (${DEFAULT_PASS}) 以确认重置: " confirm
        
        if [ "$confirm" == "${DEFAULT_PASS}" ]; then
            if [ -z "$DB_ROOT_PASSWORD" ]; then
                echo -e "${RED}错误：无法从 .env 获取数据库密码。请检查文件是否存在。${NC}"
                exit 1
            fi
            
            # 检查数据库容器是否在运行
            if ! docker ps --format '{{.Names}}' | grep -q "^testnet-db$"; then
                echo -e "${RED}错误：数据库容器 'testnet-db' 未运行。请先执行 './testnet.sh start'。${NC}"
                exit 1
            fi

            echo -e "${CYAN}正在通过数据库重置密码...${NC}"
            # 在数据库容器中执行 SQL
            docker exec -i -e PGPASSWORD="${DB_ROOT_PASSWORD}" testnet-db psql -U "${DB_USERNAME:-testnet}" -d testnet \
                -c "UPDATE sys_user SET password = '${REAL_HASH}' WHERE username = 'admin';"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}密码重置成功！${NC}"
                echo -e "${GREEN}新密码为: ${DEFAULT_PASS}${NC}"
                echo -e "${RED}⚠  安全警告：请立即登录并修改默认密码！未修改将面临严重安全风险！${NC}"
                echo -e "${YELLOW}  修改路径：登录后 → 个人中心 → 修改密码${NC}"
            else
                echo -e "${RED}重置失败。请检查数据库容器是否正常运行或密码是否正确。${NC}"
            fi
        fi
        ;;
    logs)
        check_env
        $DOCKER_COMPOSE_CMD logs -f
        ;;
    status)
        check_env
        load_env_vars "$1"
        $DOCKER_COMPOSE_CMD ps
        ;;
    *)
        show_help
        ;;
esac
