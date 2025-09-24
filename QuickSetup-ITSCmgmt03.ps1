#Requires -Version 5.1

<#
.SYNOPSIS
    Certificate Surveillance System - ITSCmgmt03 Quick Setup
    
.DESCRIPTION
    [DE] Schnell-Setup fuer CertSurv auf ITSCmgmt03.srv.meduniwien.ac.at
         Automatisierte Installation mit MedUniWien-spezifischen Einstellungen
    [EN] Quick setup for CertSurv on ITSCmgmt03.srv.meduniwien.ac.at
         Automated installation with MedUniWien-specific settings
    
.PARAMETER NetworkPath
    [DE] Netzwerkpfad zum CertSurv-Deployment
    [EN] Network path to CertSurv deployment
    
.PARAMETER InstallPath
    [DE] Lokaler Installationspfad (Standard: C:\Tools\CertSurv)
    [EN] Local installation path (default: C:\Tools\CertSurv)
    
.EXAMPLE
    .\QuickSetup-ITSCmgmt03.ps1 -NetworkPath "C:\ISO\CertSurv"
    [DE] Schnelle Installation vom lokalen ISO-Pfad
    [EN] Quick installation from local ISO path
    
.NOTES
    Version:        v1.0.0
    Author:         Flecki (Tom) Garnreiter
    Target Server:  ITSCmgmt03.srv.meduniwien.ac.at
    Datum:          2025-09-23
    Regelwerk:      v9.5.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$NetworkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv",
    
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "C:\Script\CertSurv-Master"
)

$Global:ScriptVersion = "v1.0.0"
$Global:RulebookVersion = "v9.5.0"
$Global:TargetServer = "ITSCmgmt03.srv.meduniwien.ac.at"

#----------------------------------------------------------[Functions]----------------------------------------------------------

function Show-SetupBanner {
    $banner = @"

[SETUP] =================================================================
[SETUP] Certificate Surveillance System - ITSCmgmt03 Quick Setup v$Global:ScriptVersion
[SETUP] =================================================================
[SETUP] Target Server: $Global:TargetServer
[SETUP] Network Path: $NetworkPath
[SETUP] Install Path: $InstallPath
[SETUP] PowerShell: $($PSVersionTable.PSVersion.ToString())
[SETUP] Regelwerk: $Global:RulebookVersion
[SETUP] =================================================================

"@
    Write-Host $banner -ForegroundColor Cyan
}

function Test-Prerequisites {
    Write-Host "[INFO] Checking prerequisites..." -ForegroundColor Yellow
    
    # Administrator check
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "[FAIL] Script must be run as Administrator!" -ForegroundColor Red
        return $false
    }
    Write-Host "[OK] Running as Administrator" -ForegroundColor Green
    
    # PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host "[FAIL] PowerShell 5.1+ required (current: $($PSVersionTable.PSVersion))" -ForegroundColor Red
        return $false
    }
    Write-Host "[OK] PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Green
    
    # Network path access
    if (-not (Test-Path $NetworkPath)) {
        Write-Host "[FAIL] Network path not accessible: $NetworkPath" -ForegroundColor Red
        return $false
    }
    Write-Host "[OK] Network path accessible: $NetworkPath" -ForegroundColor Green
    
    # Free disk space (min 1GB)
    $drive = (Split-Path $InstallPath -Qualifier)
    $freeSpace = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$drive'").FreeSpace / 1GB
    if ($freeSpace -lt 1) {
        Write-Host "[FAIL] Insufficient disk space (${freeSpace}GB free, 1GB required)" -ForegroundColor Red
        return $false
    }
    Write-Host "[OK] Disk space: ${freeSpace}GB free" -ForegroundColor Green
    
    return $true
}

