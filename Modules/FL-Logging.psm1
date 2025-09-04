#Requires -version 5.1

Function Write-Log {
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

Export-ModuleMember -Function Write-Log
