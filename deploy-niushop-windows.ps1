# NiuShop商城自动化部署脚本 (Windows版本)
# 作者: Trae AI
# 描述: 此脚本用于自动化部署NiuShop商城系统，包括代码获取、环境检查与安装、容器配置等功能

# 设置错误操作首选项
$ErrorActionPreference = "Stop"

# 定义颜色函数
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success($message) {
    Write-ColorOutput Green "[成功] $message"
}

function Write-Info($message) {
    Write-ColorOutput Cyan "[信息] $message"
}

function Write-Warning($message) {
    Write-ColorOutput Yellow "[警告] $message"
}

function Write-Error($message) {
    Write-ColorOutput Red "[错误] $message"
    exit 1
}

# 创建日志目录和文件
$logDir = "$PSScriptRoot\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = "$logDir\deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
New-Item -ItemType File -Path $logFile -Force | Out-Null

# 日志函数
function Log-Message($message) {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp - $message" | Out-File -Append -FilePath $logFile
    Write-Output $message
}

# 检查管理员权限
function Check-AdminPrivileges {
    Log-Message "检查管理员权限..."
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Error "此脚本需要管理员权限运行。请右键点击PowerShell，选择'以管理员身份运行'，然后重新执行此脚本。"
    }
    
    Write-Success "管理员权限检查通过"
}

# 检查并安装Docker
function Check-Docker {
    Log-Message "检查Docker安装状态..."
    
    $dockerInstalled = $false
    try {
        $dockerVersion = docker --version
        $dockerInstalled = $true
        Log-Message "Docker已安装: $dockerVersion"
    } catch {
        Log-Message "Docker未安装，准备安装Docker Desktop..."
    }
    
    if (-not $dockerInstalled) {
        try {
            # 下载Docker Desktop安装程序
            $dockerInstallerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
            $dockerInstallerPath = "$env:TEMP\DockerDesktopInstaller.exe"
            
            Log-Message "下载Docker Desktop安装程序..."
            Invoke-WebRequest -Uri $dockerInstallerUrl -OutFile $dockerInstallerPath
            
            # 安装Docker Desktop
            Log-Message "安装Docker Desktop..."
            Start-Process -FilePath $dockerInstallerPath -ArgumentList "install --quiet" -Wait
            
            # 删除安装程序
            Remove-Item -Path $dockerInstallerPath -Force
            
            Log-Message "Docker Desktop安装完成，请重启计算机后再次运行此脚本"
            Write-Warning "Docker Desktop安装完成，请重启计算机后再次运行此脚本"
            exit 0
        } catch {
            Write-Error "Docker安装失败: $_"
        }
    }
    
    # 检查Docker是否运行
    try {
        $dockerInfo = docker info
        Log-Message "Docker正在运行"
    } catch {
        Log-Message "Docker未运行，请启动Docker Desktop"
        Write-Warning "Docker未运行，请启动Docker Desktop后再次运行此脚本"
        exit 0
    }
    
    # 检查Docker Compose
    try {
        $dockerComposeVersion = docker-compose --version
        Log-Message "Docker Compose已安装: $dockerComposeVersion"
    } catch {
        Log-Message "Docker Compose未安装，但现代Docker Desktop已包含Docker Compose功能"
    }
    
    Write-Success "Docker环境检查通过"
}

