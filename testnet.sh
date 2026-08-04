#!/bin/bash

# TestNet 管理工具 (testnet.sh)
# 支持: install | start | stop | restart | update | reset-password | logs | status

# 1. 确保工作目录始终为脚本所在目录 (支持从任意路径执行)
cd "$(dirname "$(readlink -f "$0")")" || exit 1

VERSION="v3.0.3" # 默认版本号
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
    
    echo -e "${CYAN}正在测试网络环境...${NC}"
    echo -n -e "  - 探测 CNB 国内节点 (cnb.cool) ... "
    
    local cnb_status=""
    if command -v curl >/dev/null 2>&1; then
        cnb_status=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 3 -m 5 "$CNB_BASE_URL/version.yml")
    elif command -v wget >/dev/null 2>&1; then
        cnb_status=$(wget --spider --timeout=3 --tries=1 "$CNB_BASE_URL/version.yml" >/dev/null 2>&1 && echo "200" || echo "000")
    fi

    if [ "$cnb_status" = "200" ]; then
        echo -e "${GREEN}连通正常 (HTTP 200)${NC}"
        PROBED_CHOICE="2"
        PROBED_DESC="阿里云 (Alibaba Cloud - 中国加速)"
        DOWNLOAD_BASE_URL="$CNB_BASE_URL"
        VERSION_URL="$CNB_BASE_URL/version.yml"
        SELECTED_REGISTRY_URL="registry.cn-hangzhou.aliyuncs.com/testnet0/"
    else
        echo -e "${YELLOW}连接较慢或不可达${NC}"
        PROBED_CHOICE="1"
        PROBED_DESC="DockerHub (Docker Hub 源)"
        DOWNLOAD_BASE_URL="$GITHUB_BASE_URL"
        VERSION_URL="$GITHUB_BASE_URL/version.yml"
        SELECTED_REGISTRY_URL="testnet0/"
    fi
    echo -e "${GREEN}[√] 网络探测完成，推荐使用: ${PROBED_CHOICE}) ${PROBED_DESC}${NC}\n"
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

# 自动感知局域网 IP (多层降级: hostname -I -> ip -> ifconfig -> python3 -> 127.0.0.1)
get_host_ip() {
    local host_ip=""
    local OS_TYPE=$(uname -s 2>/dev/null)

    # 1. Linux 优先尝试 hostname -I
    if [ "$OS_TYPE" = "Linux" ] && command -v hostname >/dev/null 2>&1; then
        host_ip=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' | head -n 1)
    fi

    # 2. 尝试 iproute2
    if [ -z "$host_ip" ] && command -v ip >/dev/null 2>&1; then
        host_ip=$(ip -4 addr show 2>/dev/null | grep -oP 'inet \K\S+' | grep -E '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' | head -n 1)
    fi

    # 3. 尝试 ifconfig (macOS / BSD 降级)
    if [ -z "$host_ip" ] && command -v ifconfig >/dev/null 2>&1; then
        host_ip=$(ifconfig 2>/dev/null | grep -E 'inet ' | awk '{print $2}' | tr -d 'addr:' | grep -E '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' | head -n 1)
    fi

    # 4. 尝试 Python3 原生套接字降级
    if [ -z "$host_ip" ] && command -v python3 >/dev/null 2>&1; then
        host_ip=$(python3 -c "import socket; print(socket.gethostbyname(socket.gethostname()))" 2>/dev/null | grep -E '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)')
    fi

    # 5. 兜底地址
    if [ -z "$host_ip" ]; then
        host_ip="127.0.0.1"
    fi
    echo "$host_ip"
}

# 端口占用检测 (多层降级: ss -> netstat -> lsof -> bash /dev/tcp)
check_port_conflict() {
    local port=${1:-3100}
    local port_occupied=false
    
    # 1. 尝试使用 ss (Linux 推荐，非 root 可用)
    if command -v ss >/dev/null 2>&1; then
        if ss -tuln 2>/dev/null | grep -E -q ":$port\b"; then
            port_occupied=true
        fi
    # 2. 尝试使用 netstat (跨平台，非 root 可用)
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -E -q ":$port\b"; then
            port_occupied=true
        fi
    # 3. 尝试使用 lsof (macOS / Linux)
    elif command -v lsof >/dev/null 2>&1; then
        if lsof -i :$port -sTCP:LISTEN >/dev/null 2>&1; then
            port_occupied=true
        fi
    # 4. 纯 Bash 原生 Socket 连接探测兜底 (零外部依赖，非 root 100% 可用)
    elif (echo >/dev/tcp/127.0.0.1/$port) >/dev/null 2>&1; then
        port_occupied=true
    fi

    if [ "$port_occupied" = "true" ]; then
        if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -q "testnet-web"; then
            echo -e "${CYAN}检测到端口 ${port} 正由已运行的 TestNet 容器使用。${NC}"
        else
            echo -e "${RED}错误: 端口 ${port} 已被宿主机其他服务占用，无法继续安装！${NC}"
            echo -e "${YELLOW}请先停止占用该端口的服务，或修改映射端口后重试。${NC}"
            exit 1
        fi
    fi
}

