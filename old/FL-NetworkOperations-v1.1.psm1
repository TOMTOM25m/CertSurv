#requires -Version 5.1

<#
.SYNOPSIS
    [DE] FL-NetworkOperations v1.1.0 - Blockweise Zertifikatsprüfung mit Fortschrittsanzeige
    [EN] FL-NetworkOperations v1.1.0 - Block-wise certificate checking with progress display
.DESCRIPTION
    [DE] Verbessertes Modul für blockweise Server-Verarbeitung mit visueller Fortschrittsanzeige
    [EN] Enhanced module for block-wise server processing with visual progress display
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.1.0
    Regelwerk: v9.3.0
    Features: Block processing, progress display, intelligent certificate retrieval
#>

#----------------------------------------------------------[Initialisations]--------------------------------------------------------
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#----------------------------------------------------------[Functions]----------------------------------------------------------

<#
.SYNOPSIS
    [DE] Testet ob ein Servername ein Haupt-Skript mit blockweiser Verarbeitung
    [EN] Main script with block-wise processing
#>
function Invoke-NetworkOperations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$ServerData,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Starting block-wise network operations for $($ServerData.Count) servers..." -LogFile $LogFile
    
    # Group servers by domain/workgroup for block processing
    $domainServers = $ServerData | Where-Object { $_._IsDomainServer -eq $true }
    $workgroupServers = $ServerData | Where-Object { $_._IsDomainServer -ne $true }
    
    Write-Log "Block Processing Overview:" -LogFile $LogFile
    Write-Log "  Domain servers: $($domainServers.Count)" -LogFile $LogFile
    Write-Log "  Workgroup servers: $($workgroupServers.Count)" -LogFile $LogFile
    
    # Group domain servers by domain
    $domainGroups = $domainServers | Group-Object -Property _DomainContext
    
    Write-Host "=== BLOCKWEISE ZERTIFIKAT-VERARBEITUNG START ===" -ForegroundColor Cyan
    Write-Host "Gesamt: $($ServerData.Count) Server" -ForegroundColor White
    Write-Host "Domain-Server: $($domainServers.Count)" -ForegroundColor Green
    Write-Host "Workgroup-Server: $($workgroupServers.Count)" -ForegroundColor Yellow
    
    $totalProcessed = 0
    $totalSuccessful = 0
    $totalFailed = 0
    
    # Process domain blocks first
    foreach ($domainGroup in $domainGroups) {
        $domainName = if ($domainGroup.Name) { $domainGroup.Name } else { "Unknown" }
        $domainServerList = $domainGroup.Group
        
        Write-Host "`n--- Verarbeite ${domainName} Domain Block ($($domainServerList.Count) Server) ---" -ForegroundColor Cyan
        Write-Log "Processing $domainName domain block with $($domainServerList.Count) servers" -LogFile $LogFile
        
        $blockIndex = 0
        $blockSuccess = 0
        $blockFailed = 0
        
        foreach ($row in $domainServerList) {
            $blockIndex++
            $totalProcessed++
            
            $serverName = $row.$($Config.Excel.ServerNameColumnName)
            Write-Host "  [$blockIndex/$($domainServerList.Count)] ${domainName}: $serverName" -ForegroundColor White -NoNewline
            
            # Process this server
            try {
                $result = Process-SingleServerCertificate -Row $row -Config $Config -LogFile $LogFile
                if ($result.Success) {
                    Write-Host " ✓" -ForegroundColor Green
                    $blockSuccess++
                    $totalSuccessful++
                } else {
                    Write-Host " ✗ ($($result.Reason))" -ForegroundColor Red
                    $blockFailed++
                    $totalFailed++
                }
            } catch {
                Write-Host " ✗ ERROR" -ForegroundColor Red
                Write-Log "Error processing $serverName`: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
                $blockFailed++
                $totalFailed++
            }
        }
        
        Write-Host "  ${domainName} Block abgeschlossen: $blockSuccess erfolgreiche, $blockFailed fehlgeschlagene" -ForegroundColor Green
    }
    
    # Process workgroup block
    if ($workgroupServers.Count -gt 0) {
        Write-Host "`n--- Verarbeite Workgroup Block ($($workgroupServers.Count) Server) ---" -ForegroundColor Yellow
        Write-Log "Processing workgroup block with $($workgroupServers.Count) servers" -LogFile $LogFile
        
        $blockIndex = 0
        $blockSuccess = 0
        $blockFailed = 0
        
        foreach ($row in $workgroupServers) {
            $blockIndex++
            $totalProcessed++
            
            $serverName = $row.$($Config.Excel.ServerNameColumnName)
            Write-Host "  [$blockIndex/$($workgroupServers.Count)] Workgroup: $serverName" -ForegroundColor White -NoNewline
            
            # Process this server
            try {
                $result = Process-SingleServerCertificate -Row $row -Config $Config -LogFile $LogFile
                if ($result.Success) {
                    Write-Host " ✓" -ForegroundColor Green
                    $blockSuccess++
                    $totalSuccessful++
                } else {
                    Write-Host " ✗ ($($result.Reason))" -ForegroundColor Red
                    $blockFailed++
                    $totalFailed++
                }
            } catch {
                Write-Host " ✗ ERROR" -ForegroundColor Red
                Write-Log "Error processing $serverName`: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
                $blockFailed++
                $totalFailed++
            }
        }
        
        Write-Host "  Workgroup Block abgeschlossen: $blockSuccess erfolgreiche, $blockFailed fehlgeschlagene" -ForegroundColor Green
    }
    
    Write-Host "`n=== BLOCKWEISE VERARBEITUNG ABGESCHLOSSEN ===" -ForegroundColor Cyan
    Write-Host "Gesamt verarbeitet: $totalProcessed Server" -ForegroundColor Green
    Write-Host "Erfolgreich: $totalSuccessful" -ForegroundColor Green
    Write-Host "Fehlgeschlagen: $totalFailed" -ForegroundColor Red
    Write-Log "Block processing completed: $totalProcessed servers processed ($totalSuccessful successful, $totalFailed failed)" -LogFile $LogFile
    
    # Return summary result
    return @{
        ProcessedCount = $totalProcessed
        SuccessfulCount = $totalSuccessful
        FailedCount = $totalFailed
        Success = $true
    }
}

