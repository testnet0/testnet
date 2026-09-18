#!/bin/bash
# TestNet 扫描探针 · 二进制快速安装脚本 (install-client.sh)
#
# 用途: 在任意 Linux 机器上一键下载、配置并以 systemd 服务运行 testnet-client
# 使用: bash install-client.sh [选项]
#
# 选项:
#   -s, --server-url  <URL>    服务端地址，例如 https://your-server-ip:3100  (必填)
#   -k, --secret      <SECRET> 节点连接密码 TESTNET_CLIENT_SECRET             (必填)
#   -n, --node-name   <NAME>   节点名称，留空则自动使用主机名                   (可选)
#   -c, --concurrent  <NUM>    最大并发任务数，默认 5                           (可选)
#   -v, --version     <VER>    指定版本号，默认 latest                         (可选)
#   --no-systemd               仅下载解压，不安装 systemd 服务                  (可选)
#   --no-tls-verify            跳过 TLS 证书校验（自签名证书时使用）             (可选)
#   -h, --help                 显示帮助

set -euo pipefail

# ─── 颜色 ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── 默认参数 ────────────────────────────────────────────────────────────────
SERVER_URL=""
CLIENT_SECRET=""
NODE_NAME=""
MAX_CONCURRENT=5
VERSION="latest"
INSTALL_SYSTEMD=true
TLS_INSECURE=false

INSTALL_DIR="/opt/testnet/client"
BIN_NAME="testnet-client"
SERVICE_NAME="testnet-client"

CNB_RELEASE_BASE="https://cnb.cool/testnet0/testnet-public/-/releases/download"
GITHUB_RELEASE_BASE="https://github.com/testnet0/testnet/releases/download"

# ─── 帮助 ────────────────────────────────────────────────────────────────────
usage() {
    echo -e "${BOLD}用法:${NC}"
    echo "  bash install-client.sh -s <SERVER_URL> -k <SECRET> [选项]"
    echo ""
    echo -e "${BOLD}必填:${NC}"
    echo "  -s, --server-url  <URL>    服务端地址 (如 https://1.2.3.4:3100)"
    echo "  -k, --secret      <SECRET> 节点连接密码 (从服务端 .env 中的 TESTNET_CLIENT_SECRET 获取)"
    echo ""
    echo -e "${BOLD}可选:${NC}"
    echo "  -n, --node-name   <NAME>   节点名称 (默认: 主机名)"
    echo "  -c, --concurrent  <NUM>    最大并发任务数 (默认: 5)"
    echo "  -v, --version     <VER>    版本号 (默认: latest, 如 v3.0.4)"
    echo "  --no-systemd               仅下载解压，不注册 systemd 服务"
    echo "  --no-tls-verify            跳过 TLS 证书校验 (自签名证书时使用)"
    echo "  -h, --help                 显示此帮助"
    echo ""
    echo -e "${BOLD}示例:${NC}"
    echo "  bash install-client.sh -s https://1.2.3.4:3100 -k MySecret123 -n node-beijing-01"
    echo "  bash install-client.sh -s https://1.2.3.4:3100 -k MySecret123 --no-tls-verify --no-systemd"
}

# ─── 参数解析 ────────────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--server-url)  SERVER_URL="$2"; shift 2 ;;
            -k|--secret)      CLIENT_SECRET="$2"; shift 2 ;;
            -n|--node-name)   NODE_NAME="$2"; shift 2 ;;
            -c|--concurrent)  MAX_CONCURRENT="$2"; shift 2 ;;
            -v|--version)     VERSION="$2"; shift 2 ;;
            --no-systemd)     INSTALL_SYSTEMD=false; shift ;;
            --no-tls-verify)  TLS_INSECURE=true; shift ;;
            -h|--help)        usage; exit 0 ;;
            *) echo -e "${RED}未知参数: $1${NC}"; usage; exit 1 ;;
        esac
    done

    [[ -z "$SERVER_URL" ]] && { echo -e "${RED}错误: 必须通过 -s/--server-url 指定服务端地址${NC}"; usage; exit 1; }
    [[ -z "$CLIENT_SECRET" ]] && { echo -e "${RED}错误: 必须通过 -k/--secret 指定连接密码${NC}"; usage; exit 1; }

    # 节点名称默认为主机名
    [[ -z "$NODE_NAME" ]] && NODE_NAME=$(hostname -s 2>/dev/null || echo "node-$(date +%s)")
}

