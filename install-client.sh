#!/bin/bash
# TestNet 扫描探针 · 二进制安装与管理脚本 (install-client.sh)
#
# 功能: 一键安装、配置、自启动管理 (systemd 系统/用户级)、启停控制、更新与卸载
# 支持: Linux (amd64 / arm64), 支持 root 及普通免 root 用户
#
# 用法:
#   安装:   bash install-client.sh -s <SERVER_URL> -k <SECRET> [选项]
#   卸载:   bash install-client.sh uninstall [--purge]
#   管理:   bash install-client.sh {start|stop|restart|status|logs}
#   更新:   bash install-client.sh update [-v <VERSION>]

set -euo pipefail

# ─── 颜色 ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── 基础默认参数 ────────────────────────────────────────────────────────────
ACTION="install"
SERVER_URL=""
CLIENT_SECRET=""
NODE_NAME=""
MAX_CONCURRENT=5
VERSION="latest"
INSTALL_SYSTEMD=true
SYSTEMD_MODE="auto"   # auto, system, user, none
TLS_INSECURE=false
PURGE_DATA=false

BIN_NAME="testnet-client"
SERVICE_NAME="testnet-client"
CURRENT_USER=$(id -un)

# 安装目录选择
if [[ $EUID -eq 0 ]]; then
    DEFAULT_INSTALL_DIR="/opt/testnet/client"
else
    DEFAULT_INSTALL_DIR="${HOME}/testnet-client"
fi
INSTALL_DIR="$DEFAULT_INSTALL_DIR"

CNB_RELEASE_BASE="https://cnb.cool/testnet0/testnet-public/-/releases/download"
GITHUB_RELEASE_BASE="https://github.com/testnet0/testnet/releases/download"

# ─── 帮助 ────────────────────────────────────────────────────────────────────
usage() {
    echo -e "${BOLD}TestNet Client 二进制安装与管理工具${NC}"
    echo ""
    echo -e "${BOLD}安装用法:${NC}"
    echo "  bash install-client.sh -s <SERVER_URL> -k <SECRET> [选项]"
    echo ""
    echo -e "${BOLD}必填参数 (仅安装时):${NC}"
    echo "  -s, --server-url  <URL>    服务端地址 (如 https://1.2.3.4:3100 或 https://domain.com)"
    echo "  -k, --secret      <SECRET> 节点连接密码 (从服务端 .env 中的 TESTNET_CLIENT_SECRET 获取)"
    echo ""
    echo -e "${BOLD}可选配置:${NC}"
    echo "  -n, --node-name   <NAME>   节点标识名称 (默认: 当前主机名)"
    echo "  -d, --dir         <PATH>   安装目录 (root 默认: /opt/testnet/client, 普通用户默认: ~/testnet-client)"
    echo "  -c, --concurrent  <NUM>    最大并发任务数 (默认: 5)"
    echo "  -v, --version     <VER>    指定版本 (默认: latest, 例如 v3.0.4)"
    echo "  --user                     强制使用普通用户级 systemd 自启服务 (免 root)"
    echo "  --system                   强制使用系统级 systemd 自启服务 (需要 sudo/root)"
    echo "  --no-systemd               仅安装文件，不注册 systemd 开机自启服务"
    echo "  --no-tls-verify            跳过服务端 TLS 证书校验 (自签名证书必选)"
    echo ""
    echo -e "${BOLD}运维管理命令:${NC}"
    echo "  bash install-client.sh status              # 查看服务运行状态与连接信息"
    echo "  bash install-client.sh start               # 启动探针客户端"
    echo "  bash install-client.sh stop                # 停止探针客户端"
    echo "  bash install-client.sh restart             # 重启探针客户端"
    echo "  bash install-client.sh logs                # 实时追踪日志输出"
    echo "  bash install-client.sh update [-v <VER>]   # 在线升级二进制并平滑重启"
    echo "  bash install-client.sh uninstall [--purge] # 卸载服务与二进制 (--purge 同时清理历史数据与缓存)"
    echo "  -h, --help                                 显示此帮助信息"
    echo ""
    echo -e "${BOLD}快速安装示例:${NC}"
    echo "  # 普通用户一键安装 (自动适配系统/用户自启):"
    echo "  bash install-client.sh -s https://testnet.iotaa.cn -k <SECRET> -n node-myhost --no-tls-verify"
    echo ""
    echo "  # 卸载清理:"
    echo "  bash install-client.sh uninstall --purge"
}

