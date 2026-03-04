# ============================================================
#  infoManage - Docker Deploy Tool (Windows PowerShell)
# ============================================================

param(
    [Parameter(Position = 0)]
    [ValidateSet("deploy", "stop", "restart", "status", "logs", "clean", "help")]
    [string]$Command = "deploy"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$APP_NAME       = "infoManage"
$APP_PORT       = if ($env:APP_PORT)            { $env:APP_PORT }            else { "9901" }
$MYSQL_PORT     = if ($env:MYSQL_PORT)          { $env:MYSQL_PORT }          else { "3306" }
$MYSQL_PASSWORD = if ($env:MYSQL_ROOT_PASSWORD) { $env:MYSQL_ROOT_PASSWORD } else { "rootmysql" }
$MYSQL_DATABASE = if ($env:MYSQL_DATABASE)      { $env:MYSQL_DATABASE }      else { "infoManage" }
$COMPOSE_CMD    = ""

function Write-Info    { param($msg) Write-Host "[INFO] "  -ForegroundColor Cyan   -NoNewline; Write-Host $msg }
function Write-Success { param($msg) Write-Host "[OK]   "  -ForegroundColor Green  -NoNewline; Write-Host $msg }
function Write-Warn    { param($msg) Write-Host "[WARN] "  -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Err     { param($msg) Write-Host "[ERROR] " -ForegroundColor Red    -NoNewline; Write-Host $msg; exit 1 }

Set-Location $PSScriptRoot

# -------------------- Docker --------------------

function Test-Docker {
    try {
        $v = & docker --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $v) {
            Write-Success "Docker installed: $v"
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
            Write-Success "Docker Compose (V2 plugin) ready"
            $script:COMPOSE_CMD = "docker compose"
            return $true
        }
    } catch {}

    try {
        & docker-compose version 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Compose (standalone) ready"
            $script:COMPOSE_CMD = "docker-compose"
            return $true
        }
    } catch {}

    return $false
}

function Install-Docker {
    Write-Info "Docker not found, trying to install..."

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Installing Docker Desktop via winget..."
        winget install --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Desktop installed"
            Write-Warn "Please start Docker Desktop manually, then re-run this script"
            Write-Host ""
            Write-Host "  -> Search 'Docker Desktop' in Start Menu and open it" -ForegroundColor White
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
    Write-Err ("Docker not installed. Please install manually:`n" +
        "  1. Visit https://www.docker.com/products/docker-desktop/`n" +
        "  2. Download Docker Desktop for Windows`n" +
        "  3. Install and start Docker Desktop`n" +
        "  4. Re-run this script")
}

function Ensure-Docker {
    if (-not (Test-Docker)) {
        Install-Docker
    }

    if (-not (Test-DockerRunning)) {
        Write-Warn "Docker is not running, trying to start Docker Desktop..."
        $dockerPath = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerPath) {
            Start-Process $dockerPath
            Write-Info "Waiting for Docker Desktop to start (max 120s)..."
            $waited = 0
            while ($waited -lt 120) {
                Start-Sleep -Seconds 3
                $waited += 3
                if (Test-DockerRunning) {
                    Write-Success "Docker Desktop is running"
                    break
                }
                if ($waited % 15 -eq 0) {
                    Write-Info ("Still waiting for Docker... " + $waited + "s")
                }
            }
            if (-not (Test-DockerRunning)) {
                Write-Err "Docker Desktop start timeout. Please start it manually and retry"
            }
        } else {
            Write-Err "Docker Desktop is not running. Please start Docker Desktop first"
        }
    }

    if (-not (Test-DockerCompose)) {
        Write-Err "Docker Compose unavailable. Please make sure Docker Desktop is installed correctly"
    }
}

# -------------------- Port check --------------------

function Test-PortAvailable {
    param([int]$Port)
    try {
        $conn = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        return ($null -eq $conn -or $conn.Count -eq 0)
    } catch {
        return $true
    }
}

# -------------------- Compose wrapper --------------------

function Invoke-Compose {
    param([string[]]$ComposeArgs)
    if ($COMPOSE_CMD -eq "docker compose") {
        & docker compose @ComposeArgs
    } else {
        & docker-compose @ComposeArgs
    }
}

# -------------------- Commands --------------------