# ─── Banner ──────────────────────────────────────────────────────────────────
print_header() {
    echo -e "${CYAN}"
    echo "================================================================"
    echo "       TestNet Client · 二进制探针快速安装脚本                    "
    echo "================================================================"
    echo -e "${NC}"
}

# ─── 辅助: HTTP 下载 ─────────────────────────────────────────────────────────
fetch_url() {
    local url="$1" output="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -sSL --connect-timeout 10 -m 120 --retry 2 "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$output" --timeout=30 -t 2 "$url"
    else
        echo -e "${RED}错误: 系统未安装 curl 或 wget，请先安装后重试${NC}" >&2
        exit 1
    fi
}

# ─── 辅助: HTTP 状态码探测 ───────────────────────────────────────────────────
probe_status() {
    local url="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -o /dev/null -s -w "%{http_code}" --connect-timeout 3 -m 5 "$url" 2>/dev/null || echo "000"
    elif command -v wget >/dev/null 2>&1; then
        wget --spider --timeout=3 --tries=1 "$url" >/dev/null 2>&1 && echo "200" || echo "000"
    else
        echo "000"
    fi
}

# ─── 1. 系统检查 ─────────────────────────────────────────────────────────────
check_system() {
    echo -e "${CYAN}[1/5] 检查系统环境...${NC}"

    # 操作系统
    if [[ "$(uname -s)" != "Linux" ]]; then
        echo -e "${RED}错误: 本脚本仅支持 Linux 系统${NC}"
        exit 1
    fi

    # 架构检测
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)  ARCH_NAME="amd64" ;;
        aarch64|arm64) ARCH_NAME="arm64" ;;
        *)
            echo -e "${RED}错误: 暂不支持架构 ${ARCH}，目前支持 amd64 / arm64${NC}"
            exit 1
            ;;
    esac
    echo -e "  ${GREEN}✓${NC} 操作系统: Linux / 架构: ${BOLD}${ARCH_NAME}${NC}"

    # root 权限检查（systemd 安装需要）
    if [[ $EUID -ne 0 ]] && [[ "$INSTALL_SYSTEMD" == "true" ]]; then
        echo -e "${YELLOW}  ⚠ 当前非 root 用户，systemd 服务安装需要 sudo 权限${NC}"
        echo -e "${YELLOW}    若无 sudo，可追加 --no-systemd 参数跳过服务注册，手动运行二进制${NC}"
    fi

    # Docker socket 可用性（可选）
    if [[ -S /var/run/docker.sock ]]; then
        echo -e "  ${GREEN}✓${NC} 检测到 Docker Socket，容器化工具执行能力已就绪"
        DOCKER_AVAILABLE=true
    else
        echo -e "  ${YELLOW}⚠${NC} 未检测到 /var/run/docker.sock，容器化安全工具将无法执行"
        echo -e "     如需 Docker 执行能力，请先安装 Docker 并确保 Socket 可访问"
        DOCKER_AVAILABLE=false
    fi
}

# ─── 2. 解析版本与下载地址 ───────────────────────────────────────────────────
resolve_version_and_source() {
    echo -e "${CYAN}[2/5] 解析版本与下载节点...${NC}"

    # 版本号处理：latest → 从 CNB 版本清单获取实际版本
    if [[ "$VERSION" == "latest" ]]; then
        echo -n "  - 获取最新版本号 ... "
        local version_url="${CNB_RELEASE_BASE}/version.yml"
        local tmp_ver
        tmp_ver=$(mktemp)
        if fetch_url "$version_url" "$tmp_ver" 2>/dev/null && [[ -s "$tmp_ver" ]]; then
            local parsed
            parsed=$(grep -E "^version[:=]" "$tmp_ver" | sed -E 's/^version[:=][[:space:]]*//' | tr -d '\r' || true)
            [[ -n "$parsed" ]] && VERSION="$parsed"
        fi
        rm -f "$tmp_ver"
        echo -e "${GREEN}${VERSION}${NC}"
    fi

    # 确保版本号有 v 前缀
    [[ "$VERSION" != v* ]] && VERSION="v${VERSION}"

    TARBALL_NAME="testnet-client-linux-${ARCH_NAME}.tar.gz"

    # 探测最快下载源
    echo -n "  - 探测国内 CNB 节点 ... "
    local cnb_url="${CNB_RELEASE_BASE}/${VERSION}/${TARBALL_NAME}"
    local cnb_status
    cnb_status=$(probe_status "$cnb_url")

    if [[ "$cnb_status" == "200" || "$cnb_status" == "302" || "$cnb_status" == "301" ]]; then
        DOWNLOAD_URL="$cnb_url"
        echo -e "${GREEN}可用，使用国内节点${NC}"
    else
        DOWNLOAD_URL="${GITHUB_RELEASE_BASE}/${VERSION}/${TARBALL_NAME}"
        echo -e "${YELLOW}不可达，切换 GitHub Releases${NC}"
    fi

    echo -e "  ${GREEN}✓${NC} 目标: ${BOLD}${VERSION}${NC} / ${BOLD}${ARCH_NAME}${NC}"
    echo -e "  ${GREEN}✓${NC} 下载地址: ${DOWNLOAD_URL}"
}

