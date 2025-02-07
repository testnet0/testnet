#!/bin/bash

# Functions for messages
info() { echo -e "\033[37m[TestNet] $*\033[0m"; }
warning() { echo -e "\033[33m[TestNet] $*\033[0m"; }
error() { echo -e "\033[31m[TestNet] $*\033[0m"; }
abort() {
    echo -e "\033[31m[TestNet] $*\033[0m"
    echo "
如果遇到安装问题，建议查看帮助文档：https://testnet.shengkai.wang/guide/%E5%AE%89%E8%A3%85%E6%8A%A5%E9%94%99.html
如果没有找到你的问题，请到 https://github.com/testnet0/testnet/issues"
    echo_qrcode && exit 1
}

echo_qrcode() {
    echo "加入用户交流群：
            █████████████████████████████████████
            █████████████████████████████████████
            ████ ▄▄▄▄▄ █▀█ █▄▄▀▀ █▄█ █ ▄▄▄▄▄ ████
            ████ █   █ █▀▀▀█ ▀█▄▀██▀▄█ █   █ ████
            ████ █▄▄▄█ █▀ █▀▀▄▀  █▄█ █ █▄▄▄█ ████
            ████▄▄▄▄▄▄▄█▄▀ ▀▄█ █ █▄▀ █▄▄▄▄▄▄▄████
            ████   ▄ █▄  ▄▀▄   ▄▀█▀ █ ▀ ▀▄█▄▀████
            ████▀ ▄▄ ▄▄  █▄█▀█▀ ▀███ ▄▀  ▀█▀█████
            ████▀▀▀ █ ▄█ ▄▄▀▀ ▄▄ ▄█ ▀▀▀▀▀▄▄█▀████
            ████▀ ▀▄  ▄▄▄▄ ██▄█ ▄▄▄▀  ▄ ▀▄▄▀█████
            ████▀█▄▀▀▄▄▄▀▀▄ ▀▀  ▀▄▄ ▀▀▀ ▀▄ █▀████
            ████ ██▀▀▀▄▄ ██▀▀▄ ▄ █▀▀▄▄█▀██▄▀█████
            ████▄█▄█▄▄▄▄▀  ▀█▄▀    █ ▄▄▄ ▀   ████
            ████ ▄▄▄▄▄ █▄█▀▀██▄▄ ██  █▄█ ▄▄▀█████
            ████ █   █ █ ▀█ ▀▄▄▄▀▄██ ▄▄▄▄▀ ▄▀████
            ████ █▄▄▄█ █ ▄ █ █▀ ▀█ ▄ █▄▀  ▄ █████
            ████▄▄▄▄▄▄▄█▄████▄█▄█▄███▄█▄▄▄▄██████
            █████████████████████████████████████
            █████████████████████████████████████
          "
}
# Trap for clean exit
trap 'abort "用户手动结束操作"' INT

# Check if a command exists
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Confirmation prompt
confirm() {
    echo -e -n "\033[36m[TestNet] $* \033[1;36m(Y/n)\033[0m"
    read -n 1 -s opt
    [[ "$opt" == $'\n' ]] || echo
    [[ "$opt" =~ [yY] ]] && return 0 || [[ "$opt" =~ [nN] ]] && return 1 || confirm "$*"
}

# Check environment dependencies
check_dependencies() {
    [[ -z "$BASH" ]] && abort "请用 bash 执行本脚本"
    [[ ! -t 0 ]] && abort "STDIN 不是标准的输入设备"
    os_type=$(uname)
    if [ "$os_type" = "Linux" ]; then
        if [[ "$EUID" -ne "0" ]]; then
            echo "请以 root 权限运行"
            abort "中止安装"
        fi
    fi
    if ! command_exists docker; then
        warning "缺少 Docker 环境"
        confirm "是否需要自动安装 Docker" && install_docker || abort "中止安装"
    fi

    docker version >/dev/null 2>&1 || abort "Docker 服务工作异常"

    compose_command="docker compose"
    if $compose_command version >/dev/null 2>&1; then
        info "发现 Docker Compose Plugin"
    else
        warning "未发现 Docker Compose Plugin"
        compose_command="docker-compose"
        if ! command_exists "docker-compose"; then
            warning "未发现 docker-compose 组件"
            if confirm "是否需要自动安装 Docker Compose Plugin"; then
                curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                chmod +x /usr/local/bin/docker-compose
                if [ $? -ne 0 ]; then
                    abort "Docker Compose Plugin 安装失败"
                fi
                info "Docker Compose Plugin 安装完成"
            else
                abort "中止安装"
            fi
        else
            info "发现 docker-compose 组件: '$(command -v docker-compose)'"
            if ! $compose_command up -d --help >/dev/null 2>&1; then
                warning "Docker Compose Plugin 不支持 '-d' 参数"
                confirm "是否需要自动升级 Docker Compose Plugin" && install_docker_compose || abort "中止安装"
            fi
        fi
    fi
    start_docker
    info "docker环境确认正常"
}

