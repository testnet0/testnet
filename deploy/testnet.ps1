# 支持: install | start | stop | restart | update | reset-password | logs | status
$Version = "v3.0.0beta"
$VersionUrl = "https://cnb.cool/testnet0/testnet-public/-/git/raw/main/version.yml"

Function Get-RemoteVersion {
    Write-Host "正在从远程获取最新版本号..." -ForegroundColor Cyan
    try {
        $content = Invoke-RestMethod -Uri $VersionUrl -UseBasicParsing
        if ($content -match "version=(.*)") {
            $script:Version = $matches[1].Trim()
            $env:TESTNET_VERSION = $script:Version
            Write-Host "获取成功，当前最新版本: $Version" -ForegroundColor Green
        } else {
            Write-Host "警告: 远程文件格式错误，将使用默认版本: $Version" -ForegroundColor Yellow
            $env:TESTNET_VERSION = $script:Version
        }
    } catch {
        Write-Host "警告: 无法获取远程版本号 ($($_.Exception.Message))，将使用默认版本: $Version" -ForegroundColor Yellow
        $env:TESTNET_VERSION = $script:Version
    }
}


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
    -join $result
}

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
    -join $result
}

Function Get-DockerCompose {
    if (docker compose version >$null 2>&1) { return "docker compose" }
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) { return "docker-compose" }
    return $null
}

Function Load-EnvVars {
    param([string]$Action)
    if (Test-Path .env) {
        $envFile = Get-Content .env
        foreach ($line in $envFile) {
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
        if ($null -eq $env:DOCKER_REGISTRY) { $env:DOCKER_REGISTRY = "testnet0/" }
        
        # 如果没有版本号，尝试获取一次（仅针对 start/restart 等非安装指令）
        if ([string]::IsNullOrEmpty($env:TESTNET_VERSION) -and $Action -ne "install" -and $Action -ne "update") {
            Write-Host "检测到 .env 中缺少版本号，正在尝试补全..." -ForegroundColor Yellow
            Get-RemoteVersion
        }
    } elseif ($Action -ne "install") {
        Write-Host "Error: .env file not found. Have you run 'install' yet?" -ForegroundColor Red
        exit 1
    }
}

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
    return $cmd
}

$action = $args[0]
$dockerComposeCmd = Check-Env

