# TestNet 管理工具 (testnet.ps1)
# 支持: install | start | stop | restart | update | reset-password | logs | status

# 确保工作目录始终为脚本所在目录 (支持从任意路径执行)
Set-Location $PSScriptRoot

$Version = "v3.0.2" # 默认版本号，实际会从远程获取
$VersionUrl = ""
$DownloadBaseUrl = ""
$SelectedRegistryUrl = "testnet0/"

Function Read-HostWithTimeout {
    param(
        [string]$Prompt,
        [string]$DefaultValue,
        [int]$TimeoutSeconds = 10
    )
    Write-Host "$Prompt " -NoNewline -ForegroundColor Yellow
    try {
        $startTime = [System.DateTime]::Now
        $inputStr = ""
        while (([System.DateTime]::Now - $startTime).TotalSeconds -lt $TimeoutSeconds) {
            if ([System.Console]::KeyAvailable) {
                $key = [System.Console]::ReadKey($true)
                if ($key.Key -eq [System.ConsoleKey]::Enter) {
                    Write-Host ""
                    if ([string]::IsNullOrEmpty($inputStr)) { return $DefaultValue }
                    return $inputStr.Trim()
                } elseif ($key.Key -eq [System.ConsoleKey]::Backspace) {
                    if ($inputStr.Length -gt 0) {
                        $inputStr = $inputStr.Substring(0, $inputStr.Length - 1)
                        Write-Host "`b `b" -NoNewline
                    }
                } else {
                    $char = $key.KeyChar
                    if ($char -ge ' ') {
                        $inputStr += $char
                        Write-Host $char -NoNewline
                    }
                }
            }
            Start-Sleep -Milliseconds 100
        }
        Write-Host ""
        Write-Host "10秒未输入，自动使用默认推荐源 [$DefaultValue]。" -ForegroundColor Green
        return $DefaultValue
    } catch {
        $res = Read-Host
        if ([string]::IsNullOrEmpty($res)) { return $DefaultValue }
        return $res.Trim()
    }
}

# 探测最优下载源和镜像源
Function Detect-Sources {
    $cnbBaseUrl = "https://cnb.cool/testnet0/testnet-public/-/git/raw/main"
    $githubBaseUrl = "https://raw.githubusercontent.com/testnet0/testnet/main"

    Write-Host "正在测试网络环境..." -ForegroundColor Cyan
    Write-Host "  - 探测 CNB 国内节点 (cnb.cool) ... " -NoNewline

    $cnbSuccess = $false
    try {
        $resp = Invoke-WebRequest -Uri "$cnbBaseUrl/version.yml" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            $cnbSuccess = $true
        }
    } catch {}

    if ($cnbSuccess) {
        Write-Host "连通正常 (HTTP 200)" -ForegroundColor Green
        $script:ProbedChoice = "2"
        $script:ProbedDesc = "阿里云 (Alibaba Cloud - 中国加速)"
        $script:DownloadBaseUrl = $cnbBaseUrl
        $script:VersionUrl = "$cnbBaseUrl/version.yml"
        $script:SelectedRegistryUrl = "registry.cn-hangzhou.aliyuncs.com/testnet0/"
    } else {
        Write-Host "连接较慢或不可达" -ForegroundColor Yellow
        $script:ProbedChoice = "1"
        $script:ProbedDesc = "DockerHub (Docker Hub 源)"
        $script:DownloadBaseUrl = $githubBaseUrl
        $script:VersionUrl = "$githubBaseUrl/version.yml"
        $script:SelectedRegistryUrl = "testnet0/"
    }
    Write-Host "[√] 网络探测完成，推荐使用: $script:ProbedChoice) $script:ProbedDesc`n" -ForegroundColor Green
}

