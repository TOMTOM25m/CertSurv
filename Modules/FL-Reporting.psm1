#requires -Version 5.1

<#
.SYNOPSIS
    FL-Reporting Module - Report generation and notifications
.DESCRIPTION
    Handles HTML report generation, email notifications, and other reporting operations
.AUTHOR
    System Administrator
.VERSION
    v1.0.0
.RULEBOOK
    v9.3.0
#>

$ModuleName = "FL-Reporting"
$ModuleVersion = "v1.0.0"

#----------------------------------------------------------[Functions]----------------------------------------------------------

<#
.SYNOPSIS
    Generates HTML report and sends notifications
.DESCRIPTION
    Main orchestration function for reporting operations
#>
function Invoke-ReportingOperations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Certificates,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$ScriptDirectory,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Starting reporting operations..." -LogFile $LogFile
    
    # Generate HTML report
    $reportResult = New-HTMLReport -Certificates $Certificates -Config $Config -ScriptDirectory $ScriptDirectory -LogFile $LogFile
    
    # Send email notification if enabled (use shared Utils implementation if available)
    if ($Config.Mail.Enabled) {
        if (Get-Command -Name Send-MailNotification -Module FL-Utils -ErrorAction SilentlyContinue) {
            # FL-Utils version expects hashtable-like Mail config
            Send-MailNotification -MailConfig $Config.Mail -Subject "Certificate Surveillance Report" -Body $reportResult.HTMLContent -Attachments $reportResult.ReportPath
        } else {
            # Fallback to local implementation
            Send-ReportMail -MailConfig $Config.Mail -Subject "Certificate Surveillance Report" -Body $reportResult.HTMLContent -Attachments $reportResult.ReportPath -LogFile $LogFile
        }
        Write-Log "Email notification sent" -LogFile $LogFile
    }
    else {
        Write-Log "Email notifications disabled in configuration" -LogFile $LogFile
    }
    
    Write-Log "Reporting operations complete" -LogFile $LogFile
    
    return @{
        ReportPath = $reportResult.ReportPath
        EmailSent = $Config.Mail.Enabled
    }
}

<#
.SYNOPSIS
    Generates HTML certificate report
.DESCRIPTION
    Creates a formatted HTML report with certificate status information
