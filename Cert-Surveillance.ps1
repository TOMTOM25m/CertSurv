#Requires -version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Monitors SSL certificates on servers listed in an Excel file, generates a report,
    and updates the Excel file with discovered FQDNs and certificate details.
.DESCRIPTION
    This script adheres to Regelwerk9.0.9 and performs the following actions:
    1. Loads configuration from JSON files.
    2. Checks for required PowerShell modules.
    3. Reads a list of servers from a specified Excel file.
    4. Constructs the FQDN for each server based on a defined logic.
    5. Queries each server for SSL certificates on port 443 and in the local certificate store.
    6. Writes the discovered FQDNs and additional certificate names back to the Excel file.
    7. Generates an HTML report detailing certificate statuses (Valid, Warning, Critical, Urgent).
    8. Sends the report via email.
    9. Performs log file cleanup (archiving and deleting old logs).
.PARAMETER ExcelPath
    Overrides the Excel file path specified in the configuration file.
.EXAMPLE
    .\Cert-Surveillance.ps1
    Runs the script using the configuration defined in Config-Cert-Surveillance.ps1.json.
.EXAMPLE
    .\Cert-Surveillance.ps1 -ExcelPath "C:\temp\MyServerList.xlsx"
    Runs the script, but uses a different Excel file than the one in the config.
.NOTES
    Author: GitHub Copilot
    Version: 1.0.0
    Rulebook: 9.0.9
.DISCLAIMER
    This script is provided as-is. Use at your own risk.
#>

#---------------------------------------------------------[Script Parameters]------------------------------------------------------
[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $false)]
    [string]$ExcelPath
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#region ####################### [1. Global Variables & Modules] ##############################
$Global:ScriptName = $MyInvocation.MyCommand.Name
$Global:ScriptVersion = "v1.0.0"
$Global:RulebookVersion = "v9.0.9"
$Global:ScriptDirectory = $PSScriptRoot
$ErrorActionPreference = 'SilentlyContinue'

# Import internal modules
try {
    Import-Module (Join-Path -Path $Global:ScriptDirectory -ChildPath "Modules\FL-Config.psm1") -Force
    Import-Module (Join-Path -Path $Global:ScriptDirectory -ChildPath "Modules\FL-Logging.psm1") -Force
    Import-Module (Join-Path -Path $Global:ScriptDirectory -ChildPath "Modules\FL-Maintenance.psm1") -Force
    Import-Module (Join-Path -Path $Global:ScriptDirectory -ChildPath "Modules\FL-Utils.psm1") -Force
}
catch {
    Write-Host "FATAL: Could not import internal modules. Error: $($_.Exception.Message)"
    exit 1
}

# Load Configuration and Localization
try {
    $ScriptConfig = Get-ScriptConfiguration -ScriptDirectory $Global:ScriptDirectory
    $Global:Config = $ScriptConfig.Config
    $Global:Localization = $ScriptConfig.Localization
    # Override Excel path if provided as a parameter
    if ($PSBoundParameters.ContainsKey('ExcelPath')) {
        $Global:Config.Excel.ExcelPath = $ExcelPath
    }
}
catch {
    Write-Host "FATAL: Could not load configuration. Error: $($_.Exception.Message)"
    exit 1
}
#endregion

#region ####################### [2. Log File Initialization] ##############################
$sLogPath = Join-Path -Path $Global:ScriptDirectory -ChildPath $Global:Config.Paths.LogDirectory
If (!(Test-Path $sLogPath)) {
    New-Item -Path $sLogPath -ItemType Directory | Out-Null
}

$scriptBaseName = $Global:ScriptName.trimend('.ps1')
$sLogName = "$($Global:Config.RunMode)_${scriptBaseName}_$(Get-Date -Format 'yyyy-MM-dd').log"
$Global:sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName
Write-Log -Message ($Global:Localization.log_initialized -f $Global:sLogFile) -LogFile $Global:sLogFile

Write-Log ($Global:Localization.script_loaded -f $Global:ScriptName, $Global:ScriptVersion, $Global:RulebookVersion) -LogFile $Global:sLogFile
Write-Log $Global:Localization.config_loaded -LogFile $Global:sLogFile
#endregion

#region ####################### [3. Module Management] ##############################
[ARRAY]$ModuleArray = @('ImportExcel')
$modulesMissing = $false
foreach ($Module in $ModuleArray) {
    if (-not (Get-Module -ListAvailable -Name $Module)) {
        Write-Log "Module '$Module' is missing." -Level WARN -LogFile $Global:sLogFile
        $modulesMissing = $true
    }
}

if ($modulesMissing) {
    $missingModules = $ModuleArray | Where-Object { -not (Get-Module -ListAvailable -Name $_) } | Join-String -Separator ', '
    Write-Log ($Global:Localization.modules_missing -f $missingModules) -Level ERROR -LogFile $Global:sLogFile
    exit 1
} else {
    Write-Log $Global:Localization.modules_ok -LogFile $Global:sLogFile
}
#endregion

#----------------------------------------------------------[Main Logic]------------------------------------------------------------