# ─── 辅助: 打印 Header ────────────────────────────────────────────────────────
print_header() {
    echo -e "${CYAN}"
    echo "================================================================"
    echo "       TestNet Client · 扫描探针管理工具                        "
    echo "================================================================"
    echo -e "${NC}"
}

# ─── 辅助: HTTP 下载与探测 ────────────────────────────────────────────────────
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

can_sudo() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        return 0
    fi
    return 1
}

# ─── 参数解析 ────────────────────────────────────────────────────────────────
parse_args() {
    # 优先检测子命令
    if [[ $# -gt 0 ]]; then
        case "$1" in
            install|uninstall|status|start|stop|restart|logs|update)
                ACTION="$1"
                shift
                ;;
            --uninstall)
                ACTION="uninstall"
                shift
                ;;
            --status)
                ACTION="status"
                shift
                ;;
            --update)
                ACTION="update"
                shift
                ;;
        esac
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--server-url)  SERVER_URL="$2"; shift 2 ;;
            -k|--secret)      CLIENT_SECRET="$2"; shift 2 ;;
            -n|--node-name)   NODE_NAME="$2"; shift 2 ;;
            -d|--dir)         INSTALL_DIR="$2"; shift 2 ;;
            -c|--concurrent)  MAX_CONCURRENT="$2"; shift 2 ;;
            -v|--version)     VERSION="$2"; shift 2 ;;
            --user)           SYSTEMD_MODE="user"; INSTALL_SYSTEMD=true; shift ;;
            --system)         SYSTEMD_MODE="system"; INSTALL_SYSTEMD=true; shift ;;
            --no-systemd)     INSTALL_SYSTEMD=false; SYSTEMD_MODE="none"; shift ;;
            --no-tls-verify)  TLS_INSECURE=true; shift ;;
            --purge)          PURGE_DATA=true; shift ;;
            -h|--help)        usage; exit 0 ;;
            *) echo -e "${RED}未知参数: $1${NC}"; usage; exit 1 ;;
        esac
    done

    if [[ "$ACTION" == "install" ]]; then
        if [[ -z "$SERVER_URL" ]]; then
            echo -e "${RED}错误: 必须通过 -s/--server-url 指定服务端地址${NC}"
            usage
            exit 1
        fi
        if [[ -z "$CLIENT_SECRET" ]]; then
            echo -e "${RED}错误: 必须通过 -k/--secret 指定连接密码${NC}"
            usage
            exit 1
        fi
        if [[ -z "$NODE_NAME" ]]; then
            NODE_NAME=$(hostname -s 2>/dev/null || echo "node-$(date +%s)")
        fi
    fi
}

# ─── 确定当前安装状态与 systemd 模式 ─────────────────────────────────────────
detect_active_service() {
    # 检测是否存在系统级或用户级 service
    SYSTEM_SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    USER_SERVICE_FILE="${HOME}/.config/systemd/user/${SERVICE_NAME}.service"

    ACTIVE_SERVICE_TYPE="none"
    if [[ -f "$SYSTEM_SERVICE_FILE" ]]; then
        ACTIVE_SERVICE_TYPE="system"
    elif [[ -f "$USER_SERVICE_FILE" ]]; then
        ACTIVE_SERVICE_TYPE="user"
    fi
}