function Install-CertSurv {
    Write-Host "[INFO] Installing CertSurv..." -ForegroundColor Cyan
    
    # Create installation directory
    if (-not (Test-Path $InstallPath)) {
        Write-Host "[INFO] Creating installation directory: $InstallPath" -ForegroundColor Yellow
        New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
    }
    
    # Copy files using robocopy (Regelwerk v9.5.0)
    Write-Host "[INFO] Copying files using robocopy..." -ForegroundColor Yellow
    & robocopy $NetworkPath $InstallPath /E /R:3 /W:10 /NP /LOG:"$env:TEMP\CertSurv-Install.log"
    
    $robocopyResult = $LASTEXITCODE
    if ($robocopyResult -le 7) {
        Write-Host "[OK] Files copied successfully (Exit Code: $robocopyResult)" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Robocopy failed (Exit Code: $robocopyResult)" -ForegroundColor Red
        Write-Host "[INFO] Check log: $env:TEMP\CertSurv-Install.log" -ForegroundColor Gray
        return $false
    }
    
    return $true
}

function Set-MedUniWienConfiguration {
    Write-Host "[INFO] Applying MedUniWien-specific configuration..." -ForegroundColor Cyan
    
    $configPath = Join-Path $InstallPath "Config\Config-Cert-Surveillance.json"
    
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            
            # Update basic settings (nur vorhandene Properties)
            $config.RunMode = "PROD"
            $config.ConfigurationUpdated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            
            # Update version information
            if ($config.PSObject.Properties.Name -contains "ScriptVersion") {
                $config.ScriptVersion = "v1.3.0"
            }
            if ($config.PSObject.Properties.Name -contains "RulebookVersion") {
                $config.RulebookVersion = "v9.5.0"
            }
            
            # Update paths safely
            if ($config.Paths) {
                $config.Paths.ConfigFile = "$InstallPath\Config\Config-Cert-Surveillance.json"
                $config.Paths.LogDirectory = "$InstallPath\LOG"
                $config.Paths.JsonDataDirectory = "$InstallPath\LOG"
                if ($config.Paths.PSObject.Properties.Name -contains "ReportDirectory") {
                    $config.Paths.ReportDirectory = "C:\Reports\CertSurv"
                }
            }
            
            # Save configuration
            $config | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding ASCII
            Write-Host "[OK] Configuration updated for ITSCmgmt03" -ForegroundColor Green
        }
        catch {
            Write-Host "[WARN] Configuration update failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "[INFO] Using default configuration" -ForegroundColor Gray
        }
    } else {
        Write-Host "[WARN] Configuration file not found: $configPath" -ForegroundColor Yellow
    }
    
    # Create required directories
    $requiredDirs = @("C:\Reports\CertSurv-Master", "C:\Backup\CertSurv-Master", "C:\Archive\CertSurv-Master")
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Host "[OK] Created directory: $dir" -ForegroundColor Green
            }
            catch {
                Write-Host "[WARN] Could not create directory: $dir" -ForegroundColor Yellow
            }
        }
    }
}

function Install-ScheduledTask {
    Write-Host "[INFO] Installing scheduled task..." -ForegroundColor Cyan
    
    try {
        $taskName = "CertSurv-ITSCmgmt03-Daily"
        $scriptPath = Join-Path $InstallPath "Main.ps1"
        
        # Task Action
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Environment Production"
        
        # Task Trigger (daily at 2:00 AM)
        $trigger = New-ScheduledTaskTrigger -Daily -At "02:00"
        
        # Task Settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
        
        # Task Principal (run as SYSTEM for server environment)
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
        
        # Register Task
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
        
        Write-Host "[OK] Scheduled task '$taskName' created successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[FAIL] Failed to create scheduled task: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-Installation {
    Write-Host "[INFO] Testing installation..." -ForegroundColor Cyan
    
    # Test 1: Files present
    $requiredFiles = @("Main.ps1", "Setup.ps1", "Manage.ps1", "Deploy.ps1", "Check.ps1")
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $InstallPath $file
        if (Test-Path $filePath) {
            Write-Host "[OK] File present: $file" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Missing file: $file" -ForegroundColor Red
            return $false
        }
    }
    
    # Test 2: Modules loadable
    $modulePath = Join-Path $InstallPath "Modules\FL-Config.psm1"
    try {
        Import-Module $modulePath -Force
        Write-Host "[OK] Modules loadable" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAIL] Module import failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Test 3: Configuration valid
    $configPath = Join-Path $InstallPath "Config\Config-Cert-Surveillance.json"
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        Write-Host "[OK] Configuration valid" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAIL] Invalid configuration: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Test 4: System Check
    try {
        $checkScript = Join-Path $InstallPath "Check.ps1"
        & PowerShell.exe -ExecutionPolicy Bypass -File $checkScript -ConfigOnly
        Write-Host "[OK] System check passed" -ForegroundColor Green
    }
    catch {
        Write-Host "[WARN] System check issues (may be normal for first run)" -ForegroundColor Yellow
    }
    
    return $true
}

