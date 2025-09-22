#requires -Version 5.1

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "FL-CoreLogic - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

<#
.SYNOPSIS
    [DE] FL-CoreLogic Modul - Haupt-Workflow-Orchestrierung für Cert-Surveillance
    [EN] FL-CoreLogic Module - Main workflow orchestration for Cert-Surveillance
.DESCRIPTION
    [DE] Enthält die Hauptausführungslogik, delegiert vom Hauptskript gemäß strict modularity Prinzipien.
         Orchestriert den gesamten Certificate Surveillance Workflow.
    [EN] Contains the main execution logic, delegated from the main script according to strict modularity principles.
         Orchestrates the entire certificate surveillance workflow.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.09.04
    Last modified:  2025.09.04
    Version:        v1.1.0
    MUW-Regelwerk:  v9.4.0 (PowerShell Version Adaptation)
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
    
    v1.1.0 Changes:
    - Added Invoke-EnhancedCertificateOperations for parallel multi-server API processing
    - Leverages existing Get-CertificatesFromMultipleServers for ~16x performance improvement
    - Supports decentralized WebService architecture (per-server WebServices on 9080/9443)
#>

$ModuleName = "FL-CoreLogic"
$ModuleVersion = "v1.1.0"

#----------------------------------------------------------[Functions]----------------------------------------------------------

<#
.SYNOPSIS
    Main workflow execution
.DESCRIPTION
    Orchestrates the entire certificate surveillance workflow
#>
function Invoke-MainWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters,
        
        [Parameter(Mandatory = $true)]
        [string]$ScriptDirectory,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Starting main certificate surveillance workflow..." -LogFile $LogFile
    
    try {
        # Step 1: Import and process Excel data
        Write-Log "Step 1: Processing Excel data..." -LogFile $LogFile
        $excelResult = Import-ExcelData -ExcelPath $Config.Excel.ExcelPath -WorksheetName $Config.Excel.SheetName -Config $Config -LogFile $LogFile
        
        if ($excelResult.FilteredCount -eq 0) {
            throw "No valid server data found in Excel file after filtering"
        }
        
        # Step 2: Process network operations (FQDN construction, AD queries)
        Write-Log "Step 2: Processing network operations..." -LogFile $LogFile
        $networkResult = Invoke-NetworkOperations -ServerData $excelResult.Data -Config $Config -LogFile $LogFile
        
        if ($networkResult.Results.Count -eq 0) {
            throw "No servers were successfully processed"
        }
        
        # Step 3: Enhanced parallel certificate operations (NEW v1.1.0)
        Write-Log "Step 3: Performing enhanced parallel certificate discovery..." -LogFile $LogFile
        $certResult = Invoke-EnhancedCertificateOperations -NetworkResults $networkResult.Results -Config $Config -LogFile $LogFile
        
        # Step 4: Save updated Excel data
        Write-Log "Step 4: Saving updated Excel data..." -LogFile $LogFile
        $updatedRows = $networkResult.Results | ForEach-Object { $_.Row }
        Export-ExcelData -ServerData $updatedRows -OutputPath $Config.Excel.ExcelPath -Config $Config -LogFile $LogFile
        
        # Step 4.5: Save certificate data to JSON for daily email reports (NEW v1.1.0)
        Write-Log "Step 4.5: Saving certificate data to JSON..." -LogFile $LogFile
        if ($certResult.Certificates -and ($certResult.Certificates | Measure-Object).Count -gt 0) {
            $jsonResult = Save-CertificateDataToJson -CertificateData $certResult.Certificates -Config $Config -LogFile $LogFile
            Write-Log "Certificate data saved to JSON: $($jsonResult.FilePath)" -LogFile $LogFile
        } else {
            Write-Log "No certificates to save to JSON" -LogFile $LogFile
        }
        
        # Step 5: Generate reports and send notifications
        Write-Log "Step 5: Generating reports..." -LogFile $LogFile
        if ($certResult.Certificates -and ($certResult.Certificates | Measure-Object).Count -gt 0) {
            $reportResult = Invoke-ReportingOperations -Certificates $certResult.Certificates -Config $Config -ScriptDirectory $ScriptDirectory -LogFile $LogFile
        } else {
            Write-Log "No certificates found - skipping report generation" -LogFile $LogFile
            $reportResult = @{
                Success = $true
                ReportPath = "No certificates found"
                EmailSent = $false
            }
        }
        
        # Step 6: Check and send daily email report (NEW v1.1.0)
        Write-Log "Step 6: Checking daily email schedule..." -LogFile $LogFile
        if ($jsonResult -and $jsonResult.Success) {
            try {
                $dailyEmailResult = Send-DailyCertificateReport -JsonFilePath $jsonResult.FilePath -Config $Config -LogFile $LogFile
                if ($dailyEmailResult.Success) {
                    Write-Log "Daily email report sent successfully to: $($dailyEmailResult.Recipient)" -LogFile $LogFile
                } else {
                    Write-Log "Daily email not sent: $($dailyEmailResult.Reason)" -LogFile $LogFile
                }
            } catch {
                Write-Log "Daily email report failed: $($_.Exception.Message)" -Level WARN -LogFile $LogFile
            }
        }
        
        # Step 7: Log final summary
        $certCount = if ($certResult.Certificates) { ($certResult.Certificates | Measure-Object).Count } else { 0 }
        Write-Log "Workflow completed successfully!" -LogFile $LogFile
        Write-Log "Summary:" -LogFile $LogFile
        Write-Log "  - Excel rows processed: $($excelResult.OriginalCount) (filtered: $($excelResult.FilteredCount))" -LogFile $LogFile
        Write-Log "  - Domain servers: $($networkResult.DomainServersCount)" -LogFile $LogFile
        Write-Log "  - Workgroup servers: $($networkResult.WorkgroupServersCount)" -LogFile $LogFile
        Write-Log "  - Certificates found: $certCount" -LogFile $LogFile
        Write-Log "  - Report saved to: $($reportResult.ReportPath)" -LogFile $LogFile
        
        return @{
            Success = $true
            ExcelProcessed = $excelResult.FilteredCount
            CertificatesFound = $certCount
            ReportPath = $reportResult.ReportPath
            EmailSent = $reportResult.EmailSent
        }
        
    }
    catch {
        Write-Log "Workflow failed: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
        throw
    }
}