# ─── 1. 系统检查 ─────────────────────────────────────────────────────────────
check_system() {
    echo -e "${CYAN}[1/5] 检查系统环境与权限...${NC}"

    if [[ "$(uname -s)" != "Linux" ]]; then
        echo -e "${RED}错误: 本工具仅支持 Linux 操作系统${NC}"
        exit 1
    fi

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)  ARCH_NAME="amd64" ;;
        aarch64|arm64) ARCH_NAME="arm64" ;;
        *)
            echo -e "${RED}错误: 暂不支持架构 ${ARCH}，目前支持 amd64 / arm64${NC}"
            exit 1
            ;;
    esac
    echo -e "  ${GREEN}✓${NC} 架构: ${BOLD}${ARCH_NAME}${NC} / 当前运行用户: ${BOLD}${CURRENT_USER}${NC}"

    # 判定自启动策略
    if [[ "$INSTALL_SYSTEMD" == "true" ]]; then
        if [[ "$SYSTEMD_MODE" == "auto" ]]; then
            if [[ $EUID -eq 0 ]]; then
                SYSTEMD_MODE="system"
            elif can_sudo; then
                # 用户具备免密 sudo，可选用系统级
                SYSTEMD_MODE="system"
            elif command -v systemctl >/dev/null 2>&1 && systemctl --user list-units >/dev/null 2>&1; then
                # 普通用户降级至 systemd user service，完全免 root！
                SYSTEMD_MODE="user"
            else
                SYSTEMD_MODE="none"
                INSTALL_SYSTEMD=false
            fi
        fi

        case "$SYSTEMD_MODE" in
            system)
                echo -e "  ${GREEN}✓${NC} 自启动模式: ${BOLD}systemd 系统服务${NC} (/etc/systemd/system)"
                ;;
            user)
                echo -e "  ${GREEN}✓${NC} 自启动模式: ${BOLD}systemd 用户服务 (免 root)${NC} (~/.config/systemd/user)"
                ;;
            none)
                echo -e "  ${YELLOW}⚠${NC} 自启动模式: 跳过 systemd 注册 (将提示前后台手动启动方式)"
                ;;
        esac
    else
        echo -e "  ${YELLOW}⚠${NC} 自启动模式: 已禁用 (--no-systemd)"
    fi

    # Docker 环境与权限检测
    if [[ -S /var/run/docker.sock ]]; then
        if [[ -w /var/run/docker.sock ]] || [[ $EUID -eq 0 ]] || groups "$CURRENT_USER" 2>/dev/null | grep -qw "docker"; then
            echo -e "  ${GREEN}✓${NC} Docker Socket 可访问，已就绪支持容器化扫描工具"
            DOCKER_AVAILABLE=true
        else
            echo -e "  ${YELLOW}⚠${NC} 检测到 Docker Socket，但当前用户 (${CURRENT_USER}) 暂无读写权限。"
            echo -e "     建议后续执行: sudo usermod -aG docker ${CURRENT_USER} 后重新登录以赋权。"
            DOCKER_AVAILABLE=true
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} 未检测到 /var/run/docker.sock，仅支持原生 Shell/TCP/HTTP/DNS 工具"
        DOCKER_AVAILABLE=false
    fi
}

# ─── 2. 解析版本与下载节点 ───────────────────────────────────────────────────
resolve_version_and_source() {
    echo -e "${CYAN}[2/5] 解析客户端版本与下载镜像源...${NC}"

    if [[ "$VERSION" == "latest" ]]; then
        echo -n "  - 查询最新 Release 版本 ... "
        local version_url="https://cnb.cool/testnet0/testnet-public/-/git/raw/main/version.yml"
        local tmp_ver
        tmp_ver=$(mktemp)
        if fetch_url "$version_url" "$tmp_ver" 2>/dev/null && [[ -s "$tmp_ver" ]]; then
            local parsed
            parsed=$(grep -E "^version[:=]" "$tmp_ver" | sed -E 's/^version[:=][[:space:]]*//' | tr -d '\r' || true)
            if [[ -n "$parsed" ]]; then VERSION="$parsed"; fi
        fi
        rm -f "$tmp_ver"
        if [[ "$VERSION" == "latest" ]]; then VERSION="v3.0.4"; fi
        echo -e "${GREEN}${VERSION}${NC}"
    fi

    if [[ "$VERSION" != v* ]]; then VERSION="v${VERSION}"; fi

    TARBALL_NAME="testnet-client-linux-${ARCH_NAME}.tar.gz"

    echo -n "  - 探测国内 CNB 下载镜像 ... "
    local cnb_url="${CNB_RELEASE_BASE}/${VERSION}/${TARBALL_NAME}"
    local cnb_status
    cnb_status=$(probe_status "$cnb_url")

    if [[ "$cnb_status" == "200" || "$cnb_status" == "302" || "$cnb_status" == "301" ]]; then
        DOWNLOAD_URL="$cnb_url"
        echo -e "${GREEN}可用 (CNB 加速源)${NC}"
    else
        DOWNLOAD_URL="${GITHUB_RELEASE_BASE}/${VERSION}/${TARBALL_NAME}"
        echo -e "${YELLOW}连接受限，切换至 GitHub Releases${NC}"
    fi

    echo -e "  ${GREEN}✓${NC} 目标版本: ${BOLD}${VERSION}${NC} (${ARCH_NAME})"
    echo -e "  ${GREEN}✓${NC} 下载地址: ${DOWNLOAD_URL}"
}

