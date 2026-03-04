<#
.SYNOPSIS
    infoManage Windows 原生部署工具（不使用 Docker）

.DESCRIPTION
    自动安装 Go 和 MySQL，直接在 Windows 上部署应用
    使用国内镜像源，无需梯子

.PARAMETER Command
    执行的命令: install, start, stop, restart, status, logs, uninstall, help

.PARAMETER NonInteractive
    非交互模式，用于 CI/CD 环境

.EXAMPLE
    .\deploy-windows-native.ps1 install
    安装所有依赖并部署

.EXAMPLE
    .\deploy-windows-native.ps1 start
    启动服务

.LINK
    https://github.com/goodbigmilk/infoManage01
#>

param(
    [Parameter(Position = 0, HelpMessage = "Command to execute")]
    [ValidateSet("install", "start", "stop", "restart", "status", "logs", "uninstall", "help")]
    [string]$Command = "install",

    [Parameter(HelpMessage = "Run in non-interactive mode")]
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"

# ==================== 配置 ====================

$APP_NAME = "infoManage"
$APP_PORT = if ($env:PORT) { $env:PORT } else { "9901" }
$MYSQL_PORT = "3306"
$MYSQL_PASSWORD = if ($env:MYSQL_ROOT_PASSWORD) { $env:MYSQL_ROOT_PASSWORD } else { "rootmysql" }
$DB_NAME = "infoManage"

$INSTALL_DIR = "C:\infoManage"
$GO_INSTALL_DIR = "$INSTALL_DIR\go"
$MYSQL_INSTALL_DIR = "$INSTALL_DIR\mysql"
$APP_DIR = $PSScriptRoot
$LOG_DIR = "$INSTALL_DIR\logs"

# 国内镜像源
$GO_DOWNLOAD_URL = "https://golang.google.cn/dl/go1.21.6.windows-amd64.zip"
$MYSQL_DOWNLOAD_URL = "https://mirrors.aliyun.com/mysql/MySQL-8.0/mysql-8.0.36-winx64.zip"

# ==================== 辅助函数 ====================

function Write-Info { param($msg) Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline; Write-Host $msg }
function Write-Success { param($msg) Write-Host "[OK]   " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Warn { param($msg) Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Err { param($msg) Write-Host "[ERROR] " -ForegroundColor Red -NoNewline; Write-Host $msg; exit 1 }

function Test-AdminPrivilege {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Download-File {
    param(
        [string]$Url,
        [string]$Output
    )

    Write-Info "从 $Url 下载..."
    Write-Info "保存到 $Output"

    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $Output -UseBasicParsing
        Write-Success "下载完成"
    } catch {
        Write-Err "下载失败: $_"
    }
}

# ==================== Go 安装 ====================

function Test-GoInstalled {
    try {
        $goPath = "$GO_INSTALL_DIR\bin\go.exe"
        if (Test-Path $goPath) {
            $version = & $goPath version
            Write-Success "Go 已安装: $version"
            return $true
        }
    } catch {}

    # 检查系统是否已安装 Go
    try {
        $version = & go version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "系统已安装 Go: $version"
            return $true
        }
    } catch {}

    return $false
}

function Install-Go {
    if (Test-GoInstalled) {
        return
    }

    Write-Info "开始安装 Go..."

    # 创建安装目录
    New-Item -ItemType Directory -Force -Path $GO_INSTALL_DIR | Out-Null

    # 下载 Go
    $zipFile = "$env:TEMP\go.zip"
    Download-File -Url $GO_DOWNLOAD_URL -Output $zipFile

    # 解压
    Write-Info "解压 Go..."
    Expand-Archive -Path $zipFile -DestinationPath $INSTALL_DIR -Force

    # 移动到目标目录
    if (Test-Path "$INSTALL_DIR\go") {
        Move-Item -Path "$INSTALL_DIR\go\*" -Destination $GO_INSTALL_DIR -Force
        Remove-Item -Path "$INSTALL_DIR\go" -Force
    }

    # 清理
    Remove-Item -Path $zipFile -Force

    # 设置环境变量
    $env:Path = "$GO_INSTALL_DIR\bin;$env:Path"
    $env:GOROOT = $GO_INSTALL_DIR
    $env:GOPROXY = "https://goproxy.cn,direct"

    Write-Success "Go 安装完成"
}

# ==================== MySQL 安装 ====================

function Test-MySQLInstalled {
    $serviceName = "MySQL80_infoManage"
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Success "MySQL 服务已安装"
        return $true
    }
    return $false
}

function Install-MySQL {
    if (Test-MySQLInstalled) {
        return
    }

    Write-Info "开始安装 MySQL..."

    # 创建安装目录
    New-Item -ItemType Directory -Force -Path $MYSQL_INSTALL_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path "$MYSQL_INSTALL_DIR\data" | Out-Null

    # 下载 MySQL
    $zipFile = "$env:TEMP\mysql.zip"
    Download-File -Url $MYSQL_DOWNLOAD_URL -Output $zipFile

    # 解压
    Write-Info "解压 MySQL..."
    Expand-Archive -Path $zipFile -DestinationPath $env:TEMP -Force

    # 移动到目标目录
    $extractedDir = Get-ChildItem -Path $env:TEMP -Filter "mysql-*-winx64" -Directory | Select-Object -First 1
    if ($extractedDir) {
        Move-Item -Path "$($extractedDir.FullName)\*" -Destination $MYSQL_INSTALL_DIR -Force
        Remove-Item -Path $extractedDir.FullName -Recurse -Force
    }

    # 清理
    Remove-Item -Path $zipFile -Force

    # 创建 MySQL 配置文件
    $myIniContent = @"
[mysqld]
# 基本设置
port=$MYSQL_PORT
basedir=$MYSQL_INSTALL_DIR
datadir=$MYSQL_INSTALL_DIR\data
max_connections=200
max_connect_errors=10
character-set-server=utf8mb4
default-storage-engine=INNODB

# SQL 模式
sql_mode=NO_ENGINE_SUBSTITUTION

[mysql]
default-character-set=utf8mb4

[client]
port=$MYSQL_PORT
default-character-set=utf8mb4
"@

    $myIniContent | Out-File -FilePath "$MYSQL_INSTALL_DIR\my.ini" -Encoding ascii

    Write-Info "初始化 MySQL 数据库..."
    & "$MYSQL_INSTALL_DIR\bin\mysqld.exe" --initialize-insecure --basedir=$MYSQL_INSTALL_DIR --datadir="$MYSQL_INSTALL_DIR\data"

    Write-Info "安装 MySQL 服务..."
    & "$MYSQL_INSTALL_DIR\bin\mysqld.exe" --install MySQL80_infoManage --defaults-file="$MYSQL_INSTALL_DIR\my.ini"

    Write-Info "启动 MySQL 服务..."
    Start-Service MySQL80_infoManage

    Start-Sleep -Seconds 3

    # 设置 root 密码
    Write-Info "设置 MySQL root 密码..."
    & "$MYSQL_INSTALL_DIR\bin\mysql.exe" -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"

    # 创建数据库
    Write-Info "创建数据库..."
    & "$MYSQL_INSTALL_DIR\bin\mysql.exe" -u root -p"$MYSQL_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

    Write-Success "MySQL 安装完成"
}

# ==================== 应用部署 ====================

function Build-App {
    Write-Info "编译应用..."

    Push-Location $APP_DIR

    # 设置 Go 环境变量
    $env:GOROOT = $GO_INSTALL_DIR
    $env:GOPROXY = "https://goproxy.cn,direct"
    $goExe = if (Test-Path "$GO_INSTALL_DIR\bin\go.exe") { "$GO_INSTALL_DIR\bin\go.exe" } else { "go" }

    # 下载依赖
    Write-Info "下载 Go 依赖..."
    & $goExe mod download

    # 编译
    & $goExe build -o "$APP_NAME.exe" .

    if ($LASTEXITCODE -ne 0) {
        Write-Err "编译失败"
    }

    Pop-Location

    Write-Success "应用编译完成"
}

function Install-AppService {
    Write-Info "安装应用服务..."

    # 使用 NSSM 或者创建计划任务
    # 这里使用计划任务作为服务

    $action = New-ScheduledTaskAction -Execute "$APP_DIR\$APP_NAME.exe" -WorkingDirectory $APP_DIR
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    # 设置环境变量
    $env:DB_USER = "root"
    $env:DB_PASSWORD = $MYSQL_PASSWORD
    $env:DB_HOST = "localhost"
    $env:DB_PORT = $MYSQL_PORT
    $env:DB_NAME = $DB_NAME
    $env:PORT = $APP_PORT

    $envVars = @"
`$env:DB_USER='root'
`$env:DB_PASSWORD='$MYSQL_PASSWORD'
`$env:DB_HOST='localhost'
`$env:DB_PORT='$MYSQL_PORT'
`$env:DB_NAME='$DB_NAME'
`$env:PORT='$APP_PORT'
"@

    # 创建启动脚本
    $startScript = @"
@echo off
set DB_USER=root
set DB_PASSWORD=$MYSQL_PASSWORD
set DB_HOST=localhost
set DB_PORT=$MYSQL_PORT
set DB_NAME=$DB_NAME
set PORT=$APP_PORT
cd /d "$APP_DIR"
"$APP_DIR\$APP_NAME.exe"
"@

    $startScript | Out-File -FilePath "$APP_DIR\start.bat" -Encoding ascii

    # 修改计划任务的执行命令
    $action = New-ScheduledTaskAction -Execute "$APP_DIR\start.bat" -WorkingDirectory $APP_DIR

    # 注册任务
    $task = Register-ScheduledTask -TaskName $APP_NAME -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force

    Write-Success "应用服务安装完成"
}

# ==================== 服务管理 ====================

function Start-App {
    Write-Info "启动应用..."

    # 确保 MySQL 运行
    $mysqlService = Get-Service -Name "MySQL80_infoManage" -ErrorAction SilentlyContinue
    if ($mysqlService -and $mysqlService.Status -ne "Running") {
        Start-Service MySQL80_infoManage
        Start-Sleep -Seconds 3
    }

    # 启动应用
    Start-ScheduledTask -TaskName $APP_NAME

    Start-Sleep -Seconds 2

    # 检查应用是否启动
    $retries = 0
    $maxRetries = 30
    while ($retries -lt $maxRetries) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$APP_PORT/" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Success "========================================="
                Write-Success "  $APP_NAME 启动成功!"
                Write-Success "========================================="
                Write-Host ""
                Write-Info "访问地址: http://localhost:$APP_PORT"
                Write-Host ""
                return
            }
        } catch {}
        $retries++
        Start-Sleep -Seconds 1
    }

    Write-Warn "应用可能启动失败，请检查日志"
}

