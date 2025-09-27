@echo off
setlocal enabledelayedexpansion

REM Certificate WebService - Automatische Installation mit Robocopy
REM Version: v1.0.3 | Datum: 2025-09-17 | UNC-Pfad optimiert

echo.
echo ================================================================
echo   Certificate WebService - Automatische Installation v1.0.3
echo ================================================================
echo.

REM Administrator-Rechte prüfen
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [FEHLER] Als Administrator ausfuehren!
    pause
    exit /b 1
)

echo [INFO] Starte automatische Installation von Network-Share
echo Network-Share: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment\
echo.

REM Temporäres Verzeichnis
if not exist "C:\Temp" mkdir "C:\Temp" >nul

REM Download mit Robocopy (UNC-kompatibel)
echo [1/4] Lade CertWebService_Latest.zip mit Robocopy...
robocopy "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment" "C:\Temp" "CertWebService_Latest.zip" /R:3 /W:5 >nul
if %errorLevel% gtr 7 (
    echo [FEHLER] Download fehlgeschlagen! 
    echo - Network-Share nicht erreichbar
    echo - VPN-Verbindung pruefen
    echo - Berechtigung pruefen
    goto :error
)

if not exist "C:\Temp\CertWebService_Latest.zip" (
    echo [FEHLER] CertWebService_Latest.zip nicht auf Network-Share gefunden!
    goto :error
)

REM Entpacken
echo [2/4] Entpacke Deployment-Paket...
powershell -Command "try { Expand-Archive -Path 'C:\Temp\CertWebService_Latest.zip' -DestinationPath 'C:\Temp\' -Force; exit 0 } catch { exit 1 }" >nul
if %errorLevel% neq 0 (
    echo [FEHLER] Entpacken fehlgeschlagen!
    goto :error
)

REM Server-Typ auswählen
echo [3/4] Server-Typ waehlen...
echo.
echo Welcher Server-Typ soll installiert werden?
echo   1) ISO-Server (Port 9080/9443) - Standard fuer itscmgmt03
echo   2) Exchange-Server (Port 9081/9444)
echo   3) Domain-Controller (Port 9082/9445)  
echo   4) Application-Server (Port 9083/9446)
echo.
set /p serverChoice="Auswahl (1-4): "

set serverType=ISO
if "%serverChoice%"=="1" set serverType=ISO
if "%serverChoice%"=="2" set serverType=Exchange
if "%serverChoice%"=="3" set serverType=DomainController
if "%serverChoice%"=="4" set serverType=Application

echo [INFO] Installiere als %serverType%-Server...

REM Installation
echo [4/4] Installiere Certificate WebService...
if not exist "C:\Temp\CertWebService-Deployment\Install-DeploymentPackage.ps1" (
    echo [FEHLER] Installations-Skript nicht gefunden!
    goto :error
)

cd /d "C:\Temp\CertWebService-Deployment"
powershell -ExecutionPolicy Bypass -Command "& '.\Install-DeploymentPackage.ps1' -ServerType %serverType% -Force" 
set installResult=%errorLevel%

REM Test und Ausgabe
if %installResult% equ 0 (
    echo.
    echo ================================================================
    echo   INSTALLATION ERFOLGREICH!
    echo ================================================================
    echo.
    echo Certificate WebService ist betriebsbereit als %serverType%-Server
    echo Logs: C:\Temp\CertWebService-Deployment\LOG\
    echo.
) else (
    echo [FEHLER] Installation mit Fehlercode %installResult% beendet
    goto :error
)

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