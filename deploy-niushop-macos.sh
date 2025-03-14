#!/bin/bash
# NiuShop商城自动化部署脚本 (macOS版本)
# 作者: Trae AI
# 描述: 此脚本用于自动化部署NiuShop商城系统，包括代码获取、环境检查与安装、容器配置等功能

# 设置错误处理
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志目录和文件
LOG_DIR="$(pwd)/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"
touch "$LOG_FILE"

# 日志函数
log_message() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp - $1" | tee -a "$LOG_FILE"
}

# 成功消息
success_message() {
    echo -e "${GREEN}[成功] $1${NC}"
    log_message "[成功] $1"
}

# 信息消息
info_message() {
    echo -e "${CYAN}[信息] $1${NC}"
    log_message "[信息] $1"
}

# 警告消息
warning_message() {
    echo -e "${YELLOW}[警告] $1${NC}"
    log_message "[警告] $1"
}

# 错误消息
error_message() {
    echo -e "${RED}[错误] $1${NC}"
    log_message "[错误] $1"
    exit 1
}

# 检查并安装Homebrew
check_homebrew() {
    log_message "检查Homebrew安装状态..."
    
    if command -v brew &> /dev/null; then
        local brew_version=$(brew --version | head -n 1)
        log_message "Homebrew已安装: $brew_version"
    else
        log_message "Homebrew未安装，准备安装Homebrew..."
        
        # 安装Homebrew
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # 检查安装结果
        if ! command -v brew &> /dev/null; then
            error_message "Homebrew安装失败"
        fi
        
        log_message "Homebrew安装完成"
    fi
    
    success_message "Homebrew检查通过"
}

# 检查并安装Docker
check_docker() {
    log_message "检查Docker安装状态..."
    
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version)
        log_message "Docker已安装: $docker_version"
    else
        log_message "Docker未安装，准备安装Docker..."
        
        # 使用Homebrew安装Docker
        brew install --cask docker
        
        log_message "Docker安装完成，请启动Docker Desktop应用"
        open -a Docker
        
        # 等待Docker启动
        log_message "等待Docker启动..."
        warning_message "请确保Docker Desktop已启动，然后按Enter键继续..."
        read -p ""
    fi
    
    # 检查Docker是否运行
    if ! docker info &> /dev/null; then
        log_message "Docker未运行，请启动Docker Desktop"
        warning_message "Docker未运行，请启动Docker Desktop后再次运行此脚本"
        exit 0
    fi
    
    # 检查Docker Compose
    if command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version)
        log_message "Docker Compose已安装: $compose_version"
    else
        log_message "安装Docker Compose..."
        brew install docker-compose
        log_message "Docker Compose安装完成"
    fi
    
    success_message "Docker环境检查通过"
}

# 检查并获取代码
check_code() {
    log_message "检查代码..."
    
    local niushop_dir="$(pwd)/niushop-master"
    if [ -d "$niushop_dir" ]; then
        log_message "niushop-master目录已存在"
    else
        log_message "niushop-master目录不存在，从GitHub拉取代码..."
        
        # 检查Git是否安装
        if ! command -v git &> /dev/null; then
            log_message "Git未安装，准备安装Git..."
            brew install git
            log_message "Git安装完成"
        fi
        
        # 克隆代码库
        log_message "克隆代码库..."
        git clone https://github.com/bleasprodhnf/niushop-backup.git temp-shop
        
        # 移动niushop-master目录
        if [ -d "temp-shop/niushop-master" ]; then
            mv temp-shop/niushop-master .
            log_message "代码拉取成功"
        else
            error_message "代码库中未找到niushop-master目录"
        fi
        
        # 清理临时目录
        if [ -d "temp-shop" ]; then
            rm -rf temp-shop
        fi
    fi
    
    success_message "代码检查通过"
}

