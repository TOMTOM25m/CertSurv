#Requires -Version 5.1

<#
.SYNOPSIS
    Erstellt CertWebService_Latest.zip fur Deployment
    
.DESCRIPTION
    Komprimiert das Deployment-Paket in die erwartete CertWebService_Latest.zip
    
.NOTES
    Version: v1.0.3
    Datum: 2025-09-22
#>

[CmdletBinding()]
param()

try {
    Write-Host "Creating CertWebService_Latest.zip..." -ForegroundColor Green
    
    $sourcePath = "f:\DEV\repositories\CertWebService-Deployment"
    $zipPath = Join-Path $sourcePath "CertWebService_Latest.zip"
    
    # Entferne existierende ZIP-Datei
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
        Write-Host "Existing ZIP file removed" -ForegroundColor Yellow
    }
    
    # Definiere Dateien und Ordner die eingeschlossen werden sollen
    $itemsToInclude = @(
        "Install-DeploymentPackage.ps1",
        "README.md",
        "DEPLOYMENT-OVERVIEW.md",
        "WebService",
        "Scripts", 
        "Config",
        "Documentation"
    )
    
    # Erstelle temporares Verzeichnis fur ZIP-Inhalt
    $tempZipContent = Join-Path $env:TEMP "CertWebService-ZIP-Content"
    if (Test-Path $tempZipContent) {
        Remove-Item $tempZipContent -Recurse -Force
    }
    New-Item $tempZipContent -ItemType Directory -Force | Out-Null
    
    # Kopiere alle notwendigen Dateien
    foreach ($item in $itemsToInclude) {
        $sourcePath = Join-Path "f:\DEV\repositories\CertWebService-Deployment" $item
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath -Destination $tempZipContent -Recurse -Force
            Write-Host "Included: $item" -ForegroundColor Gray
        }
    }
    
    # Erstelle ZIP-Archiv
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempZipContent, $zipPath)
    
    # Aufraumen
    Remove-Item $tempZipContent -Recurse -Force
    
    # Validiere ZIP-Datei
    if (Test-Path $zipPath) {
        $zipInfo = Get-Item $zipPath
        $sizeMB = [math]::Round($zipInfo.Length / 1MB, 2)
        
        Write-Host ""
        Write-Host "SUCCESS: CertWebService_Latest.zip created!" -ForegroundColor Green
        Write-Host "Size: $sizeMB MB" -ForegroundColor White
        Write-Host "Path: $zipPath" -ForegroundColor Gray
        
        # Zeige ZIP-Inhalt
        Write-Host ""
        Write-Host "ZIP Contents:" -ForegroundColor Cyan
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        foreach ($entry in $zip.Entries) {
            Write-Host "  $($entry.FullName)" -ForegroundColor Gray
        }
        $zip.Dispose()
        
        return $zipPath
    } else {
        throw "ZIP file could not be created"
    }
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}