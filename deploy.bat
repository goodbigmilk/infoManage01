@echo off
chcp 65001 >nul 2>&1
echo.
echo  正在启动部署脚本...
echo.

where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未找到 PowerShell，请安装 PowerShell 后重试
    pause
    exit /b 1
)

set CMD=%1
if "%CMD%"=="" set CMD=deploy

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %CMD%

if %errorlevel% neq 0 (
    echo.
    echo  部署过程中出现错误，请检查上方输出信息
)

pause
