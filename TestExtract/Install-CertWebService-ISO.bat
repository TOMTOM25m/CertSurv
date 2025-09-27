@echo off
setlocal enabledelayedexpansion

REM Certificate WebService - ISO-Server Installation mit Robocopy
REM Version: v1.0.3 | Datum: 2025-09-17 | Optimiert für UNC-Pfade

echo.
echo ================================================================
echo   Certificate WebService - ISO-Server Installation v1.0.3
echo ================================================================
echo.

REM Administrator-Rechte prüfen
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [FEHLER] Als Administrator ausfuehren!
    pause
    exit /b 1
)

echo [INFO] Starte automatische Installation fuer ISO-Server (%COMPUTERNAME%)
echo.

REM Temporäres Verzeichnis
if not exist "C:\Temp" mkdir "C:\Temp" >nul

REM Download mit Robocopy (UNC-kompatibel)
echo [1/4] Lade CertWebService_Latest.zip mit Robocopy...
robocopy "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment" "C:\Temp" "CertWebService_Latest.zip" /R:3 /W:5 >nul
if %errorLevel% gtr 7 (
    echo [FEHLER] Download fehlgeschlagen! Network-Share nicht erreichbar.
    goto :error
)

if not exist "C:\Temp\CertWebService_Latest.zip" (
    echo [FEHLER] CertWebService_Latest.zip nicht gefunden!
    goto :error
)

REM Entpacken mit PowerShell
echo [2/4] Entpacke Deployment-Paket...
powershell -Command "try { Expand-Archive -Path 'C:\Temp\CertWebService_Latest.zip' -DestinationPath 'C:\Temp\' -Force; exit 0 } catch { exit 1 }" >nul
if %errorLevel% neq 0 (
    echo [FEHLER] Entpacken fehlgeschlagen!
    goto :error
)

REM Installation
echo [3/4] Installiere Certificate WebService...
if not exist "C:\Temp\CertWebService-Deployment\Install-DeploymentPackage.ps1" (
    echo [FEHLER] Installations-Skript nicht gefunden!
    goto :error
)

cd /d "C:\Temp\CertWebService-Deployment"
powershell -ExecutionPolicy Bypass -Command "& '.\Install-DeploymentPackage.ps1' -ServerType ISO -Force" 
set installResult=%errorLevel%

REM Test
echo [4/4] Teste Installation...
if %installResult% equ 0 (
    if exist ".\Scripts\Test-Installation.ps1" (
        powershell -ExecutionPolicy Bypass -Command "& '.\Scripts\Test-Installation.ps1'" >nul
        if !errorLevel! equ 0 (
            echo.
            echo ================================================================
            echo   INSTALLATION ERFOLGREICH!
            echo ================================================================
            echo.
            echo Certificate WebService ist betriebsbereit:
            echo   HTTP:  http://%COMPUTERNAME%:9080
            echo   HTTPS: https://%COMPUTERNAME%:9443
            echo.
            echo Naechster Schritt: Certificate Surveillance konfigurieren
            echo.
            goto :success
        ) else (
            echo [WARNING] Installation abgeschlossen, aber Tests fehlgeschlagen
            goto :success
        )
    ) else (
        echo [WARNING] Test-Skript nicht gefunden, Installation scheint erfolgreich
        goto :success
    )
) else (
    echo [FEHLER] Installation mit Fehlercode %installResult% beendet
    goto :error
)

:success
echo Installation abgeschlossen. Logs: C:\Temp\CertWebService-Deployment\LOG\
goto :end

:error
echo.
echo [FEHLER] Installation fehlgeschlagen!
echo Logs: C:\Temp\CertWebService-Deployment\LOG\
echo Network-Share: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment\
echo.

:end
echo.
echo Druecken Sie eine beliebige Taste zum Beenden...
pause >nul