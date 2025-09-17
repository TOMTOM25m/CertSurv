#requires -Version 5.1

<#
.SYNOPSIS
    [DE] FL-DataProcessing Modul - Excel und Datenverarbeitungsoperationen
    [EN] FL-DataProcessing Module - Excel and data processing operations
.DESCRIPTION
    [DE] Behandelt alle Excel-Dateioperationen, Datenimport/-export und Datenverarbeitungsaufgaben
    [EN] Handles all Excel file operations, data import/export, and data processing tasks
.AUTHOR
    System Administrator
.VERSION
    v1.0.0
.RULEBOOK
    v9.3.0
#>

$ModuleName = "FL-DataProcessing"
$ModuleVersion = "v1.1.0"

#----------------------------------------------------------[Functions]----------------------------------------------------------

<#
.SYNOPSIS
    [DE] Importiert Excel-Daten mit intelligenter Header-Erkennung und Durchstreichungsfilterung
    [EN] Imports Excel data with intelligent header detection and strikethrough filtering
.DESCRIPTION
    [DE] Liest Excel-Daten, erkennt automatisch die Header-Zeile, filtert durchgestrichene Einträge
    [EN] Reads Excel data, automatically detects header row, filters out strikethrough entries
#>
function Import-ExcelData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExcelPath,
        
        [Parameter(Mandatory = $true)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Starting Excel data import from: $ExcelPath" -LogFile $LogFile
    
    # Validate file exists
    if (-not (Test-Path $ExcelPath)) {
        throw "Excel file not found: $ExcelPath"
    }
    
    # Check available worksheets and pick a safe worksheet name
    try {
        $worksheets = Get-ExcelSheetInfo -Path $ExcelPath
        $availableSheets = $worksheets | ForEach-Object { $_.Name }
        Write-Log "Available worksheets: $($availableSheets -join ', ')" -LogFile $LogFile

        $selectedSheet = $WorksheetName

        # Prefer exact (case-insensitive) match
        if ($availableSheets -notcontains $WorksheetName) {
            $ciMatch = $availableSheets | Where-Object { $_.ToString().Trim() -ieq $WorksheetName }
            if ($ciMatch) {
                $selectedSheet = $ciMatch[0]
            }
            else {
                # Try partial match (starts-with or contains)
                $partial = $availableSheets | Where-Object { $_.ToString() -ilike "$WorksheetName*" } |
                           Select-Object -First 1
                if (-not $partial) {
                    $partial = $availableSheets | Where-Object { $_.ToString() -imatch [regex]::Escape($WorksheetName) } |
                               Select-Object -First 1
                }
                if ($partial) {
                    $selectedSheet = $partial
                    Write-Log "Configured sheet '$WorksheetName' not found. Using closest match: '$selectedSheet'" -Level WARN -LogFile $LogFile
                }
                elseif ($availableSheets -and $availableSheets.Count -eq 1) {
                    $selectedSheet = $availableSheets[0]
                    Write-Log "Configured sheet '$WorksheetName' not found. Using only available sheet: '$selectedSheet'" -Level WARN -LogFile $LogFile
                }
                else {
                    Write-Log "Worksheet '$WorksheetName' not found. Available: $($availableSheets -join ', ')" -Level WARN -LogFile $LogFile
                }
            }
        }

        $WorksheetName = $selectedSheet
        Write-Log "Using worksheet: $WorksheetName" -LogFile $LogFile
    }
    catch {
        Write-Log "Could not enumerate worksheets, proceeding with configured sheet..." -Level WARN -LogFile $LogFile
    }
    
    # Intelligent header detection
    $excelData = $null
    $headerRowFound = $Config.Excel.HeaderRow
    $hasServerNameColumn = $false
    $hasFqdnColumn = $false
    
    for ($testRow = 1; $testRow -le 5; $testRow++) {
        try {
            Write-Log "Testing header row $testRow..." -LogFile $LogFile
            $testData = Import-Excel -Path $ExcelPath -WorksheetName $WorksheetName -HeaderRow $testRow -ErrorAction Stop
            
            if ($testData -and $testData.Count -gt 0) {
                $sampleRow = $testData[0]
                $columnNames = $sampleRow.PSObject.Properties.Name
                $hasServerNameColumn = ($columnNames -contains $Config.Excel.ServerNameColumnName)
                $hasFqdnColumn = ($columnNames -contains $Config.Excel.FqdnColumnName)

                if ($hasServerNameColumn -or $hasFqdnColumn) {
                    $excelData = $testData
                    $headerRowFound = $testRow
                    $reason = if ($hasServerNameColumn) { "'$($Config.Excel.ServerNameColumnName)'" } else { "'$($Config.Excel.FqdnColumnName)'" }
                    Write-Log "Detected valid header row $testRow based on column $reason" -LogFile $LogFile
                    break
                }
            }
        }
        catch {
            Write-Log "Header row $testRow failed: $($_.Exception.Message)" -Level WARN -LogFile $LogFile
            continue
        }
    }
    
    if (-not $excelData) {
        throw "Could not find valid header row with column '$($Config.Excel.ServerNameColumnName)' or '$($Config.Excel.FqdnColumnName)'"
    }
    
    Write-Log "Imported $($excelData.Count) rows using header row $headerRowFound" -LogFile $LogFile

    # Backfill ServerName from FQDN if missing
    if (-not $hasServerNameColumn -and $hasFqdnColumn -and $excelData.Count -gt 0) {
        Write-Log "ServerName column '$($Config.Excel.ServerNameColumnName)' not found; deriving from FQDN column '$($Config.Excel.FqdnColumnName)'" -Level WARN -LogFile $LogFile
        foreach ($row in $excelData) {
            $fqdnVal = $row.($Config.Excel.FqdnColumnName)
            $derived = if ([string]::IsNullOrWhiteSpace($fqdnVal)) { $null } else { ($fqdnVal -split '\.')[0] }
            if ($null -ne $row.PSObject.Properties[$Config.Excel.ServerNameColumnName]) {
                $row.PSObject.Properties[$Config.Excel.ServerNameColumnName].Value = $derived
            } else {
                Add-Member -InputObject $row -NotePropertyName $Config.Excel.ServerNameColumnName -NotePropertyValue $derived -Force
            }
        }
    }
    
    # Extract header context information
    Write-Log "Extracting header context from Excel file..." -LogFile $LogFile
    $headerContext = Extract-HeaderContext -ExcelPath $ExcelPath -WorksheetName $WorksheetName -HeaderRow $headerRowFound -Config $Config -LogFile $LogFile
    
    # Filter strikethrough entries
    $filteredData = Remove-StrikethroughServers -ExcelData $excelData -ExcelPath $ExcelPath -WorksheetName $WorksheetName -HeaderRow $headerRowFound -Config $Config -LogFile $LogFile
    
    # Apply header context to filtered data
    $enrichedData = Apply-HeaderContext -ServerData $filteredData -HeaderContext $headerContext -Config $Config -LogFile $LogFile
    
    # Apply test mode filter if enabled
    if ($Config.Certificate.TestMode.Enabled) {
        $enrichedData = Apply-TestModeFilter -ServerData $enrichedData -Config $Config -LogFile $LogFile
    }
    
    return @{
        Data = $enrichedData
        HeaderRow = $headerRowFound
        OriginalCount = $excelData.Count
        FilteredCount = $enrichedData.Count
        HeaderContext = $headerContext
    }
}

