#!/bin/bash

# TestNet 引导安装脚本 (install.sh - 在线引导器)
# 职责：基础依赖检查、下载部署资源，并把安装与控制交付给 testnet.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CNB_BASE_URL="https://cnb.cool/testnet0/testnet-public/-/git/raw/main"
GITHUB_BASE_URL="https://raw.githubusercontent.com/testnet0/testnet/main"

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

# 静默探测最快下载源
detect_download_source() {
    echo -e "${CYAN}[1/3] 正在检测最快下载节点...${NC}"
    local cnb_status=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 2 "$CNB_BASE_URL/version.yml")
    if [ "$cnb_status" = "200" ]; then
        SELECTED_SOURCE="$CNB_BASE_URL"
        echo -e "${GREEN}[√] 已选择国内下载节点 (CNB)${NC}"
    else
        SELECTED_SOURCE="$GITHUB_BASE_URL"
        echo -e "${GREEN}[√] 已选择国际下载节点 (GitHub)${NC}"
    fi
}

# 检查并自动安装基础 Docker 环境
check_docker() {
    echo -e "\n${CYAN}[2/3] 正在检查 Docker 环境...${NC}"
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${YELLOW}未检测到 Docker，准备自动安装...${NC}"
        curl -fsSL https://get.docker.com | bash -s docker
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Docker 安装失败，请手动安装后重试。${NC}"
            exit 1
        fi
        systemctl enable --now docker 2>/dev/null || true
    fi
    echo -e "${GREEN}[√] Docker 已就绪: $(docker --version)${NC}"
}

# 下载所需部署清单与文件
download_resources() {
    echo -e "\n${CYAN}[3/3] 正在同步部署文件与清单...${NC}"
    
    mkdir -p testnet-deploy && cd testnet-deploy

    echo -n -e "  - 拉取版本清单 (version.yml) ... "
    curl -sSL "$SELECTED_SOURCE/version.yml" -o "version.yml"
    if grep -qE "^\{|^<html>" "version.yml"; then
        echo -e "${RED}失败 (远程文件不可达)${NC}"
        exit 1
    fi
    echo -e "${GREEN}成功${NC}"

    local files=($(grep -A 50 "^files:" version.yml | grep "^  -" | sed 's/^  - //'))
    if [ ${#files[@]} -eq 0 ]; then
        echo -e "${RED}Error: 无法从 version.yml 中解析到文件清单。${NC}"
        exit 1
    fi

    for entry in "${files[@]}"; do
        local file=$(echo "$entry" | cut -d':' -f1)
        if [ "$file" = "version.yml" ] || [ "$file" = "install.sh" ]; then
            continue
        fi
        
        local dir_part=$(dirname "$file")
        if [ "$dir_part" != "." ]; then
            mkdir -p "$dir_part"
        fi

        echo -n -e "  - 拉取 $file ... "
        curl -sSL "$SELECTED_SOURCE/$file" -o "$file"
        if [ $? -ne 0 ] || grep -qE "^\{|^<html>" "$file"; then
            echo -e "${RED}失败${NC}"
            exit 1
        fi
        echo -e "${GREEN}成功${NC}"
    done
    
    chmod +x testnet.sh gen-certs.sh 2>/dev/null || true
}

# 交付控制权给 testnet.sh 完成交互安装
start_installation() {
    echo -e "\n${GREEN}[√] 文件同步完成，正在启动 TestNet 管理引擎...${NC}\n"
    bash testnet.sh install
}

main() {
    print_header
    detect_download_source
    check_docker
    download_resources
    start_installation
}

main
