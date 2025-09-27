@echo off
REM Certificate WebService Installer for Server Core
REM Version: 1.3.0

echo.
echo ========================================
echo Certificate WebService Installer v1.3.0
echo Server Core Compatible Version
echo ========================================
echo.

REM Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo Administrator privileges confirmed.
echo.

REM Detect if Server Core compatible script exists
if exist "%~dp0Setup-WebService-ServerCore.ps1" (
    echo Using Server Core compatible version...
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup-WebService-ServerCore.ps1"
) else (
    echo Using standard version...
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup-WebService.ps1"
)

echo.
if %errorLevel% equ 0 (
    echo Installation completed successfully!
    echo.
    echo Test the installation with: Test-WebService.ps1
) else (
    echo Installation failed!
    echo Check the error messages above.
)

echo.
pause