# ─── 3. 下载并解压 ───────────────────────────────────────────────────────────
download_and_extract() {
    echo -e "${CYAN}[3/5] 下载并解压二进制文件...${NC}"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT

    local tarball="${tmp_dir}/${TARBALL_NAME}"
    echo -n "  - 正在下载 ${TARBALL_NAME} ... "
    if ! fetch_url "$DOWNLOAD_URL" "$tarball"; then
        echo -e "${RED}失败${NC}"
        echo -e "${RED}错误: 无法下载客户端包，请检查网络或手动下载: ${DOWNLOAD_URL}${NC}"
        exit 1
    fi
    echo -e "${GREEN}成功${NC}"

    if ! tar -tzf "$tarball" >/dev/null 2>&1; then
        echo -e "${RED}错误: 压缩包损坏，请重新执行安装${NC}"
        exit 1
    fi

    mkdir -p "$INSTALL_DIR"

    echo -n "  - 解压至 ${INSTALL_DIR} ... "
    tar -xzf "$tarball" -C "$INSTALL_DIR" --strip-components=0
    echo -e "${GREEN}完成${NC}"

    # 兼容架构后缀文件名，生成统一 testnet-client 软链接
    local actual_bin
    actual_bin=$(find "$INSTALL_DIR" -maxdepth 1 -type f -name "testnet-client*" ! -name "*.yaml" ! -name "*.yml" ! -name "*.bak*" | head -1)
    if [[ -z "$actual_bin" ]]; then
        echo -e "${RED}错误: 解压目录中未找到可执行文件${NC}"
        exit 1
    fi
    chmod +x "$actual_bin"
    if [[ "$(basename "$actual_bin")" != "$BIN_NAME" ]]; then
        ln -sf "$actual_bin" "${INSTALL_DIR}/${BIN_NAME}"
    fi

    echo -e "  ${GREEN}✓${NC} 可执行文件: ${INSTALL_DIR}/${BIN_NAME}"

    # 将安装脚本自身固化保存到安装目录，支持后续以本地脚本执行管理
    persist_script_and_symlinks
}

# ─── 固化脚本自身并创建全局快捷命令 ──────────────────────────────────────────
persist_script_and_symlinks() {
    local target_script="${INSTALL_DIR}/install-client.sh"
    local raw_script_url="https://cnb.cool/testnet0/testnet-public/-/git/raw/main/install-client.sh"

    # 如果当前脚本是一个实际存在的普通磁盘文件，直接拷贝
    if [[ -f "$0" && ! "$0" =~ ^/dev/fd && ! "$0" =~ ^/proc/ ]]; then
        cp -f "$0" "$target_script" 2>/dev/null || true
    else
        # 否则通过 curl/wget 将自身下载落盘保存
        fetch_url "$raw_script_url" "$target_script" 2>/dev/null || true
    fi

    if [[ -f "$target_script" ]]; then
        chmod +x "$target_script"
        echo -e "  ${GREEN}✓${NC} 管理脚本已归档保存: ${target_script}"
    fi

    # 尝试在 PATH 目录注册全局快捷命令 testnet-client-ctl 与 testnet-client.sh
    GLOBAL_CMD_REGISTERED=false
    if [[ $EUID -eq 0 ]]; then
        if mkdir -p /usr/local/bin 2>/dev/null; then
            ln -sf "$target_script" /usr/local/bin/testnet-client-ctl 2>/dev/null && GLOBAL_CMD_REGISTERED=true
            ln -sf "$target_script" /usr/local/bin/testnet-client.sh 2>/dev/null || true
        fi
    elif can_sudo; then
        sudo mkdir -p /usr/local/bin 2>/dev/null || true
        if sudo ln -sf "$target_script" /usr/local/bin/testnet-client-ctl 2>/dev/null; then
            sudo ln -sf "$target_script" /usr/local/bin/testnet-client.sh 2>/dev/null || true
            GLOBAL_CMD_REGISTERED=true
        fi
    else
        # 普通用户尝试 ~/.local/bin
        local user_bin="${HOME}/.local/bin"
        if mkdir -p "$user_bin" 2>/dev/null; then
            ln -sf "$target_script" "${user_bin}/testnet-client-ctl" 2>/dev/null || true
            if [[ ":$PATH:" == *":$user_bin:"* ]]; then
                GLOBAL_CMD_REGISTERED=true
            fi
        fi
    fi

    if [[ "$GLOBAL_CMD_REGISTERED" == "true" ]]; then
        echo -e "  ${GREEN}✓${NC} 全局管理命令已注册: ${BOLD}testnet-client-ctl${NC} (可在任意目录直接运行)"
    fi
}


