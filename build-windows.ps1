<#
.SYNOPSIS
    打包 infoManage 为 Windows 可执行文件分发包

.DESCRIPTION
    编译 Go 程序为 infoManage.exe，并复制 static 目录到 dist/ 文件夹。
    生成的 dist/ 可直接复制到目标 Windows 电脑运行，无需安装 Go。

.PARAMETER Arch
    目标架构: amd64（64位）或 386（32位），默认 amd64

.EXAMPLE
    .\build-windows.ps1
    .\build-windows.ps1 -Arch 386
#>

param(
    [ValidateSet("amd64", "386")]
    [string]$Arch = "amd64"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$APP_NAME = "infoManage"
$DIST_DIR = "dist"
$DIST_APP = "$DIST_DIR\$APP_NAME"

function Write-Info    { param($msg) Write-Host "[INFO]  " -ForegroundColor Cyan   -NoNewline; Write-Host $msg }
function Write-Success { param($msg) Write-Host "[OK]    " -ForegroundColor Green  -NoNewline; Write-Host $msg }
function Write-Err     { param($msg) Write-Host "[ERROR] " -ForegroundColor Red    -NoNewline; Write-Host $msg; exit 1 }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  $APP_NAME - Windows 打包工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 Go
$goExe = "go"
try {
    $v = & go version 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Go not found" }
    Write-Success "Go: $v"
} catch {
    Write-Err "未找到 Go。请先安装 Go: https://go.dev/dl/ 或使用 deploy-windows-native.ps1 install"
}

# 清理并创建 dist 目录
if (Test-Path $DIST_DIR) {
    Remove-Item -Path $DIST_DIR -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $DIST_APP | Out-Null

# 编译
Write-Info "编译 Windows $Arch 可执行文件..."
$env:GOOS = "windows"
$env:GOARCH = $Arch
& go build -ldflags="-s -w" -o "$DIST_APP\$APP_NAME.exe" .

if ($LASTEXITCODE -ne 0) {
    Write-Err "编译失败"
}

# 复制 static
if (Test-Path "static") {
    Copy-Item -Path "static" -Destination "$DIST_APP\static" -Recurse -Force
    Write-Success "已复制 static 目录"
} else {
    Write-Err "未找到 static 目录"
}

# 生成 start.bat 模板
$startBat = @"
@echo off
chcp 65001 >nul
set DB_USER=root
set DB_PASSWORD=rootmysql
set DB_HOST=localhost
set DB_PORT=3306
set DB_NAME=infoManage
set PORT=9901

cd /d "%~dp0"
echo 正在启动 infoManage...
start "" $APP_NAME.exe
echo.
echo 应用已启动！
echo 请在浏览器访问: http://localhost:9901
echo.
pause
"@
$startBat | Out-File -FilePath "$DIST_APP\start.bat" -Encoding ascii

# 生成配置说明
$readme = @"
# infoManage Windows 分发包

## 使用方法

1. 确保本机已安装并启动 MySQL 8.0（或 5.7+）
2. 创建数据库:
   mysql -u root -p -e "CREATE DATABASE infoManage CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
3. 编辑 start.bat 中的 DB_PASSWORD 等参数（如与实际不符）
4. 双击 start.bat 启动
5. 浏览器访问 http://localhost:9901

## 文件说明

- infoManage.exe  主程序（无需安装 Go）
- static/         前端资源
- start.bat       启动脚本（含数据库配置）

详细说明请参阅 WINDOWS_MANUAL_INSTALL.md
"@
$readme | Out-File -FilePath "$DIST_APP\使用说明.txt" -Encoding utf8

Write-Host ""
Write-Success "打包完成！"
Write-Host ""
Write-Info "输出目录: $DIST_APP"
Write-Info "包含: infoManage.exe, static/, start.bat, 使用说明.txt"
Write-Host ""
Write-Info "可将 $DIST_APP 整个文件夹复制到目标 Windows 电脑运行"
Write-Host ""
