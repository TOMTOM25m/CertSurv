@echo off
REM Certificate WebService Installer - Always Latest Version
REM Author: Flecki (Tom) Garnreiter
REM Regelwerk v9.5.0 Compliant

echo.
echo ================================================
echo Certificate WebService Installer
echo Auto-Detection of Latest Version
echo Regelwerk v9.5.0 Compliant
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

echo [SUCCESS] Administrator privileges confirmed.
echo.

REM Get server FQDN for remote access
for /f "tokens=2 delims==" %%i in ('wmic computersystem get domain /value ^| find "="') do set DOMAIN=%%i
for /f "tokens=2 delims==" %%i in ('wmic computersystem get name /value ^| find "="') do set HOSTNAME=%%i
set SERVER_FQDN=%HOSTNAME%.%DOMAIN%

echo [INFO] Server: %HOSTNAME%
echo [INFO] Domain: %DOMAIN%
echo [INFO] Full FQDN: %SERVER_FQDN%
echo.

REM Auto-detect latest Setup-WebService script version
REM Priority: ServerCore (ASCII-safe) -^> Latest versioned -^> Legacy
if exist "%~dp0Setup-WebService-ServerCore.ps1" (
    echo [INSTALL] Using Server Core compatible version for maximum compatibility...
    echo.
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup-WebService-ServerCore.ps1"
    set INSTALL_RESULT=%errorLevel%
) else if exist "%~dp0Setup-WebService-v1.4.0.ps1" (
    echo [INSTALL] Using Regelwerk v9.5.0 compliant version v1.4.0...
    echo.
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup-WebService-v1.4.0.ps1"
    set INSTALL_RESULT=%errorLevel%
) else if exist "%~dp0Setup-WebService.ps1" (
    echo [INSTALL] Using legacy version...
    echo.
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup-WebService.ps1"
    set INSTALL_RESULT=%errorLevel%
) else (
    echo [ERROR] No Setup-WebService script found!
    echo.
    echo Expected files:
    echo - Setup-WebService-ServerCore.ps1 (preferred for Server Core)
    echo - Setup-WebService-v1.4.0.ps1
    echo - Setup-WebService.ps1
    echo.
    pause
    exit /b 1
)

echo.
if %INSTALL_RESULT% equ 0 (
    echo ================================================
    echo [SUCCESS] Installation completed successfully!
    echo.
    echo [TEST] Test the installation with: Test-WebService.ps1
    echo [COMPLIANCE] Regelwerk: v9.5.0 Compliant
    echo [ENDPOINTS] Service Endpoints:
    echo   - HTTP:  http://localhost:9080/api/certificates
    echo   - HTTPS: https://localhost:9443/api/certificates
    echo ================================================
) else (
    echo ================================================
    echo [FAILED] Installation failed!
    echo Check the error messages above.
    echo ================================================
)

echo.
pause
