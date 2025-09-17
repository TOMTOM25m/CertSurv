#requires -Version 5.1

<#
.SYNOPSIS
    Daily Certificate Email Scheduler v1.1.0
.DESCRIPTION
    Zeitgesteuertes Skript für tägliche E-Mail-Versendung von Zertifikats-Reports um 06:00 Uhr.
    Dieses Skript kann als geplante Aufgabe (Task Scheduler) eingerichtet werden.
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.1.0
    Regelwerk: v9.3.1
    Usage: Sollte täglich um 06:00 Uhr via Windows Task Scheduler ausgeführt werden
#>

#----------------------------------------------------------[Initialisations]--------------------------------------------------------
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script metadata
$ScriptVersion = "v1.1.0"
$RulebookVersion = "v9.3.1"

# Get script directory
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ModulesPath = Join-Path $ScriptDirectory "Modules"
$ConfigPath = Join-Path $ScriptDirectory "Config"
$LogPath = Join-Path $ScriptDirectory "LOG"

# Create log directory if it doesn't exist
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Initialize logging
$LogFile = Join-Path $LogPath "DailyEmailScheduler_$(Get-Date -Format 'yyyy-MM-dd').log"

#----------------------------------------------------------[Functions]--------------------------------------------------------

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
    }
}

#----------------------------------------------------------[Main Execution]--------------------------------------------------------

try {
    Write-Log "=== Daily Certificate Email Scheduler v$ScriptVersion Started ===" -LogFile $LogFile
    Write-Log "Execution time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -LogFile $LogFile
    
    # Load configuration
    $ConfigFile = Join-Path $ConfigPath "Config-Cert-Surveillance.json"
    if (-not (Test-Path $ConfigFile)) {
        throw "Configuration file not found: $ConfigFile"
    }
    
    $Config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
    Write-Log "Configuration loaded from: $ConfigFile" -LogFile $LogFile
    
    # Import required modules
    $requiredModules = @(
        "FL-Config.psm1",
        "FL-Logging.psm1", 
        "FL-DataStorage.psm1"
    )
    
    foreach ($module in $requiredModules) {
        $modulePath = Join-Path $ModulesPath $module
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force
            Write-Log "Module imported: $module" -LogFile $LogFile
        } else {
            Write-Log "Module not found: $module" -Level WARN -LogFile $LogFile
        }
    }
    
    # Find latest certificate data JSON file
    $dateString = (Get-Date).ToString('yyyy-MM-dd')
    $jsonFile = Join-Path $LogPath "CertificateData_$dateString.json"
    
    # Check for today's data first, then yesterday's as fallback
    if (-not (Test-Path $jsonFile)) {
        $yesterdayString = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
        $jsonFile = Join-Path $LogPath "CertificateData_$yesterdayString.json"
        Write-Log "Today's data not found, checking yesterday's: $jsonFile" -LogFile $LogFile
    }
    
    if (-not (Test-Path $jsonFile)) {
        # Look for any recent JSON files (last 7 days)
        $jsonFiles = Get-ChildItem -Path $LogPath -Name "CertificateData_*.json" | 
                    Sort-Object -Descending | 
                    Select-Object -First 1
        
        if ($jsonFiles) {
            $jsonFile = Join-Path $LogPath $jsonFiles
            Write-Log "Using most recent certificate data: $jsonFile" -LogFile $LogFile
        } else {
            throw "No certificate data JSON files found in the last 7 days"
        }
    }
    
    Write-Log "Using certificate data file: $jsonFile" -LogFile $LogFile
    
    # Check current time - should be around 06:00
    $currentTime = Get-Date
    Write-Log "Current time: $($currentTime.ToString('HH:mm:ss'))" -LogFile $LogFile
    
    # Send daily report (will check time window internally unless forced)
    Write-Log "Attempting to send daily certificate report..." -LogFile $LogFile
    
    $result = Send-DailyCertificateReport -JsonFilePath $jsonFile -Config $Config -LogFile $LogFile
    
    if ($result.Success) {
        Write-Log "✅ Daily certificate report sent successfully!" -LogFile $LogFile
        Write-Log "Recipient: $($result.Recipient)" -LogFile $LogFile
        Write-Log "Subject: $($result.Subject)" -LogFile $LogFile
        Write-Log "Summary: $($result.Summary.Filtered) certificates requiring attention" -LogFile $LogFile
        
        # Log detailed summary
        if ($result.Summary) {
            Write-Log "Certificate breakdown:" -LogFile $LogFile
            Write-Log "  - Expired: $($result.Summary.Expired)" -LogFile $LogFile
            Write-Log "  - Urgent: $($result.Summary.Urgent)" -LogFile $LogFile
            Write-Log "  - Critical: $($result.Summary.Critical)" -LogFile $LogFile
            Write-Log "  - Warning: $($result.Summary.Warning)" -LogFile $LogFile
        }
        
        $exitCode = 0
        
    } else {
        Write-Log "ℹ️ Daily certificate report not sent: $($result.Reason)" -LogFile $LogFile
        Write-Log "Scheduled time: $($result.ScheduledTime), Current time: $($result.CurrentTime)" -LogFile $LogFile
        
        $exitCode = 1
    }
    
} catch {
    Write-Log "❌ Daily email scheduler failed: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level ERROR -LogFile $LogFile
    $exitCode = 2
    
} finally {
    Write-Log "=== Daily Certificate Email Scheduler Completed ===" -LogFile $LogFile
    Write-Log "Exit code: $exitCode" -LogFile $LogFile
    
    # Clean up old log files (older than 30 days)
    try {
        $cutoffDate = (Get-Date).AddDays(-30)
        Get-ChildItem -Path $LogPath -Name "DailyEmailScheduler_*.log" | ForEach-Object {
            $filePath = Join-Path $LogPath $_
            $fileDate = (Get-Item $filePath).CreationTime
            if ($fileDate -lt $cutoffDate) {
                Remove-Item $filePath -Force
                Write-Log "Cleaned up old log file: $_" -LogFile $LogFile
            }
        }
    } catch {
        Write-Log "Warning: Failed to clean up old log files: $($_.Exception.Message)" -Level WARN -LogFile $LogFile
    }
    
    exit $exitCode
}

# --- End of script --- v1.1.0 ; Regelwerk: v9.3.1 ---