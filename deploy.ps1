# ============================================================
#  infoManage 一键部署工具 (Windows PowerShell)
#  自动检测并安装 Docker Desktop
# ============================================================

param(
    [Parameter(Position = 0)]
    [ValidateSet("deploy", "stop", "restart", "status", "logs", "clean", "help")]
    [string]$Command = "deploy",

    [Parameter()]
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"

$APP_NAME       = "infoManage"
$APP_PORT       = if ($env:APP_PORT)            { $env:APP_PORT }            else { "9901" }
$MYSQL_PORT     = if ($env:MYSQL_PORT)          { $env:MYSQL_PORT }          else { "3306" }
$MYSQL_PASSWORD = if ($env:MYSQL_ROOT_PASSWORD) { $env:MYSQL_ROOT_PASSWORD } else { "rootmysql" }
$MYSQL_DATABASE = if ($env:MYSQL_DATABASE)      { $env:MYSQL_DATABASE }      else { "infoManage" }
$COMPOSE_CMD    = ""

function Write-Info    { param($msg) Write-Host "[INFO] "    -ForegroundColor Cyan   -NoNewline; Write-Host $msg }
function Write-Success { param($msg) Write-Host "[OK]   "    -ForegroundColor Green  -NoNewline; Write-Host $msg }
function Write-Warn    { param($msg) Write-Host "[WARN] "    -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Err     { param($msg) Write-Host "[ERROR] "   -ForegroundColor Red    -NoNewline; Write-Host $msg; exit 1 }

Set-Location $PSScriptRoot

# -------------------- Docker --------------------

function Test-Docker {
    try {
        $v = & docker --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $v) {
            Write-Success "Docker already installed: $v"
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
            Write-Success "Docker Compose (V2 plugin) available"
            $script:COMPOSE_CMD = "docker compose"
            return $true
        }
    } catch {}

    try {
        $v = & docker-compose version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Compose (standalone) available"
            $script:COMPOSE_CMD = "docker-compose"
            return $true
        }
    } catch {}

    return $false
}

function Install-Docker {
    Write-Info "Docker not found, attempting auto-install..."

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Installing Docker Desktop via winget..."
        winget install --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Desktop installed"
            Write-Warn "Please start Docker Desktop manually, then re-run this script"
            Write-Host ""
            Write-Host "  Open Start Menu -> search 'Docker Desktop' -> launch it" -ForegroundColor White
            Write-Host ""
            exit 0
        }
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Info "Installing Docker Desktop via Chocolatey..."
        choco install docker-desktop -y
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Desktop installed"
            Write-Warn "Please start Docker Desktop manually, then re-run this script"
            exit 0
        }
    }

    Write-Host ""
    Write-Err "Docker not installed. Please install manually: https://www.docker.com/products/docker-desktop/"
}

function Find-DockerDesktop {
    $possiblePaths = @(
        (Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Docker\Docker\Docker Desktop.exe"),
        (Join-Path $env:LOCALAPPDATA "Docker\Docker Desktop\Docker Desktop.exe")
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Ensure-Docker {
    if (-not (Test-Docker)) {
        Install-Docker
    }

    if (-not (Test-DockerRunning)) {
        Write-Warn "Docker is not running, attempting to start Docker Desktop..."
        $dockerPath = Find-DockerDesktop
        if ($dockerPath) {
            Start-Process $dockerPath
            Write-Info "Waiting for Docker Desktop to start (up to 120s)..."
            $waited = 0
            while ($waited -lt 120) {
                Start-Sleep -Seconds 3
                $waited += 3
                if (Test-DockerRunning) {
                    Write-Success "Docker Desktop started"
                    break
                }
                if ($waited % 15 -eq 0) {
                    Write-Info "Still waiting for Docker... ($($waited)s)"
                }
            }
            if (-not (Test-DockerRunning)) {
                Write-Err "Docker Desktop start timeout. Please start it manually and retry."
            }
        } else {
            Write-Err "Docker Desktop not found. Please start Docker Desktop first."
        }
    }

    if (-not (Test-DockerCompose)) {
        Write-Err "Docker Compose not available. Please verify Docker Desktop installation."
    }
}

# -------------------- Port Check --------------------

function Test-PortAvailable {
    param([int]$Port)
    try {
        $connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        return ($null -eq $connections -or $connections.Count -eq 0)
    } catch {
        return $true
    }
}

function Get-NextAvailablePort {
    param([int]$StartPort)
    $port = $StartPort
    while ($port -lt 65535) {
        if (Test-PortAvailable $port) {
            return $port
        }
        $port++
    }
    return $null
}

# -------------------- Compose Helper --------------------

function Invoke-Compose {
    param([string[]]$ComposeArgs)
    if ($COMPOSE_CMD -eq "docker compose") {
        & docker compose @ComposeArgs
    } else {
        & docker-compose @ComposeArgs
    }
}

# -------------------- Actions --------------------

function Start-Deploy {
    Write-Info "Checking port availability..."

    # 检查 APP_PORT
    if (-not (Test-PortAvailable $APP_PORT)) {
        Write-Warn "Port $APP_PORT is in use"
        if ($NonInteractive) {
            $newPort = Get-NextAvailablePort ([int]$APP_PORT + 1)
            if ($newPort) {
                Write-Info "Auto-selected port: $newPort"
                $script:APP_PORT = $newPort
            } else {
                Write-Err "Cannot find available port"
            }
        } else {
            $newPort = Read-Host "Enter a new port (or press Enter to auto-select)"
            if ($newPort) {
                $script:APP_PORT = $newPort
            } else {
                $autoPort = Get-NextAvailablePort ([int]$APP_PORT + 1)
                if ($autoPort) {
                    Write-Info "Auto-selected port: $autoPort"
                    $script:APP_PORT = $autoPort
                }
            }
        }
    }

    # 检查 MYSQL_PORT
    if (-not (Test-PortAvailable $MYSQL_PORT)) {
        Write-Warn "MySQL port $MYSQL_PORT is in use, skipping host mapping"
        $script:MYSQL_PORT = "0"
    }

    Write-Info "Generating .env config..."
    $envContent = "APP_PORT=$APP_PORT`nMYSQL_PORT=$MYSQL_PORT`nMYSQL_ROOT_PASSWORD=$MYSQL_PASSWORD`nMYSQL_DATABASE=$MYSQL_DATABASE"
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ".env"), $envContent, [System.Text.UTF8Encoding]::new($false))
    Write-Success ".env file created"

    Write-Info "Building and starting services..."
    Invoke-Compose @("up", "-d", "--build")

    Write-Info "Waiting for services to be ready..."
    $retries = 0
    $maxRetries = 60
    while ($retries -lt $maxRetries) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$APP_PORT/" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) { break }
        } catch {}
        $retries++
        Start-Sleep -Seconds 2
    }

    Write-Host ""
    if ($retries -ge $maxRetries) {
        Write-Warn "Service start timeout. Check logs:"
        Write-Host "  $COMPOSE_CMD logs" -ForegroundColor White
    } else {
        Write-Success "========================================="
        Write-Success "  $APP_NAME deployed successfully!"
        Write-Success "========================================="
        Write-Host ""
        Write-Info "URL:        http://localhost:$APP_PORT"
        Write-Info "MySQL port: $MYSQL_PORT"
        Write-Host ""
        Write-Info "Commands:"
        Write-Host "  Logs:     .\deploy.ps1 logs"    -ForegroundColor White
        Write-Host "  Stop:     .\deploy.ps1 stop"    -ForegroundColor White
        Write-Host "  Restart:  .\deploy.ps1 restart"  -ForegroundColor White
        Write-Host "  Status:   .\deploy.ps1 status"   -ForegroundColor White
        Write-Host "  Clean:    .\deploy.ps1 clean"    -ForegroundColor White
        Write-Host ""
    }
}

