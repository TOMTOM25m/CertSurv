#Requires -Version 5.1

<#
.SYNOPSIS
    Certificate Surveillance System - Network Deployment
    
.DESCRIPTION
    [DE] Deployment-Skript fuer die Veroeffentlichung des CertSurv-Systems auf Netzwerkpfad
         und Einrichtung auf itscmgmt03 Server
    [EN] Deployment script for publishing CertSurv system to network path
         and setup on itscmgmt03 server
    
.PARAMETER NetworkPath
    [DE] Netzwerkpfad fuer die Veroeffentlichung (z.B. \\server\iso\CertSurv)
    [EN] Network path for publishing (e.g. \\server\iso\CertSurv)
    
.PARAMETER Action
    [DE] Aktion: Publish, Install, Verify
    [EN] Action: Publish, Install, Verify
    
.EXAMPLE
    .\Deploy-Network.ps1 -Action Publish -NetworkPath "\\itscmgmt03\iso\CertSurv"
    [DE] Veroeffentlicht CertSurv auf dem Netzwerkpfad
    [EN] Publishes CertSurv to the network path
    
.NOTES
    Version:        v1.0.0
    Author:         Flecki (Tom) Garnreiter
    Datum:          2025-09-23
    Regelwerk:      v9.5.0 (File Operations + Network Deployment Standards)
    [DE] Vollstaendig ASCII-kompatibel fuer universelle PowerShell-Unterstuetzung
    [EN] Fully ASCII-compatible for universal PowerShell support
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$NetworkPath,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Publish", "Install", "Verify")]
    [string]$Action
)

# Script version information
$Global:ScriptVersion = "v1.0.0"
$Global:RulebookVersion = "v9.5.0"
$Global:ScriptName = "Deploy-Network"

$SourcePath = $PSScriptRoot

#----------------------------------------------------------[Functions]----------------------------------------------------------

function Show-DeploymentBanner {
    param([string]$Action, [string]$Source, [string]$Target)
    
    $banner = @"

[CONFIG] ================================================================
[CONFIG] Certificate Surveillance System - Network Deployment v$Global:ScriptVersion
[CONFIG] ================================================================
[CONFIG] Source Path: $Source
[CONFIG] Target Path: $Target
[CONFIG] Action: $Action
[CONFIG] PowerShell: $($PSVersionTable.PSVersion.ToString())
[CONFIG] Regelwerk: $Global:RulebookVersion
[CONFIG] ================================================================

"@
    Write-Host $banner -ForegroundColor Cyan
}

