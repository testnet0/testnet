#!/bin/bash

echo "
████████╗███████╗███████╗████████╗███╗   ██╗███████╗████████╗
╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝████╗  ██║██╔════╝╚══██╔══╝
   ██║   █████╗  ███████╗   ██║   ██╔██╗ ██║█████╗     ██║
   ██║   ██╔══╝  ╚════██║   ██║   ██║╚██╗██║██╔══╝     ██║
   ██║   ███████╗███████║   ██║   ██║ ╚████║███████╗   ██║
   ╚═╝   ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═══╝╚══════╝   ╚═╝
"

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

confirm() {
    echo -e -n "\033[36m[TestNet] $* \033[1;36m(Y/n)\033[0m"
    read -n 1 -s opt

    [[ "$opt" == $'\n' ]] || echo

    case "$opt" in
    'y' | 'Y') return 0 ;;
    'n' | 'N') return 1 ;;
    *) confirm "$1" ;;
    esac
}

info() {
    echo -e "\033[37m[TestNet] $*\033[0m"
}

warning() {
    echo -e "\033[33m[TestNet] $*\033[0m"
}

abort() {
    echo -e "\033[31m[TestNet] $*\033[0m"
    exit 1
}

trap 'onexit' INT
onexit() {
    echo
    abort "用户手动结束操作"
}

check_depend() {
    if [ -z "$BASH" ]; then
        abort "请用 bash 执行本脚本，请参考最新的官方技术文档 https://waf-ce.chaitin.cn/"
    fi
    if [ ! -t 0 ]; then
        abort "STDIN 不是标准的输入设备，请参考最新的官方技术文档 https://waf-ce.chaitin.cn/"
    fi
    if [ "$EUID" -ne "0" ]; then
        abort "请以 root 权限运行"
    fi
    if ! command_exists docker; then
        warning "缺少 Docker 环境"
        if confirm "是否需要自动安装 Docker"; then
            install_docker
        else
            abort "中止安装"
        fi
    fi
    info "发现 Docker 环境: '$(command -v docker)'"
    docker version >/dev/null 2>&1
    if [ $? -ne "0" ]; then
        abort "Docker 服务工作异常"
    fi
    compose_command="docker compose"
    if $compose_command version; then
        info "发现 Docker Compose Plugin"
    else
        compose_command="docker-compose"
        if $compose_command version; then
            info "发现 Docker Compose"
        else
          warning "未发现 Docker Compose Plugin"
          if confirm "是否需要自动安装 Docker Compose Plugin"; then
            install_docker_compose
          else
            abort "中止安装"
          fi
        fi
    fi

    # check docker compose support -d
    if ! $compose_command up -d --help >/dev/null 2>&1; then
        warning "Docker Compose Plugin 不支持 '-d' 参数"
        if confirm "是否需要自动升级 Docker Compose Plugin"; then
            install_docker_compose
        else
            abort "中止安装"
        fi
    fi
    start_docker
    info "安装环境确认正常"
}

start_docker() {
    systemctl enable docker
    systemctl daemon-reload
    systemctl start docker
}

get_average_delay() {
    local source=$1
    local total_delay=0
    local iterations=3

    for ((i = 0; i < iterations; i++)); do
        # check timeout
        if ! curl -o /dev/null -m 1 -s -w "%{http_code}\n" "$source" >/dev/null; then
            delay=999
        else
            delay=$(curl -o /dev/null -s -w "%{time_total}\n" "$source")
        fi
        total_delay=$(awk "BEGIN {print $total_delay + $delay}")
    done

    average_delay=$(awk "BEGIN {print $total_delay / $iterations}")
    echo "$average_delay"
}

local_ips() {
    if command_exists ip; then
        ip addr show | grep -Eo 'inet ([0-9]*\.){3}[0-9]*' | awk '{print $2}'
    else
        ifconfig -a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | awk '{print $2}'
    fi
}