switch ($action) {
    "install" {
        Get-RemoteVersion
        $dockerComposeCmd = Check-Env

        
        Write-Host "请选择镜像源 (Choose Mirror Source):" -ForegroundColor Cyan
        Write-Host "1) DockerHub (默认)"
        Write-Host "2) 阿里云 (Alibaba Cloud - 中国加速)"
        $choice = Read-Host "请输入选项 [1-2, 默认1]"
        
        $selectedRegistry = ""
        if ($choice -eq "2") {
            $selectedRegistry = "registry.cn-hangzhou.aliyuncs.com/testnet0/"
            Write-Host "已选择阿里云镜像源。" -ForegroundColor Green
        } else {
            Write-Host "已选择 DockerHub 默认源。" -ForegroundColor Green
        }

        if (-not (Test-Path .env)) {
            Write-Host "Creating .env with dynamic secrets..." -ForegroundColor Yellow
            $adminPassword = Generate-AdminPassword
            $envContent = "DB_ROOT_PASSWORD=$(Generate-RandomString)`nJWT_SECRET=$(Generate-RandomString)`nTESTNET_CLIENT_SECRET=$(Generate-RandomString)`nADMIN_INIT_PASSWORD=$adminPassword`nDOCKER_REGISTRY=$selectedRegistry`nTESTNET_VERSION=$Version"
            Set-Content -Path .env -Value $envContent
            Write-Host "New secrets and version generated." -ForegroundColor Green
        } else {
            Write-Host "Using existing .env configuration." -ForegroundColor Cyan
            $content = Get-Content .env
            # 更新 DOCKER_REGISTRY
            if ($content -match "DOCKER_REGISTRY") {
                $content = $content -replace "DOCKER_REGISTRY=.*", "DOCKER_REGISTRY=$selectedRegistry"
            } else {
                $content += "`nDOCKER_REGISTRY=$selectedRegistry"
            }
            # 更新 TESTNET_VERSION
            if ($content -match "TESTNET_VERSION") {
                $content = $content -replace "TESTNET_VERSION=.*", "TESTNET_VERSION=$Version"
            } else {
                $content += "`nTESTNET_VERSION=$Version"
            }
            if ($content -notmatch "ADMIN_INIT_PASSWORD") {
                $adminPassword = Generate-AdminPassword
                $content += "`nADMIN_INIT_PASSWORD=$adminPassword"
                Write-Host "Generated new admin password." -ForegroundColor Green
            } else {
                $adminPassword = ($content | Select-String "ADMIN_INIT_PASSWORD=(.*)").Matches.Groups[1].Value
            }
            Set-Content .env -Value $content
        }
        
        # 设置环境变量供当前进程使用
        $env:DOCKER_REGISTRY = $selectedRegistry
        
        # 如果本地已存在镜像，则执行 pull 以确保是最新版本
        $existingImages = docker images --format "{{.Repository}}" | Select-String "testnet-"
        if ($existingImages) {
            Write-Host "检测到本地已存在 TestNet 镜像，正在尝试拉取更新..." -ForegroundColor Cyan
            Invoke-Expression "$dockerComposeCmd pull"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "警告: 拉取最新镜像失败，将尝试使用本地现有镜像启动。" -ForegroundColor Yellow
            }
        }

        Write-Host "Launching containers..." -ForegroundColor Cyan
        Invoke-Expression "$dockerComposeCmd up -d"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Container launch failed." -ForegroundColor Red
            Write-Host "Collecting last 20 lines of logs for troubleshooting..." -ForegroundColor Yellow
            Invoke-Expression "$dockerComposeCmd logs --tail=20"
            exit 1
        }
        
        Write-Host "TestNet installed successfully!" -ForegroundColor Green
        Write-Host "Access URL: https://localhost:3100" -ForegroundColor Cyan
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
        Load-EnvVars -Action "update"

        Write-Host "Updating Registry: $($env:DOCKER_REGISTRY)" -ForegroundColor Cyan
        Write-Host "Target Version: $Version" -ForegroundColor Cyan
        
        # 更新 .env 中的版本号
        $content = Get-Content .env
        if ($content -match "TESTNET_VERSION") {
            $content = $content -replace "TESTNET_VERSION=.*", "TESTNET_VERSION=$Version"
        } else {
            $content += "`nTESTNET_VERSION=$Version"
        }
        Set-Content .env -Value $content

        Write-Host "Pulling latest images..." -ForegroundColor Cyan
        Invoke-Expression "$dockerComposeCmd pull"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warning: Pull failed. Trying to start with local images..." -ForegroundColor Yellow
        }
        
        Write-Host "Updating and rebuilding..." -ForegroundColor Cyan
        Invoke-Expression "$dockerComposeCmd up -d --remove-orphans"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Update failed." -ForegroundColor Red
            exit 1
        }
        
        Write-Host "TestNet updated and started." -ForegroundColor Green
    }
    "reset-password" {
        Load-EnvVars -Action "reset-password"
        
        $defaultPass = "Admin@123456"
        # BCrypt hash for "Admin@123456"
        $realHash = '$2a$10$8.UnVuG9HHgffUDAlk8qfOuVGkqRzgVymGe07xd00DMxs.TVuHOnu'
        
        Write-Host "警告：此操作将直接重置 Web 管理界面的 'admin' 用户密码。" -ForegroundColor Red
        Write-Host "它不会修改 JWT 密钥或重置配置，服务无需重启。" -ForegroundColor Yellow
        $confirm = Read-Host "确定要将 admin 密码重置为默认值 ($defaultPass) 吗? (y/n)"
        
        if ($confirm -eq "y") {
            if ([string]::IsNullOrEmpty($env:DB_ROOT_PASSWORD)) {
                Write-Host "错误：无法从 .env 获取数据库密码。" -ForegroundColor Red
                exit 1
            }
            
            # 检查数据库容器是否在运行
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
                Write-Host "请在登录后尽快修改初始密码。" -ForegroundColor Yellow
            } else {
                Write-Host "重置失败。请检查数据库容器是否正常运行。" -ForegroundColor Red
            }
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
