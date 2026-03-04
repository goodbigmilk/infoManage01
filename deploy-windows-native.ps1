<#
.SYNOPSIS
    infoManage Windows native deploy tool (no Docker)

.DESCRIPTION
    Auto-install Go and MySQL, deploy the app directly on Windows.
    Uses China mirror sources.

.PARAMETER Command
    Command: install, start, stop, restart, status, logs, uninstall, help

.PARAMETER NonInteractive
    Non-interactive mode for CI/CD

.EXAMPLE
    .\deploy-windows-native.ps1 install

.EXAMPLE
    .\deploy-windows-native.ps1 start
#>

param(
    [Parameter(Position = 0, HelpMessage = "Command to execute")]
    [ValidateSet("install", "start", "stop", "restart", "status", "logs", "uninstall", "help")]
    [string]$Command = "install",

    [Parameter(HelpMessage = "Run in non-interactive mode")]
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8

# ==================== Config ====================

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

$GO_DOWNLOAD_URL = "https://golang.google.cn/dl/go1.21.6.windows-amd64.zip"
$MYSQL_DOWNLOAD_URL = "https://mirrors.aliyun.com/mysql/MySQL-8.0/mysql-8.0.36-winx64.zip"

# ==================== Helpers ====================

function Write-Info    { param($msg) Write-Host "[INFO]  " -ForegroundColor Cyan   -NoNewline; Write-Host $msg }
function Write-Success { param($msg) Write-Host "[OK]    " -ForegroundColor Green  -NoNewline; Write-Host $msg }
function Write-Warn    { param($msg) Write-Host "[WARN]  " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Err     { param($msg) Write-Host "[ERROR] " -ForegroundColor Red    -NoNewline; Write-Host $msg; exit 1 }

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

    Write-Info "Downloading from $Url ..."
    Write-Info "Save to $Output"

    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $Output -UseBasicParsing
        Write-Success "Download complete"
    } catch {
        Write-Err "Download failed: $_"
    }
}

# ==================== Go Install ====================

function Test-GoInstalled {
    try {
        $goPath = "$GO_INSTALL_DIR\bin\go.exe"
        if (Test-Path $goPath) {
            $version = & $goPath version
            Write-Success "Go installed: $version"
            return $true
        }
    } catch {}

    try {
        $version = & go version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Go found on system: $version"
            return $true
        }
    } catch {}

    return $false
}

function Install-Go {
    if (Test-GoInstalled) {
        return
    }

    Write-Info "Installing Go..."

    New-Item -ItemType Directory -Force -Path $GO_INSTALL_DIR | Out-Null

    $zipFile = "$env:TEMP\go.zip"
    Download-File -Url $GO_DOWNLOAD_URL -Output $zipFile

    Write-Info "Extracting Go..."
    Expand-Archive -Path $zipFile -DestinationPath $INSTALL_DIR -Force

    if (Test-Path "$INSTALL_DIR\go") {
        Move-Item -Path "$INSTALL_DIR\go\*" -Destination $GO_INSTALL_DIR -Force
        Remove-Item -Path "$INSTALL_DIR\go" -Force
    }

    Remove-Item -Path $zipFile -Force

    $env:Path = "$GO_INSTALL_DIR\bin;$env:Path"
    $env:GOROOT = $GO_INSTALL_DIR
    $env:GOPROXY = "https://goproxy.cn,direct"

    Write-Success "Go installation complete"
}

# ==================== MySQL Install ====================

function Test-MySQLInstalled {
    $serviceName = "MySQL80_infoManage"
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Success "MySQL service installed"
        return $true
    }
    return $false
}

