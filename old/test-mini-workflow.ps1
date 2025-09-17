# Test with smaller server set - first 10 domain servers only
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDirectory "LOG\TEST_Mini_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"

# Import modules
Import-Module "$ScriptDirectory\Modules\FL-Config.psm1" -Force
Import-Module "$ScriptDirectory\Modules\FL-Logging.psm1" -Force
Import-Module "$ScriptDirectory\Modules\FL-DataProcessing.psm1" -Force
Import-Module "$ScriptDirectory\Modules\FL-NetworkOperations.psm1" -Force
Import-Module "$ScriptDirectory\Modules\FL-Security.psm1" -Force
Import-Module "$ScriptDirectory\Modules\FL-Reporting.psm1" -Force

# Load config
$Config = Get-ScriptConfiguration -ScriptDirectory $ScriptDirectory

Write-Host "Starting MINI certificate surveillance test..."

try {
    # Import Excel data
    $excelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WIndowsServerListe\Serverliste2025FQDN.xlsx"
    $worksheetName = "Serverliste2025"
    $originalData = Import-ExcelData -ExcelPath $excelPath -WorksheetName $worksheetName -Config $Config -LogFile $LogFile
    
    # Take only first 10 servers for quick test
    $testData = $originalData | Select-Object -First 10
    Write-Host "Testing with $($testData.Count) servers..." -ForegroundColor Cyan
    
    # Process network operations
    $networkResult = Invoke-NetworkOperations -ServerData $testData -Config $Config -LogFile $LogFile
    
    if ($networkResult.Results) {
        Write-Host "Network operations completed - found results for $($networkResult.Results.Count) servers" -ForegroundColor Green
        
        # Perform certificate operations
        $certResult = Invoke-CertificateOperations -NetworkResults $networkResult.Results -Config $Config -LogFile $LogFile
        
        if ($certResult.Certificates) {
            Write-Host "Certificate operations completed - found $($certResult.Certificates.Count) certificates" -ForegroundColor Green
            
            # Generate reports
            $reportResult = Invoke-ReportingOperations -Certificates $certResult.Certificates -Config $Config -ScriptDirectory $ScriptDirectory -LogFile $LogFile
            
            Write-Host "SUCCESS: Full workflow completed!" -ForegroundColor Green
            Write-Host "Report saved to: $($reportResult.ReportPath)" -ForegroundColor Yellow
        }
        else {
            Write-Host "WARNING: No certificates found" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "WARNING: No network results found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)"
}