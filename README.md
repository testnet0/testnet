## TestNet 资产管理系统介绍
<div align="center">

简体中文 / [English](./README-en)

</div>
TestNet资产管理系统旨在提供全面、高效的互联网资产管理与监控服务，构建详细的资产信息库。该系统能够帮助企业安全团队或渗透测试人员对目标资产进行深入侦察和分析，提供攻击者视角的持续风险监测，协助用户实时掌握资产动态，识别并修复安全漏洞，从而有效收敛攻击面，提升整体安全防护能力。

### 目前功能

- [X] 项目管理
- [X] 资产管理（公司、域名、子域名、IP、端口、Web、API、漏洞、资产标签、黑名单等）
- [X] 资产导入导出
- [X] 高级搜索
- [X] 扫描脚本定制
- [X] 批量扫描 & 定时任务
- [X] 节点配置自定义

**项目自带以下工具，也可以根据需要加入其他工具：**

- [X] 子域名扫描（OneForAll、subfinder）
- [X] 端口扫描（nmap、naabu、masscan、Rustscan）
- [X] Web探测（httpx）
- [X] 漏洞扫描（nuclei、Xpoc、Afrog）
- [X] DNS解析（判断CDN及存活）
- [X] 敏感目录扫描（DirSearch、ffuf）
- [X] Web爬虫（katana）
- [X] ICP备案查询
- [X] 0.zone 根域名收集
- [X] 空间搜索引擎（Fofa、Hunter、Shodan、Quake）

#### 免责声明
本工具仅在取得足够合法授权的企业安全建设中使用。用户在使用本工具过程中，应确保所有行为符合当地的法律法规。
如用户在使用本工具的过程中存在任何非法行为，用户将自行承担所有后果。本工具的所有开发者和贡献者不承担任何法律及连带责任。
除非用户已充分阅读、完全理解并接受本协议的所有条款，否则，请勿安装并使用本工具。
用户的使用行为或以其他任何明示或默示方式表示接受本协议的，即视为用户已阅读并同意本协议的约束。

#### 快速开始

### 1、 **安装方式**
安装前请确保已安装： Git、Docker、Docker Compose。
不推荐使用kali系统部署，可能会有兼容性问题。
#### 推荐配置：
- [X] 单独安装服务端  内存：2G+
- [X] 安装服务端和客户端   内存：4G+
### Linux或Mac系统
```bash
git clone https://github.com/testnet0/testnet.git
cd testnet && bash build.sh
```
根据提示选择一键安装或者分布式部署，稍等片刻，即可启动系统。默认访问端口为 `https://IP:8099`
### Windows系统
#### 1、下载项目
```bash
git clone https://github.com/testnet0/testnet.git && cd testnet
```
#### 2、配置密码
创建.env文件，内容如下,替换成你自己的redis和MySQL密码,TESTNET_API_TOKEN自行配置：
```bash
IMAGE_PREFIX=registry.cn-hangzhou.aliyuncs.com/testnet0
REDIS_PASSWORD=xxxx
MYSQL_PASSWORD=xxxx
TESTNET_API_TOKEN=xxxx
SUBNET_PREFIX=172.16.1
GPT_ENABLE=false
GPT_KEY=xxx
GPT_HOST=https://api.openai.com
```
#### 3、启动服务端
```bash
docker-compose up -d
```
#### 安装报错
安装过程有报错建议先查看文档：[常见报错解决](https://github.com/testnet0/testnet/wiki/%E5%B8%B8%E8%A7%81%E6%8A%A5%E9%94%99%E8%A7%A3%E5%86%B3)
### 2、 **默认密码**
   - **安全测试**：`TestNet/TestNet123@`
   - **管理员**：`admin/123456`

### 3、系统界面
#### 首页
![首页](/doc/img/dashboard.png)

#### 资产管理
![资产管理](/doc/img/assets.png)

#### 空间引擎
![空间引擎](/doc/img/search_engine.png)

### 4、联系作者
如果你有疑虑或者有优化点，欢迎与我讨论（有沟通群）：

<img src="/doc/img/wechat.png" width="260" height="240" alt="微信群">

如果此项目能帮助到你，可以赞助作者一杯咖啡，谢谢你的支持！

<img src="/doc/img/qrcode.png" width="260" height="240" alt="赞赏码">

### 项目文档
- [Wiki](https://github.com/testnet0/testnet/wiki)

### 源码地址

- [前端源码](https://github.com/testnet0/testnet-vue3)
- [服务端及客户端源码](https://github.com/testnet0/testnet-java)