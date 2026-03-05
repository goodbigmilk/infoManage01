@echo off
chcp 65001 >nul
echo.
echo ========================================
echo   infoManage - Windows 打包工具
echo ========================================
echo.

where go >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] 未找到 Go。请先安装 Go 或运行 deploy-windows-native.ps1 install
    pause
    exit /b 1
)

powershell -ExecutionPolicy Bypass -File "%~dp0build-windows.ps1" %*
if %errorlevel% neq 0 (
    pause
    exit /b 1
)

pause