function Install-MySQL {
    if (Test-MySQLInstalled) {
        return
    }

    Write-Info "Installing MySQL..."

    New-Item -ItemType Directory -Force -Path $MYSQL_INSTALL_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path "$MYSQL_INSTALL_DIR\data" | Out-Null

    $zipFile = "$env:TEMP\mysql.zip"
    Download-File -Url $MYSQL_DOWNLOAD_URL -Output $zipFile

    Write-Info "Extracting MySQL..."
    Expand-Archive -Path $zipFile -DestinationPath $env:TEMP -Force

    $extractedDir = Get-ChildItem -Path $env:TEMP -Filter "mysql-*-winx64" -Directory | Select-Object -First 1
    if ($extractedDir) {
        Move-Item -Path "$($extractedDir.FullName)\*" -Destination $MYSQL_INSTALL_DIR -Force
        Remove-Item -Path $extractedDir.FullName -Recurse -Force
    }

    Remove-Item -Path $zipFile -Force

    $myIniContent = @"
[mysqld]
port=$MYSQL_PORT
basedir=$MYSQL_INSTALL_DIR
datadir=$MYSQL_INSTALL_DIR\data
max_connections=200
max_connect_errors=10
character-set-server=utf8mb4
default-storage-engine=INNODB

sql_mode=NO_ENGINE_SUBSTITUTION

[mysql]
default-character-set=utf8mb4

[client]
port=$MYSQL_PORT
default-character-set=utf8mb4
"@

    $myIniContent | Out-File -FilePath "$MYSQL_INSTALL_DIR\my.ini" -Encoding ascii

    Write-Info "Initializing MySQL database..."
    & "$MYSQL_INSTALL_DIR\bin\mysqld.exe" --initialize-insecure --basedir=$MYSQL_INSTALL_DIR --datadir="$MYSQL_INSTALL_DIR\data"

    Write-Info "Installing MySQL service..."
    & "$MYSQL_INSTALL_DIR\bin\mysqld.exe" --install MySQL80_infoManage --defaults-file="$MYSQL_INSTALL_DIR\my.ini"

    Write-Info "Starting MySQL service..."
    Start-Service MySQL80_infoManage

    Start-Sleep -Seconds 3

    Write-Info "Setting MySQL root password..."
    & "$MYSQL_INSTALL_DIR\bin\mysql.exe" -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"

    Write-Info "Creating database..."
    & "$MYSQL_INSTALL_DIR\bin\mysql.exe" -u root -p"$MYSQL_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

    Write-Success "MySQL installation complete"
}

# ==================== App Build ====================

function Build-App {
    Write-Info "Building application..."

    Push-Location $APP_DIR

    $env:GOROOT = $GO_INSTALL_DIR
    $env:GOPROXY = "https://goproxy.cn,direct"
    $goExe = if (Test-Path "$GO_INSTALL_DIR\bin\go.exe") { "$GO_INSTALL_DIR\bin\go.exe" } else { "go" }

    Write-Info "Downloading Go dependencies..."
    & $goExe mod download

    & $goExe build -o "$APP_NAME.exe" .

    if ($LASTEXITCODE -ne 0) {
        Write-Err "Build failed"
    }

    Pop-Location

    Write-Success "Build complete"
}

function Install-AppService {
    Write-Info "Installing app as scheduled task..."

    $action = New-ScheduledTaskAction -Execute "$APP_DIR\$APP_NAME.exe" -WorkingDirectory $APP_DIR
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

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

    $action = New-ScheduledTaskAction -Execute "$APP_DIR\start.bat" -WorkingDirectory $APP_DIR

    Register-ScheduledTask -TaskName $APP_NAME -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

    Write-Success "App service installed"
}

# ==================== Service Management ====================

function Start-App {
    Write-Info "Starting application..."

    $mysqlService = Get-Service -Name "MySQL80_infoManage" -ErrorAction SilentlyContinue
    if ($mysqlService -and $mysqlService.Status -ne "Running") {
        Start-Service MySQL80_infoManage
        Start-Sleep -Seconds 3
    }

    Start-ScheduledTask -TaskName $APP_NAME

    Start-Sleep -Seconds 2

    $retries = 0
    $maxRetries = 30
    while ($retries -lt $maxRetries) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$APP_PORT/" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Success "========================================="
                Write-Success "  $APP_NAME started successfully!"
                Write-Success "========================================="
                Write-Host ""
                Write-Info "URL: http://localhost:$APP_PORT"
                Write-Host ""
                return
            }
        } catch {}
        $retries++
        Start-Sleep -Seconds 1
    }

    Write-Warn "App may have failed to start, check logs"
}

function Stop-App {
    Write-Info "Stopping application..."

    Stop-ScheduledTask -TaskName $APP_NAME -ErrorAction SilentlyContinue

    $process = Get-Process -Name $APP_NAME -ErrorAction SilentlyContinue
    if ($process) {
        Stop-Process -Name $APP_NAME -Force
    }

    Write-Success "Application stopped"
}

function Restart-App {
    Stop-App
    Start-Sleep -Seconds 2
    Start-App
}

