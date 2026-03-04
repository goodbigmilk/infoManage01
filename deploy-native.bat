@echo off
chcp 65001 >nul 2>&1
echo.
echo  ================================================
echo    infoManage - Windows Native Deploy
echo    (No Docker, No WSL)
echo  ================================================
echo.

REM Check admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Administrator privileges required!
    echo.
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

set CMD=%1
if "%CMD%"=="" set CMD=install

where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] PowerShell not found
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Console]::OutputEncoding = [Console]::InputEncoding = [System.Text.Encoding]::UTF8; & '%~dp0deploy-windows-native.ps1' -Command '%CMD%'"

if %errorlevel% neq 0 (
    echo.
    echo  Deployment encountered an error. Check the output above.
)

pause