# 检查并获取代码
function Check-Code {
    Log-Message "检查代码..."
    
    $niushopDir = "$PSScriptRoot\niushop-master"
    if (Test-Path $niushopDir) {
        Log-Message "niushop-master目录已存在"
    } else {
        Log-Message "niushop-master目录不存在，从GitHub拉取代码..."
        
        # 检查Git是否安装
        try {
            $gitVersion = git --version
            Log-Message "Git已安装: $gitVersion"
        } catch {
            Write-Error "Git未安装，请安装Git后再次运行此脚本"
        }
        
        # 克隆代码库
        try {
            Log-Message "克隆代码库..."
            git clone https://github.com/bleasprodhnf/niushop-backup.git temp-shop
            
            # 移动niushop-master目录
            if (Test-Path "temp-shop\niushop-master") {
                Move-Item -Path "temp-shop\niushop-master" -Destination $PSScriptRoot
                Log-Message "代码拉取成功"
            } else {
                Write-Error "代码库中未找到niushop-master目录"
            }
            
            # 清理临时目录
            if (Test-Path "temp-shop") {
                Remove-Item -Path "temp-shop" -Recurse -Force
            }
        } catch {
            Write-Error "代码拉取失败: $_"
        }
    }
    
    # 检查并获取Nginx Proxy Manager代码
    $nginxProxyManagerDir = "$PSScriptRoot\nginx-proxy-manager"
    if (Test-Path $nginxProxyManagerDir) {
        Log-Message "nginx-proxy-manager目录已存在"
    } else {
        Log-Message "nginx-proxy-manager目录不存在，从GitHub拉取代码..."
        
        # 克隆代码库
        try {
            Log-Message "克隆Nginx Proxy Manager代码库..."
            git clone https://github.com/bleasprodhnf/nginx-proxy-manager.git "$PSScriptRoot\nginx-proxy-manager"
            Log-Message "Nginx Proxy Manager代码拉取成功"
        } catch {
            Write-Error "Nginx Proxy Manager代码拉取失败: $_"
        }
    }
    
    Write-Success "代码检查通过"
}

# 创建必要的目录
function Create-Directories {
    Log-Message "创建必要的目录..."
    
    $directories = @(
        "$PSScriptRoot\data",
        "$PSScriptRoot\data\nginx",
        "$PSScriptRoot\data\nginx\proxy_host",
        "$PSScriptRoot\mysql_data",
        "$PSScriptRoot\logs"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Log-Message "创建目录: $dir"
        } else {
            Log-Message "目录已存在: $dir"
        }
    }
    
    Write-Success "目录创建完成"
}

# 创建Nginx代理配置文件
function Create-NginxConfig {
    Log-Message "创建Nginx代理配置文件..."
    
    $nginxConfigPath = "$PSScriptRoot\data\nginx\proxy_host\0.conf"
    $nginxConfig = @"
{
  "domain": ["localhost"],
  "forward_scheme": "http",
  "forward_host": "172.17.0.1",
  "forward_port": "8080",
  "access_list": [],
  "ssl_forced": false,
  "caching_enabled": false,
  "block_exploits": false,
  "allow_websocket_upgrade": true,
  "http2_support": false,
  "hsts_enabled": false,
  "hsts_subdomains": false,
  "locations": [
    {
      "path": "/",
      "forward_scheme": "http",
      "forward_host": "172.17.0.1",
      "forward_port": "8080"
    }
  ]
}
"@
    
    Set-Content -Path $nginxConfigPath -Value $nginxConfig
    Log-Message "Nginx代理配置文件创建成功: $nginxConfigPath"
    
    Write-Success "Nginx配置创建完成"
}