# ─── 4. 生成或保留配置 ───────────────────────────────────────────────────────
write_config() {
    echo -e "${CYAN}[4/5] 写入节点配置...${NC}"

    local config_dir="${INSTALL_DIR}/configs"
    local config_path="${config_dir}/config.yaml"
    mkdir -p "$config_dir"

    local tls_enabled="false"
    local tls_insecure_str="false"
    if [[ "$SERVER_URL" == https://* ]]; then tls_enabled="true"; fi
    if [[ "$TLS_INSECURE" == "true" ]]; then tls_insecure_str="true"; fi

    if [[ -f "$config_path" ]]; then
        local backup="${config_path}.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "  ${YELLOW}⚠${NC} 已存在旧配置，已自动归档备份: ${backup}"
        cp "$config_path" "$backup"
    fi

    local docker_enabled="false"
    if [[ "$DOCKER_AVAILABLE" == "true" ]]; then docker_enabled="true"; fi

    tee "$config_path" >/dev/null <<EOF
# TestNet 扫描探针配置文件
# 由 install-client.sh 自动生成于 $(date)

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

    echo -e "  ${GREEN}✓${NC} 配置文件已就绪: ${config_path}"
}

# ─── 5. 注册 systemd 开机自启服务 ───────────────────────────────────────────
setup_systemd() {
    echo -e "${CYAN}[5/5] 配置开机自启动服务 (${SYSTEMD_MODE})...${NC}"

    if [[ "$SYSTEMD_MODE" == "system" ]]; then
        local unit_file="/etc/systemd/system/${SERVICE_NAME}.service"
        local exec_bin="${INSTALL_DIR}/${BIN_NAME}"
        local config_file="${INSTALL_DIR}/configs/config.yaml"

        local service_content="[Unit]
Description=TestNet Scanning Client Node
Documentation=https://testnet.shengkai.wang/
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
User=${CURRENT_USER}
ExecStart=${exec_bin} --config ${config_file}
WorkingDirectory=${INSTALL_DIR}
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=testnet-client
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target"

        if [[ $EUID -eq 0 ]]; then
            echo "$service_content" > "$unit_file"
            systemctl daemon-reload
            systemctl enable "${SERVICE_NAME}"
            systemctl restart "${SERVICE_NAME}"
        else
            echo "$service_content" | sudo tee "$unit_file" >/dev/null
            sudo systemctl daemon-reload
            sudo systemctl enable "${SERVICE_NAME}"
            sudo systemctl restart "${SERVICE_NAME}"
        fi

        sleep 2
        local is_active=false
        if [[ $EUID -eq 0 ]]; then
            systemctl is-active --quiet "${SERVICE_NAME}" && is_active=true
        else
            sudo systemctl is-active --quiet "${SERVICE_NAME}" && is_active=true
        fi

        if [[ "$is_active" == "true" ]]; then
            echo -e "  ${GREEN}✓${NC} 系统服务已启动并设置开机自启: ${BOLD}${SERVICE_NAME}${NC}"
        else
            echo -e "  ${YELLOW}⚠${NC} 服务已注册，请使用 journalctl -u ${SERVICE_NAME} -f 检查启动状态"
        fi

    elif [[ "$SYSTEMD_MODE" == "user" ]]; then
        local user_systemd_dir="${HOME}/.config/systemd/user"
        mkdir -p "$user_systemd_dir"
        local unit_file="${user_systemd_dir}/${SERVICE_NAME}.service"
        local exec_bin="${INSTALL_DIR}/${BIN_NAME}"
        local config_file="${INSTALL_DIR}/configs/config.yaml"

        cat > "$unit_file" <<EOF
[Unit]
Description=TestNet Scanning Client Node (User Service)
Documentation=https://testnet.shengkai.wang/
After=network.target

[Service]
Type=simple
ExecStart=${exec_bin} --config ${config_file}
WorkingDirectory=${INSTALL_DIR}
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=default.target
EOF

        systemctl --user daemon-reload
        systemctl --user enable "${SERVICE_NAME}"
        systemctl --user restart "${SERVICE_NAME}"

        # 尝试启用无须登录的 linger 驻留自启
        if command -v loginctl >/dev/null 2>&1; then
            loginctl enable-linger "$CURRENT_USER" 2>/dev/null || true
        fi

        sleep 2
        if systemctl --user is-active --quiet "${SERVICE_NAME}"; then
            echo -e "  ${GREEN}✓${NC} 普通用户 systemd 服务已启动并设置自启 (免 root)"
        else
            echo -e "  ${YELLOW}⚠${NC} 用户服务已注册，可使用 systemctl --user status ${SERVICE_NAME} 检查状态"
        fi

    else
        echo -e "  ${YELLOW}ℹ${NC} 跳过自启服务配置。"
        echo -e "    手动前台运行: ${INSTALL_DIR}/${BIN_NAME} --config ${INSTALL_DIR}/configs/config.yaml"
        echo -e "    后台 nohup 运行: nohup ${INSTALL_DIR}/${BIN_NAME} --config ${INSTALL_DIR}/configs/config.yaml > ${INSTALL_DIR}/client.log 2>&1 &"
    fi
}

# ─── 启停管理命令 ─────────────────────────────────────────────────────────────
cmd_manage() {
    local cmd="$1"
    detect_active_service

    if [[ "$ACTIVE_SERVICE_TYPE" == "system" ]]; then
        case "$cmd" in
            status)
                if [[ $EUID -eq 0 ]]; then systemctl status "${SERVICE_NAME}"; else sudo systemctl status "${SERVICE_NAME}"; fi
                ;;
            start|stop|restart)
                echo -e "${CYAN}正在对系统服务执行 ${cmd}...${NC}"
                if [[ $EUID -eq 0 ]]; then systemctl "$cmd" "${SERVICE_NAME}"; else sudo systemctl "$cmd" "${SERVICE_NAME}"; fi
                echo -e "${GREEN}操作完成${NC}"
                ;;
            logs)
                if [[ $EUID -eq 0 ]]; then journalctl -u "${SERVICE_NAME}" -f; else sudo journalctl -u "${SERVICE_NAME}" -f; fi
                ;;
        esac
    elif [[ "$ACTIVE_SERVICE_TYPE" == "user" ]]; then
        case "$cmd" in
            status)
                systemctl --user status "${SERVICE_NAME}"
                ;;
            start|stop|restart)
                echo -e "${CYAN}正在对用户服务执行 ${cmd}...${NC}"
                systemctl --user "$cmd" "${SERVICE_NAME}"
                echo -e "${GREEN}操作完成${NC}"
                ;;
            logs)
                journalctl --user -u "${SERVICE_NAME}" -f
                ;;
        esac
    else
        # 无 systemd 服务，检测正在运行的进程
        local pid
        pid=$(pgrep -f "testnet-client.*--config" || true)
        case "$cmd" in
            status)
                if [[ -n "$pid" ]]; then
                    echo -e "${GREEN}客户端正在以无服务模式运行中 (PID: ${pid})${NC}"
                else
                    echo -e "${YELLOW}未发现运行中的客户端进程或服务${NC}"
                fi
                ;;
            stop)
                if [[ -n "$pid" ]]; then
                    kill $pid 2>/dev/null && echo -e "${GREEN}已停止客户端进程 (PID: ${pid})${NC}"
                else
                    echo -e "${YELLOW}无运行中的进程${NC}"
                fi
                ;;
            start)
                if [[ -f "${INSTALL_DIR}/${BIN_NAME}" ]]; then
                    nohup "${INSTALL_DIR}/${BIN_NAME}" --config "${INSTALL_DIR}/configs/config.yaml" > "${INSTALL_DIR}/client.log" 2>&1 &
                    echo -e "${GREEN}客户端已在后台启动 (PID: $!)${NC}"
                else
                    echo -e "${RED}未找到可执行文件: ${INSTALL_DIR}/${BIN_NAME}${NC}"
                    exit 1
                fi
                ;;
            restart)
                cmd_manage "stop"
                sleep 1
                cmd_manage "start"
                ;;
            logs)
                if [[ -f "${INSTALL_DIR}/client.log" ]]; then
                    tail -f "${INSTALL_DIR}/client.log"
                else
                    echo -e "${YELLOW}未发现日志文件: ${INSTALL_DIR}/client.log${NC}"
                fi
                ;;
        esac
    fi
}