# Start Docker service
start_docker() {
    systemctl enable docker
    systemctl daemon-reload
    systemctl start docker
}

# Get the average delay for a source
get_average_delay() {
    local source=$1 total_delay=0 iterations=3
    for ((i = 0; i < iterations; i++)); do
        delay=$(curl -o /dev/null -m 1 -s -w "%{time_total}\n" "$source" || echo "999")
        total_delay=$(awk "BEGIN {print $total_delay + $delay}")
    done
    echo $(awk "BEGIN {print $total_delay / $iterations}")
}

# Get local IP addresses
local_ips() {
    command_exists ip && ip addr show | grep -Eo 'inet ([0-9]*\.){3}[0-9]*' | awk '{print $2}' || ifconfig -a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | awk '{print $2}'
}

# Install Docker
install_docker() {
    local sources=("https://mirrors.aliyun.com/docker-ce" "https://mirrors.tencent.com/docker-ce" "https://download.docker.com")
    local min_delay=999 selected_source=""
    for source in "${sources[@]}"; do
        average_delay=$(get_average_delay "$source")
        echo "source: $source, delay: $average_delay"
        (($(awk 'BEGIN {print '"$average_delay"' < '"$min_delay"' }'))) && min_delay=$average_delay && selected_source=$source
    done
    echo "selected source: $selected_source"
    export DOWNLOAD_URL="$selected_source"
    bash get-docker.sh
    start_docker
    docker version >/dev/null 2>&1 || abort "Docker 安装失败"
    info "Docker 安装成功"
}

# Install Docker Compose
install_docker_compose() {
    local url="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
    curl -L "$url" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    docker-compose version >/dev/null 2>&1 || abort "Docker Compose 安装失败"
    info "Docker Compose 安装成功"
}

# Create .env file
create_env_file() {
    chmod 755 ./db
    if [[ -f ".env" ]] && grep -q '^IMAGE_PREFIX=' .env && grep -q '^SUBNET_PREFIX=' .env; then
        info ".env 文件已存在"
    else
        touch ".env"
        if [ $? -ne 0 ]; then
            warning "创建 .env 文件失败"
        else
            echo "创建 .env 文件成功"
            if confirm "是否使用国内加速"; then
                echo "IMAGE_PREFIX=registry.cn-hangzhou.aliyuncs.com/testnet0" >>".env"
            else
                echo "IMAGE_PREFIX=testnet0" >>".env"
            fi
            echo "REDIS_PASSWORD=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 32)" >>.env
            echo "MYSQL_PASSWORD=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 32)" >>.env
            echo "TESTNET_API_TOKEN=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 32)" >>.env
            echo "TESTNET_GRPC_TOKEN=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 32)" >>.env

            echo "SUBNET_PREFIX=172.16.1" >>.env
            echo "AI_ENABLE=false" >>.env
            echo "AI_MODEL=deepseek-chat" >>.env
            echo "AI_API_KEY=xxx" >>.env
            echo "AI_API_HOST=https://api.deepseek.com" >>.env
        fi
    fi
}

# Update TestNet
update_testnet() {
    info "开始更新 TestNet..."
    # 检查当前运行的容器是否包含 testnet-client 和 testnet-server
    if docker ps --filter "name=testnet-client" | grep -q "testnet-client" &&
        docker ps --filter "name=testnet-server" | grep -q "testnet-server"; then
        info "开始更新服务端和客户端"
        compose_file="docker-compose.yml"
    elif docker ps --filter "name=testnet-client" | grep -q "testnet-client"; then
        info "开始更新服务端和客户端"
        compose_file="docker-compose-client.yml"
    else
        abort "没有找到相关的容器，无法更新"
    fi

    # 根据选定的 compose_file 执行更新操作
    $compose_command -f $compose_file down && $compose_command -f $compose_file pull && $compose_command -f $compose_file up -d || abort "更新失败"

    info "TestNet 更新完成"
}
# Start TestNet
start_testnet() {
    create_env_file
    $compose_command up -d || abort "启动 Docker 容器失败"
    show_access_urls
}

# Start TestNet server
start_testnet_server() {
    create_env_file
    $compose_command -f docker-compose-server.yml up -d || abort "启动 Docker 容器失败"
    show_access_urls
}

