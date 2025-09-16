# Test-BlockProcessing-Final.ps1
# Test für die finale blockweise Verarbeitung

# Arbeitsverzeichnis setzen
Set-Location "f:\DEV\repositories\CertSurv"

# Module laden
Import-Module ".\Modules\FL-Config.psm1" -Force
Import-Module ".\Modules\FL-Logging.psm1" -Force
Import-Module ".\Modules\FL-DataProcessing.psm1" -Force
Import-Module ".\Modules\FL-NetworkOperations.psm1" -Force -WarningAction SilentlyContinue

Write-Host "=== TEST: FINALE BLOCKWEISE VERARBEITUNG ===" -ForegroundColor Cyan

# 1. Konfiguration laden
$config = Get-ScriptConfiguration -ConfigPath ".\Config\Config-Cert-Surveillance.json"
$config.MainDomain = "meduniwien.ac.at"
$config.Certificate = @{
    Port = 443
    Timeout = 10
}

Write-Host "Konfiguration geladen:" -ForegroundColor Green
Write-Host "  Excel File: $($config.Excel.FilePath)" -ForegroundColor White
Write-Host "  Main Domain: $($config.MainDomain)" -ForegroundColor White

# 2. Testdaten aus Excel laden (nur erste 20 Server für schnellen Test)
Write-Host "`nLade Excel-Daten..." -ForegroundColor Yellow
$excelData = Import-ExcelData -ExcelFilePath $config.Excel.FilePath -Config $config
$testData = $excelData | Select-Object -First 20

Write-Host "Test-Datenset erstellt:" -ForegroundColor Green
Write-Host "  Gesamt Server im Excel: $($excelData.Count)" -ForegroundColor White
Write-Host "  Test-Server: $($testData.Count)" -ForegroundColor White

# 3. Zeige Block-Übersicht
$domainServers = $testData | Where-Object { $_._IsDomainServer -eq $true }
$workgroupServers = $testData | Where-Object { $_._IsDomainServer -ne $true }
$domainGroups = $domainServers | Group-Object -Property _DomainContext

Write-Host "`nBlock-Struktur der Test-Daten:" -ForegroundColor Yellow
Write-Host "  Domain-Server: $($domainServers.Count)" -ForegroundColor Green
foreach ($group in $domainGroups) {
    $domainName = if ($group.Name) { $group.Name } else { "Unknown" }
    Write-Host "    $domainName`: $($group.Count) Server" -ForegroundColor White
}
Write-Host "  Workgroup-Server: $($workgroupServers.Count)" -ForegroundColor Red

# 4. Test der blockweisen Verarbeitung
Write-Host "`nStarte blockweise Verarbeitung..." -ForegroundColor Yellow

$logFile = ".\LOG\TEST-BlockProcessing-Final.log"

# Mock der Get-RemoteCertificate Funktion für Test
function Get-RemoteCertificate {
    param($ServerName, $Port, $Config, $LogFile)
    Start-Sleep -Milliseconds 100  # Simuliere Verarbeitungszeit
    return @{
        Success = (Get-Random -Maximum 10) -gt 2  # 80% Erfolgsquote
        Subject = "CN=$ServerName"
        Issuer = "CN=Test CA"
        NotAfter = (Get-Date).AddDays(90)
    }
}

try {
    $result = Invoke-NetworkOperations -ServerData $testData -Config $config -LogFile $logFile
    
    Write-Host "`nVERARBEITUNG ABGESCHLOSSEN:" -ForegroundColor Green
    Write-Host "  Success: $($result.Success)" -ForegroundColor White
    Write-Host "  Processed: $($result.ProcessedCount)" -ForegroundColor White
    Write-Host "  Successful: $($result.SuccessfulCount)" -ForegroundColor Green
    Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor Red
    
} catch {
    Write-Host "FEHLER bei der Verarbeitung:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`n=== TEST ABGESCHLOSSEN ===" -ForegroundColor Cyan
