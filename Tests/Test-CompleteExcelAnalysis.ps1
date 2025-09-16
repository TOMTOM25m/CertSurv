#requires -Version 5.1

<#
.SYNOPSIS
    Vollständige Analyse der Excel-Struktur - alle Blöcke identifizieren
.DESCRIPTION
    Analysiert die komplette Excel-Datei um alle Server-Blöcke zu verstehen
#>

# Set up paths
$ScriptDirectory = "F:\DEV\repositories\CertSurv"

Write-Host "=== VOLLSTÄNDIGE EXCEL-STRUKTUR ANALYSE ===" -ForegroundColor Cyan

try {
    # Import Excel file
    $ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WIndowsServerListe\Serverliste2025FQDN.xlsx"
    $WorksheetName = "Serverliste2025"
    
    Write-Host "`nStep 1: Loading Excel file..." -ForegroundColor Yellow
    $Excel = New-Object -ComObject Excel.Application
    $Excel.Visible = $false
    $Excel.DisplayAlerts = $false
    
    $Workbook = $Excel.Workbooks.Open($ExcelPath)
    $Worksheet = $Workbook.Worksheets.Item($WorksheetName)
    
    $UsedRange = $Worksheet.UsedRange
    $RowCount = $UsedRange.Rows.Count
    
    Write-Host "Total rows: $RowCount" -ForegroundColor Green
    
    Write-Host "`nStep 2: Analyzing complete Excel structure..." -ForegroundColor Yellow
    
    # Track all servers with their positions
    $AllServers = @()
    $CurrentBlock = @{
        StartRow = 2
        Servers = @()
        BlockName = "Unknown"
    }
    
    # Process all rows
    for ($row = 1; $row -le $RowCount; $row++) {
        $cellA = $Worksheet.Cells.Item($row, 1).Text.Trim()
        $cellB = $Worksheet.Cells.Item($row, 2).Text.Trim()
        $cellC = $Worksheet.Cells.Item($row, 3).Text.Trim()
        
        # Skip header row
        if ($row -eq 1) {
            Write-Host "Row $row (Header): ServerName='$cellA', OS_Name='$cellB', FQDN='$cellC'" -ForegroundColor Gray
            continue
        }
        
        # Check if this is a server entry
        if (![string]::IsNullOrWhiteSpace($cellA) -and $cellA -ne "ServerName") {
            $server = @{
                Row = $row
                ServerName = $cellA
                OS_Name = $cellB
                FQDN = $cellC
            }
            
            $AllServers += $server
            $CurrentBlock.Servers += $server
            
            # Show server details
            Write-Host "Row $row`: ServerName='$cellA', OS='$cellB', FQDN='$cellC'" -ForegroundColor White
        }
    }
    
    Write-Host "`nStep 3: Server Analysis Summary..." -ForegroundColor Yellow
    Write-Host "Total servers found: $($AllServers.Count)" -ForegroundColor Green
    
    Write-Host "`nStep 4: Identifying Domain Patterns..." -ForegroundColor Yellow
    
    # Group servers by patterns to identify blocks
    $ServerGroups = @{
        "UVW_Obvious" = @()        # Clear UVW servers
        "NEURO_Block" = @()        # Clear NEURO servers  
        "EX_Block" = @()           # Clear EX servers
        "DGMW_Block" = @()         # Clear DGMW servers
        "AD_Block" = @()           # Clear AD servers
        "DIAWIN_Block" = @()       # Clear DIAWIN servers
        "Unknown_Servers" = @()    # Servers that don't match obvious patterns
    }
    
    foreach ($server in $AllServers) {
        $name = $server.ServerName
        
        # Classify by obvious patterns
        if ($name -match '^UVW' -or $name -match 'uvw') {
            $ServerGroups["UVW_Obvious"] += $server
        }
        elseif ($name -match '^NEURO') {
            $ServerGroups["NEURO_Block"] += $server
        }
        elseif ($name -match '^EX' -and $name -notmatch 'uvwlex') {
            $ServerGroups["EX_Block"] += $server
        }
        elseif ($name -match '^DGMW') {
            $ServerGroups["DGMW_Block"] += $server
        }
        elseif ($name -match '^AD' -or $name -match 'adonis' -or $name -match 'unifl' -or $name -eq 'syncad') {
            $ServerGroups["AD_Block"] += $server
        }
        elseif ($name -match 'diawin' -or $name -match 'winlims' -or $name -match 'winngs') {
            $ServerGroups["DIAWIN_Block"] += $server
        }
        else {
            $ServerGroups["Unknown_Servers"] += $server
        }
    }
    
    Write-Host "`nStep 5: Block Analysis Results..." -ForegroundColor Yellow
    
    foreach ($groupName in $ServerGroups.Keys) {
        $servers = $ServerGroups[$groupName]
        if ($servers.Count -gt 0) {
            Write-Host "`n=== $groupName ($($servers.Count) servers) ===" -ForegroundColor Cyan
            
            # Show row range
            $minRow = ($servers | Measure-Object -Property Row -Minimum).Minimum
            $maxRow = ($servers | Measure-Object -Property Row -Maximum).Maximum
            Write-Host "Row range: $minRow - $maxRow" -ForegroundColor Gray
            
            # Show all servers in this group
            foreach ($server in $servers | Sort-Object Row) {
                Write-Host "  Row $($server.Row): $($server.ServerName)" -ForegroundColor White
            }
        }
    }
    
    Write-Host "`nStep 6: Gap Analysis (Unknown servers between known blocks)..." -ForegroundColor Yellow
    
    # Analyze the unknown servers based on their position relative to known blocks
    foreach ($unknownServer in $ServerGroups["Unknown_Servers"] | Sort-Object Row) {
        $row = $unknownServer.Row
        $name = $unknownServer.ServerName
        
        # Find which known block this server is closest to
        $nearestBlocks = @()
        
        foreach ($groupName in @("UVW_Obvious", "NEURO_Block", "EX_Block", "DGMW_Block", "AD_Block", "DIAWIN_Block")) {
            $groupServers = $ServerGroups[$groupName]
            if ($groupServers.Count -gt 0) {
                $minGroupRow = ($groupServers | Measure-Object -Property Row -Minimum).Minimum
                $maxGroupRow = ($groupServers | Measure-Object -Property Row -Maximum).Maximum
                
                if ($row -ge $minGroupRow -and $row -le $maxGroupRow) {
                    $nearestBlocks += "$groupName (INSIDE: $minGroupRow-$maxGroupRow)"
                }
                elseif ([Math]::Abs($row - $minGroupRow) -le 5 -or [Math]::Abs($row - $maxGroupRow) -le 5) {
                    $nearestBlocks += "$groupName (NEAR: $minGroupRow-$maxGroupRow)"
                }
            }
        }
        
        Write-Host "Row $row`: '$name' -> Likely belongs to: $($nearestBlocks -join ', ')" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($Workbook) { $Workbook.Close($false) }
    if ($Excel) { $Excel.Quit() }
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel) | Out-Null
}

Write-Host "`n=== ANALYSE ABGESCHLOSSEN ===" -ForegroundColor Green