# Start TestNet client
start_testnet_client() {
    [[ -f ".env" ]] && grep -q '^IP=' .env && grep -q '^CLIENT_NAME=' .env && $compose_command -f docker-compose-client.yml up -d && echo "客户端启动成功" && echo_qrcode || abort "请先配置IP和客户端名称，参考：https://testnet.shengkai.wang/guide/%E8%8A%82%E7%82%B9%E5%88%86%E5%B8%83%E5%BC%8F%E9%83%A8%E7%BD%B2.html"
}

# Show access URLs
show_access_urls() {
    check_health_status
    warning "TestNet安装成功"
    warning "后台访问地址：https://IP:8099/"
    docker logs testnet-server | grep '随机密码：'
    for ip in $ips; do
        warning "https://$ip:8099/"
    done
    echo_qrcode
}
# Check container health status
check_health_status() {
    local services=("testnet-mysql" "testnet-redis" "testnet-server" "testnet-frontend")
    local timeout=300 interval=5 elapsed=0
    info "等待服务启动中，请稍后..."
    while [[ $elapsed -lt $timeout ]]; do
        all_healthy=true
        for service in "${services[@]}"; do
            status=$(docker inspect --format='{{json .State.Health.Status}}' "$service" || echo "unhealthy")
            [[ $status != "\"healthy\"" ]] && all_healthy=false && break
        done
        $all_healthy && info "服务端容器健康状态正常" && return 0
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    warning "容器未能在 $timeout 秒内进入健康状态"
}

remove_all_containers_and_data() {
    confirm "是否要删除所有数据？" || abort "取消"
    # 停止所有包含 testnet 前缀的容器
    docker stop $(docker ps -q --filter "name=testnet")
    # 删除所有包含 testnet 前缀的容器
    docker rm -f $(docker ps -a -q --filter "name=testnet")
    docker images | grep testnet0 | awk '{print $3}' | xargs docker rmi
    rm -rf ./data
    rm -f .env
}

reset_password() {
    confirm "是否要重置密码？" || abort "取消"
    # 从 .env 文件中读取 MYSQL_PASSWORD
    PASSWORD=$(grep -E '^MYSQL_PASSWORD=' .env | cut -d '=' -f 2)

    if [ -z "$PASSWORD" ]; then
        echo "Error: MYSQL_PASSWORD not found in .env file."
        exit 1
    fi
    warning
    # 执行 Docker 和 MySQL 更新命令
    docker exec -it testnet-mysql bash -c "mysql -uroot -p$PASSWORD -e \"USE jeecg-boot; UPDATE sys_user SET password='cb362cfeefbf3d8d', salt='RCGTeGiH' WHERE id='e9ca23d68d884d4ebb19d07889727dae';\""
    if [ $? -eq 0 ]; then
        warning "密码重置为admin/123456,登录成功后请立即修改密码！"
    else
        echo "密码重置失败！"
    fi

}

show_logs() {
    $compose_command logs -f
}

# Main menu
main_menu() {
    clear
    echo "
    ████████╗███████╗███████╗████████╗███╗   ██╗███████╗████████╗
    ╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝████╗  ██║██╔════╝╚══██╔══╝
       ██║   █████╗  ███████╗   ██║   ██╔██╗ ██║█████╗     ██║
       ██║   ██╔══╝  ╚════██║   ██║   ██║╚██╗██║██╔══╝     ██║
       ██║   ███████╗███████║   ██║   ██║ ╚████║███████╗   ██║
       ╚═╝   ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═══╝╚══════╝   ╚═╝
    "
    echo -e "\033[33m===================================================="
    echo -e "#                                                  "
    echo -e "# 欢迎使用 TestNet安装工具                            "
    echo -e "# 最新版本: 1.9                                      "
    echo -e "# Author: testnet                                   "
    echo -e "# Date: $(date +"%Y-%m-%d %H:%M:%S")                "
    echo -e "#                                                   "
    echo -e "====================================================\033[0m"
    echo "1. 一键安装 TestNet服务端 + 客户端（推荐配置：内存>4G ）"
    echo "2. 仅安装 TestNet服务端（推荐配置：公网IP，内存>2G）"
    echo "3. 仅安装 TestNet客户端（推荐配置：内存>2G）"
    echo "4. 更新 TestNet"
    echo "5. 删除所有容器和数据"
    echo "6. 查看日志"
    echo "7. 重置密码"
    echo "0. 退出"
    echo -n "请输入数字进行操作："
    read opt
    case $opt in
    1) start_testnet ;;
    2) start_testnet_server ;;
    3) start_testnet_client ;;
    4) update_testnet ;;
    5) remove_all_containers_and_data ;;
    6) show_logs ;;
    7) reset_password ;;
    0) exit 0 ;;
    *) warning "无效的选项" ;;
    esac
    echo -e "\033[1;33m按任意键返回主菜单...\033[0m"
    read -n 1 -s
    main_menu
}

# Initialize and start menu
ips=$(local_ips)
check_dependencies
main_menu