<#
.SYNOPSIS
    [DE] Entfernt Server mit Durchstreichungsformatierung
    [EN] Filters out servers with strikethrough formatting
.DESCRIPTION
    [DE] Verwendet Excel COM-Objekte um durchgestrichene Server-Einträge zu erkennen und zu filtern
    [EN] Uses Excel COM objects to detect and filter strikethrough server entries
#>
function Remove-StrikethroughServers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$ExcelData,
        
        [Parameter(Mandatory = $true)]
        [string]$ExcelPath,
        
        [Parameter(Mandatory = $true)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $true)]
        [int]$HeaderRow,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Checking for strikethrough formatting..." -LogFile $LogFile
    
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $workbook = $excel.Workbooks.Open($ExcelPath)
        $worksheet = $workbook.Worksheets.Item($WorksheetName)
        
        # Find server name column
        $serverColumnNumber = 1
        for ($col = 1; $col -le $worksheet.UsedRange.Columns.Count; $col++) {
            $headerCell = $worksheet.Cells.Item($HeaderRow, $col)
            if ($headerCell.Text -eq $Config.Excel.ServerNameColumnName) {
                $serverColumnNumber = $col
                break
            }
        }
        
        # Check strikethrough for all rows
        $strikethroughRows = @{}
        $startRow = $HeaderRow + 1
        $endRow = $startRow + $ExcelData.Count - 1
        
        for ($rowNum = $startRow; $rowNum -le $endRow; $rowNum++) {
            $cell = $worksheet.Cells.Item($rowNum, $serverColumnNumber)
            $strikethroughRows[$rowNum] = $cell.Font.Strikethrough
        }
        
        # Cleanup COM objects
        $workbook.Close($false)
        $excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($worksheet) | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        
        Write-Log "Retrieved formatting info for $($strikethroughRows.Count) rows" -LogFile $LogFile
    }
    catch {
        Write-Log "Could not check formatting: $($_.Exception.Message)" -Level WARN -LogFile $LogFile
        return $ExcelData  # Return original data if formatting check fails
    }
    
    # Filter data
    $filteredData = @()
    $skippedCount = 0
    
    for ($i = 0; $i -lt $ExcelData.Count; $i++) {
        $row = $ExcelData[$i]
        $serverName = $row.$($Config.Excel.ServerNameColumnName)
        $excelRowNumber = $HeaderRow + 1 + $i
        
        if ([string]::IsNullOrWhiteSpace($serverName)) { continue }
        
        if ($strikethroughRows.ContainsKey($excelRowNumber) -and $strikethroughRows[$excelRowNumber]) {
            Write-Log "Skipping strikethrough server: $serverName (Row $excelRowNumber)" -LogFile $LogFile
            $skippedCount++
        } else {
            $filteredData += $row
        }
    }
    
    Write-Log "Filtered data: $($filteredData.Count) active rows (skipped $skippedCount)" -LogFile $LogFile
    return $filteredData
}

