#requires -Version 5.1

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
    Version:        v1.0.0
    MUW-Regelwerk:  v9.3.0
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

$ModuleName = "FL-CoreLogic"
$ModuleVersion = "v1.0.0"

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
        
        # Step 3: Perform certificate operations
        Write-Log "Step 3: Performing certificate discovery..." -LogFile $LogFile
        $certResult = Invoke-CertificateOperations -NetworkResults $networkResult.Results -Config $Config -LogFile $LogFile
        
        # Step 4: Save updated Excel data
        Write-Log "Step 4: Saving updated Excel data..." -LogFile $LogFile
        $updatedRows = $networkResult.Results | ForEach-Object { $_.Row }
        Export-ExcelData -ExcelData $updatedRows -ExcelPath $Config.Excel.ExcelPath -WorksheetName $Config.Excel.SheetName -LogFile $LogFile
        
        # Step 5: Generate reports and send notifications
        Write-Log "Step 5: Generating reports..." -LogFile $LogFile
        $reportResult = Invoke-ReportingOperations -Certificates $certResult.Certificates -Config $Config -ScriptDirectory $ScriptDirectory -LogFile $LogFile
        
        # Step 6: Log final summary
        Write-Log "Workflow completed successfully!" -LogFile $LogFile
        Write-Log "Summary:" -LogFile $LogFile
        Write-Log "  - Excel rows processed: $($excelResult.OriginalCount) (filtered: $($excelResult.FilteredCount))" -LogFile $LogFile
        Write-Log "  - Domain servers: $($networkResult.DomainServersCount)" -LogFile $LogFile
        Write-Log "  - Workgroup servers: $($networkResult.WorkgroupServersCount)" -LogFile $LogFile
        Write-Log "  - Certificates found: $($certResult.Certificates.Count)" -LogFile $LogFile
        Write-Log "  - Report saved to: $($reportResult.ReportPath)" -LogFile $LogFile
        
        return @{
            Success = $true
            ExcelProcessed = $excelResult.FilteredCount
            CertificatesFound = $certResult.Certificates.Count
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
    'Test-WorkflowPrerequisites'
)

# --- End of module --- v1.0.0 ; Regelwerk: v9.3.0 ---