# 获取远程最新版本号 (兼容 YAML 格式)
Function Get-RemoteVersion {
    Write-Host "正在从远程获取最新版本号..." -ForegroundColor Cyan
    if ([string]::IsNullOrEmpty($script:VersionUrl)) {
        Detect-Sources
    }

    try {
        $content = Invoke-RestMethod -Uri $script:VersionUrl -UseBasicParsing -ErrorAction Stop
        if ($content -match "(?m)^version[:=]\s*(.*)") {
            $script:Version = $matches[1].Trim().Trim('"').Trim("'")
            $env:TESTNET_VERSION = $script:Version
            Write-Host "获取成功，当前最新版本: $script:Version" -ForegroundColor Green
        } else {
            Write-Host "警告: 无法解析远程版本号，将使用默认版本: $script:Version" -ForegroundColor Yellow
            $env:TESTNET_VERSION = $script:Version
        }
    } catch {
        Write-Host "警告: 无法获取远程版本号 ($($_.Exception.Message))，将使用默认版本: $script:Version" -ForegroundColor Yellow
        $env:TESTNET_VERSION = $script:Version
    }
}

# 检查并自动生成 SSL 自签名证书
Function Check-Certs {
    if (-not (Test-Path "certs/server.crt") -or -not (Test-Path "certs/server.key")) {
        Write-Host "检测到 SSL 证书缺失，正在自动生成自签名证书..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Force -Path "certs" | Out-Null
        
        if (Get-Command openssl -ErrorAction SilentlyContinue) {
            & openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
              -keyout "certs/server.key" `
              -out "certs/server.crt" `
              -subj "/C=CN/ST=Beijing/L=Beijing/O=TestNet/OU=Dev/CN=localhost" *>$null
        } else {
            # 如果没有 openssl，尝试使用 PowerShell 原生证书导出或生成占位
            try {
                $cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My -DnsName "localhost" -NotAfter (Get-Date).AddDays(365)
                # 使用证书作为回退
            } catch {}
        }

        if (Test-Path "certs/server.crt") {
            Write-Host "[√] SSL 证书已成功自动生成。" -ForegroundColor Green
        } else {
            # 如果上面没有生成成功，创建一个基本的文本证书文件
            if (-not (Test-Path "certs/server.key")) { "DUMMY KEY" | Out-File -FilePath "certs/server.key" -Encoding ascii }
            if (-not (Test-Path "certs/server.crt")) { "DUMMY CERT" | Out-File -FilePath "certs/server.crt" -Encoding ascii }
            Write-Host "已创建自签名证书文件 (certs/server.crt, certs/server.key)。" -ForegroundColor Green
        }
    }
}

# 生成随机 HEX 字符串
Function Generate-RandomString {
    param([int]$Length = 64)
    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $result = New-Object char[] $Length
    for ($i = 0; $i -lt $Length; $i++) {
        $bytes = New-Object byte[] 1
        $rng.GetBytes($bytes)
        $result[$i] = $chars[$bytes[0] % $chars.Length]
    }
    $rng.Dispose()
    return -join $result
}

# 生成随机管理员密码
Function Generate-AdminPassword {
    param([int]$Length = 16)
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $result = New-Object char[] $Length
    for ($i = 0; $i -lt $Length; $i++) {
        $bytes = New-Object byte[] 1
        $rng.GetBytes($bytes)
        $result[$i] = $chars[$bytes[0] % $chars.Length]
    }
    $rng.Dispose()
    return -join $result
}

# 获取 Docker Compose 命令
Function Get-DockerCompose {
    if (docker compose version >$null 2>&1) { return "docker compose" }
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) { return "docker-compose" }
    return $null
}

# 加载并修正 .env 环境变量
Function Load-EnvVars {
    param([string]$Action)
    if (Test-Path .env) {
        $lines = Get-Content .env
        $hasRedisPassword = $false
        
        foreach ($line in $lines) {
            if ($line -match "^REDIS_PASSWORD=(.+)") {
                $hasRedisPassword = $true
            }
            if ($line -match "^DOCKER_REGISTRY=(.*)") {
                $env:DOCKER_REGISTRY = $matches[1].Trim().Trim('"').Trim("'")
            }
            if ($line -match "^DB_ROOT_PASSWORD=(.*)") {
                $env:DB_ROOT_PASSWORD = $matches[1].Trim().Trim('"').Trim("'")
            }
            if ($line -match "^TESTNET_VERSION=(.*)") {
                $env:TESTNET_VERSION = $matches[1].Trim().Trim('"').Trim("'")
            }
        }

        # 补全 REDIS_PASSWORD
        if (-not $hasRedisPassword) {
            Write-Host "检测到 REDIS_PASSWORD 缺失，正在自动生成..." -ForegroundColor Yellow
            $newRedisPass = Generate-RandomString 32
            Add-Content -Path .env -Value "REDIS_PASSWORD=$newRedisPass"
        }

        if ([string]::IsNullOrEmpty($env:DOCKER_REGISTRY)) {
            $env:DOCKER_REGISTRY = "testnet0/"
        }

        # 设置 OFFICIAL_REGISTRY
        if ($env:DOCKER_REGISTRY -eq "testnet0/") {
            $env:OFFICIAL_REGISTRY = ""
        } else {
            $env:OFFICIAL_REGISTRY = $env:DOCKER_REGISTRY
        }
        
        # 补全版本号
        if ([string]::IsNullOrEmpty($env:TESTNET_VERSION) -and $Action -ne "install" -and $Action -ne "update") {
            Write-Host "检测到 .env 中缺少版本号，正在尝试补全..." -ForegroundColor Yellow
            Get-RemoteVersion
        }
    } elseif ($Action -ne "install") {
        Write-Host "Error: .env file not found. Have you run 'install' yet?" -ForegroundColor Red
        exit 1
    }
}