function Start-Deploy {
    Write-Info "Checking port availability..."
    if (-not (Test-PortAvailable ([int]$APP_PORT))) {
        Write-Warn "Port $APP_PORT is in use"
        $newPort = Read-Host "Enter a new port (or press Enter to skip)"
        if ($newPort) { $script:APP_PORT = $newPort }
    }
    if (-not (Test-PortAvailable ([int]$MYSQL_PORT))) {
        Write-Warn "MySQL port $MYSQL_PORT is in use, will not map to host"
        $script:MYSQL_PORT = "0"
    }

    Write-Info "Generating .env config..."
    $envContent = @(
        "APP_PORT=$APP_PORT",
        "MYSQL_PORT=$MYSQL_PORT",
        "MYSQL_ROOT_PASSWORD=$MYSQL_PASSWORD",
        "MYSQL_DATABASE=$MYSQL_DATABASE"
    )
    [System.IO.File]::WriteAllLines(
        (Join-Path $PSScriptRoot ".env"),
        $envContent,
        (New-Object System.Text.UTF8Encoding $false)
    )
    Write-Success ".env config generated"

    Write-Info "Building and starting services..."
    Invoke-Compose @("up", "-d", "--build")

    Write-Info "Waiting for service to start..."
    $retries = 0
    $maxRetries = 60
    while ($retries -lt $maxRetries) {
        try {
            $resp = Invoke-WebRequest -Uri "http://localhost:$APP_PORT/" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($resp.StatusCode -eq 200) { break }
        } catch {}
        $retries++
        Start-Sleep -Seconds 2
    }

    Write-Host ""
    if ($retries -ge $maxRetries) {
        Write-Warn "Service start timeout. Check logs:"
        Write-Host "  .\deploy.ps1 logs" -ForegroundColor White
    } else {
        Write-Success "========================================="
        Write-Success "  $APP_NAME deploy success!"
        Write-Success "========================================="
        Write-Host ""
        Write-Info  "URL:        http://localhost:$APP_PORT"
        Write-Info  "MySQL port: $MYSQL_PORT"
        Write-Host ""
        Write-Info  "Commands:"
        Write-Host "  Logs:      .\deploy.ps1 logs"    -ForegroundColor White
        Write-Host "  Stop:      .\deploy.ps1 stop"    -ForegroundColor White
        Write-Host "  Restart:   .\deploy.ps1 restart"  -ForegroundColor White
        Write-Host "  Status:    .\deploy.ps1 status"   -ForegroundColor White
        Write-Host "  Clean all: .\deploy.ps1 clean"    -ForegroundColor White
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
    Write-Warn "This will DELETE all containers and volumes (database data will be lost)!"
    $confirm = Read-Host "Confirm? (y/N)"
    if ($confirm -match "^[Yy]$") {
        Invoke-Compose @("down", "-v", "--remove-orphans")
        docker rmi "$APP_NAME-app" 2>$null
        Remove-Item -Path ".env" -Force -ErrorAction SilentlyContinue
        Write-Success "Cleanup done"
    } else {
        Write-Info "Cancelled"
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "Usage: .\deploy.ps1 [command]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  deploy    Deploy / update services (default)" -ForegroundColor White
    Write-Host "  stop      Stop services"                      -ForegroundColor White
    Write-Host "  restart   Restart services"                   -ForegroundColor White
    Write-Host "  status    Show service status"                -ForegroundColor White
    Write-Host "  logs      Show service logs"                  -ForegroundColor White
    Write-Host "  clean     Remove all containers and data"     -ForegroundColor White
    Write-Host "  help      Show this help message"             -ForegroundColor White
    Write-Host ""
    Write-Host "Environment variables:"
    Write-Host '  $env:APP_PORT = "8080"              App port    (default: 9901)'
    Write-Host '  $env:MYSQL_PORT = "3307"            MySQL port  (default: 3306)'
    Write-Host '  $env:MYSQL_ROOT_PASSWORD = "xxx"    MySQL root password (default: rootmysql)'
    Write-Host '  $env:MYSQL_DATABASE = "xxx"         Database name (default: infoManage)'
    Write-Host ""
    Write-Host "Examples:"
    Write-Host '  .\deploy.ps1                              # One-click deploy'  -ForegroundColor Gray
    Write-Host '  $env:APP_PORT="8080"; .\deploy.ps1        # Custom port'       -ForegroundColor Gray
    Write-Host '  .\deploy.ps1 logs                         # View logs'         -ForegroundColor Gray
    Write-Host '  .\deploy.ps1 clean                        # Clean everything'  -ForegroundColor Gray
    Write-Host ""
}

# -------------------- Main --------------------

Write-Host ""
Write-Host "============================================"
Write-Host "    $APP_NAME - Docker Deploy (Windows)"
Write-Host "============================================"
Write-Host ""

Write-Info ("OS: Windows " + [System.Environment]::OSVersion.Version)
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
