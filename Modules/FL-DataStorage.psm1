#requires -Version 5.1

<#
.SYNOPSIS
    FL-DataStorage v1.1.0 - JSON-Datenspeicherung für Zertifikatsdaten
.DESCRIPTION
    Modul für die persistente Speicherung und Verwaltung von Zertifikatsdaten im JSON-Format
    mit täglicher E-Mail-Versendung um 06:00 Uhr
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.1.0
    Regelwerk: v9.3.1
    Features: JSON-Storage, Daily Email Scheduling, Data Filtering
#>

$ModuleName = "FL-DataStorage"
$ModuleVersion = "v1.1.0"

#----------------------------------------------------------[Functions]----------------------------------------------------------

<#
.SYNOPSIS
    Speichert Zertifikatsdaten in JSON-Format
.DESCRIPTION
    Speichert die gesammelten Zertifikatsdaten in einer strukturierten JSON-Datei
    mit Metadaten und Zeitstempel für tägliche Verarbeitung
#>
function Save-CertificateDataToJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$CertificateData,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )
    
    if (-not $OutputPath) {
        $dateString = (Get-Date).ToString('yyyy-MM-dd')
        $OutputPath = Join-Path $Config.Paths.LogDirectory "CertificateData_$dateString.json"
    }
    
    Write-Log "Saving certificate data to JSON: $OutputPath" -LogFile $LogFile
    
    try {
        # Erstelle strukturierte Datensammlung
        $jsonData = @{
            Generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            Version = $Config.ScriptVersion
            Rulebook = $Config.RulebookVersion
            TotalServers = $CertificateData.Count
            Summary = @{
                ValidCertificates = ($CertificateData | Where-Object { $_.DaysRemaining -gt 0 }).Count
                ExpiredCertificates = ($CertificateData | Where-Object { $_.DaysRemaining -le 0 }).Count
                CriticalCertificates = ($CertificateData | Where-Object { $_.DaysRemaining -le $Config.Intervals.DaysUntilCritical -and $_.DaysRemaining -gt 0 }).Count
                WarningCertificates = ($CertificateData | Where-Object { $_.DaysRemaining -le $Config.Intervals.DaysUntilWarning -and $_.DaysRemaining -gt $Config.Intervals.DaysUntilCritical }).Count
            }
            Filters = @{
                CriticalDays = $Config.Intervals.DaysUntilCritical
                WarningDays = $Config.Intervals.DaysUntilWarning
                UrgentDays = $Config.Intervals.DaysUntilUrgent
            }
            Certificates = @()
        }
        
        # Verarbeite Zertifikatsdaten
        foreach ($cert in $CertificateData) {
            $certObject = @{
                ServerName = $cert.ServerName
                FQDN = $cert.FQDN
                ServerType = $cert.ServerType
                Subject = $cert.CertificateSubject
                NotAfter = $cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
                DaysRemaining = $cert.DaysRemaining
                Status = if ($cert.DaysRemaining -le 0) { "Expired" }
                         elseif ($cert.DaysRemaining -le $Config.Intervals.DaysUntilUrgent) { "Urgent" }
                         elseif ($cert.DaysRemaining -le $Config.Intervals.DaysUntilCritical) { "Critical" }
                         elseif ($cert.DaysRemaining -le $Config.Intervals.DaysUntilWarning) { "Warning" }
                         else { "Valid" }
                RetrievalMethod = $cert.RetrievalMethod
                Thumbprint = $cert.Thumbprint
                HasPrivateKey = $cert.HasPrivateKey
                ADInformation = @{
                    ServerExists = $cert.ADServerExists
                    LastLogon = $cert.ADLastLogon
                    OperatingSystem = $cert.ADOperatingSystem
                }
            }
            
            $jsonData.Certificates += $certObject
        }
        
        # Erstelle Verzeichnis falls nicht vorhanden
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }
        
        # Speichere JSON-Datei
        $jsonData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        
        Write-Log "Certificate data saved successfully: $($jsonData.Certificates.Count) certificates" -LogFile $LogFile
        Write-Log "Summary - Valid: $($jsonData.Summary.ValidCertificates), Critical: $($jsonData.Summary.CriticalCertificates), Expired: $($jsonData.Summary.ExpiredCertificates)" -LogFile $LogFile
        
        return @{
            Success = $true
            FilePath = $OutputPath
            Summary = $jsonData.Summary
            TotalCertificates = $jsonData.Certificates.Count
        }
        
    } catch {
        Write-Log "Failed to save certificate data to JSON: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
        throw
    }
}

<#
.SYNOPSIS
    Lädt und filtert Zertifikatsdaten aus JSON-Datei
.DESCRIPTION
    Lädt gespeicherte Zertifikatsdaten und filtert sie nach Priorität für E-Mail-Versendung
