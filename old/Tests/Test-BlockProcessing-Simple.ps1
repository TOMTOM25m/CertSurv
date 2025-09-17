# Test-BlockProcessing-Simple.ps1
# Vereinfachter Test für blockweise Verarbeitung

Set-Location "f:\DEV\repositories\CertSurv"

# Module laden
Import-Module ".\Modules\FL-Config.psm1" -Force
Import-Module ".\Modules\FL-Logging.psm1" -Force  
Import-Module ".\Modules\FL-DataProcessing.psm1" -Force -WarningAction SilentlyContinue
Import-Module ".\Modules\FL-NetworkOperations.psm1" -Force

Write-Host "=== BLOCKWEISE VERARBEITUNG TEST ===" -ForegroundColor Cyan

# Einfache Konfiguration erstellen
$config = @{
    Excel = @{
        FilePath = "f:\DEV\repositories\CertSurv\export-2024_08_29-12_25_01.xlsx"
        ServerNameColumnName = "Name"
    }
    MainDomain = "meduniwien.ac.at"
    Certificate = @{
        Port = 443
        Timeout = 10
    }
}

Write-Host "Konfiguration erstellt" -ForegroundColor Green

# Mock Get-RemoteCertificate für den Test
function Get-RemoteCertificate {
    param($ServerName, $Port, $Config, $LogFile)
    Start-Sleep -Milliseconds 50
    return @{
        Success = (Get-Random -Maximum 10) -gt 1  # 90% Erfolgsquote
        Subject = "CN=$ServerName"
        Issuer = "CN=Test CA"
        NotAfter = (Get-Date).AddDays(90)
    }
}

# Mock-Daten erstellen für Test
Write-Host "Erstelle Mock-Daten..." -ForegroundColor Yellow

$mockServers = @(
    @{ Name = "ZGAAPP01"; _IsDomainServer = $true; _DomainContext = "UVW" },
    @{ Name = "ZGASQL01"; _IsDomainServer = $true; _DomainContext = "UVW" },
    @{ Name = "DAGOBERT"; _IsDomainServer = $true; _DomainContext = "UVW" },
    @{ Name = "MUWDC"; _IsDomainServer = $true; _DomainContext = "UVW" },
    @{ Name = "C-MGMTSRV01"; _IsDomainServer = $true; _DomainContext = "UVW" },
    @{ Name = "NEUROAPP01"; _IsDomainServer = $true; _DomainContext = "NEURO" },
    @{ Name = "EXCH2019"; _IsDomainServer = $true; _DomainContext = "EX" },
    @{ Name = "EXCH2022"; _IsDomainServer = $true; _DomainContext = "EX" },
    @{ Name = "ADSRV01"; _IsDomainServer = $true; _DomainContext = "AD" },
    @{ Name = "ADSRV02"; _IsDomainServer = $true; _DomainContext = "AD" },
    @{ Name = "WORKSTATION01"; _IsDomainServer = $false; _DomainContext = $null },
    @{ Name = "WORKSTATION02"; _IsDomainServer = $false; _DomainContext = $null },
    @{ Name = "STANDALONE01"; _IsDomainServer = $false; _DomainContext = $null }
)

$testData = $mockServers | ForEach-Object { 
    $obj = New-Object PSObject
    $_.GetEnumerator() | ForEach-Object { 
        Add-Member -InputObject $obj -NotePropertyName $_.Key -NotePropertyValue $_.Value 
    }
    $obj
}
if ($testData -and $testData.Count -gt 0) {
    Write-Host "Test mit $($testData.Count) Servern:" -ForegroundColor White
    
    # Zeige Block-Struktur
    $domainServers = $testData | Where-Object { $_._IsDomainServer -eq $true }
    $workgroupServers = $testData | Where-Object { $_._IsDomainServer -ne $true }
    
    Write-Host "  Domain-Server: $($domainServers.Count)" -ForegroundColor Green
    Write-Host "  Workgroup-Server: $($workgroupServers.Count)" -ForegroundColor Yellow
    
    # Starte blockweise Verarbeitung
    $logFile = ".\LOG\TEST-BlockProcessing.log"
    
    try {
        $result = Invoke-NetworkOperations -ServerData $testData -Config $config -LogFile $logFile
        
        Write-Host "`nERGEBNIS:" -ForegroundColor Green
        Write-Host "  Verarbeitet: $($result.ProcessedCount)" -ForegroundColor White
        Write-Host "  Erfolgreich: $($result.SuccessfulCount)" -ForegroundColor Green  
        Write-Host "  Fehlgeschlagen: $($result.FailedCount)" -ForegroundColor Red
        
    } catch {
        Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} else {
    Write-Host "FEHLER: Keine Test-Daten erstellt" -ForegroundColor Red
}

Write-Host "`n=== TEST ABGESCHLOSSEN ===" -ForegroundColor Cyan
