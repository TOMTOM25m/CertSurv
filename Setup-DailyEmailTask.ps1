#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Setup-DailyEmailTask v1.1.0 - Einrichtung der geplanten Aufgabe für tägliche E-Mail-Reports
.DESCRIPTION
    Konfiguriert Windows Task Scheduler für automatische tägliche E-Mail-Versendung um 06:00 Uhr.
    Erstellt eine geplante Aufgabe mit entsprechenden Berechtigungen und Konfiguration.
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.1.0
    Regelwerk: v9.3.1
    Requires: Administrator-Rechte für Task Scheduler Konfiguration
#>

#----------------------------------------------------------[Initialisations]--------------------------------------------------------
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script directory
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DailyEmailScript = Join-Path $ScriptDirectory "DailyEmailScheduler.ps1"

#----------------------------------------------------------[Functions]--------------------------------------------------------

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
}

#----------------------------------------------------------[Main Execution]--------------------------------------------------------

try {
    Write-Log "=== Setting up Daily Certificate Email Task ==="
    
    # Check if running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator to configure Task Scheduler"
    }
    
    # Verify DailyEmailScheduler script exists
    if (-not (Test-Path $DailyEmailScript)) {
        throw "DailyEmailScheduler.ps1 not found: $DailyEmailScript"
    }
    
    Write-Log "Found daily email script: $DailyEmailScript"
    
    # Task parameters
    $TaskName = "Certificate-Surveillance-DailyEmail"
    $TaskDescription = "Tägliche E-Mail-Versendung von Zertifikats-Reports um 06:00 Uhr"
    $TaskPath = "\Certificate-Surveillance\"
    
    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Log "Task already exists. Removing existing task..."
        Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false
    }
    
    # Create task folder if it doesn't exist
    $taskScheduler = New-Object -ComObject Schedule.Service
    $taskScheduler.Connect()
    try {
        $rootFolder = $taskScheduler.GetFolder("\")
        $rootFolder.GetFolder("Certificate-Surveillance")
    } catch {
        Write-Log "Creating task folder: Certificate-Surveillance"
        $rootFolder.CreateFolder("Certificate-Surveillance")
    }
    
    # Define trigger (daily at 06:00)
    $trigger = New-ScheduledTaskTrigger -Daily -At "06:00"
    
    # Define action (run PowerShell script)
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$DailyEmailScript`""
    
    # Define settings
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable
    
    # Define principal (run as SYSTEM or current user)
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType ServiceAccount -RunLevel Highest
    
    # Register the task
    Write-Log "Creating scheduled task: $TaskName"
    Write-Log "Schedule: Daily at 06:00"
    Write-Log "User: $currentUser"
    
    $task = Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Description $TaskDescription -Trigger $trigger -Action $action -Settings $settings -Principal $principal
    
    if ($task) {
        Write-Log "✅ Scheduled task created successfully!"
        Write-Log "Task Name: $($task.TaskName)"
        Write-Log "Task Path: $($task.TaskPath)"
        Write-Log "Next Run Time: $((Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath | Get-ScheduledTaskInfo).NextRunTime)"
        
        # Test the task (optional)
        Write-Log ""
        $testChoice = Read-Host "Möchten Sie die geplante Aufgabe jetzt testen? (j/n)"
        if ($testChoice -eq 'j' -or $testChoice -eq 'J' -or $testChoice -eq 'y' -or $testChoice -eq 'Y') {
            Write-Log "Starting task test..."
            Start-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath
            
            # Wait a moment and check status
            Start-Sleep -Seconds 3
            $taskInfo = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath | Get-ScheduledTaskInfo
            Write-Log "Task Status: $($taskInfo.LastTaskResult)"
            Write-Log "Last Run Time: $($taskInfo.LastRunTime)"
        }
        
        Write-Log ""
        Write-Log "📋 Task Management Commands:"
        Write-Log "  View task:     Get-ScheduledTask -TaskName '$TaskName' -TaskPath '$TaskPath'"
        Write-Log "  Run manually:  Start-ScheduledTask -TaskName '$TaskName' -TaskPath '$TaskPath'"
        Write-Log "  View history:  Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; ID=200,201}"
        Write-Log "  Delete task:   Unregister-ScheduledTask -TaskName '$TaskName' -TaskPath '$TaskPath'"
        
    } else {
        throw "Failed to create scheduled task"
    }
    
} catch {
    Write-Log "❌ Failed to setup daily email task: $($_.Exception.Message)" -Level ERROR
    exit 1
    
} finally {
    Write-Log "=== Setup Complete ==="
}

# --- End of script --- v1.1.0 ; Regelwerk: v9.3.1 ---