function Stop-App {
    Write-Info "停止应用..."

    # 停止计划任务
    Stop-ScheduledTask -TaskName $APP_NAME -ErrorAction SilentlyContinue

    # 强制结束进程
    $process = Get-Process -Name $APP_NAME -ErrorAction SilentlyContinue
    if ($process) {
        Stop-Process -Name $APP_NAME -Force
    }

    Write-Success "应用已停止"
}

function Restart-App {
    Stop-App
    Start-Sleep -Seconds 2
    Start-App
}

function Show-Status {
    Write-Host ""
    Write-Host "========== 服务状态 ==========" -ForegroundColor Cyan

    # MySQL 状态
    $mysqlService = Get-Service -Name "MySQL80_infoManage" -ErrorAction SilentlyContinue
    if ($mysqlService) {
        $status = if ($mysqlService.Status -eq "Running") { "运行中" } else { "已停止" }
        $color = if ($mysqlService.Status -eq "Running") { "Green" } else { "Red" }
        Write-Host "MySQL:    " -NoNewline
        Write-Host $status -ForegroundColor $color
    } else {
        Write-Host "MySQL:    " -NoNewline
        Write-Host "未安装" -ForegroundColor Gray
    }

    # 应用状态
    $task = Get-ScheduledTask -TaskName $APP_NAME -ErrorAction SilentlyContinue
    $process = Get-Process -Name $APP_NAME -ErrorAction SilentlyContinue

    if ($process) {
        Write-Host "应用:     " -NoNewline
        Write-Host "运行中 (PID: $($process.Id))" -ForegroundColor Green
        Write-Host "端口:     $APP_PORT"
        Write-Host "访问:     http://localhost:$APP_PORT"
    } else {
        Write-Host "应用:     " -NoNewline
        Write-Host "已停止" -ForegroundColor Red
    }

    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Logs {
    Write-Info "显示最近日志..."

    $process = Get-Process -Name $APP_NAME -ErrorAction SilentlyContinue
    if (-not $process) {
        Write-Warn "应用未运行"
        return
    }

    Write-Host ""
    Write-Host "应用正在运行，访问 http://localhost:$APP_PORT 查看"
    Write-Host "按 Ctrl+C 停止查看"
    Write-Host ""

    # 这里可以添加日志文件监控
    # 目前 Go 应用直接输出到控制台
}

function Uninstall-All {
    if (-not $NonInteractive) {
        Write-Warn "这将卸载所有组件（Go、MySQL、应用）和数据！"
        $confirm = Read-Host "输入 'UNINSTALL' 确认卸载"
        if ($confirm -ne "UNINSTALL") {
            Write-Info "取消卸载"
            return
        }
    }

    Write-Info "开始卸载..."

    # 停止应用
    Stop-App

    # 删除计划任务
    Unregister-ScheduledTask -TaskName $APP_NAME -Confirm:$false -ErrorAction SilentlyContinue

    # 停止并删除 MySQL 服务
    $mysqlService = Get-Service -Name "MySQL80_infoManage" -ErrorAction SilentlyContinue
    if ($mysqlService) {
        Stop-Service MySQL80_infoManage -Force
        & "$MYSQL_INSTALL_DIR\bin\mysqld.exe" --remove MySQL80_infoManage
    }

    # 删除安装目录
    if (Test-Path $INSTALL_DIR) {
        Remove-Item -Path $INSTALL_DIR -Recurse -Force
    }

    # 删除编译的exe
    if (Test-Path "$APP_DIR\$APP_NAME.exe") {
        Remove-Item -Path "$APP_DIR\$APP_NAME.exe" -Force
    }

    if (Test-Path "$APP_DIR\start.bat") {
        Remove-Item -Path "$APP_DIR\start.bat" -Force
    }

    Write-Success "卸载完成"
}

function Show-Help {
    Write-Host ""
    Write-Host "用法: .\deploy-windows-native.ps1 [命令]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "命令:" -ForegroundColor Yellow
    Write-Host "  install     安装所有依赖并部署应用（首次使用）" -ForegroundColor White
    Write-Host "  start       启动应用服务" -ForegroundColor White
    Write-Host "  stop        停止应用服务" -ForegroundColor White
    Write-Host "  restart     重启应用服务" -ForegroundColor White
    Write-Host "  status      查看服务状态" -ForegroundColor White
    Write-Host "  logs        查看应用日志" -ForegroundColor White
    Write-Host "  uninstall   卸载所有组件" -ForegroundColor White
    Write-Host "  help        显示此帮助信息" -ForegroundColor White
    Write-Host ""
    Write-Host "环境变量:" -ForegroundColor Yellow
    Write-Host '  $env:PORT = "8080"                      # 应用端口（默认: 9901）'
    Write-Host '  $env:MYSQL_ROOT_PASSWORD = "xxx"        # MySQL root 密码（默认: rootmysql）'
    Write-Host ""
    Write-Host "示例:" -ForegroundColor Yellow
    Write-Host '  .\deploy-windows-native.ps1 install     # 首次安装' -ForegroundColor Gray
    Write-Host '  .\deploy-windows-native.ps1 start       # 启动服务' -ForegroundColor Gray
    Write-Host '  .\deploy-windows-native.ps1 status      # 查看状态' -ForegroundColor Gray
    Write-Host ""
    Write-Host "注意事项:" -ForegroundColor Yellow
    Write-Host "  - 需要管理员权限运行"
    Write-Host "  - Go 和 MySQL 将安装到 C:\infoManage"
    Write-Host "  - 使用国内镜像源，无需梯子"
    Write-Host "  - 首次安装大约需要下载 200MB"
    Write-Host ""
}

# ==================== 主流程 ====================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "    $APP_NAME Windows 原生部署工具" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 检查管理员权限
if (-not (Test-AdminPrivilege)) {
    Write-Err "需要管理员权限运行此脚本。请右键选择 '以管理员身份运行'"
}

switch ($Command) {
    "install" {
        Write-Info "开始完整安装流程..."
        Install-Go
        Install-MySQL
        Build-App
        Install-AppService
        Start-App
        Write-Host ""
        Write-Success "安装完成！应用已启动"
        Write-Host ""
    }
    "start" {
        Start-App
    }
    "stop" {
        Stop-App
    }
    "restart" {
        Restart-App
    }
    "status" {
        Show-Status
    }
    "logs" {
        Show-Logs
    }
    "uninstall" {
        Uninstall-All
    }
    "help" {
        Show-Help
    }
}
