Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigPath = Join-Path $ScriptDirectory "Config"
$LogPath = Join-Path $ScriptDirectory "LOG"
$ModulesPath = Join-Path $ScriptDirectory "Modules"

try {
    Write-Host "CLIENT SERVER MANAGEMENT TOOL v1.1.0" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Green
    
    Import-Module (Join-Path $ModulesPath "FL-Config.psm1") -Force
    Import-Module (Join-Path $ModulesPath "FL-Logging.psm1") -Force
    Import-Module (Join-Path $ModulesPath "FL-DataProcessing.psm1") -Force

    $ConfigFile = Join-Path $ConfigPath "Config-Cert-Surveillance.json"
    if (-not (Test-Path $ConfigFile)) {
        throw "Konfigurationsdatei nicht gefunden: $ConfigFile"
    }
    
    $Config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
    Write-Host "Konfiguration geladen: $ConfigFile" -ForegroundColor Green
    
    $ProgressFile = Join-Path $LogPath "ClientProgress.json"
    Write-Host "Fortschritts-Datei: $ProgressFile" -ForegroundColor Cyan
    
    Write-Host "Teste Excel-Datenimport..." -ForegroundColor Yellow
    
    $excelResult = Import-ExcelData -ExcelPath $Config.Excel.ExcelPath -WorksheetName $Config.Excel.SheetName -Config $Config -LogFile (Join-Path $LogPath "test.log")
    
    $serverCount = 0
    $servers = @()
    
    foreach ($row in $excelResult.Data) {
        $serverName = $row.$($Config.Excel.ServerNameColumnName)
        if (-not [string]::IsNullOrWhiteSpace($serverName)) {
            $serverCount++
            
            $isDomainServer = $row._IsDomainServer -eq $true
            $domainContext = $row._DomainContext
            
            if ($isDomainServer -and $domainContext) {
                $fqdn = "$($serverName.Trim()).$($domainContext.ToLower()).$($Config.MainDomain)"
                $serverType = "Domain ($domainContext)"
            } else {
                $fqdn = "$($serverName.Trim()).srv.$($Config.MainDomain)"
                $serverType = "Workgroup"
            }
            
            $servers += @{
                Index = $serverCount
                ServerName = $serverName.Trim()
                FQDN = $fqdn
                ServerType = $serverType
                Status = "Pending"
            }
            
            if ($serverCount -le 5) {
                Write-Host "  $serverCount. $($serverName.Trim()) -> $fqdn ($serverType)" -ForegroundColor Cyan
            }
        }
    }
    
    if ($serverCount -gt 5) {
        Write-Host "  ... und $($serverCount - 5) weitere Server" -ForegroundColor Gray
    }
    
    Write-Host "Insgesamt $serverCount Server aus Excel geladen" -ForegroundColor Green
    
    $progressData = @{
        LastUpdated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        TotalServers = $serverCount
        CompletedServers = 0
        FailedServers = 0
        PendingServers = $serverCount
        Servers = $servers
    }
    
    $progressData | ConvertTo-Json -Depth 10 | Set-Content -Path $ProgressFile -Encoding UTF8
    Write-Host "Fortschritt gespeichert: $ProgressFile" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Server-Übersicht:" -ForegroundColor Yellow
    Write-Host "   Gesamt: $serverCount Server" -ForegroundColor White
    Write-Host "   Domain-Server: $(($servers | Where-Object { $_.ServerType -like 'Domain*' }).Count)" -ForegroundColor Cyan
    Write-Host "   Workgroup-Server: $(($servers | Where-Object { $_.ServerType -eq 'Workgroup' }).Count)" -ForegroundColor Cyan
    
} catch {
    Write-Host "Fehler: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

Write-Host "Test abgeschlossen" -ForegroundColor Green