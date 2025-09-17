#requires -Version 5.1

Write-Host "=== VOLLSTAENDIGE EXCEL-STRUKTUR ANALYSE ===" -ForegroundColor Cyan

try {
    $ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WIndowsServerListe\Serverliste2025FQDN.xlsx"
    $WorksheetName = "Serverliste2025"
    
    Write-Host "Loading Excel file..." -ForegroundColor Yellow
    $Excel = New-Object -ComObject Excel.Application
    $Excel.Visible = $false
    $Excel.DisplayAlerts = $false
    
    $Workbook = $Excel.Workbooks.Open($ExcelPath)
    $Worksheet = $Workbook.Worksheets.Item($WorksheetName)
    
    $UsedRange = $Worksheet.UsedRange
    $RowCount = $UsedRange.Rows.Count
    
    Write-Host "Total rows: $RowCount" -ForegroundColor Green
    
    # Track all servers
    $AllServers = @()
    
    for ($row = 2; $row -le $RowCount; $row++) {
        $cellA = $Worksheet.Cells.Item($row, 1).Text.Trim()
        $cellB = $Worksheet.Cells.Item($row, 2).Text.Trim()
        $cellC = $Worksheet.Cells.Item($row, 3).Text.Trim()
        
        if (![string]::IsNullOrWhiteSpace($cellA) -and $cellA -ne "ServerName") {
            $server = @{
                Row = $row
                ServerName = $cellA
                OS_Name = $cellB
                FQDN = $cellC
            }
            $AllServers += $server
        }
    }
    
    Write-Host "Found $($AllServers.Count) servers" -ForegroundColor Green
    
    # Group by patterns
    $UVW_Servers = @()
    $NEURO_Servers = @()
    $EX_Servers = @()
    $DGMW_Servers = @()
    $AD_Servers = @()
    $DIAWIN_Servers = @()
    $Unknown_Servers = @()
    
    foreach ($server in $AllServers) {
        $name = $server.ServerName
        
        if ($name -match '^UVW' -or $name -match 'uvw') {
            $UVW_Servers += $server
        }
        elseif ($name -match '^NEURO') {
            $NEURO_Servers += $server
        }
        elseif ($name -match '^EX' -and $name -notmatch 'uvwlex') {
            $EX_Servers += $server
        }
        elseif ($name -match '^DGMW') {
            $DGMW_Servers += $server
        }
        elseif ($name -match '^AD' -or $name -match 'adonis' -or $name -match 'unifl' -or $name -eq 'syncad') {
            $AD_Servers += $server
        }
        elseif ($name -match 'diawin' -or $name -match 'winlims' -or $name -match 'winngs') {
            $DIAWIN_Servers += $server
        }
        else {
            $Unknown_Servers += $server
        }
    }
    
    Write-Host "`n=== UVW BLOCK ===" -ForegroundColor Cyan
    foreach ($server in $UVW_Servers | Sort-Object Row) {
        Write-Host "Row $($server.Row): $($server.ServerName)" -ForegroundColor White
    }
    
    Write-Host "`n=== NEURO BLOCK ===" -ForegroundColor Cyan
    foreach ($server in $NEURO_Servers | Sort-Object Row) {
        Write-Host "Row $($server.Row): $($server.ServerName)" -ForegroundColor White
    }
    
    Write-Host "`n=== EX BLOCK ===" -ForegroundColor Cyan
    foreach ($server in $EX_Servers | Sort-Object Row) {
        Write-Host "Row $($server.Row): $($server.ServerName)" -ForegroundColor White
    }
    
    Write-Host "`n=== DGMW BLOCK ===" -ForegroundColor Cyan
    foreach ($server in $DGMW_Servers | Sort-Object Row) {
        Write-Host "Row $($server.Row): $($server.ServerName)" -ForegroundColor White
    }
    
    Write-Host "`n=== AD BLOCK ===" -ForegroundColor Cyan
    foreach ($server in $AD_Servers | Sort-Object Row) {
        Write-Host "Row $($server.Row): $($server.ServerName)" -ForegroundColor White
    }
    
    Write-Host "`n=== DIAWIN BLOCK ===" -ForegroundColor Cyan
    foreach ($server in $DIAWIN_Servers | Sort-Object Row) {
        Write-Host "Row $($server.Row): $($server.ServerName)" -ForegroundColor White
    }
    
    Write-Host "`n=== UNKNOWN SERVERS (need classification) ===" -ForegroundColor Red
    foreach ($server in $Unknown_Servers | Sort-Object Row) {
        Write-Host "Row $($server.Row): $($server.ServerName)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($Workbook) { $Workbook.Close($false) }
    if ($Excel) { $Excel.Quit() }
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel) | Out-Null
}

Write-Host "`nAnalyse abgeschlossen!" -ForegroundColor Green
