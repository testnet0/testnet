## TestNet Asset Management System Introduction

[简体中文](./README) / English

## Product introduction
The TestNet Asset Management System aims to provide comprehensive and efficient internet asset management and monitoring services, building a detailed asset information library. This system can help enterprise security teams or penetration testers conduct in-depth reconnaissance and analysis of target assets, provide continuous risk monitoring from an attacker's perspective, assist users in real-time understanding of asset dynamics, identify and fix security vulnerabilities, effectively reduce the attack surface, and enhance overall security protection capabilities.

### Current Features

- [X] Project Management
- [X] Asset Management (company, domains, subdomains, IPs, ports, web, API, vulnerabilities, asset tags, blacklist, etc.)
- [X] Asset Import and Export
- [X] Advanced Search
- [X] Custom Scan Scripts
- [X] Batch Scanning & Scheduled Tasks
- [X] Custom Node Configuration

**Built-in tool scripts, and you can add other tools as needed:**

- [X] Subdomain Scanning (OneForAll, subfinder)
- [X] Port Scanning (Nmap, Naabu)
- [X] Web Detection (Httpx)
- [X] Vulnerability Scanning (Nuclei)
- [X] DNS Resolution (CDN and live detection)
- [X] Sensitive Directory Scanning (DirSearch)
- [X] ICP Filing Query
- [X] 0.zone API Call

#### Installation

```bash
git clone https://github.com/testnet0/testnet.git
cd testnet && bash build.sh
```

Please refer to: [Installation Guide](/wiki/安装指南) for more detailed installation steps and configuration methods.
### 3. System Interface
![](https://raw.githubusercontent.com/testnet0/testnet/main/doc/img/dashboard.png)



### Detailed Documentation Link

- [TestNet Wiki](wiki)

### Source Code
- [Frontend Source Code](https://github.com/testnet0/testnet-vue3)
- [Backend and Client Source Code](https://github.com/testnet0/testnet-java)