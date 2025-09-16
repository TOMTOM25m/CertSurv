#requires -Version 5.1

# Import modules
Import-Module "f:\DEV\repositories\CertSurv\Modules\FL-DataProcessing.psm1" -Force
Import-Module "f:\DEV\repositories\CertSurv\Modules\FL-Logging.psm1" -Force

Write-Host "=== BLOCKWEISE ZERTIFIKAT-ABFRAGE DEBUG ===" -ForegroundColor Cyan

# Load config
$ConfigPath = "f:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json
$LogFile = "f:\DEV\repositories\CertSurv\LOG\DEBUG_BlockProcessing.log"

try {
    Write-Host "1. Loading Excel data..." -ForegroundColor Yellow
    $importResult = Import-ExcelData -ExcelPath $Config.Excel.ExcelPath -WorksheetName $Config.Excel.SheetName -Config $Config -LogFile $LogFile
    $allServers = $importResult.Data
    
    Write-Host "   Total servers loaded: $($allServers.Count)" -ForegroundColor Green
    
    # Group servers by domain/workgroup
    $domainServers = $allServers | Where-Object { $_._IsDomainServer -eq $true }
    $workgroupServers = $allServers | Where-Object { $_._IsDomainServer -ne $true }
    
    Write-Host "   Domain servers: $($domainServers.Count)" -ForegroundColor Green  
    Write-Host "   Workgroup servers: $($workgroupServers.Count)" -ForegroundColor Green
    
    # Group domain servers by domain
    $uvwServers = $domainServers | Where-Object { $_._DomainContext -eq "UVW" }
    $neuroServers = $domainServers | Where-Object { $_._DomainContext -eq "NEURO" }
    $exServers = $domainServers | Where-Object { $_._DomainContext -eq "EX" }
    $dgmwServers = $domainServers | Where-Object { $_._DomainContext -eq "DGMW" }
    $adServers = $domainServers | Where-Object { $_._DomainContext -eq "AD" }
    $diawinServers = $domainServers | Where-Object { $_._DomainContext -eq "DIAWIN" }
    
    Write-Host "`n2. Domain Block Overview:" -ForegroundColor Yellow
    Write-Host "   UVW Block: $($uvwServers.Count) servers" -ForegroundColor Cyan
    Write-Host "   NEURO Block: $($neuroServers.Count) servers" -ForegroundColor Cyan
    Write-Host "   EX Block: $($exServers.Count) servers" -ForegroundColor Cyan  
    Write-Host "   DGMW Block: $($dgmwServers.Count) servers" -ForegroundColor Cyan
    Write-Host "   AD Block: $($adServers.Count) servers" -ForegroundColor Cyan
    Write-Host "   DIAWIN Block: $($diawinServers.Count) servers" -ForegroundColor Cyan
    
    # Test a few servers from each block
    $testLimit = 3
    
    Write-Host "`n3. Testing UVW Block (first $testLimit servers):" -ForegroundColor Yellow
    $uvwTest = $uvwServers | Select-Object -First $testLimit
    foreach ($server in $uvwTest) {
        Write-Host "   Testing: $($server.ServerName)" -ForegroundColor White
        # Here you would call certificate check
        Start-Sleep -Milliseconds 500
        Write-Host "     Result: [Test placeholder - would check certificate]" -ForegroundColor Gray
    }
    
    Write-Host "`n4. Testing NEURO Block (first $testLimit servers):" -ForegroundColor Yellow
    $neuroTest = $neuroServers | Select-Object -First $testLimit
    foreach ($server in $neuroTest) {
        Write-Host "   Testing: $($server.ServerName)" -ForegroundColor White
        Start-Sleep -Milliseconds 500
        Write-Host "     Result: [Test placeholder - would check certificate]" -ForegroundColor Gray
    }
    
    Write-Host "`n5. Testing EX Block (first $testLimit servers):" -ForegroundColor Yellow
    $exTest = $exServers | Select-Object -First $testLimit
    foreach ($server in $exTest) {
        Write-Host "   Testing: $($server.ServerName)" -ForegroundColor White
        Start-Sleep -Milliseconds 500
        Write-Host "     Result: [Test placeholder - would check certificate]" -ForegroundColor Gray
    }
    
    Write-Host "`n6. Testing Workgroup Block (first $testLimit servers):" -ForegroundColor Yellow
    $workgroupTest = $workgroupServers | Select-Object -First $testLimit
    foreach ($server in $workgroupTest) {
        Write-Host "   Testing: $($server.ServerName)" -ForegroundColor White
        Start-Sleep -Milliseconds 500
        Write-Host "     Result: [Test placeholder - would check certificate]" -ForegroundColor Gray
    }
    
    Write-Host "`n=== BLOCK PROCESSING SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Domain Blocks:" -ForegroundColor Yellow
    Write-Host "  UVW: $($uvwServers.Count) servers" -ForegroundColor White
    Write-Host "  NEURO: $($neuroServers.Count) servers" -ForegroundColor White
    Write-Host "  EX: $($exServers.Count) servers" -ForegroundColor White
    Write-Host "  DGMW: $($dgmwServers.Count) servers" -ForegroundColor White
    Write-Host "  AD: $($adServers.Count) servers" -ForegroundColor White
    Write-Host "  DIAWIN: $($diawinServers.Count) servers" -ForegroundColor White
    Write-Host "Workgroup: $($workgroupServers.Count) servers" -ForegroundColor White
    Write-Host "Total: $($allServers.Count) servers" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host "`nDebug completed!" -ForegroundColor Green