# 资源与磁盘空间检测 (兼容 Linux 与 macOS)
check_resources() {
    local OS_TYPE=$(uname -s 2>/dev/null)
    local total_mem=""

    # 1. Linux 内存检测
    if [ "$OS_TYPE" = "Linux" ] && [ -f /proc/meminfo ]; then
        total_mem=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null)
    # 2. macOS 内存检测
    elif [ "$OS_TYPE" = "Darwin" ] && command -v sysctl >/dev/null 2>&1; then
        local bytes=$(sysctl -n hw.memsize 2>/dev/null)
        if [ -n "$bytes" ]; then
            total_mem=$((bytes / 1024 / 1024))
        fi
    fi

    if [ -n "$total_mem" ] && [ "$total_mem" -gt 0 ] && [ "$total_mem" -lt 1500 ]; then
        echo -e "${YELLOW}警告: 当前物理内存较低 (${total_mem}MB)，建议至少配置 1.5GB 内存。${NC}"
    fi

    # 磁盘检测 (使用 POSIX 标准 df -k，兼容 Linux 与 macOS)
    local free_disk_kb=""
    free_disk_kb=$(df -k . 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$free_disk_kb" ] && [[ "$free_disk_kb" =~ ^[0-9]+$ ]]; then
        local free_disk_gb=$((free_disk_kb / 1024 / 1024))
        if [ "$free_disk_gb" -lt 2 ]; then
            echo -e "${YELLOW}警告: 当前磁盘可用空间较低 (${free_disk_gb}GB)，建议保留至少 2GB 磁盘空间。${NC}"
        fi
    fi
}