<#
.SYNOPSIS
    [DE] Extrahiert Header-Kontext aus Excel-Datei für Domain/Workgroup-Klassifizierung
    [EN] Extracts header context from Excel file for domain/workgroup classification
.DESCRIPTION
    [DE] Scannt die Excel-Datei nach Header-Zeilen, die Domain-Informationen enthalten
    [EN] Scans the Excel file for header rows containing domain information
#>
function Extract-HeaderContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExcelPath,
        
        [Parameter(Mandatory = $true)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $true)]
        [int]$HeaderRow,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Analyzing server names for domain classification (no Excel headers found)..." -LogFile $LogFile
    
    try {
        # Import server data with proper headers
        $serverData = Import-Excel -Path $ExcelPath -WorksheetName $WorksheetName -HeaderRow $HeaderRow -ErrorAction Stop
        
        # Define domain classification rules based on server name patterns
        $domainRules = @{
            "UVW" = @{
                "Patterns" = @(
                    "UVW*",           # UVW-FINANZ01, UVW-FINANZ02, UVWDC001, etc.
                    "*uvw*",          # UVWmgmt01, etc.
                    "na0fs1bkp",      # Special case: na0fs1bkp belongs to UVW
                    "ZGA*",           # ZGAAPP01, ZGASQL01 belong to UVW block
                    "DAGOBERT",       # DAGOBERT belongs to UVW block  
                    "MUWDC",          # MUWDC belongs to UVW block
                    "uvwlex01",       # uvwlex01 belongs to UVW (not EX despite "ex" in name)
                    "C-*",            # C-SQL01, C-APP01, C-APP02, C-LIC01, C-LIC02, C-FS01
                    "COOR*",          # COORAPPPROD01, COORAPPTEST01
                    "SUCCESSXPROD01", # Based on Excel analysis
                    "proman"          # Based on Excel analysis
                )
                "Type" = "Domain"
            }
            "NEURO" = @{
                "Patterns" = @("NEURO*", "*neuro*")
                "Type" = "Domain"
            }
            "EX" = @{
                "Patterns" = @("EX*", "veeam-ex-bkp", "webexconnector*")  # Removed "*ex*" to prevent uvwlex01 mismatch
                "Type" = "Domain"
            }
            "DGMW" = @{
                "Patterns" = @("DGMW*", "*dgmw*")
                "Type" = "Domain"
            }
            "AD" = @{
                "Patterns" = @("ADDC*", "*ad*", "syncad", "DCSYNC*", "*unifl*")
                "Type" = "Domain"
            }
            "DIAWIN" = @{
                "Patterns" = @("diawin*", "winlims*", "winngs*")
                "Type" = "Domain"
            }
        }
        
        $headerContext = @{}
        
        Write-Log "Classifying $($serverData.Count) servers using name-based domain rules..." -LogFile $LogFile
        
        foreach ($row in $serverData) {
            $serverName = $row.$($Config.Excel.ServerNameColumnName)
            if ([string]::IsNullOrWhiteSpace($serverName)) { continue }
            
            # Apply classification rules
            $classified = $false
            $assignedDomain = "SRV"
            $assignedType = "Workgroup"
            
            foreach ($domain in $domainRules.Keys) {
                foreach ($pattern in $domainRules[$domain].Patterns) {
                    if ($serverName -like $pattern) {
                        $assignedDomain = $domain
                        $assignedType = $domainRules[$domain].Type
                        $classified = $true
                        
                        # Log important servers
                        if ($serverName -eq "na0fs1bkp" -or $serverName -like "*UVW*" -or $serverName -like "*NEURO*") {
                            Write-Log "  Important server '$serverName' classified: Pattern='$pattern', Domain=$assignedDomain, Type=$assignedType" -LogFile $LogFile
                        }
                        break
                    }
                }
                if ($classified) { break }
            }
            
            $headerContext[$serverName] = @{
                Domain = if ($assignedType -eq "Domain") { $assignedDomain } else { "" }
                Subdomain = $assignedDomain
                IsDomain = ($assignedType -eq "Domain")
                RowNumber = $headerContext.Count + 1
            }
        }
        
        Write-Log "Header context extracted: $($headerContext.Count) servers mapped" -LogFile $LogFile
        $domainServers = ($headerContext.Values | Where-Object { $_.IsDomain }).Count
        $workgroupServers = $headerContext.Count - $domainServers
        Write-Log "  - Domain servers: $domainServers" -LogFile $LogFile
        Write-Log "  - Workgroup servers: $workgroupServers" -LogFile $LogFile
        
        return $headerContext
    }
    catch {
        Write-Log "Could not extract header context: $($_.Exception.Message)" -Level WARN -LogFile $LogFile
        return @{}
    }
}