function Show-Status {
    Write-Host ""
    Write-Host "========== Service Status ==========" -ForegroundColor Cyan

    $mysqlService = Get-Service -Name "MySQL80_infoManage" -ErrorAction SilentlyContinue
    if ($mysqlService) {
        $status = if ($mysqlService.Status -eq "Running") { "Running" } else { "Stopped" }
        $color = if ($mysqlService.Status -eq "Running") { "Green" } else { "Red" }
        Write-Host "MySQL:    " -NoNewline
        Write-Host $status -ForegroundColor $color
    } else {
        Write-Host "MySQL:    " -NoNewline
        Write-Host "Not installed" -ForegroundColor Gray
    }

    $task = Get-ScheduledTask -TaskName $APP_NAME -ErrorAction SilentlyContinue
    $process = Get-Process -Name $APP_NAME -ErrorAction SilentlyContinue

    if ($process) {
        Write-Host "App:      " -NoNewline
        Write-Host ("Running (PID: " + $process.Id + ")") -ForegroundColor Green
        Write-Host "Port:     $APP_PORT"
        Write-Host "URL:      http://localhost:$APP_PORT"
    } else {
        Write-Host "App:      " -NoNewline
        Write-Host "Stopped" -ForegroundColor Red
    }

    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Logs {
    Write-Info "Showing recent logs..."

    $process = Get-Process -Name $APP_NAME -ErrorAction SilentlyContinue
    if (-not $process) {
        Write-Warn "App is not running"
        return
    }

    Write-Host ""
    Write-Host "App is running at http://localhost:$APP_PORT"
    Write-Host ""
}

function Uninstall-All {
    if (-not $NonInteractive) {
        Write-Warn "This will uninstall all components (Go, MySQL, App) and data!"
        $confirm = Read-Host "Type 'UNINSTALL' to confirm"
        if ($confirm -ne "UNINSTALL") {
            Write-Info "Cancelled"
            return
        }
    }

    Write-Info "Uninstalling..."

    Stop-App

    Unregister-ScheduledTask -TaskName $APP_NAME -Confirm:$false -ErrorAction SilentlyContinue

    $mysqlService = Get-Service -Name "MySQL80_infoManage" -ErrorAction SilentlyContinue
    if ($mysqlService) {
        Stop-Service MySQL80_infoManage -Force
        & "$MYSQL_INSTALL_DIR\bin\mysqld.exe" --remove MySQL80_infoManage
    }

    if (Test-Path $INSTALL_DIR) {
        Remove-Item -Path $INSTALL_DIR -Recurse -Force
    }

    if (Test-Path "$APP_DIR\$APP_NAME.exe") {
        Remove-Item -Path "$APP_DIR\$APP_NAME.exe" -Force
    }

    if (Test-Path "$APP_DIR\start.bat") {
        Remove-Item -Path "$APP_DIR\start.bat" -Force
    }

    Write-Success "Uninstall complete"
}

function Show-Help {
    Write-Host ""
    Write-Host "Usage: .\deploy-windows-native.ps1 [command]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  install     Install all dependencies and deploy (first time)" -ForegroundColor White
    Write-Host "  start       Start app service"                                -ForegroundColor White
    Write-Host "  stop        Stop app service"                                 -ForegroundColor White
    Write-Host "  restart     Restart app service"                              -ForegroundColor White
    Write-Host "  status      Show service status"                              -ForegroundColor White
    Write-Host "  logs        Show app logs"                                    -ForegroundColor White
    Write-Host "  uninstall   Uninstall all components"                         -ForegroundColor White
    Write-Host "  help        Show this help"                                   -ForegroundColor White
    Write-Host ""
    Write-Host "Environment variables:" -ForegroundColor Yellow
    Write-Host '  $env:PORT = "8080"                      # App port (default: 9901)'
    Write-Host '  $env:MYSQL_ROOT_PASSWORD = "xxx"        # MySQL root password (default: rootmysql)'
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host '  .\deploy-windows-native.ps1 install     # First install'  -ForegroundColor Gray
    Write-Host '  .\deploy-windows-native.ps1 start       # Start service'  -ForegroundColor Gray
    Write-Host '  .\deploy-windows-native.ps1 status      # Check status'   -ForegroundColor Gray
    Write-Host ""
    Write-Host "Notes:" -ForegroundColor Yellow
    Write-Host "  - Requires administrator privileges"
    Write-Host "  - Go and MySQL will be installed to C:\infoManage"
    Write-Host "  - Uses China mirror sources for downloads"
    Write-Host "  - First install downloads ~200MB"
    Write-Host ""
}

# ==================== Main ====================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "    $APP_NAME - Windows Native Deploy" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-AdminPrivilege)) {
    Write-Err "Administrator privileges required. Right-click and select 'Run as administrator'"
}

switch ($Command) {
    "install" {
        Write-Info "Starting full installation..."
        Install-Go
        Install-MySQL
        Build-App
        Install-AppService
        Start-App
        Write-Host ""
        Write-Success "Installation complete! App is running"
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
