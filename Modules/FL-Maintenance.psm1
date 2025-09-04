#Requires -version 5.1

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
