#requires -Version 5.1

# Import the module  
Import-Module "f:\DEV\repositories\CertSurv\Modules\FL-DataProcessing.psm1" -Force

Write-Host "=== FULL UVW CLASSIFICATION TEST ===" -ForegroundColor Cyan

# Load config from JSON file
$ConfigPath = "f:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

$LogFile = "f:\DEV\repositories\CertSurv\LOG\TEST_UVW_Classification.log"

try {
    Write-Host "Processing Excel file..." -ForegroundColor Yellow
    $importResult = Import-ExcelData -ExcelPath $Config.Excel.ExcelPath -WorksheetName $Config.Excel.SheetName -Config $Config -LogFile $LogFile
    $result = $importResult.Data
    
    Write-Host "Total servers: $($result.Count)" -ForegroundColor Green
    
    # Check specific UVW servers
    $targetServers = @("ZGAAPP01", "ZGASQL01", "DAGOBERT", "MUWDC", "C-SQL01", "C-APP01", "COORAPPPROD01")
    
    Write-Host "`nChecking UVW classification:" -ForegroundColor Yellow
    
    foreach ($targetServer in $targetServers) {
        $server = $result | Where-Object { $_.ServerName -eq $targetServer }
        if ($server) {
            $domain = if ($server._DomainContext) { $server._DomainContext } else { "Workgroup" }
            if ($domain -eq "UVW") {
                Write-Host "OK $targetServer -> Domain: $domain" -ForegroundColor Green
            } else {
                Write-Host "NO $targetServer -> Domain: $domain (should be UVW)" -ForegroundColor Red
            }
        } else {
            Write-Host "?? $targetServer -> NOT FOUND in Excel" -ForegroundColor Yellow
        }
    }
    
    # Show all UVW classified servers
    $uvwServers = $result | Where-Object { $_._DomainContext -eq "UVW" } | Sort-Object ServerName
    Write-Host "`nAll UVW classified servers ($($uvwServers.Count)):" -ForegroundColor Cyan
    foreach ($uvwServer in $uvwServers) {
        Write-Host "  $($uvwServer.ServerName)" -ForegroundColor White
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest complete!" -ForegroundColor Cyan
