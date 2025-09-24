@echo off
REM Certificate Surveillance System - Quick Install Batch
REM Version: v1.3.1
REM Regelwerk: v9.5.0
REM Datum: 2025-09-24

echo.
echo ================================================================
echo Certificate Surveillance System - Quick Network Install
echo ================================================================
echo.

REM Config am Anfang des Scripts
set DEFAULT_NETWORK_PATH=\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv
set DEFAULT_LOCAL_PATH=C:\Script\CertSurv-Master

REM Check if running as Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [FAIL] This script must be run as Administrator!
    echo [INFO] Right-click and select "Run as Administrator"
    pause
    exit /b 1
)

echo [OK] Running as Administrator
echo.

REM Set network path (ANPASSEN JE NACH INFRASTRUCTURE!)
set NETWORK_PATH=\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv
set LOCAL_PATH=C:\Script\CertSurv-Master

echo [INFO] Network Path: %NETWORK_PATH%
echo [INFO] Local Install Path: %LOCAL_PATH%
echo.

REM Test network connectivity
echo [INFO] Testing network connectivity...
dir "%NETWORK_PATH%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [FAIL] Cannot access network path: %NETWORK_PATH%
    echo [INFO] Please check network connectivity and path
    echo [INFO] Expected: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv
    pause
    exit /b 1
)
echo [OK] Network path accessible
echo.

REM Create local directory
echo [INFO] Creating local installation directory...
if not exist "%LOCAL_PATH%" (
    mkdir "%LOCAL_PATH%"
)
echo [OK] Local directory ready: %LOCAL_PATH%
echo.

REM Copy files using robocopy (Regelwerk v9.5.0)
echo [INFO] Copying files from network using robocopy...
robocopy "%NETWORK_PATH%" "%LOCAL_PATH%" /E /R:3 /W:10 /NP
set ROBOCOPY_RESULT=%errorlevel%

if %ROBOCOPY_RESULT% leq 7 (
    echo [OK] Files copied successfully
) else (
    echo [FAIL] Robocopy failed with exit code: %ROBOCOPY_RESULT%
    pause
    exit /b 1
)
echo.

REM Run setup script
echo [INFO] Running CertSurv Setup...
cd /d "%LOCAL_PATH%"
PowerShell.exe -ExecutionPolicy Bypass -File "Setup.ps1"

REM Optional: Run configuration GUI
echo.
echo [OPTION] You can now configure the system using the GUI:
echo PowerShell.exe -ExecutionPolicy Bypass -File "Setup-CertSurv.ps1"
echo.

if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] CertSurv v1.3.1 installation completed successfully!
    echo [INFO] Features: WebService Integration, Setup-GUI, Network Deployment
    echo.
    echo Next steps:
    echo 1. Review configuration: %LOCAL_PATH%\Config\Config-Cert-Surveillance.json
    echo 2. Edit configuration GUI: PowerShell.exe -ExecutionPolicy Bypass -File "Setup-CertSurv.ps1"
    echo 3. Test system: PowerShell.exe -ExecutionPolicy Bypass -File "Check.ps1"
    echo 4. Start surveillance: PowerShell.exe -ExecutionPolicy Bypass -File "Cert-Surveillance.ps1"
    echo.
) else (
    echo [FAIL] Setup script failed
    echo Please check logs and configuration
)

pause