#>
function New-HTMLReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Certificates,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$ScriptDirectory,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Generating HTML report..." -LogFile $LogFile
    
    # Ensure report directory exists
    $reportDir = Join-Path -Path $ScriptDirectory -ChildPath $Config.Paths.ReportDirectory
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
        Write-Log "Created report directory: $reportDir" -LogFile $LogFile
    }
    
    $reportPath = Join-Path -Path $reportDir -ChildPath "Cert-Report-$(Get-Date -Format 'yyyy-MM-dd').html"
    
    # Generate CSS styles
    $cssStyles = @"
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #dddddd; text-align: left; padding: 8px; }
        th { background-color: $($Config.CorporateDesign.PrimaryColor); color: white; }
        .status-urgent { background-color: #ff4444; color: white; font-weight: bold; }
        .status-critical { background-color: #ff8800; color: black; font-weight: bold; }
        .status-warning { background-color: #ffff44; color: black; }
        .status-valid { background-color: #44ff44; color: black; }
    .header { background-color: $($Config.CorporateDesign.HoverColor); padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .summary { background-color: #f0f0f0; padding: 10px; margin-bottom: 20px; border-radius: 3px; }
        .footer { margin-top: 30px; font-size: 12px; color: #666; }
    </style>
"@
    
    # Generate report header
    $reportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $htmlHeader = @"
    <div class="header">
        <h1>Certificate Expiration Report</h1>
        <p><strong>Generated:</strong> $reportDate</p>
        <p><strong>Total Certificates:</strong> $($Certificates.Count)</p>
    </div>
"@
    
    # Generate summary
    $urgentCount = ($Certificates | Where-Object { $_.DaysRemaining -le $Config.Intervals.DaysUntilUrgent }).Count
    $criticalCount = ($Certificates | Where-Object { $_.DaysRemaining -le $Config.Intervals.DaysUntilCritical -and $_.DaysRemaining -gt $Config.Intervals.DaysUntilUrgent }).Count
    $warningCount = ($Certificates | Where-Object { $_.DaysRemaining -le $Config.Intervals.DaysUntilWarning -and $_.DaysRemaining -gt $Config.Intervals.DaysUntilCritical }).Count
    $validCount = ($Certificates | Where-Object { $_.DaysRemaining -gt $Config.Intervals.DaysUntilWarning }).Count
    
    $htmlSummary = @"
    <div class="summary">
        <h2>Summary</h2>
        <ul>
            <li><strong>Urgent (≤ $($Config.Intervals.DaysUntilUrgent) days):</strong> $urgentCount certificates</li>
            <li><strong>Critical (≤ $($Config.Intervals.DaysUntilCritical) days):</strong> $criticalCount certificates</li>
            <li><strong>Warning (≤ $($Config.Intervals.DaysUntilWarning) days):</strong> $warningCount certificates</li>
            <li><strong>Valid (> $($Config.Intervals.DaysUntilWarning) days):</strong> $validCount certificates</li>
        </ul>
    </div>
"@
    
    # Generate certificate table
    $htmlTable = ""
    
    if ($Certificates.Count -eq 0) {
        $htmlTable = "<p><strong>No certificates were found or processed.</strong></p>"
        Write-Log "No certificates found for report generation" -Level WARN -LogFile $LogFile
    }
    else {
        $sortedCerts = $Certificates | Sort-Object DaysRemaining
        
        $tableRows = foreach ($cert in $sortedCerts) {
            $statusClass = Get-CertificateStatusClass -DaysRemaining $cert.DaysRemaining -Config $Config
            $daysDisplay = if ($cert.DaysRemaining -lt 0) { "Expired" } else { "$($cert.DaysRemaining) days" }
            
            "<tr class='$statusClass'>"
            "<td>$($cert.ServerName)</td>"
            "<td>$($cert.FQDN)</td>"
            "<td>$($cert.ServerType)</td>"
            "<td>$($cert.CertificateSubject)</td>"
            "<td>$($cert.NotAfter.ToString('yyyy-MM-dd'))</td>"
            "<td>$daysDisplay</td>"
            "</tr>"
        }
        
        $htmlTable = @"
        <h2>Certificate Details</h2>
        <table>
            <thead>
                <tr>
                    <th>Server Name</th>
                    <th>FQDN</th>
                    <th>Server Type</th>
                    <th>Certificate Subject</th>
                    <th>Expiration Date</th>
                    <th>Days Remaining</th>
                </tr>
            </thead>
            <tbody>
                $($tableRows -join "`n                ")
            </tbody>
        </table>
"@
    }
    
    # Generate footer
    $htmlFooter = @"
    <div class="footer">
        <p>Report generated by Cert-Surveillance Script v1.0.2</p>
        <p>Rulebook Version: v9.3.0</p>
    </div>
"@
    
    # Combine all parts
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Certificate Expiration Report</title>
    $cssStyles
</head>
<body>
    $htmlHeader
    $htmlSummary
    $htmlTable
    $htmlFooter
</body>
</html>
"@
    
    # Save HTML file
    try {
        $htmlContent | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Log "HTML report saved to: $reportPath" -LogFile $LogFile
    }
    catch {
        Write-Log "Failed to save HTML report: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
        throw "Failed to save HTML report: $($_.Exception.Message)"
    }
    
    return @{
        ReportPath = $reportPath
        HTMLContent = $htmlContent
    }
}

<#
.SYNOPSIS
    Determines CSS class for certificate status
.DESCRIPTION
    Returns appropriate CSS class based on days remaining
#>
function Get-CertificateStatusClass {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DaysRemaining,
        
        [Parameter(Mandatory = $true)]
        [object]$Config
    )
    
    if ($DaysRemaining -le $Config.Intervals.DaysUntilUrgent) {
        return "status-urgent"
    }
    elseif ($DaysRemaining -le $Config.Intervals.DaysUntilCritical) {
        return "status-critical"
    }
    elseif ($DaysRemaining -le $Config.Intervals.DaysUntilWarning) {
        return "status-warning"
    }
    else {
        return "status-valid"
    }
}

<#
.SYNOPSIS
    Sends email notification
.DESCRIPTION
    Sends HTML report via email with optional attachments
#>
function Send-ReportMail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$MailConfig,
        
        [Parameter(Mandatory = $true)]
        [string]$Subject,
        
        [Parameter(Mandatory = $true)]
        [string]$Body,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Attachments = @()
    )
    
    if (-not $MailConfig.Enabled) {
        Write-Verbose "Email notifications are disabled"
        return
    }
    
    try {
        # Normalize config keys to Utils schema
        $toList = @()
        if ($MailConfig.To) { $toList = @($MailConfig.To) }
        elseif ($MailConfig.ProdTo -or $MailConfig.DevTo) {
            $isProd = ($Global:Config.RunMode -eq 'PROD')
            $toList = @($(if ($isProd) { $MailConfig.ProdTo } else { $MailConfig.DevTo }))
        }

        if (-not $toList -or -not ($toList -join '')) { throw "Mail 'To' is empty in configuration" }

        $fromValue = if ($MailConfig.From) { $MailConfig.From } else { $MailConfig.SenderAddress }
        $portValue = if ($MailConfig.Port) { $MailConfig.Port } else { $MailConfig.SmtpPort }
        $mailParams = @{
            From = $fromValue
            To = $toList
            Subject = $Subject
            Body = $Body
            BodyAsHtml = $true
            SmtpServer = $MailConfig.SmtpServer
            Port = $portValue
            UseSsl = $MailConfig.UseSsl
        }
        
        if ($MailConfig.Credential) {
            $mailParams.Credential = $MailConfig.Credential
        }
        
        if ($Attachments -and $Attachments.Count -gt 0) {
            $mailParams.Attachments = $Attachments
        }
        
    Send-MailMessage @mailParams
    Write-Log "Email sent successfully to $($mailParams.To -join ', ')" -LogFile $LogFile
    }
    catch {
    Write-Log "Failed to send email: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
    throw "Failed to send email: $($_.Exception.Message)"
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------
Export-ModuleMember -Function @(
    'Invoke-ReportingOperations',
    'New-HTMLReport',
    'Get-CertificateStatusClass',
    'Send-ReportMail'
)

# --- End of module --- v1.0.0 ; Regelwerk: v9.3.0 ---
