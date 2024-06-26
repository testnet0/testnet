#!/bin/bash

echo "
████████╗███████╗███████╗████████╗███╗   ██╗███████╗████████╗
╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝████╗  ██║██╔════╝╚══██╔══╝
   ██║   █████╗  ███████╗   ██║   ██╔██╗ ██║█████╗     ██║
   ██║   ██╔══╝  ╚════██║   ██║   ██║╚██╗██║██╔══╝     ██║
   ██║   ███████╗███████║   ██║   ██║ ╚████║███████╗   ██║
   ╚═╝   ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═══╝╚══════╝   ╚═╝
"

# 检查命令
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

confirm() {
    echo -e -n "\033[36m[TestNet] $* \033[1;36m(Y/n)\033[0m"
    read -n 1 -s opt

    [[ "$opt" == $'\n' ]] || echo

    case "$opt" in
        'y' | 'Y' ) return 0;;
        'n' | 'N' ) return 1;;
        *) confirm "$1";;
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
    abort "用户手动结束安装"
}

testnet_path='/data/testnet'

if [ -z "$BASH" ]; then
    abort "请用 bash 执行本脚本"
fi

if [ ! -t 0 ]; then
    abort "STDIN 不是标准的输入设备"
fi

if [ "$#" -ne 0 ]; then
    abort "当前脚本无需任何参数"
fi

info "脚本调用方式确认正常"

if ! command_exists docker; then
    warning "缺少 Docker 环境"
    if confirm "是否需要自动安装 Docker"; then
        if ! curl -sSLk https://get.docker.com/ | bash -s -- --mirror; then
            abort "Docker 安装失败，请检查网络连接或尝试手动安装"
        fi
        info "Docker 安装完成"
    else
        abort "中止安装"
    fi
fi

info "发现 Docker 环境: '$(command -v docker)'"

docker version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    abort "Docker 服务工作异常"
fi
info "Docker 工作状态正常"

compose_command="docker compose"
if $compose_command version; then
    info "发现 Docker Compose Plugin"
else
    warning "未发现 Docker Compose Plugin"
    compose_command="docker-compose"
    if [ -z `command_exists "docker-compose"` ]; then
        warning "未发现 docker-compose 组件"
        if confirm "是否需要自动安装 Docker Compose Plugin"; then
            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            if [ $? -ne 0 ]; then
                abort "Docker Compose Plugin 安装失败"
            fi
            info "Docker Compose Plugin 安装完成"
            compose_command="docker compose"
        else
            abort "中止安装"
        fi
    else
        info "发现 docker-compose 组件: '`command -v docker-compose`'"
    fi
fi

# 检查是否已经存在 .env 文件
if [ -f ".env" ]; then
    echo "文件已存在"
else
    # 如果不存在，则创建 .env 文件
    touch ".env"
    if [ $? -ne 0 ]; then
        echo "创建 .env 文件失败"
    else
        echo "创建 .env 文件成功"
        echo "REDIS_PASSWORD=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 32)" >> .env
        echo "MYSQL_PASSWORD=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 32)" >> .env
        echo "SUBNET_PREFIX=172.16.1" >> .env
    fi
fi

# 检查ES文件夹
if [ -d "./es_data" ]; then
    echo "文件夹已存在"
else
    # 如果不存在，则创建 es_data 文件夹
    mkdir "./es_data"
    if [ $? -ne 0 ]; then
        echo "创建 ./es_data 文件夹失败"
    else
        chmod 777 ./es_data
        if [ $? -ne 0 ]; then
            echo "设置 ./es_data 文件夹权限失败"
        else
            echo "成功创建并设置 ./es_data 文件夹"
        fi
    fi
fi

$compose_command up -d

warning "TestNet安装成功，请稍等2分钟打开后台登录..."
warning "后台访问地址：http://IP:8099/"

if confirm "是否需要自动安装运行环境"; then
  docker exec testnet-client /bin/bash -c "cd /testnet-client && chmod +x ./start.sh && ./start.sh"
else
 abort "取消安装运行环境"
fi