<#
.SYNOPSIS
    [DE] Wendet Header-Kontext auf Server-Daten an
    [EN] Applies header context to server data
.DESCRIPTION
    [DE] Fügt Domain/Workgroup-Informationen zu den Server-Daten hinzu
    [EN] Adds domain/workgroup information to server data
#>
function Apply-HeaderContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$ServerData,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$HeaderContext,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Applying header context to server data..." -LogFile $LogFile
    
    $enrichedData = @()
    $domainCount = 0
    $workgroupCount = 0
    
    foreach ($row in $ServerData) {
        $serverName = $row.($Config.Excel.ServerNameColumnName)
        
        if ([string]::IsNullOrWhiteSpace($serverName)) { continue }
        
        # Look up context for this server
        $context = $HeaderContext[$serverName.Trim()]
        
        if ($context) {
            # Add context properties to the row
            Add-Member -InputObject $row -NotePropertyName "_DomainContext" -NotePropertyValue $context.Domain -Force
            Add-Member -InputObject $row -NotePropertyName "_SubdomainContext" -NotePropertyValue $context.Subdomain -Force
            Add-Member -InputObject $row -NotePropertyName "_IsDomainServer" -NotePropertyValue $context.IsDomain -Force
            
            # CRITICAL: Add HeaderType property for compatibility with FL-NetworkOperations
            $headerType = if ($context.IsDomain) { "Domain" } else { "Workgroup" }
            Add-Member -InputObject $row -NotePropertyName "HeaderType" -NotePropertyValue $headerType -Force
            
            if ($context.IsDomain) {
                $domainCount++
                Write-Log "Server '$serverName' marked as domain server (Domain: $($context.Domain))" -LogFile $LogFile
            } else {
                $workgroupCount++
                Write-Log "Server '$serverName' marked as workgroup server" -LogFile $LogFile
            }
        } else {
            # Default to workgroup if no context found
            Add-Member -InputObject $row -NotePropertyName "_DomainContext" -NotePropertyValue "" -Force
            Add-Member -InputObject $row -NotePropertyName "_SubdomainContext" -NotePropertyValue "" -Force
            Add-Member -InputObject $row -NotePropertyName "_IsDomainServer" -NotePropertyValue $false -Force
            
            # CRITICAL: Add HeaderType property for compatibility with FL-NetworkOperations
            Add-Member -InputObject $row -NotePropertyName "HeaderType" -NotePropertyValue "Workgroup" -Force
            $workgroupCount++
            Write-Log "Server '$serverName' marked as workgroup server (no context found)" -LogFile $LogFile
        }
        
        $enrichedData += $row
    }
    
    Write-Log "Header context applied: $domainCount domain servers, $workgroupCount workgroup servers" -LogFile $LogFile
    return $enrichedData
}