#>
function Get-FilteredCertificateData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile,
        
        [Parameter(Mandatory = $false)]
        [string[]]$StatusFilter = @("Expired", "Urgent", "Critical", "Warning")
    )
    
    Write-Log "Loading and filtering certificate data from: $JsonFilePath" -LogFile $LogFile
    
    try {
        if (-not (Test-Path $JsonFilePath)) {
            throw "JSON file not found: $JsonFilePath"
        }
        
        $jsonData = Get-Content -Path $JsonFilePath -Raw | ConvertFrom-Json
        
        # Filtere Zertifikate nach Status
        $filteredCertificates = $jsonData.Certificates | Where-Object { $_.Status -in $StatusFilter }
        
        # Sortiere nach Priorität (Expired > Urgent > Critical > Warning)
        $priorityOrder = @{ "Expired" = 1; "Urgent" = 2; "Critical" = 3; "Warning" = 4 }
        $sortedCertificates = $filteredCertificates | Sort-Object { $priorityOrder[$_.Status] }, DaysRemaining
        
        Write-Log "Filtered certificates: $($sortedCertificates.Count) of $($jsonData.Certificates.Count) total" -LogFile $LogFile
        
        return @{
            Success = $true
            OriginalData = $jsonData
            FilteredCertificates = $sortedCertificates
            Summary = @{
                Total = $jsonData.Certificates.Count
                Filtered = $sortedCertificates.Count
                Expired = ($sortedCertificates | Where-Object { $_.Status -eq "Expired" }).Count
                Urgent = ($sortedCertificates | Where-Object { $_.Status -eq "Urgent" }).Count
                Critical = ($sortedCertificates | Where-Object { $_.Status -eq "Critical" }).Count
                Warning = ($sortedCertificates | Where-Object { $_.Status -eq "Warning" }).Count
            }
        }
        
    } catch {
        Write-Log "Failed to load certificate data from JSON: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
        throw
    }
}

<#
.SYNOPSIS
    Erstellt HTML-E-Mail-Report aus gefilterten Zertifikatsdaten
.DESCRIPTION
    Generiert einen formatierten HTML-E-Mail-Report für tägliche Versendung um 06:00