# ─── 3. 下载并解压 ───────────────────────────────────────────────────────────
download_and_extract() {
    echo -e "${CYAN}[3/5] 下载并解压客户端...${NC}"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT

    local tarball="${tmp_dir}/${TARBALL_NAME}"
    echo -n "  - 下载 ${TARBALL_NAME} ... "
    if ! fetch_url "$DOWNLOAD_URL" "$tarball"; then
        echo -e "${RED}失败${NC}"
        echo -e "${RED}错误: 下载失败，请检查网络或手动下载:${NC}"
        echo "  ${DOWNLOAD_URL}"
        exit 1
    fi
    echo -e "${GREEN}成功${NC}"

    # 验证 tar.gz 文件
    if ! tar -tzf "$tarball" >/dev/null 2>&1; then
        echo -e "${RED}错误: 下载文件损坏，请重试${NC}"
        exit 1
    fi

    # 创建安装目录
    if [[ $EUID -eq 0 ]]; then
        mkdir -p "$INSTALL_DIR"
    else
        sudo mkdir -p "$INSTALL_DIR"
    fi

    echo -n "  - 解压到 ${INSTALL_DIR} ... "
    if [[ $EUID -eq 0 ]]; then
        tar -xzf "$tarball" -C "$INSTALL_DIR" --strip-components=0
    else
        sudo tar -xzf "$tarball" -C "$INSTALL_DIR" --strip-components=0
    fi
    echo -e "${GREEN}成功${NC}"

    # 赋予执行权限
    if [[ $EUID -eq 0 ]]; then
        chmod +x "${INSTALL_DIR}/${BIN_NAME}"
    else
        sudo chmod +x "${INSTALL_DIR}/${BIN_NAME}"
    fi

    echo -e "  ${GREEN}✓${NC} 二进制: ${INSTALL_DIR}/${BIN_NAME}"
    echo -e "  ${GREEN}✓${NC} 配置模板: ${INSTALL_DIR}/configs/config.yaml"
}

