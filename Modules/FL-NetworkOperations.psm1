#requires -Version 5.1

<#
.SYNOPSIS
    FL-NetworkOperations v1.3.0 - Blockweise Zertifikatsprüfung mit SRV-Server Unterstützung
.DESCRIPTION
    Robustes Modul für blockweise Server-Verarbeitung mit visueller Fortschrittsanzeige
    Unterstützt 88 SRV-Server (Workgroup) und Domain-Server
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.3.0
    SRV-Server: 88 Server über srv.meduniwien.ac.at
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
    
    Write-Host "=== BLOCKWEISE ZERTIFIKAT-VERARBEITUNG START ===" -ForegroundColor Cyan
    Write-Host "Gesamt: $($ServerData.Count) Server" -ForegroundColor White
    
    # Group servers by domain/workgroup (SRV)
    $domainServers = $ServerData | Where-Object { $_._IsDomainServer -eq $true }
    $srvServers = $ServerData | Where-Object { $_._IsDomainServer -ne $true }
    
    Write-Host "Domain-Server: $($domainServers.Count)" -ForegroundColor Green
    Write-Host "SRV-Server (Workgroup): $($srvServers.Count)" -ForegroundColor Yellow
    
    $totalProcessed = 0
    $totalSuccessful = 0
    $totalFailed = 0
    
    # Process domain blocks first
    if ($domainServers.Count -gt 0) {
        $domainGroups = $domainServers | Group-Object -Property _DomainContext
        
        foreach ($domainGroup in $domainGroups) {
            $domainName = if ($domainGroup.Name) { $domainGroup.Name } else { "Unknown" }
            $domainServerList = $domainGroup.Group
            
            Write-Host "`n--- Domain Block: $domainName ($($domainServerList.Count) Server) ---" -ForegroundColor Cyan
            
            $blockIndex = 0
            $blockSuccess = 0
            $blockFailed = 0
            
            foreach ($row in $domainServerList) {
                $blockIndex++
                $totalProcessed++
                
                $serverName = $row.$($Config.Excel.ServerNameColumnName)
                Write-Host "  [$blockIndex/$($domainServerList.Count)] ${domainName}: $serverName" -ForegroundColor White -NoNewline
                
                try {
                    $result = Test-SingleServerCertificate -Row $row -Config $Config -LogFile $LogFile
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
                    $blockFailed++
                    $totalFailed++
                }
            }
            
            Write-Host "  $domainName abgeschlossen: $blockSuccess erfolgreiche, $blockFailed fehlgeschlagene" -ForegroundColor Green
        }
    }
    
    # Process SRV block (88 Workgroup servers)
    if ($srvServers.Count -gt 0) {
        Write-Host "`n--- SRV Block (srv.meduniwien.ac.at) - $($srvServers.Count) Server ---" -ForegroundColor Yellow
        
        $blockIndex = 0
        $blockSuccess = 0
        $blockFailed = 0
        
        foreach ($row in $srvServers) {
            $blockIndex++
            $totalProcessed++
            
            $serverName = $row.$($Config.Excel.ServerNameColumnName)
            Write-Host "  [$blockIndex/$($srvServers.Count)] SRV: $serverName" -ForegroundColor White -NoNewline
            
            try {
                $result = Test-SingleServerCertificate -Row $row -Config $Config -LogFile $LogFile
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
                $blockFailed++
                $totalFailed++
            }
        }
        
        Write-Host "  SRV Block abgeschlossen: $blockSuccess erfolgreiche, $blockFailed fehlgeschlagene" -ForegroundColor Green
    }
    
    Write-Host "`n=== BLOCKWEISE VERARBEITUNG ABGESCHLOSSEN ===" -ForegroundColor Cyan
    Write-Host "Gesamt verarbeitet: $totalProcessed Server" -ForegroundColor Green
    Write-Host "Erfolgreich: $totalSuccessful" -ForegroundColor Green
    Write-Host "Fehlgeschlagen: $totalFailed" -ForegroundColor Red
    
    # Prepare results in format expected by CoreLogic
    $results = @()
    foreach ($row in $ServerData) {
        $results += @{
            Row = $row
            FQDN = $row.FQDN_Used
            Success = $row.CertificateStatus -eq "Valid"
        }
    }
    
    # Count domain and workgroup servers for reporting
    $domainCount = ($ServerData | Where-Object { $_._IsDomainServer -eq $true }).Count
    $workgroupCount = ($ServerData | Where-Object { $_._IsDomainServer -ne $true }).Count
    
    return @{
        Results = $results
        DomainServersCount = $domainCount
        WorkgroupServersCount = $workgroupCount
        ProcessedCount = $totalProcessed
        SuccessfulCount = $totalSuccessful
        FailedCount = $totalFailed
        Success = $true
    }
}

function Test-SingleServerCertificate {
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
    
    if ([string]::IsNullOrWhiteSpace($serverName)) { 
        return @{ Success = $false; Reason = "Empty server name" }
    }
    
    $cleanServerName = $serverName.Trim()
    
    # Construct FQDN based on server type
    $isDomainServer = $Row._IsDomainServer -eq $true
    $domainContext = $Row._DomainContext
    
    if ($isDomainServer -and $domainContext) {
        # Domain server: server.domain.meduniwien.ac.at
        $fqdn = "$cleanServerName.$($domainContext.ToLower()).$($Config.MainDomain)"
    } else {
        # SRV server (Workgroup): server.srv.meduniwien.ac.at
        $fqdn = "$cleanServerName.srv.$($Config.MainDomain)"
    }
    
    try {
        $certResult = Get-RemoteCertificate -ServerName $fqdn -Port $Config.Certificate.Port -Config $Config -LogFile $LogFile
        
        if ($certResult -and $certResult.Success) {
            Add-Member -InputObject $Row -NotePropertyName "FQDN_Used" -NotePropertyValue $fqdn -Force
            Add-Member -InputObject $Row -NotePropertyName "Certificate" -NotePropertyValue $certResult -Force
            Add-Member -InputObject $Row -NotePropertyName "CertificateStatus" -NotePropertyValue "Valid" -Force
            
            return @{ Success = $true; FQDN = $fqdn; Certificate = $certResult }
        } else {
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

Export-ModuleMember -Function @('Invoke-NetworkOperations')

# --- End of module --- v1.3.0 ---