# 自动感知局域网 IP
Function Get-HostIP {
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -Type Unicast | Where-Object { 
            ($_.IPAddress -like "10.*" -or $_.IPAddress -like "192.168.*" -or ($_.IPAddress -like "172.*" -and [int]($_.IPAddress.Split('.')[1]) -ge 16 -and [int]($_.IPAddress.Split('.')[1]) -le 31))
        } | Select-Object -First 1).IPAddress
        if ($ip) { return $ip }
    } catch {}
    return "127.0.0.1"
}

# 端口占用检测
Function Check-PortConflict {
    param([int]$Port = 3100)
    $occupied = $false
    try {
        $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($conn) { $occupied = $true }
    } catch {}

    if (-not $occupied) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $async = $tcp.BeginConnect("127.0.0.1", $Port, $null, $null)
            $wait = $async.AsyncWaitHandle.WaitOne(500, $false)
            if ($wait -and $tcp.Connected) {
                $occupied = $true
                $tcp.Close()
            }
        } catch {}
    }

    if ($occupied) {
        $isTestnet = $false
        try {
            $containers = docker ps --format "{{.Names}}" 2>$null
            if ($containers -match "testnet-web") {
                $isTestnet = $true
            }
        } catch {}

        if ($isTestnet) {
            Write-Host "检测到端口 $Port 正由已运行的 TestNet 容器使用。" -ForegroundColor Cyan
        } else {
            Write-Host "错误: 端口 $Port 已被宿主机其他服务占用，无法继续安装！" -ForegroundColor Red
            Write-Host "请先停止占用该端口的服务，或修改映射端口后重试。" -ForegroundColor Yellow
            exit 1
        }
    }
}

# 资源检测
Function Check-Resources {
    try {
        $mem = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        if ($mem -and $mem.Sum) {
            $totalGB = [math]::Round($mem.Sum / 1GB, 2)
            if ($totalGB -lt 1.5) {
                Write-Host "警告: 当前系统物理内存较低 (${totalGB}GB)，建议至少配置 1.5GB 内存。" -ForegroundColor Yellow
            }
        }
        $drive = Get-PSDrive -Name (Get-Location).Drive.Name -ErrorAction SilentlyContinue
        if ($drive -and ($drive.Free / 1GB) -lt 2) {
            $freeGB = [math]::Round($drive.Free / 1GB, 2)
            Write-Host "警告: 当前磁盘可用空间较低 (${freeGB}GB)，建议保留至少 2GB 空间。" -ForegroundColor Yellow
        }
    } catch {}
}

# 容器服务健康等待
Function Wait-ForHealth {
    Write-Host "正在等待 TestNet 核心服务完成初始化..." -ForegroundColor Cyan
    $attempts = 0
    $maxAttempts = 20
    $healthy = $false
    
    while ($attempts -lt $maxAttempts) {
        $status = docker inspect --format='{{json .State.Health.Status}}' testnet-server 2>$null
        if ($status) { $status = $status.Trim('"') }
        if ($status -eq "healthy") {
            $healthy = $true
            break
        }
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
        $attempts++
    }
    Write-Host ""
    if ($healthy) {
        Write-Host "[√] TestNet 核心服务已成功初始化并就绪。" -ForegroundColor Green
    } else {
        Write-Host "服务已启动，后台正继续加载数据库与配置..." -ForegroundColor Yellow
    }
}