try {
    #region ####################### [4. Excel Data Processing] ##############################
    Write-Log ($Global:Localization.excel_opening -f $Global:Config.Excel.ExcelPath) -LogFile $Global:sLogFile
    if (-not (Test-Path $Global:Config.Excel.ExcelPath)) {
        throw ($Global:Localization.excel_not_found -f $Global:Config.Excel.ExcelPath)
    }

    $excelData = Import-Excel -Path $Global:Config.Excel.ExcelPath -WorksheetName $Global:Config.Excel.SheetName -HeaderRow $Global:Config.Excel.HeaderRow
    $currentDomain = ""
    $allServerCertificates = @()

    for ($i = 0; $i -lt $excelData.Count; $i++) {
        $row = $excelData[$i]
        $serverNameValue = $row.$($Global:Config.Excel.ServerNameColumnName)

        if ($serverNameValue -like "*(Domain)*") {
            $currentDomain = ($serverNameValue -replace "\(Domain\)", "").Trim()
            continue
        }

        if (-not ([string]::IsNullOrWhiteSpace($serverNameValue)) -and -not ([string]::IsNullOrWhiteSpace($currentDomain))) {
            $fqdn = "$serverNameValue.$currentDomain.$($Global:Config.MainDomain)"
            Write-Log ($Global:Localization.processing_server -f $serverNameValue) -LogFile $Global:sLogFile
            Write-Log ($Global:Localization.fqdn_constructed -f $serverNameValue, $fqdn) -LogFile $Global:sLogFile

            # Update Excel file in memory
            $row.$($Global:Config.Excel.FqdnColumnName) = $fqdn
            
            # Get Certificates
            Write-Log ($Global:Localization.cert_check_start -f $fqdn) -LogFile $Global:sLogFile
            $certs = Get-Certificates -FQDN $fqdn
            
            if ($certs) {
                $certInfo = $certs | ForEach-Object {
                    $allServerCertificates += [PSCustomObject]@{
                        ServerName = $serverNameValue
                        FQDN = $fqdn
                        CertificateSubject = $_.Subject
                        NotAfter = $_.NotAfter
                        DaysRemaining = ($_.NotAfter - (Get-Date)).Days
                    }
                    Write-Log ($Global:Localization.cert_found -f $_.Subject, $_.NotAfter) -LogFile $Global:sLogFile
                    $_.Subject # Return subject for joining
                }

                $additionalCerts = ($certInfo | Select-Object -Skip 1) -join "; "
                if ($additionalCerts) {
                    $row.$($Global:Config.Excel.FqdnColumnName) += "; $additionalCerts"
                    Write-Log ($Global:Localization.cert_additional_found -f $additionalCerts) -LogFile $Global:sLogFile
                }
            } else {
                 Write-Log ($Global:Localization.cert_no_certs_found -f $fqdn) -Level WARN -LogFile $Global:sLogFile
            }
        }
    }

    # Save changes back to Excel
    $excelData | Export-Excel -Path $Global:Config.Excel.ExcelPath -WorksheetName $Global:Config.Excel.SheetName -Clear -Force
    Write-Log "Excel file has been updated with constructed FQDNs and certificate information." -LogFile $Global:sLogFile
    #endregion

    #region ####################### [5. HTML Report Generation] ##############################
    Write-Log $Global:Localization.report_generation_start -LogFile $Global:sLogFile
    
    $reportPath = Join-Path -Path (Join-Path -Path $Global:ScriptDirectory -ChildPath $Global:Config.Paths.ReportDirectory) -ChildPath "Cert-Report-$(Get-Date -format 'yyyy-MM-dd').html"
    
    $htmlHead = @"
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #dddddd; text-align: left; padding: 8px; }
        th { background-color: $($Global:Config.CorporateDesign.PrimaryColor); color: white; }
        .status-urgent { background-color: red; color: white; }
        .status-critical { background-color: orange; }
        .status-warning { background-color: yellow; }
    </style>
"@

    $htmlBody = "<h1>Certificate Expiration Report - $(Get-Date)</h1>"
    
    $categorizedCerts = $allServerCertificates | Sort-Object DaysRemaining
    
    $htmlBody += "<h2>Certificates</h2>"
    $htmlBody += $categorizedCerts | ConvertTo-Html -Head $htmlHead -Property ServerName, FQDN, CertificateSubject, NotAfter, DaysRemaining | ForEach-Object {
        $line = $_
        if ($line -match '<td>(\d+)</td>') {
            $days = [int]$matches[1]
            if ($days -le $Global:Config.Intervals.DaysUntilUrgent) {
                $line = $line -replace '<tr>', '<tr class="status-urgent">'
            } elseif ($days -le $Global:Config.Intervals.DaysUntilCritical) {
                $line = $line -replace '<tr>', '<tr class="status-critical">'
            } elseif ($days -le $Global:Config.Intervals.DaysUntilWarning) {
                $line = $line -replace '<tr>', '<tr class="status-warning">'
            }
        }
        $line
    } | Out-String

    $htmlBody | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Log ($Global:Localization.report_generation_complete -f $reportPath) -LogFile $Global:sLogFile
    #endregion

    #region ####################### [6. Email Notification] ##############################
    Write-Log $Global:Localization.email_sending -LogFile $Global:sLogFile
    Send-MailNotification -MailConfig $Global:Config.Mail -Subject "Certificate Surveillance Report" -Body $htmlBody -Attachments $reportPath
    #endregion
}
catch {
    Write-Log "An unhandled error occurred: $($_.Exception.Message)" -Level ERROR -LogFile $Global:sLogFile
    # Optionally send an error email
    Send-MailNotification -MailConfig $Global:Config.Mail -Subject "SCRIPT FAILED: $($Global:ScriptName)" -Body "The script failed with the following error: <br><pre>$($_.Exception.ToString())</pre>"
}
finally {
    #region ####################### [7. Cleanup] ##############################
    Invoke-LogCleanup -LogDirectory $sLogPath -ArchiveLogsOlderThanDays $Global:Config.Intervals.ArchiveLogsOlderThanDays -DeleteZipArchivesOlderThanDays $Global:Config.Intervals.DeleteZipArchivesOlderThanDays -PathTo7Zip $Global:Config.Paths.PathTo7Zip
    Write-Log $Global:Localization.script_finished -LogFile $Global:sLogFile
    #endregion
}
