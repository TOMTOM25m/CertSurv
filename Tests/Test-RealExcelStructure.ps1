#requires -Version 5.1

<#
.SYNOPSIS
    Test der KORREKTEN Excel-Struktur mit (Domain)UVW, (Workgroup)SRV etc.
.DESCRIPTION
    Testet die korrekte Erkennung der Gruppenheader wie (Domain)NEURO, (Domain)UVW, (Workgroup)SRV
    und das Ende der Blöcke mit SUMME:
#>

# Set up paths
$ScriptDirectory = "F:\DEV\repositories\CertSurv"
$ModulesPath = Join-Path -Path $ScriptDirectory -ChildPath "Modules"

# Import required modules
Import-Module (Join-Path -Path $ModulesPath -ChildPath "FL-Logging.psm1") -Force
Import-Module (Join-Path -Path $ModulesPath -ChildPath "FL-Config.psm1") -Force

Write-Host "Testing REAL Excel Structure..." -ForegroundColor Cyan

try {
    # Import Excel file and analyze raw structure
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
    
    Write-Host "`nStep 2: Scanning for group headers..." -ForegroundColor Yellow
    
    # First, let's see what's actually in the first 50 rows across all columns
    Write-Host "Sample of first 50 rows (checking all columns A-F):" -ForegroundColor Cyan
    for ($row = 1; $row -le [Math]::Min(50, $RowCount); $row++) {
        $cellA = $Worksheet.Cells.Item($row, 1).Text
        $cellB = $Worksheet.Cells.Item($row, 2).Text
        $cellC = $Worksheet.Cells.Item($row, 3).Text
        $cellD = $Worksheet.Cells.Item($row, 4).Text
        $cellE = $Worksheet.Cells.Item($row, 5).Text
        $cellF = $Worksheet.Cells.Item($row, 6).Text
        
        # Show non-empty rows
        if (![string]::IsNullOrWhiteSpace($cellA) -or ![string]::IsNullOrWhiteSpace($cellB) -or ![string]::IsNullOrWhiteSpace($cellC)) {
            Write-Host "Row $row`: A='$cellA' B='$cellB' C='$cellC' D='$cellD' E='$cellE' F='$cellF'" -ForegroundColor Gray
        }
        
        # Look for patterns that match (Domain)UVW or (Workgroup)SRV in ANY column
        $allCells = @($cellA, $cellB, $cellC, $cellD, $cellE, $cellF)
        foreach ($cell in $allCells) {
            if ($cell -match '\((Domain|Workgroup)\)') {
                Write-Host "*** FOUND PATTERN in row $row`: '$cell'" -ForegroundColor Yellow
            }
            if ($cell -match 'SUMME:') {
                Write-Host "*** FOUND SUMME in row $row`: '$cell'" -ForegroundColor Yellow
            }
        }
    }
    
    # Look for group headers and block structure
    $GroupHeaders = @()
    $CurrentBlock = $null
    $BlockCount = 0
    
    for ($row = 1; $row -le $RowCount; $row++) {
        $cellA = $Worksheet.Cells.Item($row, 1).Text
        $cellB = $Worksheet.Cells.Item($row, 2).Text
        $cellC = $Worksheet.Cells.Item($row, 3).Text
        
        # Check for group headers like (Domain)UVW, (Workgroup)SRV in any of the first 3 columns
        $allCells = @($cellA, $cellB, $cellC)
        $headerFound = $false
        
        foreach ($cell in $allCells) {
            if ($cell -match '\((Domain|Workgroup)\)([A-Z]+)') {
                $HeaderType = $matches[1]
                $Subdomain = $matches[2]
                $BlockCount++
                $headerFound = $true
                
                Write-Host "  Block $BlockCount - Found header: '$cell' -> Type=$HeaderType, Subdomain=$Subdomain" -ForegroundColor Cyan
                
                $CurrentBlock = @{
                    Row = $row
                    HeaderText = $cell
                    HeaderType = $HeaderType
                    Subdomain = $Subdomain
                    Servers = @()
                }
                $GroupHeaders += $CurrentBlock
                break
            }
        }
        
        # Check for block end (SUMME:) in any column
        if ($cellA -match 'SUMME:' -or $cellB -match 'SUMME:' -or $cellC -match 'SUMME:') {
            if ($CurrentBlock) {
                Write-Host "    Block ended at row $row with 'SUMME:' - Found $($CurrentBlock.Servers.Count) servers" -ForegroundColor Green
                $CurrentBlock = $null
            }
        }
        # Check for server entries (non-empty ServerName, and not header rows)
        elseif ($CurrentBlock -and ![string]::IsNullOrWhiteSpace($cellA) -and $cellA -notmatch '^(ServerName|SUMME:|\((Domain|Workgroup)\))' -and !$headerFound) {
            $HeaderType = $matches[1]
            $Subdomain = $matches[2]
            $BlockCount++
            
            Write-Host "  Block $BlockCount - Found header: '$cellA' -> Type=$HeaderType, Subdomain=$Subdomain" -ForegroundColor Cyan
            
            $CurrentBlock = @{
                Row = $row
                HeaderText = $cellA
                HeaderType = $HeaderType
                Subdomain = $Subdomain
                Servers = @()
            }
            $GroupHeaders += $CurrentBlock
        }
        # Check for block end (SUMME:)
        elseif ($cellA -match '^SUMME:' -and $CurrentBlock) {
            Write-Host "    Block ended at row $row with 'SUMME:' - Found $($CurrentBlock.Servers.Count) servers" -ForegroundColor Green
            $CurrentBlock = $null
        }
        # Check for server entries (non-empty ServerName, and not header rows)
        elseif ($CurrentBlock -and ![string]::IsNullOrWhiteSpace($cellA) -and $cellA -notmatch '^(ServerName|SUMME:|\((Domain|Workgroup)\))') {
            $ServerName = $cellA.Trim()
            $OS = $cellB.Trim()
            $FQDN = $cellC.Trim()
            
            if ($ServerName -ne "ServerName" -and $ServerName.Length -gt 1) {
                $CurrentBlock.Servers += @{
                    Row = $row
                    ServerName = $ServerName
                    OS_Name = $OS
                    FQDN = $FQDN
                }
                
                # Show important servers
                if ($ServerName -in @('na0fs1bkp', 'UVWDC001', 'NEURODC01', 'DGMWDC001')) {
                    Write-Host "    *** Important server found: '$ServerName' in $($CurrentBlock.HeaderType) $($CurrentBlock.Subdomain) block" -ForegroundColor Yellow
                }
            }
        }
    }
    
    Write-Host "`nStep 3: Summary of found blocks..." -ForegroundColor Yellow
    
    foreach ($block in $GroupHeaders) {
        Write-Host "Block: $($block.HeaderText)" -ForegroundColor Cyan
        Write-Host "  Type: $($block.HeaderType)" -ForegroundColor White
        Write-Host "  Subdomain: $($block.Subdomain)" -ForegroundColor White
        Write-Host "  Servers: $($block.Servers.Count)" -ForegroundColor White
        
        # Show sample servers
        $sampleServers = $block.Servers | Select-Object -First 3
        foreach ($server in $sampleServers) {
            Write-Host "    - $($server.ServerName)" -ForegroundColor Gray
        }
        if ($block.Servers.Count -gt 3) {
            Write-Host "    ... and $($block.Servers.Count - 3) more" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "Step 4: Checking na0fs1bkp classification..." -ForegroundColor Yellow
    
    $na0fs1bkpBlock = $GroupHeaders | Where-Object { $_.Servers.ServerName -contains 'na0fs1bkp' }
    if ($na0fs1bkpBlock) {
        Write-Host "na0fs1bkp found in block:" -ForegroundColor Green
        Write-Host "  Header: $($na0fs1bkpBlock.HeaderText)" -ForegroundColor White
        Write-Host "  Type: $($na0fs1bkpBlock.HeaderType)" -ForegroundColor White
        Write-Host "  Subdomain: $($na0fs1bkpBlock.Subdomain)" -ForegroundColor White
    } else {
        Write-Host "na0fs1bkp NOT FOUND in any block!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($Workbook) { $Workbook.Close($false) }
    if ($Excel) { $Excel.Quit() }
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel) | Out-Null
}

Write-Host "`nReal Excel structure analysis completed!" -ForegroundColor Green
