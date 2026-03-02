# ============================================================
#  infoManage 一键部署工具 (Windows PowerShell)
#  自动检测并安装 Docker Desktop
# ============================================================

param(
    [Parameter(Position = 0)]
    [ValidateSet("deploy", "stop", "restart", "status", "logs", "clean", "help")]
    [string]$Command = "deploy"
)

$ErrorActionPreference = "Stop"

$APP_NAME       = "infoManage"
$APP_PORT       = if ($env:APP_PORT)              { $env:APP_PORT }              else { "9901" }
$MYSQL_PORT     = if ($env:MYSQL_PORT)            { $env:MYSQL_PORT }            else { "3306" }
$MYSQL_PASSWORD = if ($env:MYSQL_ROOT_PASSWORD)   { $env:MYSQL_ROOT_PASSWORD }   else { "rootmysql" }
$MYSQL_DATABASE = if ($env:MYSQL_DATABASE)         { $env:MYSQL_DATABASE }         else { "infoManage" }
$COMPOSE_CMD    = ""

function Write-Info    { param($msg) Write-Host "[信息] " -ForegroundColor Cyan -NoNewline; Write-Host $msg }
function Write-Success { param($msg) Write-Host "[成功] " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Warn    { param($msg) Write-Host "[警告] " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Err     { param($msg) Write-Host "[错误] " -ForegroundColor Red -NoNewline; Write-Host $msg; exit 1 }

Set-Location $PSScriptRoot

# -------------------- Docker 检测与安装 --------------------

function Test-Docker {
    try {
        $v = & docker --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $v) {
            Write-Success "Docker 已安装: $v"
            return $true
        }
    } catch {}
    return $false
}

function Test-DockerRunning {
    try {
        & docker info 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-DockerCompose {
    try {
        & docker compose version 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Compose (V2 插件) 可用"
            $script:COMPOSE_CMD = "docker compose"
            return $true
        }
    } catch {}

    try {
        $v = & docker-compose version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Compose (独立版) 可用"
            $script:COMPOSE_CMD = "docker-compose"
            return $true
        }
    } catch {}

    return $false
}

function Install-Docker {
    Write-Info "Docker 未安装，尝试自动安装..."
    
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "通过 winget 安装 Docker Desktop..."
        winget install --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Desktop 安装完成"
            Write-Warn "请手动启动 Docker Desktop 并等待其完全启动后，重新运行此脚本"
            Write-Host ""
            Write-Host "  启动方式: 在开始菜单搜索 'Docker Desktop' 并打开" -ForegroundColor White
            Write-Host ""
            exit 0
        }
    }
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Info "通过 Chocolatey 安装 Docker Desktop..."
        choco install docker-desktop -y
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Desktop 安装完成"
            Write-Warn "请手动启动 Docker Desktop 并等待其完全启动后，重新运行此脚本"
            exit 0
        }
    }

    Write-Host ""
    Write-Err @"
Docker 未安装且自动安装失败，请手动安装:
  1. 访问 https://www.docker.com/products/docker-desktop/
  2. 下载 Docker Desktop for Windows
  3. 安装并启动 Docker Desktop
  4. 重新运行此脚本
"@
}

function Ensure-Docker {
    if (-not (Test-Docker)) {
        Install-Docker
    }

    if (-not (Test-DockerRunning)) {
        Write-Warn "Docker 未运行，尝试启动 Docker Desktop..."
        $dockerPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerPath) {
            Start-Process $dockerPath
            Write-Info "等待 Docker Desktop 启动 (最多等待 120 秒)..."
            $waited = 0
            while ($waited -lt 120) {
                Start-Sleep -Seconds 3
                $waited += 3
                if (Test-DockerRunning) {
                    Write-Success "Docker Desktop 已启动"
                    break
                }
                if ($waited % 15 -eq 0) {
                    Write-Info "仍在等待 Docker 启动... (${waited}s)"
                }
            }
            if (-not (Test-DockerRunning)) {
                Write-Err "Docker Desktop 启动超时，请手动启动后重试"
            }
        } else {
            Write-Err "Docker Desktop 未运行，请先手动启动 Docker Desktop"
        }
    }

    if (-not (Test-DockerCompose)) {
        Write-Err "Docker Compose 不可用，请确认 Docker Desktop 已正确安装"
    }
}

# -------------------- 端口检测 --------------------

function Test-PortAvailable {
    param([int]$Port)
    try {
        $connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        return ($null -eq $connections -or $connections.Count -eq 0)
    } catch {
        return $true
    }
}

# -------------------- 执行 Compose 命令 --------------------

function Invoke-Compose {
    param([string[]]$Args)
    if ($COMPOSE_CMD -eq "docker compose") {
        & docker compose @Args
    } else {
        & docker-compose @Args
    }
}

# -------------------- 部署操作 --------------------