# ─── 在线更新升级 ─────────────────────────────────────────────────────────────
cmd_update() {
    print_header
    echo -e "${CYAN}>>> 检查并升级 TestNet 客户端...${NC}"
    check_system
    resolve_version_and_source

    echo -e "${CYAN}正在下载新版本二进制...${NC}"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT

    local tarball="${tmp_dir}/${TARBALL_NAME}"
    if ! fetch_url "$DOWNLOAD_URL" "$tarball"; then
        echo -e "${RED}下载新版本失败${NC}"; exit 1
    fi

    # 停止旧服务
    detect_active_service
    if [[ "$ACTIVE_SERVICE_TYPE" != "none" ]]; then
        cmd_manage "stop"
    else
        pkill -f "testnet-client.*--config" 2>/dev/null || true
    fi

    # 备份旧二进制
    if [[ -f "${INSTALL_DIR}/${BIN_NAME}" ]]; then
        mv "${INSTALL_DIR}/${BIN_NAME}" "${INSTALL_DIR}/${BIN_NAME}.bak.$(date +%Y%m%d%H%M%S)"
    fi

    # 解压新文件
    tar -xzf "$tarball" -C "$INSTALL_DIR" --strip-components=0
    local actual_bin
    actual_bin=$(find "$INSTALL_DIR" -maxdepth 1 -type f -name "testnet-client*" ! -name "*.yaml" ! -name "*.yml" ! -name "*.bak*" | head -1)
    chmod +x "$actual_bin"
    ln -sf "$actual_bin" "${INSTALL_DIR}/${BIN_NAME}"

    echo -e "${GREEN}✓ 二进制更新成功: ${VERSION}${NC}"

    # 重新启动服务
    if [[ "$ACTIVE_SERVICE_TYPE" != "none" ]]; then
        cmd_manage "start"
    else
        cmd_manage "start"
    fi
    echo -e "${GREEN}✅ 客户端已平滑升级并重启完成！${NC}"
}

