# Test script for Excel header processing
param(
    [string]$LogLevel = "DEBUG"
)

# Import required modules
$modules = @(
    ".\Modules\FL-Config.psm1",
    ".\Modules\FL-Logging.psm1", 
    ".\Modules\FL-DataProcessing.psm1"
)

foreach ($module in $modules) {
    if (Test-Path $module) {
        Import-Module $module -Force
        Write-Host "✓ Imported: $module" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing: $module" -ForegroundColor Red
        exit 1
    }
}

# Load configuration
$configPath = ".\Config\Config-Cert-Surveillance.json"
if (-not (Test-Path $configPath)) {
    Write-Host "✗ Configuration file not found: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-ConfigFromFile -ConfigPath $configPath
Write-Host "✓ Configuration loaded" -ForegroundColor Green

# Create log file
$logFile = ".\LOG\TEST_Header-Processing_$(Get-Date -Format 'yyyy-MM-dd').log"
New-Item -Path $logFile -ItemType File -Force | Out-Null

Write-Log "=== Testing Extract-HeaderContext Function ===" -LogFile $logFile
Write-Log "Test started: $(Get-Date)" -LogFile $logFile
Write-Log "Log Level: $LogLevel" -LogFile $logFile

# Test Excel path
$excelPath = $config.Excel.FilePath
if (-not (Test-Path $excelPath)) {
    Write-Log "ERROR: Excel file not found: $excelPath" -LogFile $logFile
    Write-Host "✗ Excel file not found: $excelPath" -ForegroundColor Red
    exit 1
}

Write-Log "Excel file found: $excelPath" -LogFile $logFile
Write-Host "✓ Excel file: $excelPath" -ForegroundColor Green

try {
    # Test the Extract-HeaderContext function
    Write-Host "`n--- Testing Extract-HeaderContext ---" -ForegroundColor Yellow
    Write-Log "Calling Extract-HeaderContext function..." -LogFile $logFile
    
    $headerContext = Extract-HeaderContext -ExcelPath $excelPath -WorksheetName $config.Excel.WorksheetName -HeaderRow $config.Excel.HeaderRow -Config $config -LogFile $logFile
    
    Write-Host "✓ Extract-HeaderContext completed successfully" -ForegroundColor Green
    Write-Log "Extract-HeaderContext function completed successfully" -LogFile $logFile
    
    # Analyze results
    Write-Host "`n--- Results Analysis ---" -ForegroundColor Yellow
    Write-Host "Total servers processed: $($headerContext.Count)" -ForegroundColor Cyan
    
    $domainServers = @($headerContext.Values | Where-Object { $_.IsDomain })
    $workgroupServers = @($headerContext.Values | Where-Object { -not $_.IsDomain })
    
    Write-Host "Domain servers: $($domainServers.Count)" -ForegroundColor Green
    Write-Host "Workgroup servers: $($workgroupServers.Count)" -ForegroundColor Yellow
    
    # Show first few domain servers
    if ($domainServers.Count -gt 0) {
        Write-Host "`nFirst 5 Domain servers:" -ForegroundColor Green
        $domainServers | Select-Object -First 5 | ForEach-Object {
            $serverName = ($headerContext.GetEnumerator() | Where-Object { $_.Value -eq $_ }).Key
            Write-Host "  $serverName -> Domain: $($_.Domain), Subdomain: $($_.Subdomain), Block: $($_.BlockNumber)" -ForegroundColor Green
        }
    }
    
    # Check specific server na0fs1bkp
    if ($headerContext.ContainsKey("na0fs1bkp")) {
        $na0Context = $headerContext["na0fs1bkp"]
        Write-Host "`nSpecific check - na0fs1bkp:" -ForegroundColor Magenta
        Write-Host "  Domain: $($na0Context.Domain)" -ForegroundColor Cyan
        Write-Host "  Subdomain: $($na0Context.Subdomain)" -ForegroundColor Cyan
        Write-Host "  IsDomain: $($na0Context.IsDomain)" -ForegroundColor Cyan
        Write-Host "  Block: $($na0Context.BlockNumber)" -ForegroundColor Cyan
        
        Write-Log "na0fs1bkp classification: Domain=$($na0Context.Domain), Subdomain=$($na0Context.Subdomain), IsDomain=$($na0Context.IsDomain), Block=$($na0Context.BlockNumber)" -LogFile $logFile
    } else {
        Write-Host "`nWARNING: na0fs1bkp not found in results!" -ForegroundColor Red
        Write-Log "WARNING: na0fs1bkp not found in header context results" -LogFile $logFile
    }
    
} catch {
    Write-Host "✗ Error during testing: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "ERROR: $($_.Exception.Message)" -LogFile $logFile
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -LogFile $logFile
    exit 1
}

Write-Log "Test completed: $(Get-Date)" -LogFile $logFile
Write-Host "`n✓ Test completed successfully. Check log: $logFile" -ForegroundColor Green