function Start-Deploy {
    Write-Info "检查端口占用..."
    if (-not (Test-PortAvailable $APP_PORT)) {
        Write-Warn "端口 $APP_PORT 已被占用"
        $newPort = Read-Host "请输入新端口号 (或直接回车跳过)"
        if ($newPort) { $script:APP_PORT = $newPort }
    }
    if (-not (Test-PortAvailable $MYSQL_PORT)) {
        Write-Warn "MySQL 端口 $MYSQL_PORT 已被占用，将不映射到宿主机"
        $script:MYSQL_PORT = "0"
    }

    Write-Info "生成环境配置..."
    @"
APP_PORT=$APP_PORT
MYSQL_PORT=$MYSQL_PORT
MYSQL_ROOT_PASSWORD=$MYSQL_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
"@ | Out-File -FilePath ".env" -Encoding utf8NoBOM
    Write-Success "配置文件 .env 已生成"

    Write-Info "构建并启动服务..."
    Invoke-Compose @("up", "-d", "--build")

    Write-Info "等待服务启动..."
    $retries = 0
    $maxRetries = 60
    while ($retries -lt $maxRetries) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:${APP_PORT}/" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) { break }
        } catch {}
        $retries++
        Start-Sleep -Seconds 2
    }

    Write-Host ""
    if ($retries -ge $maxRetries) {
        Write-Warn "服务启动超时，请检查日志:"
        Write-Host "  $COMPOSE_CMD logs" -ForegroundColor White
    } else {
        Write-Success "========================================="
        Write-Success "  $APP_NAME 部署成功！"
        Write-Success "========================================="
        Write-Host ""
        Write-Info "访问地址:   http://localhost:${APP_PORT}"
        Write-Info "MySQL 端口: ${MYSQL_PORT}"
        Write-Host ""
        Write-Info "常用命令:"
        Write-Host "  查看日志:     .\deploy.ps1 logs"     -ForegroundColor White
        Write-Host "  停止服务:     .\deploy.ps1 stop"     -ForegroundColor White
        Write-Host "  重启服务:     .\deploy.ps1 restart"  -ForegroundColor White
        Write-Host "  查看状态:     .\deploy.ps1 status"   -ForegroundColor White
        Write-Host "  清除数据重建: .\deploy.ps1 clean"    -ForegroundColor White
        Write-Host ""
    }
}

function Stop-Deploy {
    Write-Info "停止服务..."
    Invoke-Compose @("down")
    Write-Success "服务已停止"
}

function Restart-Deploy {
    Write-Info "重启服务..."
    Invoke-Compose @("restart")
    Write-Success "服务已重启"
}

function Show-Status {
    Invoke-Compose @("ps")
}

function Show-Logs {
    Invoke-Compose @("logs", "-f", "--tail=100")
}

function Start-Clean {
    Write-Warn "即将删除所有容器和数据卷（数据库数据将丢失）！"
    $confirm = Read-Host "确认删除？(y/N)"
    if ($confirm -match "^[Yy]$") {
        Invoke-Compose @("down", "-v", "--remove-orphans")
        docker rmi "${APP_NAME}-app" 2>$null
        Remove-Item -Path ".env" -Force -ErrorAction SilentlyContinue
        Write-Success "清理完成"
    } else {
        Write-Info "已取消"
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "用法: .\deploy.ps1 [命令]"
    Write-Host ""
    Write-Host "命令:"
    Write-Host "  deploy    部署/更新服务（默认）" -ForegroundColor White
    Write-Host "  stop      停止服务"             -ForegroundColor White
    Write-Host "  restart   重启服务"             -ForegroundColor White
    Write-Host "  status    查看服务状态"          -ForegroundColor White
    Write-Host "  logs      查看服务日志"          -ForegroundColor White
    Write-Host "  clean     清除所有容器和数据"     -ForegroundColor White
    Write-Host "  help      显示帮助信息"          -ForegroundColor White
    Write-Host ""
    Write-Host "环境变量:"
    Write-Host '  $env:APP_PORT = "8080"              应用端口（默认: 9901）'
    Write-Host '  $env:MYSQL_PORT = "3307"            MySQL 端口（默认: 3306）'
    Write-Host '  $env:MYSQL_ROOT_PASSWORD = "xxx"    MySQL root 密码（默认: rootmysql）'
    Write-Host '  $env:MYSQL_DATABASE = "xxx"         数据库名称（默认: infoManage）'
    Write-Host ""
    Write-Host "示例:"
    Write-Host '  .\deploy.ps1                              # 一键部署'                -ForegroundColor Gray
    Write-Host '  $env:APP_PORT="8080"; .\deploy.ps1        # 指定端口部署'             -ForegroundColor Gray
    Write-Host '  .\deploy.ps1 logs                         # 查看日志'                -ForegroundColor Gray
    Write-Host '  .\deploy.ps1 clean                        # 清除所有数据'             -ForegroundColor Gray
    Write-Host ""
}

# -------------------- 主入口 --------------------

Write-Host ""
Write-Host "============================================"
Write-Host "    $APP_NAME 一键部署工具 (Windows)"
Write-Host "============================================"
Write-Host ""

Write-Info "操作系统: Windows $([System.Environment]::OSVersion.Version)"
Write-Info "系统架构: $env:PROCESSOR_ARCHITECTURE"

Ensure-Docker

switch ($Command) {
    "deploy"  { Start-Deploy }
    "stop"    { Stop-Deploy }
    "restart" { Restart-Deploy }
    "status"  { Show-Status }
    "logs"    { Show-Logs }
    "clean"   { Start-Clean }
    "help"    { Show-Help }
}