# 创建Docker Compose配置文件
function Create-DockerComposeConfig {
    Log-Message "创建Docker Compose配置文件..."
    
    $dockerComposePath = "$PSScriptRoot\docker-compose.yml"
    $dockerComposeConfig = @"
 version: '3'

 services:
  # MySQL服务
  mysql:
    image: mysql:8.0
    container_name: niushop_mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: niushop123
      MYSQL_DATABASE: niushop
      MYSQL_USER: niushop
      MYSQL_PASSWORD: niushop123
    volumes:
      - ./mysql_data:/var/lib/mysql
    ports:
      - "3306:3306"
    command: --default-authentication-plugin=mysql_native_password --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    networks:
      - niushop_network

  # PHP服务
  php:
    image: php:8.0.2-fpm
    container_name: niushop_php
    restart: always
    volumes:
      - ./niushop-master/niucloud:/var/www/html
    ports:
      - "9000:9000"
    depends_on:
      - mysql
      - redis
    environment:
      - TZ=Asia/Shanghai
    command: >
      bash -c "apt-get update && 
      apt-get install -y libfreetype6-dev libjpeg62-turbo-dev libpng-dev libzip-dev libicu-dev libonig-dev && 
      docker-php-ext-configure gd --with-freetype --with-jpeg && 
      docker-php-ext-install -j\$(nproc) gd pdo_mysql mysqli zip intl bcmath opcache && 
      pecl install redis && 
      docker-php-ext-enable redis && 
      pecl install sodium && 
      docker-php-ext-enable sodium && 
      docker-php-ext-install fileinfo && 
      chown -R www-data:www-data /var/www/html && 
      chmod -R 777 /var/www/html/runtime /var/www/html/public/upload /var/www/html/app/install && 
      if [ -f /var/www/html/.env ]; then chmod 777 /var/www/html/.env; fi && 
      php-fpm"
    networks:
      - niushop_network

  # Nginx服务
  nginx:
    image: nginx:latest
    container_name: niushop_nginx
    restart: always
    volumes:
      - ./niushop-master/niucloud:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    ports:
      - "8080:80"
    depends_on:
      - php
    networks:
      - niushop_network

  # Redis服务
  redis:
    image: redis:latest
    container_name: niushop_redis
    restart: always
    ports:
      - "6379:6379"
    networks:
      - niushop_network

  # Nginx Proxy Manager
  nginx-proxy-manager:
    build:
      context: ./nginx-proxy-manager/docker
      dockerfile: Dockerfile
    container_name: niushop_proxy_manager
    restart: always
    ports:
      - "80:80"
      - "81:81"
      - "443:443"
    volumes:
      - ./data:/data
      - ./logs:/var/log
    environment:
      - DB_SQLITE_FILE=/data/database.sqlite
    networks:
      - niushop_network

networks:
  niushop_network:
    driver: bridge
"@
    
    Set-Content -Path $dockerComposePath -Value $dockerComposeConfig
    Log-Message "Docker Compose配置文件创建成功: $dockerComposePath"
    
    Write-Success "Docker Compose配置创建完成"
}