# ─── 卸载客户端 ───────────────────────────────────────────────────────────────
cmd_uninstall() {
    print_header
    echo -e "${YELLOW}>>> 准备卸载 TestNet 扫描探针客户端...${NC}"

    detect_active_service

    # 1. 停止并移除 systemd 服务
    if [[ "$ACTIVE_SERVICE_TYPE" == "system" ]]; then
        echo -e "  - 停止系统服务 ${SERVICE_NAME} ..."
        if [[ $EUID -eq 0 ]]; then
            systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
            systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
            rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
            systemctl daemon-reload
        else
            sudo systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
            sudo systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
            sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
            sudo systemctl daemon-reload
        fi
        echo -e "  ${GREEN}✓${NC} 系统服务已清理"

    elif [[ "$ACTIVE_SERVICE_TYPE" == "user" ]]; then
        echo -e "  - 停止用户级服务 ${SERVICE_NAME} ..."
        systemctl --user stop "${SERVICE_NAME}" 2>/dev/null || true
        systemctl --user disable "${SERVICE_NAME}" 2>/dev/null || true
        rm -f "${HOME}/.config/systemd/user/${SERVICE_NAME}.service"
        systemctl --user daemon-reload
        echo -e "  ${GREEN}✓${NC} 用户级自启服务已清理"
    fi

    # 2. 终止残留进程
    local pids
    pids=$(pgrep -f "testnet-client" || true)
    if [[ -n "$pids" ]]; then
        echo -e "  - 终止残留客户端进程: ${pids}"
        kill $pids 2>/dev/null || true
        sleep 1
    fi

    # 3. 移除安装目录与全局软链接
    if [[ -d "$INSTALL_DIR" ]]; then
        echo -e "  - 移除安装目录: ${INSTALL_DIR}"
        rm -rf "$INSTALL_DIR"
        echo -e "  ${GREEN}✓${NC} 安装目录已删除"
    fi

    # 清理快捷命令软链接
    if [[ $EUID -eq 0 ]]; then
        rm -f /usr/local/bin/testnet-client-ctl /usr/local/bin/testnet-client.sh 2>/dev/null || true
    elif can_sudo; then
        sudo rm -f /usr/local/bin/testnet-client-ctl /usr/local/bin/testnet-client.sh 2>/dev/null || true
    fi
    rm -f "${HOME}/.local/bin/testnet-client-ctl" 2>/dev/null || true

    # 4. 可选彻底清理持久化节点 ID 与缓存
    if [[ "$PURGE_DATA" == "true" ]]; then
        echo -e "  - 彻底清理本地缓存与节点指纹 (~/.testnet) ..."
        rm -rf "${HOME}/.testnet"
        if [[ $EUID -eq 0 ]]; then
            rm -rf /root/.testnet
        fi
        echo -e "  ${GREEN}✓${NC} 历史缓存已清理完毕"
    else
        echo -e "  ${YELLOW}ℹ${NC} 提示: 节点的持久化 ID 与缓存仍保留在 ~/.testnet/。若需彻底删除请运行: rm -rf ~/.testnet"
    fi

    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  ✅ TestNet 客户端已成功卸载！${NC}"
    echo -e "${GREEN}================================================================${NC}"
}