# 创建必要的目录
create_directories() {
    log_message "创建必要的目录..."
    
    local directories=(
        "$(pwd)/data"
        "$(pwd)/data/nginx"
        "$(pwd)/data/nginx/proxy_host"
        "$(pwd)/mysql_data"
        "$(pwd)/logs"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_message "创建目录: $dir"
        else
            log_message "目录已存在: $dir"
        fi
    done
    
    success_message "目录创建完成"
}

# 创建Nginx代理配置文件
create_nginx_config() {
    log_message "创建Nginx代理配置文件..."
    
    local nginx_config_path="$(pwd)/data/nginx/proxy_host/0.conf"
    cat > "$nginx_config_path" << 'EOF'
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
EOF
    
    log_message "Nginx代理配置文件创建成功: $nginx_config_path"
    
    success_message "Nginx配置创建完成"
}

# 创建Docker Compose配置文件
create_docker_compose_config() {
    log_message "创建Docker Compose配置文件..."
    
    local docker_compose_path="$(pwd)/docker-compose.yml"
    cat > "$docker_compose_path" << 'EOF'
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
      docker-php-ext-install -j$(nproc) gd pdo_mysql mysqli zip intl bcmath opcache && 
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
EOF
    
    log_message "Docker Compose配置文件创建成功: $docker_compose_path"
    
    success_message "Docker Compose配置创建完成"
}

# 创建Nginx配置文件
create_nginx_server_config() {
    log_message "创建Nginx服务器配置文件..."
    
    local nginx_server_config_path="$(pwd)/nginx.conf"
    cat > "$nginx_server_config_path" << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /var/www/html/public;
    index index.php index.html index.htm;
    
    location / {
        if (!-e $request_filename) {
            rewrite ^(.*)$ /index.php/$1 last;
            break;
        }
    }
    
    location ~ \.php(.*) {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
    
    log_message "Nginx服务器配置文件创建成功: $nginx_server_config_path"
    
    success_message "Nginx服务器配置创建完成"
}

# 设置文件权限
set_file_permissions() {
    log_message "设置文件权限..."
    
    # 设置niucloud目录权限
    local niucloud_dir="$(pwd)/niushop-master/niucloud"
    if [ -d "$niucloud_dir" ]; then
        log_message "设置niucloud目录权限: $niucloud_dir"
        
        # 设置runtime目录权限
        if [ -d "$niucloud_dir/runtime" ]; then
            chmod -R 777 "$niucloud_dir/runtime"
            log_message "设置runtime目录权限: $niucloud_dir/runtime"
        fi
        
        # 设置public/upload目录权限
        if [ -d "$niucloud_dir/public/upload" ]; then
            chmod -R 777 "$niucloud_dir/public/upload"
            log_message "设置public/upload目录权限: $niucloud_dir/public/upload"
        fi
        
        # 设置app/install目录权限
        if [ -d "$niucloud_dir/app/install" ]; then
            chmod -R 777 "$niucloud_dir/app/install"
            log_message "设置app/install目录权限: $niucloud_dir/app/install"
        fi
        
        # 设置.env文件权限
        if [ -f "$niucloud_dir/.env" ]; then
            chmod 777 "$niucloud_dir/.env"
            log_message "设置.env文件权限: $niucloud_dir/.env"
        fi
    else
        warning_message "niucloud目录不存在，跳过权限设置: $niucloud_dir"
    fi
    
    success_message "文件权限设置完成"
}

# 启动Docker容器
start_containers() {
    log_message "启动Docker容器..."
    
    # 使用docker-compose启动容器
    log_message "执行docker-compose up -d..."
    docker-compose up -d
    
    if [ $? -ne 0 ]; then
        error_message "Docker容器启动失败"
    fi
    
    log_message "Docker容器启动成功"
    success_message "Docker容器启动完成"
}

# 健康检查
check_health() {
    log_message "执行健康检查..."
    
    # 等待服务启动
    log_message "等待服务启动..."
    sleep 10
    
    # 检查MySQL容器
    local mysql_status=$(docker ps --filter "name=niushop_mysql" --format "{{.Status}}")
    if [[ $mysql_status == *"Up"* ]]; then
        log_message "MySQL容器运行正常: $mysql_status"
    else
        warning_message "MySQL容器可能未正常运行: $mysql_status"
    fi
    
    # 检查PHP容器
    local php_status=$(docker ps --filter "name=niushop_php" --format "{{.Status}}")
    if [[ $php_status == *"Up"* ]]; then
        log_message "PHP容器运行正常: $php_status"
    else
        warning_message "PHP容器可能未正常运行: $php_status"
    fi
    
    # 检查Nginx容器
    local nginx_status=$(docker ps --filter "name=niushop_nginx" --format "{{.Status}}")
    if [[ $nginx_status == *"Up"* ]]; then
        log_message "Nginx容器运行正常: $nginx_status"
    else
        warning_message "Nginx容器可能未正常运行: $nginx_status"
    fi
    
    # 检查Redis容器
    local redis_status=$(docker ps --filter "name=niushop_redis" --format "{{.Status}}")
    if [[ $redis_status == *"Up"* ]]; then
        log_message "Redis容器运行正常: $redis_status"
    else
        warning_message "Redis容器可能未正常运行: $redis_status"
    fi
    
    # 检查Nginx Proxy Manager容器
    local npm_status=$(docker ps --filter "name=niushop_proxy_manager" --format "{{.Status}}")
    if [[ $npm_status == *"Up"* ]]; then
        log_message "Nginx Proxy Manager容器运行正常: $npm_status"
    else
        warning_message "Nginx Proxy Manager容器可能未正常运行: $npm_status"
    fi
    
    # 检查网站是否可访问
    if curl -s --head --request GET http://localhost:8080 | grep "200" > /dev/null; then
        log_message "网站可以访问，状态码: 200"
    else
        warning_message "网站访问检查失败"
    fi
    
    success_message "健康检查完成"
}

# 显示安装信息
show_installation_info() {
    log_message "显示安装信息..."
    
    info_message "\n=================================================="
    info_message "NiuShop商城部署完成！"
    info_message "=================================================="
    info_message "访问地址: http://localhost"
    info_message "Nginx Proxy Manager管理地址: http://localhost:81"
    info_message "  - 默认用户名: admin@example.com"
    info_message "  - 默认密码: changeme"
    info_message "数据库信息:"
    info_message "  - 主机: mysql"
    info_message "  - 数据库: niushop"
    info_message "  - 用户名: niushop"
    info_message "  - 密码: niushop123"
    info_message "=================================================="
    info_message "首次访问时，请完成安装向导。在数据库配置步骤中，使用上述数据库信息。"
    info_message "建议将商城名称设置为'模板商城'。"
    info_message "=================================================="
    
    log_message "安装信息显示完成"
}

# 备份功能
backup_system() {
    local backup_path="$(pwd)/backups"
    
    log_message "开始系统备份..."
    
    # 创建备份目录
    if [ ! -d "$backup_path" ]; then
        mkdir -p "$backup_path"
    fi
    
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local backup_file="$backup_path/niushop-backup-$timestamp.tar.gz"
    
    # 停止容器
    log_message "停止容器以确保数据一致性..."
    docker-compose stop
    
    # 创建备份
    log_message "创建备份文件: $backup_file"
    tar -czf "$backup_file" niushop-master mysql_data data
    
    # 重启容器
    log_message "重启容器..."
    docker-compose start
    
    success_message "系统备份完成: $backup_file"
}

# 恢复功能
restore_system() {
    local backup_file="$1"
    
    log_message "开始系统恢复..."
    
    if [ ! -f "$backup_file" ]; then
        error_message "备份文件不存在: $backup_file"
    fi
    
    # 停止并移除容器
    log_message "停止并移除容器..."
    docker-compose down
    
    # 备份当前数据
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local current_backup_dir="$(pwd)/pre_restore_backup_$timestamp"
    log_message "备份当前数据到: $current_backup_dir"
    mkdir -p "$current_backup_dir"
    
    # 移动当前数据
    if [ -d "$(pwd)/mysql_data" ]; then
        mv "$(pwd)/mysql_data" "$current_backup_dir"
    fi
    if [ -d "$(pwd)/data" ]; then
        mv "$(pwd)/data" "$current_backup_dir"
    fi
    
    # 解压备份文件
    log_message "解压备份文件..."
    tar -xzf "$backup_file"
    
    # 启动容器
    log_message "启动容器..."
    docker-compose up -d
    
    success_message "系统恢复完成"
}

# 主函数
main() {
    info_message "开始NiuShop商城自动化部署..."
    
    # 检查Homebrew
    check_homebrew
    
    # 检查Docker环境
    check_docker
    
    # 检查并获取代码
    check_code
    
    # 创建必要的目录
    create_directories
    
    # 创建Nginx代理配置文件
    create_nginx_config
    
    # 创建Docker Compose配置文件
    create_docker_compose_config
    
    # 创建Nginx服务器配置文件
    create_nginx_server_config
    
    # 设置文件权限
    set_file_permissions
    
    # 启动Docker容器
    start_containers
    
    # 健康检查
    check_health
    
    # 显示安装信息
    show_installation_info
    
    success_message "NiuShop商城自动化部署完成！"
}

# 处理命令行参数
if [ $# -eq 0 ]; then
    # 无参数，执行主函数
    main
else
    case "$1" in
        backup)
            backup_system
            ;;
        restore)
            if [ -z "$2" ]; then
                error_message "恢复功能需要指定备份文件路径"
            fi
            restore_system "$2"
            ;;
        *)
            error_message "未知参数: $1"
            ;;
    esac
fi