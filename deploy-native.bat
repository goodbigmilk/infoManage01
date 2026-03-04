@echo off
chcp 65001 >nul 2>&1
echo.
echo  ================================================
echo    infoManage - Windows 原生一键部署
echo    (不需要 Docker，无需 WSL)
echo  ================================================
echo.

REM 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 需要管理员权限！
    echo.
    echo 请右键此文件，选择 "以管理员身份运行"
    echo.
    pause
    exit /b 1
)

set CMD=%1
if "%CMD%"=="" set CMD=install

where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] PowerShell 未找到
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-windows-native.ps1" %CMD%

if %errorlevel% neq 0 (
    echo.
    echo  部署遇到错误，请检查上面的输出。
)

pause
