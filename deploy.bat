@echo off
chcp 65001 >nul 2>&1

echo.
echo  ================================================
echo    infoManage - Docker Deploy (Windows)
echo  ================================================
echo.

where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARN] Docker not found in PATH.
    echo        The script will try to install it.
    echo.
)

set CMD=%1
if "%CMD%"=="" set CMD=deploy

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Console]::OutputEncoding = [Console]::InputEncoding = [System.Text.Encoding]::UTF8; & '%~dp0deploy.ps1' -Command '%CMD%'"

if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] Deployment failed. Check the output above.
)

pause
