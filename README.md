# TestNet资产管理系统

[English](./README-en.md) / 简体中文

## 产品简介
TestNet资产管理系统旨在提供全面、高效的互联网资产管理与监控服务，构建详细的资产信息库。
该系统能够帮助企业安全团队或渗透测试人员对目标资产进行深入侦察和分析，提供攻击者视角的持续风险监测，协助用户实时掌握资产动态，识别并修复安全漏洞，从而有效收敛攻击面，提升整体安全防护能力。

## 功能概览
目前TestNet资产管理系统支持以下主要功能：
- **项目管理**：管理多个资产项目。
- **资产管理**：支持`公司`、`域名`、`子域名`、`IP`、`端口`、`Web`、`API`、`漏洞`、`资产标签`、`黑名单`等的全面管理。
- **用户管理**：配置用户权限和访问控制。
- **资产导入导出**：便捷的资产数据`导入`与`导出`功能。
- **高级搜索**：强大的`搜索`功能，支持多维度资产搜索。
- **扫描脚本定制**：支持`自定义`扫描脚本。
- **批量扫描&定时任务**：支持`批量`资产扫描及`定时`任务。
- **节点配置自定义**：支持`分布式`多节点的灵活配置。
- **AI助手**：`AI智能助手`功能，提升代码效率。

集成以下工具：
- **子域名扫描**：`OneForAll`、`subfinder`
- **端口扫描**：`nmap`、`naabu`、`masscan`、`Rustscan`、`防火墙探测`
- **Web探测及截图**：`httpx`
- **Web指纹识别**：`TideFinger`、`xapp`
- **漏洞扫描**：`nuclei`、`Xpoc`、`Afrog`
- **Web敏感目录扫描**：`DirSearch`、`ffuf`
- **Web爬虫**：`katana`
- **ICP备案查询**
- **空间搜索引擎**：`Fofa`、`Hunter`、`Shodan`、`Quake`

## 安装
打开终端，执行以下命令来克隆项目并运行安装脚本：
```bash
git clone https://github.com/testnet0/testnet.git
cd testnet && bash build.sh
```
请参考：[安装指南](https://testnet.shengkai.wang/guide/%E5%AE%89%E8%A3%85%E6%8C%87%E5%8D%97.html)以获取更详细的安装步骤和配置方法。

## 使用
1. **快速入门**：参考：[快速入门指南](https://testnet.shengkai.wang/guide/%E5%BF%AB%E9%80%9F%E5%85%A5%E9%97%A8.html)，快速开始使用TestNet资产管理系统。

## 常见问题
在安装或者使用过程中遇到问题？
请查看：[常见问题解答](https://testnet.shengkai.wang/guide/FAQ.html)获取帮助。

## 赞助作者
如果此项目能帮助到你，可以赞助作者一杯咖啡，谢谢你的支持！

<img src="/doc/img/qrcode.png" width="300" height="300" alt="赞赏码">

## 项目截图

### 首页
![首页](/doc/img/dashboard.png)

### 资产管理
![资产管理](/doc/img/assets.png)

### 空间引擎
![空间引擎](/doc/img/search_engine.png)

## 项目源码
- **后端及客户端源码**: [testnet-java](https://github.com/testnet0/testnet-java)
- **前端源码**: [testnet-vue3](https://github.com/testnet0/testnet-vue3)

## 免责声明
- 本工具仅在取得足够合法授权的企业安全建设中使用。
- 用户在使用本工具过程中，应确保所有行为符合当地的法律法规。
- 如用户在使用本工具的过程中存在任何非法行为，用户将自行承担所有后果。本工具的所有开发者和贡献者不承担任何法律及连带责任。
- 除非用户已充分阅读、完全理解并接受本协议的所有条款，否则，请勿安装并使用本工具。
- 用户的使用行为或以其他任何明示或默示方式表示接受本协议的，即视为用户已阅读并同意本协议的约束。
