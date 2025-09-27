#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Certificate WebService - Deployment Package Installer
    
.DESCRIPTION
    Automatisierte Installation des Certificate WebService auf Windows Server.
    Unterstützt verschiedene Server-Typen mit angepassten Port-Konfigurationen.
    
.PARAMETER ServerType
    Server-Typ: ISO, Exchange, DomainController, Application
    
.PARAMETER HttpPort
    HTTP-Port (Standard: 9080)
    
.PARAMETER HttpsPort
    HTTPS-Port (Standard: 9443)
    
.PARAMETER SiteName
    IIS-Site Name (Standard: CertSurveillance)
    
.PARAMETER InstallPath
    Installations-Pfad (Standard: C:\inetpub\wwwroot\CertSurveillance)
    
.PARAMETER SkipFirewall
    Firewall-Konfiguration überspringen
    
.PARAMETER TestInstallation
    Nach Installation automatisch testen
    
.EXAMPLE
    .\Install-DeploymentPackage.ps1 -ServerType ISO
    
.EXAMPLE
    .\Install-DeploymentPackage.ps1 -ServerType Exchange -HttpPort 9180 -HttpsPort 9543
    
.NOTES
    Version: v1.0.3
    Regelwerk: v9.3.0
    Erstellt: 2025-09-17
    Ziel: Produktive WebService Distribution
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("ISO", "Exchange", "DomainController", "Application", "Custom")]
    [string]$ServerType,
    
    [Parameter(Mandatory = $false)]
    [int]$HttpPort = 9080,
    
    [Parameter(Mandatory = $false)]
    [int]$HttpsPort = 9443,
    
    [Parameter(Mandatory = $false)]
    [string]$SiteName = "CertSurveillance",
    
    [Parameter(Mandatory = $false)]
    [string]$InstallPath = "C:\inetpub\wwwroot\CertSurveillance",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipFirewall,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestInstallation = $true
)

# 🎯 DEPLOYMENT-KONFIGURATION
$deploymentConfig = @{
    "ISO" = @{
        HttpPort = 9080
        HttpsPort = 9443
        Description = "ISO Server (itscmgmt03)"
    }
    "Exchange" = @{
        HttpPort = 9180
        HttpsPort = 9543
        Description = "Exchange Server (EX01, EX02, EX03)"
    }
    "DomainController" = @{
        HttpPort = 9280
        HttpsPort = 9643
        Description = "Domain Controller (UVWDC001, UVWDC002)"
    }
    "Application" = @{
        HttpPort = 9380
        HttpsPort = 9743
        Description = "Application Server (C-APP01, C-APP02)"
    }
}

# 📊 LOGGING SETUP
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = ".\LOG\Deployment_$($ServerType)_$timestamp.log"
New-Item -Path ".\LOG" -ItemType Directory -Force | Out-Null

