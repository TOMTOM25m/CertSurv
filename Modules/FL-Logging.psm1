#requires -Version 5.1

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "FL-Logging - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

<#
.SYNOPSIS
    [DE] FL-Logging Modul - Strukturiertes Logging für Cert-Surveillance
    [EN] FL-Logging Module - Structured logging for Cert-Surveillance
.DESCRIPTION
    [DE] Stellt Funktionen für strukturiertes und levelbezogenes Logging bereit.
         Unterstützt Console- und Datei-Output mit konfigurierbaren Log-Levels.
    [EN] Provides functions for structured and level-based logging.
         Supports console and file output with configurable log levels.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.09.04
    Last modified:  2025.09.04
    Version:        v1.0.0
    MUW-Regelwerk:  v9.4.0 (PowerShell Version Adaptation)
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

$ModuleName = "FL-Logging"
$ModuleVersion = "v1.1.0"

#region PowerShell Version Logging Functions (Regelwerk v9.4.0)
function Write-PowerShellVersionInfo {
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogFile
    )
    
    $psInfo = "PowerShell $($PSVersion.ToString()) ($($PSVersionTable.PSEdition))"
    if ($IsPS7Plus -and $PSVersionTable.Platform) {
        $psInfo += " on $($PSVersionTable.Platform)"
    }
    
    Write-Log -Message "Session Started - $psInfo" -Level 'INFO' -LogFile $LogFile
}
#endregion

#----------------------------------------------------------[Functions]----------------------------------------------------------

Function Write-Log {
    <#
    .SYNOPSIS
        [DE] Schreibt strukturierte Log-Einträge.
        [EN] Writes structured log entries.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',
        [Parameter(Mandatory = $false)]
        [string]$LogFile
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    if ($Global:Config.DebugMode -or $Level -ne 'DEBUG') {
        Write-Host $logEntry
    }
    
    if ($LogFile) {
        Out-File -FilePath $LogFile -InputObject $logEntry -Append
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function Write-Log, Write-PowerShellVersionInfo

Write-Verbose "FL-Logging module v$ModuleVersion loaded successfully"

# --- End of module --- v1.1.0 ; Regelwerk: v9.3.1 ---