# 容器服务健康等待
wait_for_health() {
    echo -e "${CYAN}正在等待 TestNet 核心服务完成初始化...${NC}"
    local max_attempts=25
    local attempt=0
    local healthy=false
    
    while [ $attempt -lt $max_attempts ]; do
        local server_status=""
        if command -v docker >/dev/null 2>&1; then
            server_status=$(docker inspect --format='{{json .State.Health.Status}}' testnet-server 2>/dev/null | tr -d '"')
        fi
        
        if [ "$server_status" = "healthy" ]; then
            healthy=true
            break
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    echo ""
    
    if [ "$healthy" = "true" ]; then
        echo -e "${GREEN}[√] TestNet 核心服务已成功初始化并就绪。${NC}"
    else
        echo -e "${YELLOW}服务已启动，后台正继续加载数据库与配置...${NC}"
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
        echo -e "${RED}Error: Cannot connect to Docker daemon.${NC}"
        echo -e "${YELLOW}如果以非 root 用户运行，请确认 Docker 服务已启动且当前用户已加入 docker 用户组：${NC}"
        echo -e "${YELLOW}  sudo usermod -aG docker \$USER && newgrp docker${NC}"
        echo -e "${YELLOW}或者尝试使用 sudo 执行此脚本。${NC}"
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

    check_resources
    check_port_conflict 3100
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
            default_choice="${PROBED_CHOICE:-1}"
            default_desc="${PROBED_DESC:-DockerHub (Docker Hub 源)}"
            
            echo -e "${CYAN}请选择镜像源 (Choose Mirror Source):${NC}"
            echo -e "网络探测推荐: ${GREEN}${default_choice}) ${default_desc}${NC}"
            echo "1) DockerHub (Docker Hub 源)"
            echo "2) 阿里云 (Alibaba Cloud - 中国加速)"
            
            registry_choice=""
            echo -n -e "${YELLOW}请输入选项 [1-2, 默认$default_choice] (10秒内未输入将自动使用推荐源): ${NC}"
            read -t 10 registry_choice || true
            echo ""
            
            if [ -z "$registry_choice" ]; then
                registry_choice="$default_choice"
                echo -e "${GREEN}[√] 10秒超时未输入，已自动采用推荐源: ${registry_choice}) ${default_desc}${NC}"
            else
                echo -e "${GREEN}[√] 您已手动选择: ${registry_choice}${NC}"
            fi
            
            case "$registry_choice" in
                2)
                    SELECTED_REGISTRY_URL="registry.cn-hangzhou.aliyuncs.com/testnet0/"
                    DOWNLOAD_BASE_URL="https://cnb.cool/testnet0/testnet-public/-/git/raw/main"
                    VERSION_URL="https://cnb.cool/testnet0/testnet-public/-/git/raw/main/version.yml"
                    ;;
                *)
                    SELECTED_REGISTRY_URL="testnet0/"
                    DOWNLOAD_BASE_URL="https://raw.githubusercontent.com/testnet0/testnet/main"
                    VERSION_URL="https://raw.githubusercontent.com/testnet0/testnet/main/version.yml"
                    ;;
            esac
        fi

        if [ ! -f .env ]; then
            echo -e "${YELLOW}Creating .env file with dynamic secrets...${NC}"
            ADMIN_PASSWORD=$(generate_admin_password 16)
            DEFAULT_NODE_NAME="Node-$(hostname 2>/dev/null || echo 'Default')"
            echo "DB_ROOT_PASSWORD=$(generate_random_string)" > .env
            echo "REDIS_PASSWORD=$(generate_random_string)" >> .env
            echo "JWT_SECRET=$(generate_random_string)" >> .env
            echo "TESTNET_CLIENT_SECRET=$(generate_random_string)" >> .env
            echo "ADMIN_INIT_PASSWORD=${ADMIN_PASSWORD}" >> .env
            echo "DOCKER_REGISTRY=$SELECTED_REGISTRY_URL" >> .env
            echo "CORS_ALLOWED_ORIGINS=*" >> .env
            echo "TESTNET_VERSION=$VERSION" >> .env
            echo "TESTNET_NODE_NAME=${DEFAULT_NODE_NAME}" >> .env
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
            if ! grep -q "TESTNET_NODE_NAME" .env; then
                DEFAULT_NODE_NAME="Node-$(hostname 2>/dev/null || echo 'Default')"
                echo "TESTNET_NODE_NAME=${DEFAULT_NODE_NAME}" >> .env
                echo -e "${GREEN}Added TESTNET_NODE_NAME to .env (${DEFAULT_NODE_NAME}).${NC}"
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

        echo -e "${CYAN}正在拉取最新 Docker 镜像...${NC}"
        $DOCKER_COMPOSE_CMD pull
        if [ $? -ne 0 ]; then
            echo -e "${RED}错误: 拉取 Docker 镜像失败！${NC}"
            echo -e "${YELLOW}请检查网络连接或重新运行脚本选择其他镜像源 (如 阿里云源) 后重试。${NC}"
            exit 1
        fi

        echo -e "${CYAN}Launching containers...${NC}"
        if ! $DOCKER_COMPOSE_CMD up -d; then
            echo -e "${YELLOW}检测到重名的旧容器冲突，正在自动清理残留容器重试...${NC}"
            docker rm -f testnet-redis testnet-db testnet-server testnet-web testnet-client 2>/dev/null || true
            $DOCKER_COMPOSE_CMD up -d
            check_status "Container launch" "true"
        fi
        
        wait_for_health
        
        host_ip=$(get_host_ip)
        echo -e "${GREEN}TestNet installed successfully!${NC}"
        echo -e "${CYAN}Access URL:${NC}"
        if [ "$host_ip" != "127.0.0.1" ] && [ "$host_ip" != "localhost" ]; then
            echo -e "${CYAN}  - 局域网访问: https://${host_ip}:3100${NC}"
        fi
        echo -e "${CYAN}  - 本地访问:   https://localhost:3100${NC}"
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
        # 捕获本地已安装版本，必须在 fetch_latest_version 之前读取：
        # fetch_latest_version 会 export TESTNET_VERSION=$VERSION（远端版本），
        # 若在此之后读取 local_version，则 VERSION == local_version 恒成立，
        # 导致 sync_latest_files 永不触发，配置文件（docker-compose.yml 等）无法同步。
        local_version="${TESTNET_VERSION:-}"
        fetch_latest_version
        check_env
        check_certs

        # 自动同步配置文件并更新脚本
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

        echo -e "${CYAN}正在拉取最新 Docker 镜像...${NC}"
        $DOCKER_COMPOSE_CMD pull
        if [ $? -ne 0 ]; then
            echo -e "${RED}错误: 拉取 Docker 镜像失败！${NC}"
            echo -e "${YELLOW}请检查网络连接或重新运行脚本选择其他镜像源后重试。${NC}"
            exit 1
        fi
        
        echo -e "${CYAN}Updating and rebuilding...${NC}"
        if ! $DOCKER_COMPOSE_CMD up -d --remove-orphans; then
            echo -e "${YELLOW}检测到重名的旧容器冲突，正在自动清理残留容器重试...${NC}"
            docker rm -f testnet-redis testnet-db testnet-server testnet-web testnet-client 2>/dev/null || true
            $DOCKER_COMPOSE_CMD up -d --remove-orphans
            check_status "Update"
        fi
        
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
