#requires -Version 5.1

<#
.SYNOPSIS
    Test Header Processing für Domain/Workgroup-Klassifizierung
.DESCRIPTION
    Testet die neue Header-Verarbeitung die (Domain|Workgroup|Domain-ADsync|)$Subdomain Format erkennt
#>

# Set up paths
$ScriptDirectory = "F:\DEV\repositories\CertSurv"
$ModulesPath = Join-Path -Path $ScriptDirectory -ChildPath "Modules"

# Import required modules
Import-Module (Join-Path -Path $ModulesPath -ChildPath "FL-Logging.psm1") -Force
Import-Module (Join-Path -Path $ModulesPath -ChildPath "FL-Config.psm1") -Force
Import-Module (Join-Path -Path $ModulesPath -ChildPath "FL-DataProcessing.psm1") -Force

# Load configuration
$ScriptConfig = Get-ScriptConfiguration -ScriptDirectory $ScriptDirectory
$Config = $ScriptConfig.Config

# Set up logging
$logPath = Join-Path -Path $ScriptDirectory -ChildPath "LOG"
$logFile = Join-Path -Path $logPath -ChildPath "TEST_HeaderProcessing_$(Get-Date -Format 'yyyy-MM-dd').log"

Write-Host "Testing Header Processing..." -ForegroundColor Cyan
Write-Host "Log file: $logFile" -ForegroundColor Gray

try {
    # Test Excel import with header context
    Write-Host "`nStep 1: Testing Excel import with header context..." -ForegroundColor Yellow
    $excelResult = Import-ExcelData -ExcelPath $Config.Excel.ExcelPath -WorksheetName $Config.Excel.SheetName -Config $Config -LogFile $logFile
    
    Write-Host "Excel import results:" -ForegroundColor Green
    Write-Host "  - Original rows: $($excelResult.OriginalCount)" -ForegroundColor Gray
    Write-Host "  - Filtered rows: $($excelResult.FilteredCount)" -ForegroundColor Gray
    Write-Host "  - Header context entries: $($excelResult.HeaderContext.Count)" -ForegroundColor Gray
    
    # Check specific servers
    Write-Host "`nStep 2: Checking specific servers..." -ForegroundColor Yellow
    
    $testServers = @("na0fs1bkp", "UVWDC001", "UVWDC002", "UVWDC003")
    
    foreach ($serverName in $testServers) {
        Write-Host "`nChecking server: $serverName" -ForegroundColor Cyan
        
        # Find server in data
        $serverRow = $excelResult.Data | Where-Object { $_.$($Config.Excel.ServerNameColumnName) -eq $serverName }
        
        if ($serverRow) {
            $domainContext = if ($serverRow.PSObject.Properties['_DomainContext']) { $serverRow._DomainContext } else { "Not set" }
            $subdomainContext = if ($serverRow.PSObject.Properties['_SubdomainContext']) { $serverRow._SubdomainContext } else { "Not set" }
            $isDomainServer = if ($serverRow.PSObject.Properties['_IsDomainServer']) { $serverRow._IsDomainServer } else { "Not set" }
            
            Write-Host "  - Found in data: YES" -ForegroundColor Green
            Write-Host "  - Domain Context: $domainContext" -ForegroundColor Gray
            Write-Host "  - Subdomain Context: $subdomainContext" -ForegroundColor Gray
            Write-Host "  - Is Domain Server: $isDomainServer" -ForegroundColor Gray
            
            # Check header context
            $headerInfo = $excelResult.HeaderContext[$serverName]
            if ($headerInfo) {
                Write-Host "  - Header Context: Domain=$($headerInfo.Domain), Subdomain=$($headerInfo.Subdomain), IsDomain=$($headerInfo.IsDomain)" -ForegroundColor Gray
            } else {
                Write-Host "  - Header Context: NOT FOUND" -ForegroundColor Red
            }
        } else {
            Write-Host "  - Found in data: NO" -ForegroundColor Red
        }
    }
    
    # Show some header context entries
    Write-Host "`nStep 3: Sample header context entries..." -ForegroundColor Yellow
    $sampleCount = 0
    foreach ($key in $excelResult.HeaderContext.Keys) {
        if ($sampleCount -ge 5) { break }
        $context = $excelResult.HeaderContext[$key]
        Write-Host "  $key -> Domain: '$($context.Domain)', Subdomain: '$($context.Subdomain)', IsDomain: $($context.IsDomain)" -ForegroundColor Gray
        $sampleCount++
    }
    
    Write-Host "`nHeader processing test completed!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "Test failed: $($_.Exception.Message)" -Level ERROR -LogFile $logFile
}

Write-Host "`nCheck log file for details: $logFile" -ForegroundColor Cyan