<#
.SYNOPSIS
    [DE] Exportiert Serverdaten zurück in Excel-Datei mit Zertifikatsinformationen
    [EN] Exports server data back to Excel file with certificate information
.DESCRIPTION
    [DE] Schreibt die verarbeiteten Serverdaten mit Zertifikatsinformationen zurück in die Excel-Datei
    [EN] Writes processed server data with certificate information back to Excel file
#>
function Export-ExcelData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$ServerData,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Exporting enhanced server data to: $OutputPath" -LogFile $LogFile
    
    try {
        # Prepare data for export
        $exportData = @()
        
        foreach ($server in $ServerData) {
            $exportRow = [PSCustomObject]@{
                ServerName = $server.$($Config.Excel.ServerNameColumnName)
                FQDN_Used = if ($server.FQDN_Used) { $server.FQDN_Used } else { "Not processed" }
                CertificateStatus = if ($server.CertificateStatus) { $server.CertificateStatus } else { "No certificate" }
                DomainContext = if ($server._DomainContext) { $server._DomainContext } else { "SRV/Workgroup" }
                ServerType = if ($server._IsDomainServer -eq $true) { "Domain" } else { "Workgroup" }
            }
            
            # Add certificate details if available
            if ($server.Certificate -and $server.Certificate.Subject) {
                $exportRow | Add-Member -NotePropertyName "CertificateSubject" -NotePropertyValue $server.Certificate.Subject
                $exportRow | Add-Member -NotePropertyName "CertificateExpiry" -NotePropertyValue $server.Certificate.NotAfter
                $exportRow | Add-Member -NotePropertyName "CertificateIssuer" -NotePropertyValue $server.Certificate.Issuer
            } else {
                $exportRow | Add-Member -NotePropertyName "CertificateSubject" -NotePropertyValue "No certificate found"
                $exportRow | Add-Member -NotePropertyName "CertificateExpiry" -NotePropertyValue $null
                $exportRow | Add-Member -NotePropertyName "CertificateIssuer" -NotePropertyValue $null
            }
            
            $exportData += $exportRow
        }
        
        # Export to CSV (as Excel export requires ImportExcel module)
        $csvPath = $OutputPath -replace '\.xlsx$', '_enhanced.csv'
        $exportData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        
        Write-Log "Successfully exported $($exportData.Count) server records to: $csvPath" -LogFile $LogFile
        Write-Log "Export summary:" -LogFile $LogFile
        Write-Log "  - Total servers: $($exportData.Count)" -LogFile $LogFile
        
        $domainCount = ($exportData | Where-Object { $_.ServerType -eq 'Domain' } | Measure-Object).Count
        $workgroupCount = ($exportData | Where-Object { $_.ServerType -eq 'Workgroup' } | Measure-Object).Count
        $certCount = ($exportData | Where-Object { $_.CertificateSubject -ne 'No certificate found' } | Measure-Object).Count
        
        Write-Log "  - Domain servers: $domainCount" -LogFile $LogFile
        Write-Log "  - Workgroup servers: $workgroupCount" -LogFile $LogFile
        Write-Log "  - Servers with certificates: $certCount" -LogFile $LogFile
        
        return @{
            Success = $true
            ExportPath = $csvPath
            RecordCount = $exportData.Count
        }
        
    } catch {
        Write-Log "ERROR in Export-ExcelData: $($_.Exception.Message)" -LogFile $LogFile
        throw "Failed to export Excel data: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    [DE] Filtert Serverdaten für Test-Modus basierend auf erlaubten Domains und Servern
    [EN] Filters server data for test mode based on allowed domains and servers
.DESCRIPTION
    [DE] Reduziert die Serverliste auf die konfigurierten Test-Domains und -Server
    [EN] Reduces server list to configured test domains and servers
#>
function Apply-TestModeFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$ServerData,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Applying test mode filter..." -LogFile $LogFile
    
    $allowedDomains = $Config.Certificate.TestMode.AllowedDomains
    $allowedServers = $Config.Certificate.TestMode.AllowedServers
    $maxServers = $Config.Certificate.TestMode.MaxServers
    
    $filteredData = @()
    
    foreach ($row in $ServerData) {
        $serverName = $row.($Config.Excel.ServerNameColumnName)
        $isDomainAllowed = $false
        $isServerAllowed = $false
        
        # Check if domain is allowed
        if ($row.Domain -and $allowedDomains -contains $row.Domain) {
            $isDomainAllowed = $true
        }
        
        # Check if specific server is allowed
        if ($allowedServers) {
            foreach ($allowedServer in $allowedServers) {
                if ($serverName -like "*$allowedServer*") {
                    $isServerAllowed = $true
                    break
                }
            }
        }
        
        # Include if domain or server is allowed
        if ($isDomainAllowed -or $isServerAllowed) {
            $filteredData += $row
            Write-Log "Test mode: Including server '$serverName' (Domain: $($row.Domain))" -LogFile $LogFile
        }
        
        # Stop if max servers reached
        if ($filteredData.Count -ge $maxServers) {
            Write-Log "Test mode: Maximum server limit ($maxServers) reached" -LogFile $LogFile
            break
        }
    }
    
    Write-Log "Test mode filter applied: $($filteredData.Count) servers selected from $($ServerData.Count) total" -LogFile $LogFile
    
    return $filteredData
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------
Export-ModuleMember -Function @(
    'Import-ExcelData',
    'Remove-StrikethroughServers', 
    'Extract-HeaderContext',
    'Apply-HeaderContext',
    'Apply-TestModeFilter',
    'Export-ExcelData'
)

# --- End of module --- v1.1.0 ; Regelwerk: v9.3.1 ---