# 创建Nginx配置文件
function Create-NginxServerConfig {
    Log-Message "创建Nginx服务器配置文件..."
    
    $nginxServerConfigPath = "$PSScriptRoot\nginx.conf"
    $nginxServerConfig = @"
server {
    listen 80;
    server_name localhost;
    root /var/www/html/public;
    index index.php index.html index.htm;
    
    location / {
        if (!-e \$request_filename) {
            rewrite ^(.*)\$ /index.php/\$1 last;
            break;
        }
    }
    
    location ~ \.php(.*) {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}

# 设置文件权限
function Set-FilePermissions {
    Log-Message "设置文件权限..."
    
    # 在Windows环境中，我们需要确保目录可写
    # 注意：实际的权限设置会在Docker容器内部完成
    # 这里只是确保Windows主机上的文件没有只读属性
    
    $directories = @(
        "$PSScriptRoot\niushop-master\niucloud\runtime",
        "$PSScriptRoot\niushop-master\niucloud\public\upload",
        "$PSScriptRoot\niushop-master\niucloud\app\install"
    )
    
    foreach ($dir in $directories) {
        if (Test-Path $dir) {
            Log-Message "设置目录权限: $dir"
            # 移除只读属性
            Get-ChildItem -Path $dir -Recurse -Force | ForEach-Object { $_.Attributes = $_.Attributes -band -bnot [System.IO.FileAttributes]::ReadOnly }
        } else {
            Log-Message "目录不存在，跳过权限设置: $dir"
        }
    }
    
    # 检查并设置.env文件权限
    $envFile = "$PSScriptRoot\niushop-master\niucloud\.env"
    if (Test-Path $envFile) {
        Log-Message "设置.env文件权限: $envFile"
        # 移除只读属性
        Set-ItemProperty -Path $envFile -Name IsReadOnly -Value $false
    }
    
    Write-Success "文件权限设置完成"
}

# 启动Docker容器
function Start-Containers {
    Log-Message "启动Docker容器..."
    
    try {
        # 使用docker-compose启动容器
        Log-Message "执行docker-compose up -d..."
        $process = Start-Process -FilePath "docker-compose" -ArgumentList "up", "-d" -NoNewWindow -PassThru -Wait
        
        if ($process.ExitCode -ne 0) {
            Write-Error "Docker容器启动失败，退出代码: $($process.ExitCode)"
        }
        
        Log-Message "Docker容器启动成功"
    } catch {
        Write-Error "Docker容器启动失败: $_"
    }
    
    Write-Success "Docker容器启动完成"
}

# 健康检查
function Check-Health {
    Log-Message "执行健康检查..."
    
    # 等待服务启动
    Log-Message "等待服务启动..."
    Start-Sleep -Seconds 10
    
    # 检查MySQL容器
    try {
        $mysqlStatus = docker ps --filter "name=niushop_mysql" --format "{{.Status}}"
        if ($mysqlStatus -match "Up") {
            Log-Message "MySQL容器运行正常: $mysqlStatus"
        } else {
            Write-Warning "MySQL容器可能未正常运行: $mysqlStatus"
        }
    } catch {
        Write-Warning "MySQL容器检查失败: $_"
    }
    
    # 检查PHP容器
    try {
        $phpStatus = docker ps --filter "name=niushop_php" --format "{{.Status}}"
        if ($phpStatus -match "Up") {
            Log-Message "PHP容器运行正常: $phpStatus"
        } else {
            Write-Warning "PHP容器可能未正常运行: $phpStatus"
        }
    } catch {
        Write-Warning "PHP容器检查失败: $_"
    }
    
    # 检查Nginx容器
    try {
        $nginxStatus = docker ps --filter "name=niushop_nginx" --format "{{.Status}}"
        if ($nginxStatus -match "Up") {
            Log-Message "Nginx容器运行正常: $nginxStatus"
        } else {
            Write-Warning "Nginx容器可能未正常运行: $nginxStatus"
        }
    } catch {
        Write-Warning "Nginx容器检查失败: $_"
    }
    
    # 检查Redis容器
    try {
        $redisStatus = docker ps --filter "name=niushop_redis" --format "{{.Status}}"
        if ($redisStatus -match "Up") {
            Log-Message "Redis容器运行正常: $redisStatus"
        } else {
            Write-Warning "Redis容器可能未正常运行: $redisStatus"
        }
    } catch {
        Write-Warning "Redis容器检查失败: $_"
    }
    
    # 检查Nginx Proxy Manager容器
    try {
        $npmStatus = docker ps --filter "name=niushop_proxy_manager" --format "{{.Status}}"
        if ($npmStatus -match "Up") {
            Log-Message "Nginx Proxy Manager容器运行正常: $npmStatus"
        } else {
            Write-Warning "Nginx Proxy Manager容器可能未正常运行: $npmStatus"
        }
    } catch {
        Write-Warning "Nginx Proxy Manager容器检查失败: $_"
    }
    
    # 检查网站是否可访问
    try {
        $webResponse = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing -TimeoutSec 5
        Log-Message "网站可以访问，状态码: $($webResponse.StatusCode)"
    } catch {
        Write-Warning "网站访问检查失败: $_"
    }
    
    Write-Success "健康检查完成"
}

# 显示安装信息
function Show-InstallationInfo {
    Log-Message "显示安装信息..."
    
    Write-Info "\n=================================================="
    Write-Info "NiuShop商城部署完成！"
    Write-Info "=================================================="
    Write-Info "访问地址: http://localhost"
    Write-Info "Nginx Proxy Manager管理地址: http://localhost:81"
    Write-Info "  - 默认用户名: admin@example.com"
    Write-Info "  - 默认密码: changeme"
    Write-Info "数据库信息:"
    Write-Info "  - 主机: mysql"
    Write-Info "  - 数据库: niushop"
    Write-Info "  - 用户名: niushop"
    Write-Info "  - 密码: niushop123"
    Write-Info "=================================================="
    Write-Info "首次访问时，请完成安装向导。在数据库配置步骤中，使用上述数据库信息。"
    Write-Info "建议将商城名称设置为'模板商城'。"
    Write-Info "=================================================="
    
    Log-Message "安装信息显示完成"
}

# 备份功能
function Backup-System {
    param (
        [string]$BackupPath = "$PSScriptRoot\backups"
    )
    
    Log-Message "开始系统备份..."
    
    # 创建备份目录
    if (-not (Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupFile = "$BackupPath\niushop-backup-$timestamp.zip"
    
    try {
        # 停止容器
        Log-Message "停止容器以确保数据一致性..."
        docker-compose stop
        
        # 创建备份
        Log-Message "创建备份文件: $backupFile"
        Compress-Archive -Path "$PSScriptRoot\niushop-master", "$PSScriptRoot\mysql_data", "$PSScriptRoot\data" -DestinationPath $backupFile -Force
        
        # 重启容器
        Log-Message "重启容器..."
        docker-compose start
        
        Write-Success "系统备份完成: $backupFile"
    } catch {
        Write-Error "系统备份失败: $_"
    }
}

# 恢复功能
function Restore-System {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BackupFile
    )
    
    Log-Message "开始系统恢复..."
    
    if (-not (Test-Path $BackupFile)) {
        Write-Error "备份文件不存在: $BackupFile"
    }
    
    try {
        # 停止并移除容器
        Log-Message "停止并移除容器..."
        docker-compose down
        
        # 备份当前数据
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $currentBackupDir = "$PSScriptRoot\pre_restore_backup_$timestamp"
        Log-Message "备份当前数据到: $currentBackupDir"
        New-Item -ItemType Directory -Path $currentBackupDir -Force | Out-Null
        
        # 移动当前数据
        if (Test-Path "$PSScriptRoot\mysql_data") {
            Move-Item -Path "$PSScriptRoot\mysql_data" -Destination $currentBackupDir
        }
        if (Test-Path "$PSScriptRoot\data") {
            Move-Item -Path "$PSScriptRoot\data" -Destination $currentBackupDir
        }
        
        # 解压备份文件
        Log-Message "解压备份文件..."
        Expand-Archive -Path $BackupFile -DestinationPath $PSScriptRoot -Force
        
        # 启动容器
        Log-Message "启动容器..."
        docker-compose up -d
        
        Write-Success "系统恢复完成"
    } catch {
        Write-Error "系统恢复失败: $_"
    }
}

# 主函数
function Main {
    Write-Info "开始NiuShop商城自动化部署..."
    
    # 检查管理员权限
    Check-AdminPrivileges
    
    # 检查Docker环境
    Check-Docker
    
    # 检查并获取代码
    Check-Code
    
    # 创建必要的目录
    Create-Directories
    
    # 创建Nginx代理配置文件
    Create-NginxConfig
    
    # 创建Docker Compose配置文件
    Create-DockerComposeConfig
    
    # 创建Nginx服务器配置文件
    Create-NginxServerConfig
    
    # 设置文件权限
    Set-FilePermissions
    
    # 启动Docker容器
    Start-Containers
    
    # 健康检查
    Check-Health
    
    # 显示安装信息
    Show-InstallationInfo
    
    Write-Success "NiuShop商城自动化部署完成！"
}

# 执行主函数
Main