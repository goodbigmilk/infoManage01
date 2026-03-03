@echo off
chcp 65001 >nul 2>&1
echo.
echo  infoManage - One Click Deploy
echo  ==============================
echo.

set CMD=%1
if "%CMD%"=="" set CMD=deploy

where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] PowerShell not found
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %CMD%

if %errorlevel% neq 0 (
    echo.
    echo  Deploy encountered errors. Check the output above.
)

pause
