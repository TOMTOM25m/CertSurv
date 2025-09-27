#Requires -Version 5.1

<#
.SYNOPSIS
    Erstellt ZIP-Paket für Certificate WebService Distribution
    
.DESCRIPTION
    Komprimiert das komplette Deployment-Paket in eine ZIP-Datei
    für einfache Verteilung an verschiedene Server.
    
.PARAMETER OutputPath
    Ausgabe-Pfad für die ZIP-Datei
    
.PARAMETER IncludeVersionInName
    Version in Dateinamen einschließen
    
.EXAMPLE
    .\Create-DeploymentZip.ps1
    
.EXAMPLE
    .\Create-DeploymentZip.ps1 -OutputPath "C:\Temp\" -IncludeVersionInName
    
.NOTES
    Version: v1.0.3
    Regelwerk: v9.3.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeVersionInName
)

try {
    Write-Host "🎁 Certificate WebService Deployment Package Creator v1.0.3" -ForegroundColor Green
    Write-Host ""
    
    # ZIP-Dateiname erstellen
    $timestamp = Get-Date -Format "yyyy-MM-dd"
    if ($IncludeVersionInName) {
        $zipName = "CertWebService-Deployment-v1.0.3-$timestamp.zip"
    } else {
        $zipName = "CertWebService-Deployment-$timestamp.zip"
    }
    
    $zipPath = Join-Path $OutputPath $zipName
    
    # Prüfe ob Deployment-Verzeichnis existiert
    $deploymentPath = "f:\DEV\repositories\CertWebService-Deployment"
    if (-not (Test-Path $deploymentPath)) {
        throw "Deployment-Verzeichnis nicht gefunden: $deploymentPath"
    }
    
    Write-Host "📁 Erstelle ZIP-Paket: $zipName" -ForegroundColor Yellow
    Write-Host "   Quelle: $deploymentPath" -ForegroundColor Gray
    Write-Host "   Ziel:   $zipPath" -ForegroundColor Gray
    Write-Host ""
    
    # Lösche existierende ZIP-Datei
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
        Write-Host "   Existierende ZIP-Datei überschrieben" -ForegroundColor Yellow
    }
    
    # Erstelle ZIP-Archiv
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($deploymentPath, $zipPath)
    
    # Validiere ZIP-Datei
    if (Test-Path $zipPath) {
        $zipInfo = Get-Item $zipPath
        $sizeMB = [math]::Round($zipInfo.Length / 1MB, 2)
        
        Write-Host "✅ ZIP-Paket erfolgreich erstellt!" -ForegroundColor Green
        Write-Host "   Datei:  $($zipInfo.Name)" -ForegroundColor White
        Write-Host "   Größe:  $sizeMB MB" -ForegroundColor White
        Write-Host "   Pfad:   $($zipInfo.FullName)" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "🚀 BEREIT FÜR DISTRIBUTION!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📋 NÄCHSTE SCHRITTE:" -ForegroundColor Yellow
        Write-Host "   1. ZIP-Datei auf Ziel-Server kopieren" -ForegroundColor White
        Write-Host "   2. Entpacken: Expand-Archive -Path '$zipName' -DestinationPath 'C:\Temp\'" -ForegroundColor White
        Write-Host "   3. Installation: .\Install-DeploymentPackage.ps1 -ServerType ISO" -ForegroundColor White
        Write-Host ""
        
        Write-Host "🎯 SERVER-SPEZIFISCHE INSTALLATION:" -ForegroundColor Cyan
        Write-Host "   ISO-Server:        .\Install-DeploymentPackage.ps1 -ServerType ISO" -ForegroundColor Gray
        Write-Host "   Exchange-Server:   .\Install-DeploymentPackage.ps1 -ServerType Exchange" -ForegroundColor Gray
        Write-Host "   Domain Controller: .\Install-DeploymentPackage.ps1 -ServerType DomainController" -ForegroundColor Gray
        Write-Host ""
        
        return $zipPath
    } else {
        throw "ZIP-Datei konnte nicht erstellt werden"
    }
}
catch {
    Write-Host "❌ FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}