function Test-NetworkAccess {
    param([string]$Path)
    
    Write-Host "[INFO] Testing network access to: $Path" -ForegroundColor Yellow
    
    try {
        $parent = Split-Path $Path -Parent
        if (-not (Test-Path $parent)) {
            Write-Host "[FAIL] Parent directory not accessible: $parent" -ForegroundColor Red
            return $false
        }
        
        Write-Host "[OK] Network path accessible" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[FAIL] Network access error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Publish-CertSurv {
    param([string]$SourcePath, [string]$TargetPath)
    
    Write-Host "[INFO] Publishing CertSurv to network path..." -ForegroundColor Cyan
    
    # Create target directory if not exists
    if (-not (Test-Path $TargetPath)) {
        Write-Host "[INFO] Creating target directory: $TargetPath" -ForegroundColor Yellow
        try {
            New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
            Write-Host "[OK] Target directory created" -ForegroundColor Green
        }
        catch {
            Write-Host "[FAIL] Failed to create target directory: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    
    # Use robocopy to copy entire directory structure excluding unwanted folders
    Write-Host "[INFO] Using robocopy for complete directory sync..." -ForegroundColor Yellow
    & robocopy $SourcePath $TargetPath /E /R:3 /W:5 /NP /XD ".git" "LOG" "old" /XF "Deploy-Network.ps1" "NETWORK-DEPLOYMENT-GUIDE.md"
    
    $robocopyResult = $LASTEXITCODE
    if ($robocopyResult -le 7) {
        Write-Host "[OK] Robocopy completed successfully (Exit Code: $robocopyResult)" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[FAIL] Robocopy failed (Exit Code: $robocopyResult)" -ForegroundColor Red
        return $false
    }
    
    Write-Host "[SUCCESS] CertSurv published to network path!" -ForegroundColor Green
    return $true
}

function Install-CertSurvFromNetwork {
    param([string]$NetworkPath, [string]$LocalInstallPath = "C:\Tools\CertSurv")
    
    Write-Host "[INFO] Installing CertSurv from network path..." -ForegroundColor Cyan
    
    # Create local installation directory
    if (-not (Test-Path $LocalInstallPath)) {
        Write-Host "[INFO] Creating installation directory: $LocalInstallPath" -ForegroundColor Yellow
        New-Item -Path $LocalInstallPath -ItemType Directory -Force | Out-Null
    }
    
    # Copy from network using robocopy (Regelwerk v9.5.0)
    Write-Host "[INFO] Copying files using robocopy..." -ForegroundColor Yellow
    & robocopy $NetworkPath $LocalInstallPath /E /R:3 /W:10 /NP
    
    if ($LASTEXITCODE -le 7) {
        Write-Host "[OK] Files copied successfully" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Robocopy failed (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
        return $false
    }
    
    # Run setup
    $setupScript = Join-Path $LocalInstallPath "Setup.ps1"
    if (Test-Path $setupScript) {
        Write-Host "[INFO] Running setup script..." -ForegroundColor Yellow
        & PowerShell.exe -ExecutionPolicy Bypass -File $setupScript
        Write-Host "[OK] Setup completed" -ForegroundColor Green
    }
    
    Write-Host "[SUCCESS] CertSurv installation completed!" -ForegroundColor Green
    return $true
}

function Verify-Deployment {
    param([string]$Path)
    
    Write-Host "[INFO] Verifying deployment..." -ForegroundColor Cyan
    
    $requiredFiles = @("Main.ps1", "Setup.ps1", "Manage.ps1", "Deploy.ps1", "Check.ps1", "README.md")
    $requiredDirs = @("Config", "Modules")
    
    $allGood = $true
    
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $Path $file
        if (Test-Path $filePath) {
            Write-Host "[OK] File present: $file" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Missing file: $file" -ForegroundColor Red
            $allGood = $false
        }
    }
    
    foreach ($dir in $requiredDirs) {
        $dirPath = Join-Path $Path $dir
        if (Test-Path $dirPath) {
            Write-Host "[OK] Directory present: $dir" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Missing directory: $dir" -ForegroundColor Red
            $allGood = $false
        }
    }
    
    return $allGood
}

#----------------------------------------------------------[Main Execution]----------------------------------------------------------

try {
    Show-DeploymentBanner -Action $Action -Source $SourcePath -Target $NetworkPath
    
    $success = switch ($Action) {
        "Publish" {
            if (Test-NetworkAccess $NetworkPath) {
                Publish-CertSurv -SourcePath $SourcePath -TargetPath $NetworkPath
            } else { $false }
        }
        "Install" {
            if (Test-NetworkAccess $NetworkPath) {
                Install-CertSurvFromNetwork -NetworkPath $NetworkPath
            } else { $false }
        }
        "Verify" {
            Verify-Deployment -Path $NetworkPath
        }
    }
    
    if ($success) {
        Write-Host "`n[SUCCESS] Deployment operation '$Action' completed successfully!" -ForegroundColor Green
        
        if ($Action -eq "Publish") {
            Write-Host "`n[INFO] Next steps for itscmgmt03 installation:" -ForegroundColor Cyan
            Write-Host "   1. Connect to itscmgmt03 server" -ForegroundColor White
            Write-Host "   2. Run: PowerShell.exe -ExecutionPolicy Bypass" -ForegroundColor White
            Write-Host "   3. Execute: .\Deploy-Network.ps1 -Action Install -NetworkPath '$NetworkPath'" -ForegroundColor White
            Write-Host "   4. Follow setup instructions" -ForegroundColor White
        }
    } else {
        Write-Host "`n[FAIL] Deployment operation '$Action' failed!" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "`n[FAIL] Deployment error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n[INFO] Network Deployment v$Global:ScriptVersion operation completed" -ForegroundColor Gray

# --- End of Script --- v1.0.0 ; Regelwerk: v9.5.0 ; PowerShell: $($PSVersionTable.PSVersion.ToString()) ---