# Windows 部署脚本修复说明

## 修复的问题

### 1. 编码问题 (已修复)
**问题**: deploy.ps1:177 使用 ASCII 编码写入 .env 文件,无法处理非 ASCII 字符
**修复**: 改为使用 UTF-8 without BOM 编码
```powershell
# 修复前
[System.IO.File]::WriteAllText(..., $envContent, [System.Text.Encoding]::ASCII)

# 修复后
[System.IO.File]::WriteAllText(..., $envContent, [System.Text.UTF8Encoding]::new($false))
```

### 2. Docker Desktop 路径查找 (已改进)
**问题**: 硬编码 Docker Desktop 安装路径,只检查 Program Files
**修复**: 添加 `Find-DockerDesktop` 函数,检查多个可能的安装位置:
- `C:\Program Files\Docker\Docker\Docker Desktop.exe`
- `C:\Program Files (x86)\Docker\Docker\Docker Desktop.exe`
- `%LOCALAPPDATA%\Docker\Docker Desktop\Docker Desktop.exe`

### 3. 非交互模式支持 (已添加)
**问题**: 脚本在 CI/CD 环境中会卡在交互式输入
**修复**: 添加 `-NonInteractive` 参数
```powershell
.\deploy.ps1 -NonInteractive
```
在非交互模式下:
- 端口冲突时自动选择下一个可用端口
- clean 命令会报错(需要手动确认)

### 4. 端口冲突处理 (已增强)
**问题**: 端口被占用时只能手动输入新端口
**修复**: 添加 `Get-NextAvailablePort` 函数
- 交互模式: 按 Enter 自动选择可用端口
- 非交互模式: 自动选择可用端口

### 5. 清理操作安全性 (已增强)
**问题**: 清理数据只需按 'Y' 确认,容易误操作
**修复**: 要求输入完整的 'DELETE' 确认词
```powershell
# 修复前
$confirm = Read-Host "Confirm? (y/N)"
if ($confirm -match "^[Yy]$") { ... }

# 修复后
$confirm = Read-Host "Type 'DELETE' to confirm"
if ($confirm -eq "DELETE") { ... }
```

## 测试

### GitHub Actions 自动测试
已添加 `.github/workflows/test-windows-deploy.yml` 工作流,包含:

1. **语法测试**: 验证 PowerShell 脚本语法正确性
2. **Docker Compose 配置验证**: 检查 docker-compose.yml 格式
3. **功能测试**: 测试脚本的各个函数
4. **边界测试**:
   - 特殊字符处理 (密码包含 `@!#` 等)
   - UTF-8 编码测试 (中文字符)
5. **批处理文件测试**: 测试 deploy.bat 包装器

### 触发条件
- Push 到 main 分支
- Pull Request 到 main 分支
- 手动触发 (workflow_dispatch)
- 相关文件变更时

### 本地测试 (需要 Windows 环境)

```powershell
# 1. 语法检查
$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Path .\deploy.ps1 -Raw), [ref]$null)

# 2. 查看帮助
.\deploy.ps1 help

# 3. 测试非交互部署
$env:APP_PORT="8080"
.\deploy.ps1 -NonInteractive

# 4. 测试端口自动选择
# (确保 9901 端口被占用)
.\deploy.ps1

# 5. 测试清理
.\deploy.ps1 clean
```

## 使用方法

### 基本使用
```powershell
# 一键部署 (默认端口 9901)
.\deploy.ps1

# 或使用批处理文件
.\deploy.bat
```

### 自定义端口
```powershell
$env:APP_PORT="8080"
$env:MYSQL_PORT="3307"
.\deploy.ps1
```

### CI/CD 使用
```powershell
# 非交互模式部署
.\deploy.ps1 -NonInteractive

# 带环境变量
$env:APP_PORT="19901"
.\deploy.ps1 deploy -NonInteractive
```

### 其他命令
```powershell
.\deploy.ps1 status    # 查看服务状态
.\deploy.ps1 logs      # 查看日志
.\deploy.ps1 stop      # 停止服务
.\deploy.ps1 restart   # 重启服务
.\deploy.ps1 clean     # 清理所有数据 (需要输入 DELETE 确认)
```

## 兼容性

- Windows 10/11 (推荐)
- Windows Server 2019/2022
- PowerShell 5.1+ 或 PowerShell Core 7+
- Docker Desktop for Windows

## 已知限制

1. GitHub Actions Windows runner 资源有限,只能测试脚本逻辑,无法完整部署容器
2. 非交互模式下无法执行 clean 命令 (安全考虑)
3. Docker Desktop 必须已安装并启动 (脚本会尝试自动启动)

## 下一步

- 添加更多单元测试
- 支持 WSL2 环境检测
- 添加日志文件输出
- 支持配置文件 (deploy.config.ps1)