# ─── 4. 写入配置 ─────────────────────────────────────────────────────────────
write_config() {
    echo -e "${CYAN}[4/5] 生成客户端配置...${NC}"

    local config_path="${INSTALL_DIR}/configs/config.yaml"
    local tls_enabled="false"
    local tls_insecure_str="false"

    # 自动判断是否启用 TLS
    [[ "$SERVER_URL" == https://* ]] && tls_enabled="true"
    [[ "$TLS_INSECURE" == "true" ]] && tls_insecure_str="true"

    # 如果配置文件已存在则备份
    if [[ -f "$config_path" ]]; then
        local backup="${config_path}.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "  ${YELLOW}⚠${NC} 检测到已有配置文件，已备份至: ${backup}"
        if [[ $EUID -eq 0 ]]; then
            cp "$config_path" "$backup"
        else
            sudo cp "$config_path" "$backup"
        fi
    fi

    local docker_enabled="false"
    [[ "$DOCKER_AVAILABLE" == "true" ]] && docker_enabled="true"

    # 写入配置（使用 tee 以支持 sudo 场景）
    sudo tee "$config_path" >/dev/null <<EOF
# TestNet 扫描探针配置文件
# 由 install-client.sh 自动生成于 $(date)
# 修改后重启服务生效: sudo systemctl restart ${SERVICE_NAME}

server:
  url: "${SERVER_URL}"
  secret: "${CLIENT_SECRET}"
  timeout: 30s
  tls:
    enabled: ${tls_enabled}
    insecure_skip_verify: ${tls_insecure_str}

node:
  name: "${NODE_NAME}"
  heartbeat_interval: 30s
  offline_timeout: 10s

task:
  max_concurrent: ${MAX_CONCURRENT}
  poll_timeout: 30s
  poll_interval: 5s
  execution_timeout: 300s
  retry:
    max_attempts: 3
    initial_delay: 1s
    max_delay: 30s
    multiplier: 2.0

logging:
  level: "info"
  format: "json"
  output: "stdout"

docker:
  enabled: ${docker_enabled}
  socket: "/var/run/docker.sock"
  pull_timeout: 5m
  run_timeout: 10m
  remove_on_exit: true
  registry_auth:
    username: ""
    password: ""
    server: ""

http:
  timeout: 30s
  max_redirects: 5

dns:
  timeout: 10s
  servers:
    - "8.8.8.8:53"
    - "1.1.1.1:53"

tcp:
  timeout: 10s
  banner_timeout: 5s
EOF

    echo -e "  ${GREEN}✓${NC} 配置已写入: ${config_path}"
}

# ─── 5. 安装 systemd 服务 ────────────────────────────────────────────────────
install_systemd() {
    echo -e "${CYAN}[5/5] 安装 systemd 服务...${NC}"

    local unit_file="/etc/systemd/system/${SERVICE_NAME}.service"

    sudo tee "$unit_file" >/dev/null <<EOF
[Unit]
Description=TestNet Scanning Client Node
Documentation=https://testnet.sh
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/${BIN_NAME} --config ${INSTALL_DIR}/configs/config.yaml
WorkingDirectory=${INSTALL_DIR}
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=testnet-client

# 资源限制
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "${SERVICE_NAME}"
    sudo systemctl restart "${SERVICE_NAME}"

    # 等待 2 秒确认服务已起
    sleep 2
    if sudo systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo -e "  ${GREEN}✓${NC} systemd 服务已启动: ${BOLD}${SERVICE_NAME}${NC}"
    else
        echo -e "  ${YELLOW}⚠${NC} 服务可能未正常启动，请检查日志:"
        echo "    sudo journalctl -u ${SERVICE_NAME} -n 50 --no-pager"
    fi
}

# ─── 运行说明（无 systemd 时） ───────────────────────────────────────────────
print_manual_start() {
    echo -e "${CYAN}[5/5] 跳过 systemd 服务注册 (--no-systemd)${NC}"
    echo ""
    echo -e "${YELLOW}  手动运行客户端:${NC}"
    echo "    ${INSTALL_DIR}/${BIN_NAME} --config ${INSTALL_DIR}/configs/config.yaml"
    echo ""
    echo -e "${YELLOW}  后台运行 (nohup):${NC}"
    echo "    nohup ${INSTALL_DIR}/${BIN_NAME} --config ${INSTALL_DIR}/configs/config.yaml > /var/log/testnet-client.log 2>&1 &"
}

# ─── 完成提示 ────────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  ✅ TestNet 扫描探针安装完成！${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
    echo -e "  ${BOLD}服务端地址${NC}: ${SERVER_URL}"
    echo -e "  ${BOLD}节点名称${NC}  : ${NODE_NAME}"
    echo -e "  ${BOLD}安装目录${NC}  : ${INSTALL_DIR}"
    echo -e "  ${BOLD}版本${NC}      : ${VERSION} / ${ARCH_NAME}"
    if [[ "$INSTALL_SYSTEMD" == "true" ]]; then
        echo ""
        echo -e "  ${BOLD}常用运维命令:${NC}"
        echo "    sudo systemctl status  ${SERVICE_NAME}          # 查看状态"
        echo "    sudo systemctl restart ${SERVICE_NAME}          # 重启服务"
        echo "    sudo systemctl stop    ${SERVICE_NAME}          # 停止服务"
        echo "    sudo journalctl -u     ${SERVICE_NAME} -f       # 实时日志"
    fi
    echo ""
    echo -e "  登录管理后台 → 「扫描节点」，确认节点 ${BOLD}${NODE_NAME}${NC} 已在线。"
    echo ""
}

# ─── 入口 ────────────────────────────────────────────────────────────────────
main() {
    print_header
    parse_args "$@"
    check_system
    resolve_version_and_source
    download_and_extract
    write_config

    if [[ "$INSTALL_SYSTEMD" == "true" ]]; then
        install_systemd
    else
        print_manual_start
    fi

    print_summary
}

main "$@"
