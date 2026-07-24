## 📋 环境要求

在运行脚本之前，请确保您的系统已安装以下软件：

- **Docker**: 推荐 20.10+ 版本
- **Docker Compose**: 推荐 v2.0+ 版本（脚本支持 `docker compose` 和 `docker-compose` 命令）

## 🚀 快速开始
 
 ### 1. 一键引导安装 (推荐)
 
 这是最简单的安装方式，会自动检查环境依赖并拉取最新资源。在您的服务器上执行：
 
 ```bash
 # 使用国内镜像 (默认)
 curl -sSL https://cnb.cool/testnet0/testnet-public/-/git/raw/main/deploy/install.sh | bash
 ```
 
 或者使用 GitHub 源：
 ```bash
 curl -sSL https://raw.githubusercontent.com/testnet0/testnet-public/main/deploy/install.sh | bash
 ```
 
 ### 2. 交互式配置
 
 安装脚本会自动下载所需文件并引导您进入配置阶段：
 
 - **镜像源选择**: 选择 DockerHub 或 阿里云加速。
 - **自动生成配置**: 脚本会自动生成 `.env` 及随机密码。
 - **管理员记录**: 安装完成后，请**务必妥善保存**输出的管理员随机密码。

### 3. 访问平台

安装成功后，默认访问地址为：

- **URL**: `https://localhost:3100`
- **默认账号**: `admin`
- **默认密码**: 安装脚本输出的随机密码

---

## 🛠️ 命令参考

脚本支持以下子命令：

| 命令             | 说明                                                       |
| :--------------- | :--------------------------------------------------------- |
| `install`        | 首次执行。检查环境、选择镜像源、生成配置并启动服务。       |
| `start`          | 启动所有 TestNet 容器服务。                                |
| `stop`           | 停止运行中的容器，但保留容器状态。                         |
| `restart`        | 重启所有 TestNet 容器服务。                                |
| `update`         | 拉取最新的 Docker 镜像并平滑更新服务。                     |
| `status`         | 查看当前 TestNet 服务的运行状态（容器列表）。              |
| `logs`           | 查看实时动态日志（Ctrl+C 退出）。                          |
| `reset-password` | **紧急重置**: 将 `admin` 用户的密码重置为 `Admin@123456`。 |

---

## ⚠️ 重要提示

1. **配置文件**: 脚本生成的 `.env` 文件包含数据库密码、JWT 密钥等敏感信息。请勿随意泄露或删除。
2. **授权文件**: 生产环境服务端必须配置授权文件，默认挂载目录为 `deploy/license/server/`。
3. **数据库**: 全新安装时 PostgreSQL 自动执行 `testnet-pg.sql` 初始化，后续升级由服务端启动时通过 Flyway migration 完成。数据持久化存储在 Docker Volume 中，即使删除容器，数据也不会丢失。
4. **Windows 用户**: 请在 PowerShell 中运行对应的 `testnet.ps1` 脚本，或者在 WSL (Windows Subsystem for Linux) 中运行 `testnet.sh`。