<#
.SYNOPSIS
    Enhanced parallel certificate operations leveraging multi-server API
.DESCRIPTION
    Uses Get-CertificatesFromMultipleServers for parallel processing instead of serial server-by-server approach.
    Provides significant performance improvements for large server lists (151 servers: ~5 minutes vs ~80 minutes).
#>
function Invoke-EnhancedCertificateOperations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$NetworkResults,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Starting enhanced parallel certificate operations for $($NetworkResults.Count) servers..." -LogFile $LogFile
    
    # Extract server list (FQDNs) from network results
    $serverList = @()
    $serverMapping = @{}
    
    foreach ($result in $NetworkResults) {
        if ($result.FQDN) {
            $serverList += $result.FQDN
            $serverMapping[$result.FQDN] = $result
        }
    }
    
    Write-Log "Prepared server list: $($serverList.Count) servers for parallel processing" -LogFile $LogFile
    
    $allCertificates = @()
    
    # Check if FL-CertificateAPI is available for parallel processing
    if (Get-Module -Name "FL-CertificateAPI" -ListAvailable) {
        Write-Log "Using FL-CertificateAPI for enhanced parallel certificate collection" -LogFile $LogFile
        
        try {
            # Use decentralized WebService ports (9080/9443) as specified by user
            $apiPort = if ($Config.Certificate.WebService.UseHttps) { 
                $Config.Certificate.WebService.HttpsPort 
            } else { 
                $Config.Certificate.WebService.HttpPort 
            }
            
            # Set MaxConcurrent based on server count for optimal performance
            $maxConcurrent = [Math]::Min(20, [Math]::Max(5, [Math]::Floor($serverList.Count / 10)))
            
            Write-Log "Starting parallel API collection - Port: $apiPort, MaxConcurrent: $maxConcurrent" -LogFile $LogFile
            
            # Call the existing Get-CertificatesFromMultipleServers function
            $parallelResults = Get-CertificatesFromMultipleServers -ServerList $serverList -ApiPort $apiPort -MaxConcurrent $maxConcurrent -LogFile $LogFile
            
            # Process results and map back to network results
            foreach ($result in $parallelResults) {
                if ($result.ServerName -and $serverMapping.ContainsKey($result.ServerName)) {
                    $networkResult = $serverMapping[$result.ServerName]
                    
                    # Create certificate object with enhanced metadata
                    $certObject = [PSCustomObject]@{
                        ServerName = $networkResult.ServerName
                        FQDN = $result.ServerName
                        ServerType = $networkResult.ServerType
                        RequiresAD = $networkResult.RequiresAD
                        CertificateSubject = $result.Subject
                        NotAfter = [DateTime]::Parse($result.NotAfter)
                        DaysRemaining = $result.DaysRemaining
                        RetrievalMethod = $result.Method
                        Thumbprint = $result.Thumbprint
                        HasPrivateKey = $result.HasPrivateKey
                        # AD Information from network result
                        ADServerExists = $networkResult.ADQueryResult.ServerExists
                        ADLastLogon = $networkResult.ADQueryResult.LastLogon
                        ADOperatingSystem = $networkResult.ADQueryResult.OperatingSystem
                    }
                    
                    $allCertificates += $certObject
                    
                    # Update the row with certificate information
                    Add-Member -InputObject $networkResult.Row -NotePropertyName "Certificate" -NotePropertyValue $certObject -Force
                    Add-Member -InputObject $networkResult.Row -NotePropertyName "CertificateStatus" -NotePropertyValue "Valid" -Force
                    Add-Member -InputObject $networkResult.Row -NotePropertyName "_RetrievalMethod" -NotePropertyValue $result.Method -Force
                }
            }
            
            Write-Log "Enhanced parallel certificate collection completed: Found $($allCertificates.Count) certificates using parallel API approach" -LogFile $LogFile
            
        } catch {
            Write-Log "Enhanced parallel certificate collection failed: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
            Write-Log "Falling back to traditional certificate operations..." -Level WARN -LogFile $LogFile
            
            # Fallback to existing certificate operations
            $fallbackResult = Invoke-CertificateOperations -NetworkResults $NetworkResults -Config $Config -LogFile $LogFile
            $allCertificates = $fallbackResult.Certificates
        }
        
    } else {
        Write-Log "FL-CertificateAPI module not available, using traditional certificate operations" -Level WARN -LogFile $LogFile
        
        # Fallback to existing certificate operations
        $fallbackResult = Invoke-CertificateOperations -NetworkResults $NetworkResults -Config $Config -LogFile $LogFile
        $allCertificates = $fallbackResult.Certificates
    }
    
    Write-Log "Certificate operations complete - found $($allCertificates.Count) certificates" -LogFile $LogFile
    
    return @{
        Certificates = $allCertificates
        ServerCount = $NetworkResults.Count
        Method = "EnhancedParallel"
    }
}

