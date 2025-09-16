#requires -Version 5.1

# Import the module  
Import-Module "f:\DEV\repositories\CertSurv\Modules\FL-DataProcessing.psm1" -Force

Write-Host "=== DEBUG IMPORT RESULT ===" -ForegroundColor Cyan

# Load config from JSON file
$ConfigPath = "f:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

$LogFile = "f:\DEV\repositories\CertSurv\LOG\TEST_Debug_Import.log"

try {
    Write-Host "Processing Excel file..." -ForegroundColor Yellow
    $result = Import-ExcelData -ExcelPath $Config.Excel.ExcelPath -WorksheetName $Config.Excel.SheetName -Config $Config -LogFile $LogFile
    
    Write-Host "Result type: $($result.GetType().Name)" -ForegroundColor Green
    Write-Host "Result count: $($result.Count)" -ForegroundColor Green
    
    if ($result.Count -gt 0) {
        Write-Host "First result properties:" -ForegroundColor Yellow
        $result[0] | Get-Member | Where-Object MemberType -eq NoteProperty | ForEach-Object {
            Write-Host "  $($_.Name)" -ForegroundColor White
        }
        
        Write-Host "First 10 results:" -ForegroundColor Yellow
        for ($i = 0; $i -lt [Math]::Min(10, $result.Count); $i++) {
            Write-Host "  [$i] $($result[$i].ServerName) -> Domain=$($result[$i].Domain)" -ForegroundColor White
        }
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Debug complete!" -ForegroundColor Cyan
