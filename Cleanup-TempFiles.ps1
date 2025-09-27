#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Bereinigt C:\Temp von alten Certificate WebService Installationsdateien
    
.DESCRIPTION
    Entfernt alle alten Installation-Dateien aus C:\Temp um Konflikte zu vermeiden.
    Sollte vor jeder neuen Installation ausgeführt werden.
#>

Write-Host "Certificate WebService - Temp Cleanup" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

$TempPath = "C:\Temp"
$CleanupItems = @(
    "Install-DeploymentPackage.ps1",
    "CertWebService",
    "CertWebService-Deployment",
    "CertWebService_Latest.zip"
)

foreach ($item in $CleanupItems) {
    $fullPath = Join-Path $TempPath $item
    if (Test-Path $fullPath) {
        try {
            Remove-Item $fullPath -Recurse -Force
            Write-Host "[CLEANUP] Entfernt: $fullPath" -ForegroundColor Green
        }
        catch {
            Write-Host "[WARNING] Konnte nicht entfernen: $fullPath - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "[INFO] Nicht gefunden: $fullPath" -ForegroundColor Gray
    }
}

Write-Host "`n[SUCCESS] Temp-Bereinigung abgeschlossen" -ForegroundColor Green
Write-Host "Bereit für neue Installation mit Install-CertWebService.ps1" -ForegroundColor Yellow