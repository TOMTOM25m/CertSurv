# Simple test script
Import-Module .\Modules\FL-Config.psm1 -Force
Import-Module .\Modules\FL-Logging.psm1 -Force  
Import-Module .\Modules\FL-DataProcessing.psm1 -Force

$config = Get-ConfigFromFile -ConfigPath ".\Config\Config-Cert-Surveillance.json"
$logFile = ".\LOG\TEST_Simple_$(Get-Date -Format 'yyyy-MM-dd').log"

Write-Host "Testing Extract-HeaderContext..." -ForegroundColor Yellow
$headerContext = Extract-HeaderContext -ExcelPath $config.Excel.FilePath -WorksheetName $config.Excel.WorksheetName -HeaderRow $config.Excel.HeaderRow -Config $config -LogFile $logFile

Write-Host "Total servers: $($headerContext.Count)" -ForegroundColor Cyan
$domainCount = ($headerContext.Values | Where-Object { $_.IsDomain }).Count
Write-Host "Domain servers: $domainCount" -ForegroundColor Green

if ($headerContext.ContainsKey("na0fs1bkp")) {
    $na0 = $headerContext["na0fs1bkp"]
    Write-Host "na0fs1bkp -> Domain: $($na0.Domain), Subdomain: $($na0.Subdomain), IsDomain: $($na0.IsDomain)" -ForegroundColor Magenta
} else {
    Write-Host "na0fs1bkp NOT FOUND!" -ForegroundColor Red
}