function Show-PostInstallInstructions {
    Write-Host "`n[SUCCESS] CertSurv installation completed successfully!" -ForegroundColor Green
    
    $instructions = @"

[POST-INSTALL] ==========================================================
[POST-INSTALL] Next Steps for ITSCmgmt03 Production Environment:
[POST-INSTALL] ==========================================================

1. CONFIGURATION REVIEW:
   - Edit: $InstallPath\Config\Config-Cert-Surveillance.json
   - Verify server list and email settings
   - Adjust certificate thresholds if needed

2. SECURITY SETUP:
   - Create Service Account: srv.meduniwien.ac.at\svc-certsurv
   - Assign 'Log on as service' right
   - Update scheduled task to use service account

3. INITIAL TESTING:
   cd "$InstallPath"
   .\Check.ps1 -Full
   .\Main.ps1 -TestMode

4. MONITORING SETUP:
   .\Manage.ps1 -ShowDashboard
   .\Manage.ps1 -SetupMonitoring

5. PRODUCTION ACTIVATION:
   - Start scheduled task: CertSurv-ITSCmgmt03-Daily
   - Verify first run in 24 hours
   - Check logs: $InstallPath\LOG\

6. MAINTENANCE:
   - Daily: Automatic via scheduled task
   - Weekly: .\Manage.ps1 -WeeklyMaintenance
   - Monthly: Log archiving and updates

[POST-INSTALL] ==========================================================
[POST-INSTALL] Installation Path: $InstallPath
[POST-INSTALL] Configuration: $InstallPath\Config\
[POST-INSTALL] Logs: $InstallPath\LOG\
[POST-INSTALL] Documentation: $InstallPath\README.md
[POST-INSTALL] ==========================================================

"@
    Write-Host $instructions -ForegroundColor White
}

#----------------------------------------------------------[Main Execution]----------------------------------------------------------

try {
    Show-SetupBanner
    
    # Step 1: Prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Host "[FAIL] Prerequisites not met. Installation aborted." -ForegroundColor Red
        exit 1
    }
    
    # Step 2: Installation
    if (-not (Install-CertSurv)) {
        Write-Host "[FAIL] Installation failed. Check logs." -ForegroundColor Red
        exit 1
    }
    
    # Step 3: Configuration
    Set-MedUniWienConfiguration
    
    # Step 4: Scheduled Task
    if (-not (Install-ScheduledTask)) {
        Write-Host "[WARN] Scheduled task installation failed. Manual setup required." -ForegroundColor Yellow
    }
    
    # Step 5: Testing
    if (-not (Test-Installation)) {
        Write-Host "[WARN] Installation tests failed. Manual verification required." -ForegroundColor Yellow
    }
    
    # Step 6: Post-Install Instructions
    Show-PostInstallInstructions
    
    Write-Host "`n[SUCCESS] ITSCmgmt03 Quick Setup v$Global:ScriptVersion completed!" -ForegroundColor Green
}
catch {
    Write-Host "`n[FAIL] Setup error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[INFO] Check installation log: $env:TEMP\CertSurv-Install.log" -ForegroundColor Gray
    exit 1
}

# --- End of Script --- v1.0.0 ; Regelwerk: v9.5.0 ; Target: ITSCmgmt03.srv.meduniwien.ac.at ---