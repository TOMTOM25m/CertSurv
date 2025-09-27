#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Certificate WebService - Automatische Installation (PowerShell)
    
.DESCRIPTION
    Vollautomatische Installation des Certificate WebService mit UNC-Pfad Support.
    Lädt das neueste Deployment-Paket vom Network-Share und installiert es.
    
.NOTES
    Version: v1.0.3
    Datum: 2025-09-17
    Regelwerk: v9.3.0
    Startet über: Install-CertWebService.bat
#>

[CmdletBinding()]
param()

# 📊 KONFIGURATION
$networkShare = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment"
$latestZip = "CertWebService_Latest.zip"
$tempPath = "C:\Temp"
$deploymentPath = "$tempPath\CertWebService-Deployment"

# 🎨 LOGGING SETUP
function Write-InstallLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        "STEP" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

try {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "  Certificate WebService - Automatische Installation v1.0.3" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    
    Write-InstallLog "Automatische Installation gestartet" "SUCCESS"
    Write-InstallLog "Network-Share: $networkShare"
    Write-InstallLog "Computer: $env:COMPUTERNAME"
    Write-Host ""
    
    # 🔍 VORAUSSETZUNGEN PRÜFEN
    Write-InstallLog "Prüfe Voraussetzungen..." "STEP"
    
    # PowerShell-Version prüfen
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PowerShell 5.1 oder höher erforderlich! Aktuelle Version: $($PSVersionTable.PSVersion)"
    }
    Write-InstallLog "PowerShell-Version: $($PSVersionTable.PSVersion) ✓"
    
    # Network-Share Erreichbarkeit prüfen
    if (-not (Test-Path $networkShare)) {
        throw "Network-Share nicht erreichbar: $networkShare"
    }
    Write-InstallLog "Network-Share erreichbar ✓"
    
    # Temporäres Verzeichnis erstellen
    if (-not (Test-Path $tempPath)) {
        New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
    }
    Write-InstallLog "Temporäres Verzeichnis bereit: $tempPath ✓"
    
    # 📥 SCHRITT 1: LATEST.ZIP HERUNTERLADEN
    Write-Host ""
    Write-InstallLog "Lade neueste Version vom Network-Share..." "STEP"
    
    $sourceZip = Join-Path $networkShare $latestZip
    $destZip = Join-Path $tempPath $latestZip
    
    if (-not (Test-Path $sourceZip)) {
        throw "Latest.zip nicht gefunden: $sourceZip"
    }
    
    Copy-Item -Path $sourceZip -Destination $destZip -Force
    Write-InstallLog "$latestZip heruntergeladen ($(((Get-Item $destZip).Length / 1KB).ToString('F1')) KB) ✓" "SUCCESS"
    
    # 📦 SCHRITT 2: ZIP-DATEI ENTPACKEN
    Write-Host ""
    Write-InstallLog "Entpacke Deployment-Paket..." "STEP"
    
    if (Test-Path $deploymentPath) {
        Remove-Item -Path $deploymentPath -Recurse -Force
    }
    
    Expand-Archive -Path $destZip -DestinationPath $tempPath -Force
    
    # Prüfen ob Entpackung erfolgreich war
    $installerScript = Join-Path $deploymentPath "Install-DeploymentPackage.ps1"
    if (-not (Test-Path $installerScript)) {
        throw "Installation-Skript nicht gefunden: $installerScript"
    }
    Write-InstallLog "Deployment-Paket entpackt ✓" "SUCCESS"
    
    # 🎯 SCHRITT 3: SERVER-TYP AUSWÄHLEN
    Write-Host ""
    Write-InstallLog "Server-Typ auswählen..." "STEP"
    Write-Host ""
    
    Write-Host "  1. ISO-Server (itscmgmt03) - Ports 9080/9443" -ForegroundColor Yellow
    Write-Host "  2. Exchange-Server (EX01, EX02, EX03) - Ports 9180/9543" -ForegroundColor Yellow
    Write-Host "  3. Domain Controller (UVWDC001, UVWDC002) - Ports 9280/9643" -ForegroundColor Yellow
    Write-Host "  4. Application Server (C-APP01, C-APP02) - Ports 9380/9743" -ForegroundColor Yellow
    Write-Host "  5. Custom (manuelle Port-Konfiguration)" -ForegroundColor Yellow
    Write-Host ""
    
    do {
        $serverChoice = Read-Host "Wählen Sie den Server-Typ (1-5)"
    } while ($serverChoice -notmatch '^[1-5]$')
    
    $serverType = switch ($serverChoice) {
        "1" { "ISO" }
        "2" { "Exchange" }
        "3" { "DomainController" }
        "4" { "Application" }
        "5" { "Custom" }
    }
    
    Write-InstallLog "Server-Typ gewählt: $serverType" "SUCCESS"
    
    # 🚀 SCHRITT 4: CERTIFICATE WEBSERVICE INSTALLATION
    Write-Host ""
    Write-InstallLog "Starte Certificate WebService Installation..." "STEP"
    Write-Host ""
    
    # In Deployment-Verzeichnis wechseln
    Push-Location $deploymentPath
    
    try {
        # Installation ausführen
        & ".\Install-DeploymentPackage.ps1" -ServerType $serverType
        $installResult = $LASTEXITCODE
        
        if ($installResult -eq 0) {
            Write-Host ""
            Write-Host "================================================================" -ForegroundColor Green
            Write-Host "  INSTALLATION ERFOLGREICH ABGESCHLOSSEN!" -ForegroundColor Green
            Write-Host "================================================================" -ForegroundColor Green
            Write-Host ""
            Write-InstallLog "Certificate WebService wurde erfolgreich installiert" "SUCCESS"
            Write-Host ""
            Write-Host "Nächste Schritte:" -ForegroundColor Cyan
            Write-Host "1. Externe Erreichbarkeit testen" -ForegroundColor White
            Write-Host "2. Certificate Surveillance konfigurieren" -ForegroundColor White
            Write-Host "3. Produktiven Betrieb starten" -ForegroundColor White
            Write-Host ""
            Write-Host "Teste Installation mit:" -ForegroundColor Yellow
            Write-Host "  .\Scripts\Test-Installation.ps1 -ExternalTest" -ForegroundColor Gray
            Write-Host ""
        } else {
            throw "Installation fehlgeschlagen (Exit Code: $installResult)"
        }
    }
    finally {
        Pop-Location
    }
}
catch {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "  INSTALLATION FEHLGESCHLAGEN!" -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host ""
    Write-InstallLog "FEHLER: $($_.Exception.Message)" "ERROR"
    Write-Host ""
    Write-Host "Bitte prüfen Sie:" -ForegroundColor Yellow
    Write-Host "• Log-Dateien in: $deploymentPath\LOG\" -ForegroundColor White
    Write-Host "• Test-Skript: $deploymentPath\Scripts\Test-Installation.ps1" -ForegroundColor White
    Write-Host "• Network-Share Erreichbarkeit: $networkShare" -ForegroundColor White
    Write-Host ""
    
    exit 1
}

Write-Host ""
Write-Host "Drücken Sie eine beliebige Taste zum Beenden..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")