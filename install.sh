#!/bin/bash

# TestNet 引导安装脚本 (install.sh)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 资源配置
CNB_BASE_URL="https://cnb.cool/testnet0/testnet-public/-/git/raw/main"
GITHUB_BASE_URL="https://raw.githubusercontent.com/testnet0/testnet-public/main"

# 初始化变量
SELECTED_SOURCE=""
DOCKER_REGISTRY_MODE=1
FILES=()

# 打印 Header
print_header() {
    echo -e "${CYAN}"
    echo "================================================================"
    echo "       ___________              __  _______          __         "
    echo "      |           |____   _____/  | \      \   _____/  |_       "
    echo "      '---  |  ---| __ \ /  ___/  | /   |   \_/ __ \   __\      "
    echo "          |  |  |  ___/ \___ \ |  |/    |    \  ___/|  |        "
    echo "          |__|   \___  >____  >|__|\____|__  /\___  >__|        "
    echo "                     \/     \/             \/     \/          "
    echo "================================================================"
    echo -e "                 TestNet 一键安装工具${NC}\n"
}

# 探测最优下载源
select_mirror() {
    echo -e "${CYAN}正在通过网络探测选择最优下载源...${NC}"
    
    # 探测 CNB (国内优先)
    local cnb_status=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 2 "$CNB_BASE_URL/version.yml")
    if [ "$cnb_status" == "200" ]; then
        SELECTED_SOURCE=$CNB_BASE_URL
        DOCKER_REGISTRY_MODE=2
        echo -e "${GREEN}[√] 已选择国内节点 (CNB)，将自动配置阿里云镜像源。${NC}"
        return
    fi
    
    # 探测 GitHub
    local github_status=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 3 "$GITHUB_BASE_URL/version.yml")
    if [ "$github_status" == "200" ]; then
        SELECTED_SOURCE=$GITHUB_BASE_URL
        DOCKER_REGISTRY_MODE=1
        echo -e "${GREEN}[√] 已选择国际节点 (GitHub)，将自动配置 DockerHub 镜像源。${NC}"
        return
    fi
    
    echo -e "${RED}错误: 无法连接到资源服务器，请检查网络设置。${NC}"
    exit 1
}

# 检查并安装环境
check_environment() {
    echo -e "\n${CYAN}[1/3] 正在检查环境依赖...${NC}"
    
    # 检查 Docker
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${YELLOW}未检测到 Docker，准备自动安装...${NC}"
        curl -fsSL https://get.docker.com | bash -s docker
        if [ $? -ne 0 ]; then
            echo -e "${RED}Docker 安装失败，请手动安装后重试。${NC}"
            exit 1
        fi
        systemctl enable --now docker
    fi
    echo -e "${GREEN}[√] Docker 已就绪: $(docker --version)${NC}"
    
    # 检查 Docker Compose
    if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
        echo -e "${YELLOW}未检测到 Docker Compose，准备自动安装插件...${NC}"
        # 简单尝试通过包管理器安装
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y docker-compose-plugin
        elif command -v yum >/dev/null 2>&1; then
            yum install -y docker-compose-plugin
        else
            echo -e "${RED}无法自动安装 Docker Compose，请参考官方文档手动安装。${NC}"
            exit 1
        fi
    fi
    echo -e "${GREEN}[√] Docker Compose 已就绪${NC}"
}

# 下载所需文件
download_resources() {
    echo -e "\n${CYAN}[2/3] 正在同步部署清单与资源...${NC}"
    
    # 创建工作目录
    mkdir -p testnet-deploy && cd testnet-deploy

    # 1. 先下载 version.yml 以获取最新文件列表
    echo -n -e "正在拉取版本清单 (version.yml) ... "
    curl -sSL "$SELECTED_SOURCE/version.yml" -o "version.yml"
    
    if grep -qE "^\{|^<html>" "version.yml"; then
        echo -e "${RED}失败 (远程返回了无效内容，请检查仓库权限或路径)${NC}"
        exit 1
    fi
    echo -e "${GREEN}完成${NC}"

    # 2. 解析文件列表
    FILES=($(grep -A 50 "^files:" version.yml | grep "^  -" | sed 's/^  - //'))
    
    if [ ${#FILES[@]} -eq 0 ]; then
        echo -e "${RED}错误: 无法从 version.yml 中解析到文件列表。${NC}"
        exit 1
    fi

    # 3. 批量下载
    for entry in "${FILES[@]}"; do
        local file=$(echo "$entry" | cut -d':' -f1)
        local expected_md5=$(echo "$entry" | cut -d':' -f2)

        # 如果下载清单里包含 version.yml，跳过
        [ "$file" == "version.yml" ] && continue
        
        local filename=$(basename "$file")
        echo -n -e "正在拉取 $filename ... "
        curl -sSL "$SELECTED_SOURCE/$file" -o "$filename"
        
        # 验证文件内容
        if [ $? -ne 0 ] || grep -qE "^\{|^<html>" "$filename"; then
            echo -e "${RED}失败 (内容无效或不存在)${NC}"
            exit 1
        fi

        # 验证 MD5 哈希 (若提供了预期哈希值)
        if [ -n "$expected_md5" ] && [ "$expected_md5" != "$file" ]; then
            local downloaded_md5=""
            if command -v md5sum >/dev/null 2>&1; then
                downloaded_md5=$(md5sum "$filename" | cut -d' ' -f1)
            elif command -v md5 >/dev/null 2>&1; then
                downloaded_md5=$(md5 -q "$filename")
            fi
            
            if [ -n "$downloaded_md5" ] && [ "$downloaded_md5" != "$expected_md5" ]; then
                echo -e "${RED}失败 (MD5 校验不匹配: 期望 $expected_md5，实际 $downloaded_md5)${NC}"
                exit 1
            fi
        fi
        echo -e "${GREEN}完成${NC}"
    done
    
    chmod +x testnet.sh gen-certs.sh
}

# 启动交互安装
start_installation() {
    echo -e "\n${CYAN}[3/3] 资源下载完成，正在启动安装程序...${NC}"
    echo -e "${YELLOW}--------------------------------------------------------------${NC}"
    # 传递自动选择的镜像模式
    export SELECTED_REGISTRY=$DOCKER_REGISTRY_MODE
    bash testnet.sh install
}

# 执行流程
main() {
    print_header
    select_mirror
    check_environment
    download_resources
    start_installation
}

main