function Stop-Deploy {
    Write-Info "Stopping services..."
    Invoke-Compose @("down")
    Write-Success "Services stopped"
}

function Restart-Deploy {
    Write-Info "Restarting services..."
    Invoke-Compose @("restart")
    Write-Success "Services restarted"
}

function Show-Status {
    Invoke-Compose @("ps")
}

function Show-Logs {
    Invoke-Compose @("logs", "-f", "--tail=100")
}

function Start-Clean {
    if ($NonInteractive) {
        Write-Err "Clean command requires interactive mode"
    }

    Write-Warn "This will DELETE all containers and data volumes!"
    $confirm = Read-Host "Type 'DELETE' to confirm"
    if ($confirm -eq "DELETE") {
        Invoke-Compose @("down", "-v", "--remove-orphans")
        $imageName = "$APP_NAME-app"
        docker rmi $imageName 2>$null
        Remove-Item -Path ".env" -Force -ErrorAction SilentlyContinue
        Write-Success "Cleanup complete"
    } else {
        Write-Info "Cancelled (you must type 'DELETE' exactly)"
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "Usage: .\deploy.ps1 [command] [-NonInteractive]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  deploy    Build and start services (default)" -ForegroundColor White
    Write-Host "  stop      Stop all services"                  -ForegroundColor White
    Write-Host "  restart   Restart all services"               -ForegroundColor White
    Write-Host "  status    Show service status"                -ForegroundColor White
    Write-Host "  logs      Show service logs"                  -ForegroundColor White
    Write-Host "  clean     Remove all containers and data"     -ForegroundColor White
    Write-Host "  help      Show this help"                     -ForegroundColor White
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -NonInteractive    Run without user prompts (for CI/CD)" -ForegroundColor White
    Write-Host ""
    Write-Host "Environment variables:"
    Write-Host '  $env:APP_PORT = "8080"              App port (default: 9901)'
    Write-Host '  $env:MYSQL_PORT = "3307"            MySQL port (default: 3306)'
    Write-Host '  $env:MYSQL_ROOT_PASSWORD = "xxx"    MySQL root password (default: rootmysql)'
    Write-Host '  $env:MYSQL_DATABASE = "xxx"         Database name (default: infoManage)'
    Write-Host ""
    Write-Host "Examples:"
    Write-Host '  .\deploy.ps1                              # One-click deploy'         -ForegroundColor Gray
    Write-Host '  .\deploy.ps1 -NonInteractive              # Deploy in CI/CD'          -ForegroundColor Gray
    Write-Host '  $env:APP_PORT="8080"; .\deploy.ps1        # Deploy with custom port'  -ForegroundColor Gray
    Write-Host '  .\deploy.ps1 logs                         # View logs'                -ForegroundColor Gray
    Write-Host '  .\deploy.ps1 clean                        # Remove everything'        -ForegroundColor Gray
    Write-Host ""
}

# -------------------- Main --------------------

Write-Host ""
Write-Host "============================================"
Write-Host "    $APP_NAME Deploy Tool (Windows)"
Write-Host "============================================"
Write-Host ""

Write-Info "OS: Windows $([System.Environment]::OSVersion.Version)"
Write-Info "Arch: $env:PROCESSOR_ARCHITECTURE"

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