<#
.SYNOPSIS
    [DE] Verarbeitet einen einzelnen Server und führt Zertifikatsprüfungen durch
    [EN] Processes a single server and performs certificate checks
#>
function Process-SingleServerCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Row,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    $serverName = $Row.$($Config.Excel.ServerNameColumnName)
    
    # Skip empty server names
    if ([string]::IsNullOrWhiteSpace($serverName)) { 
        return @{ Success = $false; Reason = "Empty server name" }
    }
    
    # Clean server name 
    $cleanServerName = $serverName.Trim()
    
    # Construct FQDN based on server type
    $isDomainServer = $Row._IsDomainServer -eq $true
    $domainContext = $Row._DomainContext
    
    if ($isDomainServer -and $domainContext) {
        # Domain server: server.domain.meduniwien.ac.at
        $fqdn = "$cleanServerName.$($domainContext.ToLower()).$($Config.MainDomain)"
    } else {
        # Workgroup server: server.srv.meduniwien.ac.at
        $fqdn = "$cleanServerName.srv.$($Config.MainDomain)"
    }
    
    try {
        # Try certificate retrieval using FL-Certificate module
        $certResult = Get-RemoteCertificate -ServerName $fqdn -Port $Config.Certificate.Port -Config $Config -LogFile $LogFile
        
        if ($certResult -and $certResult.Success) {
            # Update row with certificate information
            Add-Member -InputObject $Row -NotePropertyName "FQDN_Used" -NotePropertyValue $fqdn -Force
            Add-Member -InputObject $Row -NotePropertyName "Certificate" -NotePropertyValue $certResult -Force
            Add-Member -InputObject $Row -NotePropertyName "CertificateStatus" -NotePropertyValue "Valid" -Force
            
            return @{ Success = $true; FQDN = $fqdn; Certificate = $certResult }
        } else {
            # Certificate retrieval failed
            Add-Member -InputObject $Row -NotePropertyName "FQDN_Used" -NotePropertyValue $fqdn -Force
            Add-Member -InputObject $Row -NotePropertyName "CertificateStatus" -NotePropertyValue "Failed" -Force
            
            return @{ Success = $false; Reason = "Certificate retrieval failed"; FQDN = $fqdn }
        }
        
    } catch {
        Add-Member -InputObject $Row -NotePropertyName "FQDN_Used" -NotePropertyValue $fqdn -Force
        Add-Member -InputObject $Row -NotePropertyName "CertificateStatus" -NotePropertyValue "Error" -Force
        
        return @{ Success = $false; Reason = $_.Exception.Message; FQDN = $fqdn }
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------
Export-ModuleMember -Function @(
    'Invoke-NetworkOperations'
)

# --- End of module --- v1.1.0 ; Regelwerk: v9.3.0 ---