install_docker() {
    sources=(
        "https://mirrors.aliyun.com/docker-ce"
        "https://mirrors.tencent.com/docker-ce"
        "https://download.docker.com"
    )
    min_delay=${#sources[@]}
    selected_source=""
    for source in "${sources[@]}"; do
        average_delay=$(get_average_delay "$source")
        echo "source: $source, delay: $average_delay"
        if (($(awk 'BEGIN { print '"$average_delay"' < '"$min_delay"' }'))); then
            min_delay=$average_delay
            selected_source=$source
        fi
    done

    echo "selected source: $selected_source"
    export DOWNLOAD_URL="$selected_source"
    bash get-docker.sh

    start_docker
    docker version >/dev/null 2>&1
    if [ $? -ne "0" ]; then
        echo "Docker 安装失败, 请检查网络连接或手动安装 Docker"
        echo "参考文档: https://docs.docker.com/engine/install/"
        abort "Docker 安装失败"
    fi
    info "Docker 安装成功"
}

install_docker_compose() {
    DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
    curl -L $DOCKER_COMPOSE_URL -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    docker-compose version >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        abort "Docker Compose 安装失败"
    fi
    info "Docker Compose 安装成功"
}

ips=$(local_ips)
check_depend

create_env_file() {
    if [ -f ".env" ]; then
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
            echo "SUBNET_PREFIX=172.16.1" >>.env
            echo "GPT_ENABLE=false" >>.env
            echo "GPT_KEY=xxx" >>.env
            echo "GPT_HOST=https://api.openai.com" >>.env
        fi
    fi
}

create_es_data_folder() {
    if [ -d "./es_data" ]; then
        info "文件夹已存在"
    else
        mkdir "./es_data"
        if [ $? -ne 0 ]; then
            abort "创建 /es_data 文件夹失败"
        fi
    fi
    chmod 777 ./es_data
    if [ $? -ne 0 ]; then
        abort "设置 ./es_data 文件夹权限失败"
    else
        info "成功创建并设置 ./es_data 文件夹"
    fi
}

update_testnet_server() {
    info "开始更新 TestNet 服务端..."
    create_env_file
    create_es_data_folder
    git pull
    if [ $? -ne "0" ]; then
        abort "更新失败,请检查网络情况"
    fi
    # 判断.env是否存在 TESTNET_API_TOKEN
    if ! grep -q '^TESTNET_API_TOKEN=' .env; then
        echo "TESTNET_API_TOKEN=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 32)" >>.env
    fi
    $compose_command stop testnet-server testnet-frontend testnet-mysql testnet-redis testnet-es
    $compose_command rm -f testnet-server testnet-frontend testnet-mysql testnet-redis testnet-es
    $compose_command pull testnet-server testnet-frontend testnet-mysql testnet-redis testnet-es
    $compose_command up -d testnet-server testnet-frontend testnet-mysql testnet-redis testnet-es
    info "TestNet 服务端更新完成"
}

update_testnet_client() {
    info "开始更新 TestNet客户端..."
    if confirm "是否需要更新客户端？已安装工具需要重新安装"; then
        if grep -q '^IP=' .env; then
            info "分布式部署方式"
            docker compose -f docker-compose-client.yml down
            docker compose -f docker-compose-client.yml pull
            docker compose -f docker-compose-client.yml up -d
        else
            info "单机部署方式"
            $compose_command stop testnet-client
            $compose_command rm -f testnet-client
            $compose_command pull testnet-client
            $compose_command up -d testnet-client
        fi
    else
        abort "取消安装运行环境"
    fi
    info "TestNet 客户端更新完成"
}
start_testnet() {
    create_env_file
    create_es_data_folder
    $compose_command up -d
    if [ $? -ne "0" ]; then
        abort "启动 Docker 容器失败，建议查看文档: https://m55giu8f62.feishu.cn/wiki/EjLRwwPdciVKY2kMT8icAzvgnbb?fromScene=spaceOverview"
    fi
    warning "TestNet安装成功，请稍等2分钟打开后台登录..."
    warning "后台访问地址：https://IP:8099/"
    for ip in $ips; do
        warning "https://$ip:8099/"
    done
}

start_testnet_server() {
    create_env_file
    create_es_data_folder
    $compose_command -f docker-compose-server.yml up -d
    if [ $? -ne "0" ]; then
        abort "启动 Docker 容器失败，建议查看文档: https://m55giu8f62.feishu.cn/wiki/EjLRwwPdciVKY2kMT8icAzvgnbb"
    fi
    warning "TestNet安装成功，请稍等2分钟打开后台登录..."
    warning "后台访问地址：https://0.0.0.0:8099/"
    for ip in $ips; do
        warning "https://$ip:8099/"
    done
}

start_testnet_client() {
    if [ -f ".env" ]; then
        if ! grep -q '^IP=' .env; then
            abort "请先配置IP"
        fi
        if ! grep -q '^CLIENT_NAME=' .env; then
            abort "请先配置IP"
        fi
        $compose_command -f docker-compose-client.yml up -d
        if [ $? -ne "0" ]; then
            abort "启动 Docker 容器失败，建议查看文档: https://m55giu8f62.feishu.cn/wiki/EjLRwwPdciVKY2kMT8icAzvgnbb"
        fi
    else
        abort "请先复制服务端配置文件到客户端，帮助文档：https://m55giu8f62.feishu.cn/wiki/UmHtwhJTJihK6Ekr7ILcjRG9nFy"
    fi
}

# 检查容器健康状态
check_health_status() {
    services=("testnet-mysql" "testnet-redis" "testnet-es")

    while true; do
        all_healthy=true
        for service in "${services[@]}"; do
            health_status=$(docker inspect --format='{{json .State.Health.Status}}' "$service" 2>/dev/null)
            if [[ "$health_status" != '"healthy"' ]]; then
                all_healthy=false
                info "$service 容器健康状态: $health_status"
                break
            fi
        done

        if $all_healthy; then
            info "所有服务容器都处于健康状态，安装成功！"
            break
        else
            warning "正在安装中，请稍后..."
            sleep 10
        fi
    done
}

remove_all_containers_and_data() {
    $compose_command stop testnet-server testnet-frontend testnet-mysql testnet-redis testnet-es testnet-client
    $compose_command rm -f testnet-server testnet-frontend testnet-mysql testnet-redis testnet-es testnet-client
    docker images | grep testnet0 | awk '{print $3}' | xargs docker rmi
    rm -rf ./es_data
    rm -f .env
    rm -rf ./mysql_data
    rm -rf ./client_data
}

echo "请选择操作："
echo "1) 一键安装 TestNet服务端 + 客户端 (testnet-server testnet-frontend testnet-client)"
echo "2) 单独安装 TestNet服务端 (testnet-server testnet-frontend)"
echo "3) 单独安装 TestNet客户端(testnet-client)"
echo "4) 更新服务端 (testnet-server testnet-frontend)"
echo "5) 更新客户端 (testnet-client)"
echo "6) 删除所有容器和数据"
read -p "输入数字选择操作: " user_choice

case $user_choice in
1)
    start_testnet
    check_health_status
    ;;
2)
    start_testnet_server
    check_health_status
    ;;
3)
    start_testnet_client
    ;;
4)
    update_testnet_server
    check_health_status
    ;;
5)
    update_testnet_client
    ;;
6)
    remove_all_containers_and_data
    ;;
*)
    abort "无效选择，退出脚本"
    ;;
esac
