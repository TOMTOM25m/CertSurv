#requires -Version 5.1

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
    MUW-Regelwerk:  v9.3.0
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

$ModuleName = "FL-Logging"
$ModuleVersion = "v1.1.0"

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

Export-ModuleMember -Function Write-Log

Write-Verbose "FL-Logging module v$ModuleVersion loaded successfully"

# --- End of module --- v1.1.0 ; Regelwerk: v9.3.1 ---
