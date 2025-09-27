@echo off
echo Certificate WebService Installation v1.2.0
echo ==========================================
echo.

REM Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Administrator privileges confirmed
    echo.
) else (
    echo ERROR: This script must be run as Administrator!
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo Starting Certificate WebService installation...
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup-WebService.ps1"

echo.
echo Installation completed. Check output above for results.
echo.
echo Next steps:
echo 1. Test API: http://localhost:9080/certificates.json
echo 2. Verify firewall allows ports 9080 and 9443
echo 3. Check IIS Manager for CertWebService site
echo.
pause