#>
function New-DailyCertificateEmailReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$FilteredData,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Creating daily certificate email report" -LogFile $LogFile
    
    try {
        $certificates = $FilteredData.FilteredCertificates
        $summary = $FilteredData.Summary
        
        # HTML-Report erstellen
        $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: $($Config.CorporateDesign.PrimaryColor); color: white; padding: 15px; text-align: center; }
        .summary { background-color: #f5f5f5; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .expired { background-color: #ffebee; border-left: 4px solid #f44336; }
        .urgent { background-color: #fff3e0; border-left: 4px solid #ff9800; }
        .critical { background-color: #fef7e0; border-left: 4px solid #ffc107; }
        .warning { background-color: #e8f5e8; border-left: 4px solid #4caf50; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        .status-expired { color: #f44336; font-weight: bold; }
        .status-urgent { color: #ff9800; font-weight: bold; }
        .status-critical { color: #ffc107; font-weight: bold; }
        .status-warning { color: #4caf50; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📋 Täglicher Zertifikats-Report</h1>
        <p>Generiert: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')</p>
    </div>
    
    <div class="summary">
        <h2>📊 Zusammenfassung</h2>
        <p><strong>Gesamtanzahl Server:</strong> $($summary.Total)</p>
        <p><strong>Benötigen Aufmerksamkeit:</strong> $($summary.Filtered)</p>
        <ul>
            <li><span class="status-expired">🔴 Abgelaufen:</span> $($summary.Expired)</li>
            <li><span class="status-urgent">🟠 Dringend (≤$($Config.Intervals.DaysUntilUrgent) Tage):</span> $($summary.Urgent)</li>
            <li><span class="status-critical">🟡 Kritisch (≤$($Config.Intervals.DaysUntilCritical) Tage):</span> $($summary.Critical)</li>
            <li><span class="status-warning">🟢 Warnung (≤$($Config.Intervals.DaysUntilWarning) Tage):</span> $($summary.Warning)</li>
        </ul>
    </div>
"@

        if ($certificates.Count -gt 0) {
            $htmlContent += @"
    <h2>🔍 Zertifikate Details</h2>
    <table>
        <thead>
            <tr>
                <th>Status</th>
                <th>Server</th>
                <th>FQDN</th>
                <th>Zertifikat Subject</th>
                <th>Ablaufdatum</th>
                <th>Tage verbleibend</th>
                <th>Methode</th>
            </tr>
        </thead>
        <tbody>
"@
            
            foreach ($cert in $certificates) {
                $statusClass = "status-" + $cert.Status.ToLower()
                $statusIcon = switch ($cert.Status) {
                    "Expired" { "🔴" }
                    "Urgent" { "🟠" }
                    "Critical" { "🟡" }
                    "Warning" { "🟢" }
                    default { "ℹ️" }
                }
                
                $htmlContent += @"
            <tr class="$($cert.Status.ToLower())">
                <td><span class="$statusClass">$statusIcon $($cert.Status)</span></td>
                <td>$($cert.ServerName)</td>
                <td>$($cert.FQDN)</td>
                <td>$($cert.Subject)</td>
                <td>$($cert.NotAfter)</td>
                <td>$($cert.DaysRemaining)</td>
                <td>$($cert.RetrievalMethod)</td>
            </tr>
"@
            }
            
            $htmlContent += @"
        </tbody>
    </table>
"@
        } else {
            $htmlContent += @"
    <div class="summary">
        <h2>✅ Keine kritischen Zertifikate</h2>
        <p>Alle Zertifikate sind gültig und benötigen derzeit keine Aufmerksamkeit.</p>
    </div>
"@
        }
        
        $htmlContent += @"
    <div class="summary">
        <p><small>Generiert von Certificate Surveillance System v$($Config.ScriptVersion) | Regelwerk v$($Config.RulebookVersion)</small></p>
    </div>
</body>
</html>
"@
        
        # E-Mail-Betreff erstellen
        $subject = "$($Config.Mail.SubjectPrefix) "
        if ($summary.Expired -gt 0) {
            $subject += "🔴 $($summary.Expired) ABGELAUFENE Zertifikate!"
        } elseif ($summary.Urgent -gt 0) {
            $subject += "🟠 $($summary.Urgent) DRINGENDE Zertifikate!"
        } elseif ($summary.Critical -gt 0) {
            $subject += "🟡 $($summary.Critical) kritische Zertifikate"
        } elseif ($summary.Warning -gt 0) {
            $subject += "🟢 $($summary.Warning) Zertifikate zur Überwachung"
        } else {
            $subject += "✅ Alle Zertifikate gültig"
        }
        
        Write-Log "Daily email report created: Subject = '$subject', Content length = $($htmlContent.Length) chars" -LogFile $LogFile
        
        return @{
            Success = $true
            Subject = $subject
            HtmlContent = $htmlContent
            Summary = $summary
        }
        
    } catch {
        Write-Log "Failed to create daily email report: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
        throw
    }
}

<#
.SYNOPSIS
    Sendet täglichen E-Mail-Report um 06:00 Uhr
.DESCRIPTION
    Implementiert zeitgesteuerte E-Mail-Versendung für tägliche Zertifikats-Reports
#>
function Send-DailyCertificateReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    Write-Log "Starting daily certificate report process" -LogFile $LogFile
    
    try {
        # Überprüfe Zeitfenster (06:00 Uhr) außer wenn Force verwendet wird
        $currentTime = Get-Date
        $targetTime = Get-Date -Hour 6 -Minute 0 -Second 0
        $timeWindow = New-TimeSpan -Minutes 30  # 30 Minuten Fenster
        
        if (-not $Force -and (($currentTime - $targetTime).Duration() -gt $timeWindow)) {
            Write-Log "Outside daily email time window (06:00 ± 30min). Current time: $($currentTime.ToString('HH:mm:ss'))" -LogFile $LogFile
            return @{
                Success = $false
                Reason = "Outside time window"
                ScheduledTime = "06:00"
                CurrentTime = $currentTime.ToString('HH:mm:ss')
            }
        }
        
        # Lade und filtere Zertifikatsdaten
        $filteredData = Get-FilteredCertificateData -JsonFilePath $JsonFilePath -Config $Config -LogFile $LogFile
        
        # Erstelle E-Mail-Report
        $reportData = New-DailyCertificateEmailReport -FilteredData $filteredData -Config $Config -LogFile $LogFile
        
        # Bestimme E-Mail-Empfänger basierend auf RunMode
        $recipient = if ($Config.RunMode -eq "PROD") { $Config.Mail.ProdTo } else { $Config.Mail.DevTo }
        
        # Sende E-Mail
        $emailParams = @{
            To = $recipient
            From = $Config.Mail.SenderAddress
            Subject = $reportData.Subject
            Body = $reportData.HtmlContent
            BodyAsHtml = $true
            SmtpServer = $Config.Mail.SmtpServer
            Port = $Config.Mail.SmtpPort
            UseSsl = $Config.Mail.UseSsl
        }
        
        if ($Config.Mail.UseSsl -and (Test-Path $Config.Mail.CredentialFilePath)) {
            $credential = Import-Clixml -Path $Config.Mail.CredentialFilePath
            $emailParams.Credential = $credential
        }
        
        Send-MailMessage @emailParams
        
        Write-Log "Daily certificate report sent successfully to: $recipient" -LogFile $LogFile
        Write-Log "Report summary: $($reportData.Summary.Filtered) certificates requiring attention" -LogFile $LogFile
        
        return @{
            Success = $true
            Recipient = $recipient
            Subject = $reportData.Subject
            Summary = $reportData.Summary
            SentAt = $currentTime.ToString('yyyy-MM-dd HH:mm:ss')
        }
        
    } catch {
        Write-Log "Failed to send daily certificate report: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
        throw
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------
Export-ModuleMember -Function @(
    'Save-CertificateDataToJson',
    'Get-FilteredCertificateData',
    'New-DailyCertificateEmailReport',
    'Send-DailyCertificateReport'
)

# --- End of module --- v1.1.0 ; Regelwerk: v9.3.1 ---