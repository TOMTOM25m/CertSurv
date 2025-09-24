@echo off
REM Certificate Surveillance System - Universal Install Batch
REM Version: v1.3.1
REM Regelwerk: v9.5.0 (Local copy first, then install)
REM Datum: 2025-09-24
REM Methode: Robocopy -> Local -> Setup (regelwerkkonform)

REM =================================================================
REM CONFIGURATION SECTION - ANPASSEN JE NACH INFRASTRUCTURE!
REM =================================================================
set DEFAULT_NETWORK_PATH=\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv
set DEFAULT_LOCAL_PATH=C:\Script\CertSurv-Master

REM Alternative Konfigurationen (auskommentiert):
REM set DEFAULT_NETWORK_PATH=\\anderer-server.domain.com\share\CertSurv
REM set DEFAULT_NETWORK_PATH=\\fileserver01\software\CertSurv
REM set DEFAULT_LOCAL_PATH=D:\Applications\CertSurv-Master

echo.
echo ================================================================
echo Certificate Surveillance System - Universal Network Install
echo ================================================================
echo.

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

REM Set paths from configuration
set NETWORK_PATH=%DEFAULT_NETWORK_PATH%
set LOCAL_PATH=%DEFAULT_LOCAL_PATH%

echo [INFO] Network Path: %NETWORK_PATH%
echo [INFO] Local Install Path: %LOCAL_PATH%
echo [INFO] To change paths, edit the CONFIGURATION SECTION in this script
echo.

REM Test network connectivity
echo [INFO] Testing network connectivity...
dir "%NETWORK_PATH%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [FAIL] Cannot access network path: %NETWORK_PATH%
    echo [INFO] Please check network connectivity and path
    echo [INFO] Current setting: %NETWORK_PATH%
    echo [INFO] Edit CONFIGURATION SECTION in this script to change paths
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

REM Copy files using robocopy (Regelwerk v9.5.0 - lokale Kopie zuerst)
echo [INFO] Step 1/2: Copying files from network using robocopy...
echo [INFO] Source: %NETWORK_PATH%
echo [INFO] Target: %LOCAL_PATH%
echo.

robocopy "%NETWORK_PATH%" "%LOCAL_PATH%" /E /R:3 /W:10 /NP /MT:8
set ROBOCOPY_RESULT=%errorlevel%

if %ROBOCOPY_RESULT% leq 7 (
    echo [OK] Files copied successfully to local directory
    echo [INFO] Local copy completed - %LOCAL_PATH%
) else (
    echo [FAIL] Robocopy failed with exit code: %ROBOCOPY_RESULT%
    echo [INFO] Check network connectivity and permissions
    pause
    exit /b 1
)
echo.

REM Verify local files exist
echo [INFO] Verifying local installation files...
if not exist "%LOCAL_PATH%\Setup.ps1" (
    echo [FAIL] Setup.ps1 not found in local directory
    echo [INFO] Please check robocopy operation
    pause
    exit /b 1
)
if not exist "%LOCAL_PATH%\Cert-Surveillance.ps1" (
    echo [FAIL] Cert-Surveillance.ps1 not found in local directory
    echo [INFO] Please check robocopy operation
    pause
    exit /b 1
)
echo [OK] Required files verified in local directory
echo.

REM Run setup script from LOCAL copy (Regelwerk compliance)
echo [INFO] Step 2/2: Running CertSurv Setup from local copy...
echo [INFO] Working directory: %LOCAL_PATH%
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
    echo [INFO] Installation method: Local copy first, then setup (Regelwerk compliant)
    echo.
    echo Next steps (execute from local directory):
    echo 1. Review configuration: %LOCAL_PATH%\Config\Config-Cert-Surveillance.json
    echo 2. Edit configuration GUI: cd /d "%LOCAL_PATH%" ^&^& PowerShell.exe -ExecutionPolicy Bypass -File "Setup-CertSurv.ps1"
    echo 3. Test system: cd /d "%LOCAL_PATH%" ^&^& PowerShell.exe -ExecutionPolicy Bypass -File "Check.ps1"
    echo 4. Start surveillance: cd /d "%LOCAL_PATH%" ^&^& PowerShell.exe -ExecutionPolicy Bypass -File "Cert-Surveillance.ps1"
    echo.
    echo [CONFIG] Network Source: %NETWORK_PATH%
    echo [CONFIG] Local Install: %LOCAL_PATH%
    echo [REGELWERK] v9.5.0 compliant - Local execution from %LOCAL_PATH%
    echo.
) else (
    echo [FAIL] Setup script failed
    echo [INFO] Check logs in: %LOCAL_PATH%\LOG\
    echo [INFO] Verify PowerShell execution policy and file permissions
)

pause