# 环境安全检测
Function Check-Env {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Checking environment for TestNet $Version..." -ForegroundColor Cyan
        Write-Host "Error: Docker is not installed." -ForegroundColor Red
        exit 1
    }
    $cmd = Get-DockerCompose
    if ($null -eq $cmd) {
        Write-Host "Error: Docker Compose is not installed." -ForegroundColor Red
        exit 1
    }
    Check-Resources
    Check-PortConflict -Port 3100
    return $cmd
}

$action = $args[0]
$dockerComposeCmd = Check-Env

switch ($action) {
    "install" {
        Detect-Sources
        Get-RemoteVersion
        $dockerComposeCmd = Check-Env
        Check-Certs

        $defaultChoice = if ($script:ProbedChoice) { $script:ProbedChoice } else { "1" }
        $defaultDesc = if ($script:ProbedDesc) { $script:ProbedDesc } else { "DockerHub (Docker Hub 源)" }

        Write-Host "请选择镜像源 (Choose Mirror Source):" -ForegroundColor Cyan
        Write-Host "网络探测推荐: $defaultChoice) $defaultDesc" -ForegroundColor Green
        Write-Host "1) DockerHub (Docker Hub 源)"
        Write-Host "2) 阿里云 (Alibaba Cloud - 中国加速)"
        
        $choice = Read-HostWithTimeout -Prompt "请输入选项 [1-2, 默认$defaultChoice] (10秒内未输入将自动使用推荐源):" -DefaultValue $defaultChoice -TimeoutSeconds 10
        
        $selectedRegistry = "testnet0/"
        if ($choice -eq "2") {
            $selectedRegistry = "registry.cn-hangzhou.aliyuncs.com/testnet0/"
            $script:DownloadBaseUrl = "https://cnb.cool/testnet0/testnet-public/-/git/raw/main"
            $script:VersionUrl = "https://cnb.cool/testnet0/testnet-public/-/git/raw/main/version.yml"
            Write-Host "[√] 已选择/使用阿里云镜像源。" -ForegroundColor Green
        } else {
            $selectedRegistry = "testnet0/"
            $script:DownloadBaseUrl = "https://raw.githubusercontent.com/testnet0/testnet/main"
            $script:VersionUrl = "https://raw.githubusercontent.com/testnet0/testnet/main/version.yml"
            Write-Host "[√] 已选择/使用 DockerHub 默认源 (testnet0/)。" -ForegroundColor Green
        }

        $defaultNodeName = "Node-$env:COMPUTERNAME"
        if ([string]::IsNullOrEmpty($env:COMPUTERNAME)) { $defaultNodeName = "Node-Default" }

        if (-not (Test-Path .env)) {
            Write-Host "Creating .env with dynamic secrets..." -ForegroundColor Yellow
            $adminPassword = Generate-AdminPassword 16
            $envLines = @(
                "DB_ROOT_PASSWORD=$(Generate-RandomString 32)",
                "REDIS_PASSWORD=$(Generate-RandomString 32)",
                "JWT_SECRET=$(Generate-RandomString 64)",
                "TESTNET_CLIENT_SECRET=$(Generate-RandomString 32)",
                "TESTNET_MCP_API_KEY=",
                "ADMIN_INIT_PASSWORD=$adminPassword",
                "DOCKER_REGISTRY=$selectedRegistry",
                "CORS_ALLOWED_ORIGINS=*",
                "TESTNET_VERSION=$script:Version",
                "TESTNET_NODE_NAME=$defaultNodeName"
            )
            Set-Content -Path .env -Value $envLines
            Write-Host "New secrets and version generated." -ForegroundColor Green
        } else {
            Write-Host "Using existing .env configuration." -ForegroundColor Cyan
            $content = Get-Content .env
            
            # 更新 DOCKER_REGISTRY
            if ($content -match "DOCKER_REGISTRY") {
                $content = $content -replace "DOCKER_REGISTRY=.*", "DOCKER_REGISTRY=$selectedRegistry"
            } else {
                $content += "DOCKER_REGISTRY=$selectedRegistry"
            }
            # 更新 TESTNET_VERSION
            if ($content -match "TESTNET_VERSION") {
                $content = $content -replace "TESTNET_VERSION=.*", "TESTNET_VERSION=$script:Version"
            } else {
                $content += "TESTNET_VERSION=$script:Version"
            }
            # 补全 CORS_ALLOWED_ORIGINS
            if ($content -notmatch "CORS_ALLOWED_ORIGINS") {
                $content += "CORS_ALLOWED_ORIGINS=*"
                Write-Host "Added CORS_ALLOWED_ORIGINS to .env (default: *)." -ForegroundColor Green
            }
            # 补全 TESTNET_NODE_NAME
            if ($content -notmatch "TESTNET_NODE_NAME") {
                $content += "TESTNET_NODE_NAME=$defaultNodeName"
                Write-Host "Added TESTNET_NODE_NAME to .env ($defaultNodeName)." -ForegroundColor Green
            }
            # 补全 ADMIN_INIT_PASSWORD
            if ($content -notmatch "ADMIN_INIT_PASSWORD") {
                $adminPassword = Generate-AdminPassword 16
                $content += "ADMIN_INIT_PASSWORD=$adminPassword"
                Write-Host "Generated new admin password." -ForegroundColor Green
            } else {
                $adminPassword = ($content | Select-String "ADMIN_INIT_PASSWORD=(.*)").Matches.Groups[1].Value
            }
            Set-Content .env -Value $content
        }
        
        $env:DOCKER_REGISTRY = $selectedRegistry
        if ($env:DOCKER_REGISTRY -eq "testnet0/") {
            $env:OFFICIAL_REGISTRY = ""
        } else {
            $env:OFFICIAL_REGISTRY = $env:DOCKER_REGISTRY
        }
        
        Write-Host "正在拉取最新 Docker 镜像..." -ForegroundColor Cyan
        Invoke-Expression "$dockerComposeCmd pull"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "错误: 拉取 Docker 镜像失败！" -ForegroundColor Red
            Write-Host "请检查网络连接或重新运行脚本选择其他镜像源 (如 阿里云源) 后重试。" -ForegroundColor Yellow
            exit 1
        }

        Write-Host "Launching containers..." -ForegroundColor Cyan
        Invoke-Expression "$dockerComposeCmd up -d"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "检测到重名的旧容器冲突，正在自动清理残留容器重试..." -ForegroundColor Yellow
            docker rm -f testnet-redis testnet-db testnet-server testnet-web testnet-client 2>$null
            Invoke-Expression "$dockerComposeCmd up -d"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Error: Container launch failed." -ForegroundColor Red
                Write-Host "Collecting last 20 lines of logs for troubleshooting..." -ForegroundColor Yellow
                Invoke-Expression "$dockerComposeCmd logs --tail=20"
                exit 1
            }
        }
        
        Wait-ForHealth
        
        $hostIp = Get-HostIP
        Write-Host "TestNet installed successfully!" -ForegroundColor Green
        Write-Host "Access URL:" -ForegroundColor Cyan
        if ($hostIp -and $hostIp -ne "127.0.0.1" -and $hostIp -ne "localhost") {
            Write-Host "  - 局域网访问: https://${hostIp}:3100" -ForegroundColor Cyan
        }
        Write-Host "  - 本地访问:   https://localhost:3100" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "  Admin Account Credentials" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "  Username: admin" -ForegroundColor Green
        Write-Host "  Password: $adminPassword" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "  Please save this password securely!" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
    }
    "start" {
        Load-EnvVars -Action "start"
        Write-Host "Using Registry: $($env:DOCKER_REGISTRY)" -ForegroundColor Cyan
        Invoke-Expression "$dockerComposeCmd up -d"
        Write-Host "TestNet started." -ForegroundColor Green
    }
    "stop" {
        Load-EnvVars -Action "stop"
        Invoke-Expression "$dockerComposeCmd stop"
        Write-Host "TestNet stopped." -ForegroundColor Yellow
    }
    "restart" {
        Load-EnvVars -Action "restart"
        Invoke-Expression "$dockerComposeCmd restart"
        Write-Host "TestNet restarted." -ForegroundColor Green
    }
    "update" {
        Get-RemoteVersion
        Check-Certs
        Load-EnvVars -Action "update"

        Write-Host "Updating Registry: $($env:DOCKER_REGISTRY)" -ForegroundColor Cyan
        Write-Host "Target Version: $script:Version" -ForegroundColor Cyan
        
        $content = Get-Content .env
        if ($content -match "TESTNET_VERSION") {
            $content = $content -replace "TESTNET_VERSION=.*", "TESTNET_VERSION=$script:Version"
        } else {
            $content += "TESTNET_VERSION=$script:Version"
        }
        Set-Content .env -Value $content

        Write-Host "正在拉取最新 Docker 镜像..." -ForegroundColor Cyan
        Invoke-Expression "$dockerComposeCmd pull"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "错误: 拉取 Docker 镜像失败！" -ForegroundColor Red
            Write-Host "请检查网络连接或重新运行脚本选择其他镜像源后重试。" -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "Updating and rebuilding..." -ForegroundColor Cyan
        Invoke-Expression "$dockerComposeCmd up -d --remove-orphans"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "检测到重名的旧容器冲突，正在自动清理残留容器重试..." -ForegroundColor Yellow
            docker rm -f testnet-redis testnet-db testnet-server testnet-web testnet-client 2>$null
            Invoke-Expression "$dockerComposeCmd up -d --remove-orphans"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Error: Update failed." -ForegroundColor Red
                exit 1
            }
        }
        
        Write-Host "TestNet updated and started." -ForegroundColor Green
    }
    "reset-password" {
        Load-EnvVars -Action "reset-password"
        
        $defaultPass = "Admin@123456"
        # BCrypt hash for "Admin@123456"
        $realHash = '$2a$10$8.UnVuG9HHgffUDAlk8qfOuVGkqRzgVymGe07xd00DMxs.TVuHOnu'
        
        Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║  警告：此操作将直接重置 admin 用户密码为默认值！      ║" -ForegroundColor Red
        Write-Host "║  默认密码仅用于紧急恢复，登录后必须立即修改！          ║" -ForegroundColor Red
        Write-Host "║  未修改默认密码将面临严重安全风险！                    ║" -ForegroundColor Red
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host "此操作不会修改 JWT 密钥或重置配置，也不会导致已有扫描任务丢失。" -ForegroundColor Yellow
        $confirm = Read-Host "请输入完整默认密码 ($defaultPass) 以确认重置"
        
        if ($confirm -eq $defaultPass) {
            if ([string]::IsNullOrEmpty($env:DB_ROOT_PASSWORD)) {
                Write-Host "错误：无法从 .env 获取数据库密码。请检查文件是否存在。" -ForegroundColor Red
                exit 1
            }
            
            $runningContainers = docker ps --format "{{.Names}}"
            if ($runningContainers -notmatch "^testnet-db$") {
                Write-Host "错误：数据库容器 'testnet-db' 未运行。请先执行 '.\testnet.ps1 start'。" -ForegroundColor Red
                exit 1
            }

            Write-Host "正在通过数据库重置密码..." -ForegroundColor Cyan
            $sql = "UPDATE sys_user SET password = '$realHash' WHERE username = 'admin';"
            $dbUser = if ($env:DB_USERNAME) { $env:DB_USERNAME } else { "testnet" }
            & docker exec -i -e PGPASSWORD="$($env:DB_ROOT_PASSWORD)" testnet-db psql -U "$dbUser" -d testnet -c "$sql"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "密码重置成功！" -ForegroundColor Green
                Write-Host "新密码为: $defaultPass" -ForegroundColor Green
                Write-Host "⚠  安全警告：请立即登录并修改默认密码！未修改将面临严重安全风险！" -ForegroundColor Red
                Write-Host "  修改路径：登录后 → 个人中心 → 修改密码" -ForegroundColor Yellow
            } else {
                Write-Host "重置失败。请检查数据库容器是否正常运行。" -ForegroundColor Red
            }
        } else {
            Write-Host "确认失败，取消重置。" -ForegroundColor Yellow
        }
    }
    "logs" {
        Load-EnvVars -Action "logs"
        Invoke-Expression "$dockerComposeCmd logs -f"
    }
    "status" {
        Load-EnvVars -Action "status"
        Invoke-Expression "$dockerComposeCmd ps"
    }
    Default {
        Write-Host "Usage: .\testnet.ps1 {install|start|stop|restart|update|reset-password|logs|status}" -ForegroundColor White
    }
}
