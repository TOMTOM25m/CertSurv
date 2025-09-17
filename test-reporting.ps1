# Quick test of reporting module with sample data
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDirectory "LOG\TEST_Report_$(Get-Date -Format 'yyyy-MM-dd').log"

# Import modules
Import-Module "$ScriptDirectory\Modules\FL-Config.psm1" -Force
Import-Module "$ScriptDirectory\Modules\FL-Logging.psm1" -Force
Import-Module "$ScriptDirectory\Modules\FL-Reporting.psm1" -Force

# Load config
$Config = Get-ScriptConfiguration -ScriptDirectory $ScriptDirectory

# Create sample certificate data
$SampleCertificates = @(
    [PSCustomObject]@{
        ServerName = "TESTSERVER01"
        FQDN = "testserver01.meduniwien.ac.at"
        ServerType = "Domain"
        CertificateSubject = "CN=testserver01.meduniwien.ac.at"
        NotAfter = (Get-Date).AddDays(30)
        DaysRemaining = 30
    },
    [PSCustomObject]@{
        ServerName = "TESTSERVER02"
        FQDN = "testserver02.srv.meduniwien.ac.at"
        ServerType = "SRV"
        CertificateSubject = "CN=testserver02.srv.meduniwien.ac.at"
        NotAfter = (Get-Date).AddDays(7)
        DaysRemaining = 7
    }
)

Write-Host "Testing reporting module with $($SampleCertificates.Count) sample certificates..."

try {
    $reportResult = Invoke-ReportingOperations -Certificates $SampleCertificates -Config $Config -ScriptDirectory $ScriptDirectory -LogFile $LogFile
    Write-Host "SUCCESS: Report generation completed!" -ForegroundColor Green
    Write-Host "Result: $($reportResult | ConvertTo-Json -Depth 2)"
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)"
}