@echo off
REM Certificate WebService Installer v1.4.0 - Regelwerk v9.5.0 Compliant
REM Author: Flecki (Tom) Garnreiter

echo.
echo ================================================
echo Certificate WebService Installer v1.4.0
echo Regelwerk v9.5.0 Compliant Version
echo Build: 2025-09-23
echo ================================================
echo.

REM Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo Right-click and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo ✅ Administrator privileges confirmed.
echo.

REM Use Regelwerk v9.5.0 compliant script
if exist "%~dp0Setup-WebService-v1.4.0.ps1" (
    echo 🚀 Using Regelwerk v9.5.0 compliant version...
    echo.
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup-WebService-v1.4.0.ps1"
) else (
    echo ⚠️ Regelwerk compliant script not found, using legacy version...
    echo.
    if exist "%~dp0Setup-WebService-ServerCore.ps1" (
        powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup-WebService-ServerCore.ps1"
    ) else (
        powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup-WebService.ps1"
    )
)

echo.
if %errorLevel% equ 0 (
    echo ================================================
    echo ✅ Installation completed successfully!
    echo.
    echo 🧪 Test the installation with: Test-WebService.ps1
    echo 📋 Regelwerk: v9.5.0 Compliant
    echo ================================================
) else (
    echo ================================================
    echo ❌ Installation failed!
    echo Check the error messages above.
    echo ================================================
)

echo.
pause