function Write-DeploymentLog {
    param([string]$Message, [string]$Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(if($Level -eq "ERROR"){"Red"} elseif($Level -eq "WARNING"){"Yellow"} else{"Green"})
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

try {
    Write-DeploymentLog "🚀 Certificate WebService Deployment Package v1.0.3 gestartet"
    Write-DeploymentLog "Server-Typ: $ServerType"
    
    # Server-spezifische Konfiguration anwenden
    if ($deploymentConfig.ContainsKey($ServerType) -and $ServerType -ne "Custom") {
        $config = $deploymentConfig[$ServerType]
        if ($PSBoundParameters.Keys -notcontains "HttpPort") { $HttpPort = $config.HttpPort }
        if ($PSBoundParameters.Keys -notcontains "HttpsPort") { $HttpsPort = $config.HttpsPort }
        Write-DeploymentLog "Konfiguration für $($config.Description): HTTP=$HttpPort, HTTPS=$HttpsPort"
    }
    
    # 🔍 VORAUSSETZUNGEN PRÜFEN
    Write-DeploymentLog "📋 Prüfe Voraussetzungen..."
    
    # Administrator-Rechte prüfen
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "Dieses Skript muss als Administrator ausgeführt werden!"
    }
    
    # PowerShell-Version prüfen
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PowerShell 5.1 oder höher erforderlich! Aktuelle Version: $($PSVersionTable.PSVersion)"
    }
    
    # Port-Verfügbarkeit prüfen
    $httpTest = Test-NetConnection -ComputerName "localhost" -Port $HttpPort -WarningAction SilentlyContinue
    $httpsTest = Test-NetConnection -ComputerName "localhost" -Port $HttpsPort -WarningAction SilentlyContinue
    
    if ($httpTest.TcpTestSucceeded) {
        Write-DeploymentLog "WARNING: Port $HttpPort bereits belegt!" "WARNING"
    }
    if ($httpsTest.TcpTestSucceeded) {
        Write-DeploymentLog "WARNING: Port $HttpsPort bereits belegt!" "WARNING"
    }
    
    # 🏗️ IIS INSTALLATION
    Write-DeploymentLog "🏗️ Installiere IIS-Features..."
    
    $iisFeatures = @(
        "IIS-WebServerRole",
        "IIS-WebServer", 
        "IIS-CommonHttpFeatures",
        "IIS-HttpErrors",
        "IIS-HttpRedirect",
        "IIS-ApplicationDevelopment",
        "IIS-NetFxExtensibility45",
        "IIS-ISAPIExtensions",
        "IIS-ISAPIFilter",
        "IIS-ASPNET45",
        "IIS-ManagementConsole"
    )
    
    foreach ($feature in $iisFeatures) {
        try {
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
            if ($result.RestartNeeded) {
                Write-DeploymentLog "WARNING: Neustart nach IIS-Installation erforderlich!" "WARNING"
            }
        }
        catch {
            Write-DeploymentLog "WARNING: Feature $feature konnte nicht installiert werden: $_" "WARNING"
        }
    }
    
    # 📁 WEBSERVICE-DATEIEN KOPIEREN
    Write-DeploymentLog "📁 Kopiere WebService-Dateien..."
    
    # Installations-Verzeichnis erstellen
    if (Test-Path $InstallPath) {
        Write-DeploymentLog "Lösche existierende Installation: $InstallPath"
        Remove-Item -Path $InstallPath -Recurse -Force
    }
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
    
    # WebService-Dateien kopieren
    $webFilesPath = ".\WebService"
    if (Test-Path $webFilesPath) {
        Copy-Item -Path "$webFilesPath\*" -Destination $InstallPath -Recurse -Force
        Write-DeploymentLog "WebService-Dateien nach $InstallPath kopiert"
    } else {
        throw "WebService-Dateien nicht gefunden in: $webFilesPath"
    }
    
    # 🌐 IIS-SITE KONFIGURIEREN
    Write-DeploymentLog "🌐 Konfiguriere IIS-Site..."
    
    # Importiere WebAdministration-Modul
    Import-Module WebAdministration -Force
    
    # Lösche existierende Site falls vorhanden
    if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
        Remove-Website -Name $SiteName
        Write-DeploymentLog "Existierende Site '$SiteName' entfernt"
    }
    
    # Erstelle neue Website
    New-Website -Name $SiteName -Port $HttpPort -PhysicalPath $InstallPath
    Write-DeploymentLog "IIS-Site '$SiteName' auf Port $HttpPort erstellt"
    
    # 🔒 HTTPS-KONFIGURATION
    Write-DeploymentLog "🔒 Konfiguriere HTTPS..."
    
    # SSL-Zertifikat erstellen
    $cert = New-SelfSignedCertificate -DnsName "localhost", $env:COMPUTERNAME -CertStoreLocation "cert:\LocalMachine\My"
    Write-DeploymentLog "SSL-Zertifikat erstellt: $($cert.Thumbprint)"
    
    # HTTPS-Binding hinzufügen
    try {
        New-WebBinding -Name $SiteName -IP "*" -Port $HttpsPort -Protocol https
        $binding = Get-WebBinding -Name $SiteName -Port $HttpsPort -Protocol https
        $binding.AddSslCertificate($cert.Thumbprint, "my")
        Write-DeploymentLog "HTTPS-Binding auf Port $HttpsPort konfiguriert"
    }
    catch {
        Write-DeploymentLog "WARNING: HTTPS-Konfiguration fehlgeschlagen: $_" "WARNING"
    }
    
    # 🔥 FIREWALL-REGELN
    if (-not $SkipFirewall) {
        Write-DeploymentLog "🔥 Konfiguriere Firewall-Regeln..."
        
        # HTTP-Regel
        $httpRuleName = "CertSurveillance-HTTP-$HttpPort"
        if (Get-NetFirewallRule -DisplayName $httpRuleName -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName $httpRuleName
        }
        New-NetFirewallRule -DisplayName $httpRuleName -Direction Inbound -Protocol TCP -LocalPort $HttpPort -Action Allow | Out-Null
        
        # HTTPS-Regel
        $httpsRuleName = "CertSurveillance-HTTPS-$HttpsPort"
        if (Get-NetFirewallRule -DisplayName $httpsRuleName -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName $httpsRuleName
        }
        New-NetFirewallRule -DisplayName $httpsRuleName -Direction Inbound -Protocol TCP -LocalPort $HttpsPort -Action Allow | Out-Null
        
        Write-DeploymentLog "Firewall-Regeln für Ports $HttpPort und $HttpsPort erstellt"
    }
    
    # ✅ INSTALLATION TESTEN
    if ($TestInstallation) {
        Write-DeploymentLog "✅ Teste Installation..."
        
        Start-Sleep -Seconds 5  # Warten bis Services bereit sind
        
        # HTTP-Test
        try {
            $httpResponse = Invoke-WebRequest -Uri "http://localhost:$HttpPort/certificates.json" -UseBasicParsing -TimeoutSec 10
            if ($httpResponse.StatusCode -eq 200) {
                Write-DeploymentLog "✅ HTTP-Test erfolgreich (Status: $($httpResponse.StatusCode))"
            } else {
                Write-DeploymentLog "WARNING: HTTP-Test fehlgeschlagen (Status: $($httpResponse.StatusCode))" "WARNING"
            }
        }
        catch {
            Write-DeploymentLog "WARNING: HTTP-Test fehlgeschlagen: $_" "WARNING"
        }
        
        # HTTPS-Test
        try {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            $httpsResponse = Invoke-WebRequest -Uri "https://localhost:$HttpsPort/certificates.json" -UseBasicParsing -TimeoutSec 10
            if ($httpsResponse.StatusCode -eq 200) {
                Write-DeploymentLog "✅ HTTPS-Test erfolgreich (Status: $($httpsResponse.StatusCode))"
            } else {
                Write-DeploymentLog "WARNING: HTTPS-Test fehlgeschlagen (Status: $($httpsResponse.StatusCode))" "WARNING"
            }
        }
        catch {
            Write-DeploymentLog "WARNING: HTTPS-Test fehlgeschlagen: $_" "WARNING"
        }
        finally {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
    
    # 🎉 INSTALLATION ABGESCHLOSSEN
    Write-DeploymentLog "🎉 Certificate WebService Deployment erfolgreich abgeschlossen!"
    Write-DeploymentLog ""
    Write-DeploymentLog "📊 INSTALLATION ZUSAMMENFASSUNG:"
    Write-DeploymentLog "   Server-Typ: $ServerType"
    Write-DeploymentLog "   HTTP URL:   http://$env:COMPUTERNAME:$HttpPort"
    Write-DeploymentLog "   HTTPS URL:  https://$env:COMPUTERNAME:$HttpsPort"
    Write-DeploymentLog "   Site-Pfad:  $InstallPath"
    Write-DeploymentLog "   Log-Datei:  $logFile"
    Write-DeploymentLog ""
    Write-DeploymentLog "🔗 NEXT STEPS:"
    Write-DeploymentLog "   1. Externe Erreichbarkeit testen"
    Write-DeploymentLog "   2. Certificate Surveillance konfigurieren"
    Write-DeploymentLog "   3. Produktiven Betrieb starten"
    
}
catch {
    Write-DeploymentLog "❌ DEPLOYMENT FEHLGESCHLAGEN: $($_.Exception.Message)" "ERROR"
    Write-DeploymentLog "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
    
    # Rollback bei kritischen Fehlern
    Write-DeploymentLog "🔄 Starte Rollback..."
    try {
        if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
            Remove-Website -Name $SiteName
            Write-DeploymentLog "IIS-Site '$SiteName' entfernt"
        }
        if (Test-Path $InstallPath) {
            Remove-Item -Path $InstallPath -Recurse -Force
            Write-DeploymentLog "Installations-Verzeichnis '$InstallPath' entfernt"
        }
    }
    catch {
        Write-DeploymentLog "WARNING: Rollback teilweise fehlgeschlagen: $_" "WARNING"
    }
    
    exit 1
}