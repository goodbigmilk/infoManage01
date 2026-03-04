# Windows 原生部署指南（无需 Docker）

## 简介

这是一个**无需 Docker** 的 Windows 原生部署方案，专为国内用户优化：
- ✅ 不需要安装 Docker Desktop
- ✅ 不需要 WSL（Windows Subsystem for Linux）
- ✅ 使用国内镜像源，无需梯子
- ✅ 一键安装，自动配置
- ✅ 完全原生 Windows 服务

## 前提条件

- Windows 10/11 或 Windows Server 2019/2022
- 管理员权限
- 稳定的网络连接（首次安装需要下载约 200MB）

## 快速开始

### 方式 1: 使用批处理文件（推荐）

1. **以管理员身份运行 `deploy-native.bat`**
   - 右键 `deploy-native.bat` → 选择 "以管理员身份运行"
   - 或在管理员命令提示符中运行：
   ```cmd
   deploy-native.bat
   ```

2. **等待自动安装**
   脚本会自动完成以下操作：
   - 下载并安装 Go 1.21
   - 下载并安装 MySQL 8.0
   - 编译应用程序
   - 配置并启动服务

3. **访问应用**
   安装完成后，在浏览器访问：
   ```
   http://localhost:9901
   ```

### 方式 2: 使用 PowerShell

1. **以管理员身份打开 PowerShell**
   - Win+X → 选择 "Windows PowerShell (管理员)"

2. **进入项目目录**
   ```powershell
   cd 你的项目路径
   ```

3. **运行部署脚本**
   ```powershell
   .\deploy-windows-native.ps1 install
   ```

## 常用命令

安装完成后，可以使用以下命令管理应用：

```powershell
# 启动服务
.\deploy-windows-native.ps1 start

# 停止服务
.\deploy-windows-native.ps1 stop

# 重启服务
.\deploy-windows-native.ps1 restart

# 查看状态
.\deploy-windows-native.ps1 status

# 查看日志
.\deploy-windows-native.ps1 logs

# 卸载所有组件
.\deploy-windows-native.ps1 uninstall

# 查看帮助
.\deploy-windows-native.ps1 help
```

或使用批处理文件：

```cmd
deploy-native.bat start
deploy-native.bat stop
deploy-native.bat status
```

## 自定义配置

### 修改端口

```powershell
# 修改应用端口为 8080
$env:PORT = "8080"
.\deploy-windows-native.ps1 install
```

### 修改 MySQL 密码

```powershell
# 修改 MySQL root 密码
$env:MYSQL_ROOT_PASSWORD = "your_password"
.\deploy-windows-native.ps1 install
```

## 安装位置

默认安装路径：`C:\infoManage`

```
C:\infoManage\
├── go\           # Go 运行环境
├── mysql\        # MySQL 数据库
│   ├── data\     # 数据库文件
│   └── my.ini    # MySQL 配置
└── logs\         # 日志文件
```

应用程序文件保持在原项目目录中。

## 下载源

为了加快国内用户的下载速度，使用以下国内镜像源：

- **Go**: https://golang.google.cn/dl/
- **MySQL**: https://mirrors.aliyun.com/mysql/
- **Go 模块代理**: https://goproxy.cn

## 服务管理

应用作为 Windows 计划任务运行，开机自动启动。

### 查看服务

1. **MySQL 服务**
   - 服务名称: `MySQL80_infoManage`
   - 查看方式: Win+R → 输入 `services.msc` → 找到该服务

2. **应用服务**
   - 任务名称: `infoManage`
   - 查看方式: 任务计划程序 → 任务计划程序库

## 卸载

完全卸载应用和所有依赖：

```powershell
.\deploy-windows-native.ps1 uninstall
```

**警告**: 这将删除所有数据，无法恢复！

卸载前需要输入 `UNINSTALL` 确认。

## 故障排除

### 问题 1: "需要管理员权限"

**解决方案**:
- 右键脚本文件 → 选择 "以管理员身份运行"
- 或在管理员 PowerShell 中运行

### 问题 2: 下载速度慢

**解决方案**:
- 脚本已使用国内镜像源，正常速度应该很快
- 如果仍然很慢，检查网络连接
- 可以手动下载文件后放到 `C:\Users\你的用户名\AppData\Local\Temp\`

### 问题 3: 端口被占用

**解决方案**:
```powershell
# 修改端口后重新安装
$env:PORT = "8080"
.\deploy-windows-native.ps1 install
```

或手动查找占用端口的进程：
```powershell
netstat -ano | findstr :9901
taskkill /PID 进程ID /F
```

### 问题 4: MySQL 启动失败

**解决方案**:
1. 检查 3306 端口是否被占用
2. 查看 MySQL 错误日志: `C:\infoManage\mysql\data\*.err`
3. 尝试重新安装

### 问题 5: 应用无法访问

**解决方案**:
1. 检查防火墙设置
2. 运行 `.\deploy-windows-native.ps1 status` 查看服务状态
3. 检查日志文件

## 与 Docker 版本的区别

| 特性 | Docker 版本 | 原生版本 |
|------|------------|----------|
| 需要 Docker | ✅ 是 | ❌ 否 |
| 需要 WSL | ✅ 是 | ❌ 否 |
| 安装复杂度 | 高 | 低 |
| 启动速度 | 慢 | 快 |
| 资源占用 | 高 | 低 |
| 国内网络友好 | ❌ 否 | ✅ 是 |
| 跨平台 | ✅ 是 | ❌ 仅 Windows |

## 性能优化

### 数据库优化

编辑 `C:\infoManage\mysql\my.ini`:

```ini
[mysqld]
# 增加最大连接数
max_connections=500

# 增加缓冲池大小（根据内存调整）
innodb_buffer_pool_size=512M

# 查询缓存
query_cache_size=64M
```

修改后重启 MySQL:
```powershell
.\deploy-windows-native.ps1 restart
```

## 备份与恢复

### 备份数据库

```cmd
cd C:\infoManage\mysql\bin
mysqldump -u root -prootmysql infoManage > backup.sql
```

### 恢复数据库

```cmd
cd C:\infoManage\mysql\bin
mysql -u root -prootmysql infoManage < backup.sql
```

## 支持

如有问题，请访问：
- GitHub Issues: https://github.com/goodbigmilk/infoManage01/issues
- 项目主页: https://github.com/goodbigmilk/infoManage01

## 更新日志

### v1.0 (2026-03-04)
- 首个 Windows 原生部署版本
- 支持一键安装 Go + MySQL
- 使用国内镜像源
- 自动配置 Windows 服务
