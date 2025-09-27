# Certificate WebService - ISO-Server Installation (PowerShell)
# Version: v1.0.3 | Datum: 2025-09-17
# Ziel: Automatische Installation für ISO-Server (itscmgmt03)

param(
    [switch]$Verbose = $false
)

# Hauptinstallation
function Start-ISOServerInstallation {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  Certificate WebService - ISO-Server Installation v1.0.3" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Administrator-Rechte prüfen
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Host "[FEHLER] Skript muss als Administrator ausgeführt werden!" -ForegroundColor Red
            pause
            exit 1
        }

        Write-Host "[INFO] Starte automatische Installation für ISO-Server ($env:COMPUTERNAME)" -ForegroundColor Yellow
        Write-Host ""

        # Temporäres Verzeichnis
        $tempDir = "C:\Temp"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }

        # Download vom Network-Share
        Write-Host "[1/4] Lade CertWebService_Latest.zip..." -ForegroundColor Green
        $networkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment\CertWebService_Latest.zip"
        $localZip = "$tempDir\CertWebService_Latest.zip"

        if (-not (Test-Path $networkPath)) {
            throw "Network-Share nicht erreichbar: $networkPath"
        }

        Copy-Item -Path $networkPath -Destination $localZip -Force
        if (-not (Test-Path $localZip)) {
            throw "Download fehlgeschlagen"
        }

        # Entpacken
        Write-Host "[2/4] Entpacke Deployment-Paket..." -ForegroundColor Green
        $extractPath = "$tempDir\CertWebService-Deployment"
        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force
        }

        # PowerShell 5.1 kompatibles Entpacken
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($localZip, $tempDir)

        if (-not (Test-Path $extractPath)) {
            throw "Entpacken fehlgeschlagen"
        }

        # Installation
        Write-Host "[3/4] Installiere Certificate WebService..." -ForegroundColor Green
        Set-Location $extractPath

        $installScript = ".\Install-DeploymentPackage.ps1"
        if (-not (Test-Path $installScript)) {
            throw "Installations-Skript nicht gefunden: $installScript"
        }

        # Für ISO-Server mit vordefinierten Parametern
        $params = @{
            ServerType = "ISO"
            Force = $true
            Verbose = $Verbose
        }

        & $installScript @params
        $installResult = $LASTEXITCODE

        # Test
        Write-Host "[4/4] Teste Installation..." -ForegroundColor Green
        if ($installResult -eq 0) {
            $testScript = ".\Scripts\Test-Installation.ps1"
            if (Test-Path $testScript) {
                $testResult = & $testScript
                if ($testResult) {
                    Write-Host ""
                    Write-Host "================================================================" -ForegroundColor Green
                    Write-Host "  INSTALLATION ERFOLGREICH!" -ForegroundColor Green
                    Write-Host "================================================================" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "Certificate WebService ist betriebsbereit:" -ForegroundColor White
                    Write-Host "  HTTP:  http://$env:COMPUTERNAME`:9080" -ForegroundColor Cyan
                    Write-Host "  HTTPS: https://$env:COMPUTERNAME`:9443" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Nächster Schritt: Certificate Surveillance konfigurieren" -ForegroundColor Yellow
                    Write-Host ""
                } else {
                    Write-Host "[WARNING] Installation abgeschlossen, aber Tests fehlgeschlagen" -ForegroundColor Yellow
                }
            } else {
                Write-Host "[WARNING] Test-Skript nicht gefunden, aber Installation scheint erfolgreich" -ForegroundColor Yellow
            }
        } else {
            throw "Installation mit Fehlercode $installResult beendet"
        }

    } catch {
        Write-Host ""
        Write-Host "[FEHLER] Installation fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Logs: $tempDir\CertWebService-Deployment\LOG\" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

# Ausführung
Start-ISOServerInstallation

Write-Host ""
Write-Host "Drücken Sie eine beliebige Taste zum Beenden..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")