# ─── 主入口 ──────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    case "$ACTION" in
        install)
            print_header
            check_system
            resolve_version_and_source
            download_and_extract
            write_config
            setup_systemd
            echo ""
            echo -e "${GREEN}================================================================${NC}"
            echo -e "${GREEN}  ✅ TestNet 扫描探针部署成功！${NC}"
            echo -e "${GREEN}================================================================${NC}"
            echo -e "  服务端地址: ${SERVER_URL}"
            echo -e "  节点名称  : ${NODE_NAME}"
            echo -e "  安装目录  : ${INSTALL_DIR}"
            echo -e "  版本架构  : ${VERSION} / ${ARCH_NAME}"
            echo ""
            echo ""
            echo -e "  ${BOLD}常用管理命令:${NC}"
            if [[ "${GLOBAL_CMD_REGISTERED:-false}" == "true" ]]; then
                echo -e "    ${CYAN}testnet-client-ctl status${NC}    # 查看探针运行状态 (已支持全局执行)"
                echo -e "    ${CYAN}testnet-client-ctl restart${NC}   # 重启探针"
                echo -e "    ${CYAN}testnet-client-ctl stop${NC}      # 停止探针"
                echo -e "    ${CYAN}testnet-client-ctl logs${NC}      # 查看实时日志"
                echo -e "    ${CYAN}testnet-client-ctl uninstall${NC} # 卸载客户端"
                echo ""
                echo -e "  或者使用完整脚本路径执行:"
                echo "    bash ${INSTALL_DIR}/install-client.sh status"
            else
                echo "    bash ${INSTALL_DIR}/install-client.sh status    # 查看运行状态"
                echo "    bash ${INSTALL_DIR}/install-client.sh restart   # 重启探针"
                echo "    bash ${INSTALL_DIR}/install-client.sh stop      # 停止探针"
                echo "    bash ${INSTALL_DIR}/install-client.sh logs      # 查看实时日志"
                echo "    bash ${INSTALL_DIR}/install-client.sh uninstall # 卸载客户端"
            fi
            echo ""
            ;;
        uninstall)
            cmd_uninstall
            ;;
        update)
            cmd_update
            ;;
        status|start|stop|restart|logs)
            cmd_manage "$ACTION"
            ;;
    esac
}

main "$@"
