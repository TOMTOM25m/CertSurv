#requires -Version 5.1

# Import the module
Import-Module "f:\DEV\repositories\CertSurv\Modules\FL-DataProcessing.psm1" -Force

Write-Host "=== TEST ERWEITERTE UVW-KLASSIFIZIERUNG ===" -ForegroundColor Cyan

# Test the specific servers that should be UVW
$testServers = @(
    "ZGAAPP01",
    "ZGASQL01", 
    "DAGOBERT",
    "MUWDC",
    "uvwlex01",
    "C-SQL01",
    "C-APP01",
    "C-LIC01",
    "COORAPPTEST01",
    "COORAPPPROD01",
    "SUCCESSXPROD01",
    "proman"
)

Write-Host "Testing server classification:" -ForegroundColor Yellow

foreach ($server in $testServers) {
    try {
        $result = Test-ServerDomainClassification -ServerName $server
        if ($result.Domain -eq "UVW") {
            Write-Host "OK $server -> UVW (correct)" -ForegroundColor Green
        } else {
            Write-Host "NO $server -> $($result.Domain) (should be UVW)" -ForegroundColor Red
        }
    } catch {
        Write-Host "ER $server -> ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Testing complete!" -ForegroundColor Cyan