<#
.SYNOPSIS
    Validates workflow prerequisites
.DESCRIPTION
    Checks if all required modules and dependencies are available
#>
function Test-WorkflowPrerequisites {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Validating workflow prerequisites..." -LogFile $LogFile
    
    $prerequisitesOk = $true
    
    # Check required modules
    $requiredModules = @('ImportExcel', 'FL-ActiveDirectory', 'FL-DataProcessing', 'FL-NetworkOperations', 'FL-Security', 'FL-Reporting')
    
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -Name $module)) {
            Write-Log "Required module missing: $module" -Level ERROR -LogFile $LogFile
            $prerequisitesOk = $false
        }
    }
    
    # Check Excel file
    if (-not (Test-Path $Config.Excel.ExcelPath)) {
        Write-Log "Excel file not found: $($Config.Excel.ExcelPath)" -Level ERROR -LogFile $LogFile
        $prerequisitesOk = $false
    }
    
    # Check required columns exist in config
    $requiredColumns = @('ServerNameColumnName', 'FqdnColumnName')
    foreach ($column in $requiredColumns) {
        if (-not ($Config.Excel.PSObject.Properties.Name -contains $column)) {
            Write-Log "Required Excel column configuration missing: $column" -Level ERROR -LogFile $LogFile
            $prerequisitesOk = $false
        }
    }
    
    if ($prerequisitesOk) {
        Write-Log "All prerequisites validated successfully" -LogFile $LogFile
    }
    else {
        Write-Log "Prerequisites validation failed" -Level ERROR -LogFile $LogFile
    }
    
    return $prerequisitesOk
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------
Export-ModuleMember -Function @(
    'Invoke-MainWorkflow',
    'Invoke-EnhancedCertificateOperations',
    'Test-WorkflowPrerequisites'
)

# --- End of module --- v1.1.0 ; Regelwerk: v9.3.1 ---
