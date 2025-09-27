#Requires -Version 5.1

<#
.SYNOPSIS
    Debug-Skript fur ZIP-Entpack-Problem
    
.DESCRIPTION
    Untersucht das ZIP-Paket und zeigt was wirklich entpackt wird
#>

try {
    Write-Host "=== DEBUG: ZIP-PAKET ANALYSE ===" -ForegroundColor Cyan
    
    $networkShare = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment"
    $tempPath = "C:\Temp"
    $sourceZip = "$networkShare\CertWebService_Latest.zip"
    $zipPath = "$tempPath\CertWebService_Latest.zip"
    $extractPath = "$tempPath\CertWebService"
    
    # 0. ZIP vom Network-Share kopieren
    Write-Host "Kopiere ZIP vom Network-Share..." -ForegroundColor Yellow
    Copy-Item -Path $sourceZip -Destination $zipPath -Force
    
    # 1. ZIP-Datei pruefen
    if (Test-Path $zipPath) {
        Write-Host "ZIP gefunden: $zipPath" -ForegroundColor Green
        $zipSize = (Get-Item $zipPath).Length
        Write-Host "ZIP Groesse: $($zipSize / 1KB) KB" -ForegroundColor White
    } else {
        Write-Host "ZIP NICHT gefunden: $zipPath" -ForegroundColor Red
        return
    }
    
    # 2. ZIP-Inhalt anzeigen BEVOR entpacken
    Write-Host ""
    Write-Host "ZIP-INHALT (vor Entpacken):" -ForegroundColor Yellow
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    foreach ($entry in $zip.Entries) {
        Write-Host "  $($entry.FullName)" -ForegroundColor Gray
    }
    $zip.Dispose()
    
    # 3. Entpacken
    Write-Host ""
    Write-Host "ENTPACKE ZIP..." -ForegroundColor Yellow
    
    if (Test-Path $extractPath) {
        Remove-Item $extractPath -Recurse -Force
        Write-Host "Altes Verzeichnis entfernt" -ForegroundColor Yellow
    }
    
    Expand-Archive -Path $zipPath -DestinationPath $tempPath -Force
    
    # 4. Was wurde wirklich entpackt?
    Write-Host ""
    Write-Host "ENTPACKTES VERZEICHNIS:" -ForegroundColor Cyan
    if (Test-Path $extractPath) {
        Write-Host "Verzeichnis existiert: $extractPath" -ForegroundColor Green
        Get-ChildItem $extractPath -Recurse | ForEach-Object {
            $relativePath = $_.FullName.Replace("$extractPath\", "")
            if ($_.PSIsContainer) {
                Write-Host "  [DIR]  $relativePath" -ForegroundColor Blue
            } else {
                Write-Host "  [FILE] $relativePath" -ForegroundColor White
            }
        }
    } else {
        Write-Host "VERZEICHNIS EXISTIERT NICHT: $extractPath" -ForegroundColor Red
        
        # Alle Verzeichnisse in C:\Temp anzeigen
        Write-Host ""
        Write-Host "ALLE VERZEICHNISSE IN C:\Temp:" -ForegroundColor Yellow
        Get-ChildItem $tempPath | Where-Object { $_.PSIsContainer } | ForEach-Object {
            Write-Host "  $($_.Name)" -ForegroundColor Gray
        }
    }
    
    # 5. Gezielt nach Install-DeploymentPackage.ps1 suchen
    Write-Host ""
    Write-Host "SUCHE NACH Install-DeploymentPackage.ps1:" -ForegroundColor Yellow
    $foundFiles = Get-ChildItem $tempPath -Recurse -Name "*Install-DeploymentPackage*"
    if ($foundFiles) {
        foreach ($file in $foundFiles) {
            Write-Host "  GEFUNDEN: $file" -ForegroundColor Green
        }
    } else {
        Write-Host "  NICHT GEFUNDEN!" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "=== DEBUG ABGESCHLOSSEN ===" -ForegroundColor Cyan
}
catch {
    Write-Host "DEBUG FEHLER: $($_.Exception.Message)" -ForegroundColor Red
}