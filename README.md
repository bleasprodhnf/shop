# NiuShop商城部署脚本

这个仓库包含了NiuShop商城的自动化部署脚本，支持Linux、macOS和Windows平台。

## 仓库结构

```
├── deploy-niushop-linux.sh    # Linux平台部署脚本
├── deploy-niushop-macos.sh    # macOS平台部署脚本
├── deploy-niushop-windows.ps1  # Windows平台部署脚本
├── nginx-proxy-manager/       # Nginx代理管理器
└── niushop-master/           # NiuShop商城源代码
```

## 快速开始

### Linux平台

```bash
chmod +x deploy-niushop-linux.sh
./deploy-niushop-linux.sh
```

### macOS平台

```bash
chmod +x deploy-niushop-macos.sh
./deploy-niushop-macos.sh
```

### Windows平台

```powershell
.\deploy-niushop-windows.ps1
```

## 部署完成后

1. 访问商城：http://localhost
2. 访问Nginx代理管理器：http://localhost:81
   - 默认用户名：admin@admin.com
   - 默认密码：88888888

## 数据库信息

- 主机：mysql
- 数据库：niushop
- 用户名：niushop
- 密码：niushop123

## 备份和恢复

### Linux/macOS

```bash
# 备份
./deploy-niushop-linux.sh backup
# 或
./deploy-niushop-macos.sh backup

# 恢复
./deploy-niushop-linux.sh restore <备份文件路径>
# 或
./deploy-niushop-macos.sh restore <备份文件路径>
```

### Windows

```powershell
# 备份
.\deploy-niushop-windows.ps1 -Action backup

# 恢复
.\deploy-niushop-windows.ps1 -Action restore -BackupFile <备份文件路径>
```

## 注意事项

1. 确保系统已安装Docker和Docker Compose
2. Windows平台需要启用WSL2和Docker Desktop
3. macOS平台需要安装Homebrew
4. 首次访问时需要完成安装向导
5. 建议将商城名称设置为"模板商城"

## 许可证

本项目采用MIT许可证，详见LICENSE文件。