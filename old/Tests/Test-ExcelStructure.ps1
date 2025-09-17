#requires -Version 5.1

<#
.SYNOPSIS
    Analysiert die Excel-Struktur um Header-Format zu verstehen
#>

# Set up paths
$ScriptDirectory = "F:\DEV\repositories\CertSurv"
$ModulesPath = Join-Path -Path $ScriptDirectory -ChildPath "Modules"

# Import required modules
Import-Module (Join-Path -Path $ModulesPath -ChildPath "FL-Config.psm1") -Force

# Load configuration
$ScriptConfig = Get-ScriptConfiguration -ScriptDirectory $ScriptDirectory
$Config = $ScriptConfig.Config

Write-Host "Analyzing Excel Structure..." -ForegroundColor Cyan

try {
    # Import raw Excel data to see actual structure
    $rawData = Import-Excel -Path $Config.Excel.ExcelPath -WorksheetName $Config.Excel.SheetName -NoHeader
    
    Write-Host "`nFirst 20 rows of raw Excel data:" -ForegroundColor Yellow
    
    for ($i = 0; $i -lt [Math]::Min(20, $rawData.Count); $i++) {
        $row = $rawData[$i]
        $col1 = if ($row.P1) { $row.P1.ToString().Trim() } else { "[EMPTY]" }
        $col2 = if ($row.P2) { $row.P2.ToString().Trim() } else { "[EMPTY]" }
        $col3 = if ($row.P3) { $row.P3.ToString().Trim() } else { "[EMPTY]" }
        
        Write-Host "Row $($i+1): Col1='$col1' | Col2='$col2' | Col3='$col3'" -ForegroundColor Gray
        
        # Look for potential headers
        if ($col1 -match '\(.*\)' -or $col2 -match '\(.*\)' -or $col3 -match '\(.*\)') {
            Write-Host "  ^^ POTENTIAL HEADER ROW ^^" -ForegroundColor Green
        }
        
        # Look for na0fs1bkp specifically
        if ($col1 -eq "na0fs1bkp" -or $col2 -eq "na0fs1bkp" -or $col3 -eq "na0fs1bkp") {
            Write-Host "  ^^ FOUND na0fs1bkp ^^" -ForegroundColor Red
            break
        }
    }
    
    # Also look for UVW patterns
    Write-Host "`nSearching for UVW patterns in first 50 rows:" -ForegroundColor Yellow
    
    for ($i = 0; $i -lt [Math]::Min(50, $rawData.Count); $i++) {
        $row = $rawData[$i]
        $col1 = if ($row.P1) { $row.P1.ToString() } else { "" }
        $col2 = if ($row.P2) { $row.P2.ToString() } else { "" }
        $col3 = if ($row.P3) { $row.P3.ToString() } else { "" }
        
        if ($col1 -match 'UVW|Domain.*UVW|Workgroup.*UVW|\(.*UVW.*\)' -or 
            $col2 -match 'UVW|Domain.*UVW|Workgroup.*UVW|\(.*UVW.*\)' -or 
            $col3 -match 'UVW|Domain.*UVW|Workgroup.*UVW|\(.*UVW.*\)') {
            Write-Host "Row $($i+1): Found UVW pattern - Col1='$col1' | Col2='$col2' | Col3='$col3'" -ForegroundColor Green
        }
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nExcel structure analysis completed!" -ForegroundColor Cyan
