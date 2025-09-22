#requires -Version 5.1

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "FL-Maintenance - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

<#
.SYNOPSIS
    [DE] FL-Maintenance Modul - Wartungsoperationen für Cert-Surveillance
    [EN] FL-Maintenance Module - Maintenance operations for Cert-Surveillance
.DESCRIPTION
    [DE] Stellt Funktionen für Systemwartung, Log-Verwaltung und Cleanup-Operationen bereit.
    [EN] Provides functions for system maintenance, log management, and cleanup operations.
#>

Function Invoke-LogCleanup {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$LogDirectory,
        [Parameter(Mandatory = $true)]
        [int]$ArchiveLogsOlderThanDays,
        [Parameter(Mandatory = $true)]
        [int]$DeleteZipArchivesOlderThanDays,
        [Parameter(Mandatory = $false)]
        [string]$PathTo7Zip = "C:\Program Files\7-Zip\7z.exe"
    )

    $archiveLimit = (Get-Date).AddDays(-$ArchiveLogsOlderThanDays)
    $deleteLimit = (Get-Date).AddDays(-$DeleteZipArchivesOlderThanDays)

    # Archive old log files
    Get-ChildItem -Path $LogDirectory -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $archiveLimit } | ForEach-Object {
        $zipFile = Join-Path -Path $LogDirectory -ChildPath "$($_.BaseName).zip"
        if (Test-Path $PathTo7Zip) {
            & $PathTo7Zip a -tzip $zipFile $_.FullName
            Remove-Item $_.FullName
            Write-Log "Archived log file: $($_.Name)"
        } else {
            Write-Log "7-Zip not found at '$PathTo7Zip'. Cannot archive logs." -Level WARN
        }
    }

    # Delete old zip archives
    Get-ChildItem -Path $LogDirectory -Filter "*.zip" | Where-Object { $_.LastWriteTime -lt $deleteLimit } | ForEach-Object {
        Remove-Item $_.FullName
        Write-Log "Deleted old archive: $($_.Name)"
    }
}

Export-ModuleMember -Function Invoke-LogCleanup
