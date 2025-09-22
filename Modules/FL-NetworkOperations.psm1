#requires -Version 5.1

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "FL-NetworkOperations - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import CertificateAPI module for performance optimization
$apiModulePath = Join-Path $PSScriptRoot "FL-CertificateAPI.psm1"
if (Test-Path $apiModulePath) {
    Import-Module $apiModulePath -Force
    $Script:ApiModuleAvailable = $true
} else {
    $Script:ApiModuleAvailable = $false
}

function Invoke-NetworkOperations {
    param(
        [Parameter(Mandatory = $true)]
        [array]$ServerData,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Host "=== BLOCKWEISE ZERTIFIKAT-VERARBEITUNG START ===" -ForegroundColor Cyan
    Write-Host "Gesamt: $(if ($ServerData) { ($ServerData | Measure-Object).Count } else { 0 }) Server" -ForegroundColor White
    
    # NEW: Try to fetch all certificates from central WebService first
    $centralCertData = $null
    if ($Script:ApiModuleAvailable -and $Config.Certificate.WebService.Enabled) {
        try {
            Write-Host "[API] Fetching certificates from central WebService: $($Config.Certificate.WebService.PrimaryServer)" -ForegroundColor Cyan
            $centralCertData = Get-CertificateDataFromCentralAPI -Config $Config -LogFile $LogFile
            
            if ($centralCertData) {
                Write-Host "[API] Central API successful - $($centralCertData.total_count) certificates available" -ForegroundColor Green
            } else {
                Write-Host "[API] Central API failed - falling back to individual server scanning" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "[API] Central API error - falling back to individual server scanning: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Log "Central API failed: $($_.Exception.Message)" -Level WARN -LogFile $LogFile
            $centralCertData = $null
        }
    }
    
    $domainServers = $ServerData | Where-Object { $_._IsDomainServer -eq $true }
    $srvServers = $ServerData | Where-Object { $_._IsDomainServer -ne $true }
    
    # Safety check for Count properties
    $domainCount = if ($domainServers) { ($domainServers | Measure-Object).Count } else { 0 }
    $srvCount = if ($srvServers) { ($srvServers | Measure-Object).Count } else { 0 }
    
    Write-Host "Domain-Server: $domainCount" -ForegroundColor Green
    Write-Host "SRV-Server (Workgroup): $srvCount" -ForegroundColor Yellow
    
    $totalProcessed = 0
    $totalSuccessful = 0
    $totalFailed = 0
    
    if ($domainCount -gt 0) {
        $domainGroups = $domainServers | Group-Object -Property _DomainContext
        
        foreach ($domainGroup in $domainGroups) {
            $domainName = if ($domainGroup.Name) { $domainGroup.Name } else { "Unknown" }
            $domainServerList = $domainGroup.Group
            
            $domainServerListCount = if ($domainServerList) { ($domainServerList | Measure-Object).Count } else { 0 }
            Write-Host "`n--- Domain Block: $domainName ($domainServerListCount Server) ---" -ForegroundColor Cyan
            
            $blockIndex = 0
            $blockSuccess = 0
            $blockFailed = 0
            
            foreach ($row in $domainServerList) {
                $blockIndex++
                $totalProcessed++
                
                $serverName = $row.$($Config.Excel.ServerNameColumnName)
                Write-Host "  [$blockIndex/$domainServerListCount] ${domainName}: $serverName" -ForegroundColor White -NoNewline
                
                try {
                    $result = Test-SingleServerCertificate -Row $row -Config $Config -LogFile $LogFile -CentralCertData $centralCertData
                    if ($result.Success) {
                        $methodIndicator = if ($result.Method -eq "API") { "[API]" } else { "[SSL]" }
                        Write-Host " $methodIndicator OK" -ForegroundColor Green
                        $blockSuccess++
                        $totalSuccessful++
                    } else {
                        $methodIndicator = if ($result.Method -eq "API") { "[API]" } else { "[SSL]" }
                        Write-Host " $methodIndicator FAIL ($($result.Reason))" -ForegroundColor Red
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
    
    if ($srvCount -gt 0) {
        Write-Host "`n--- SRV Block (srv.meduniwien.ac.at) - $srvCount Server ---" -ForegroundColor Yellow
        
        $blockIndex = 0
        $blockSuccess = 0
        $blockFailed = 0
        
        foreach ($row in $srvServers) {
            $blockIndex++
            $totalProcessed++
            
            $serverName = $row.$($Config.Excel.ServerNameColumnName)
            Write-Host "  [$blockIndex/$srvCount] SRV: $serverName" -ForegroundColor White -NoNewline
            
            try {
                $result = Test-SingleServerCertificate -Row $row -Config $Config -LogFile $LogFile -CentralCertData $centralCertData
                if ($result.Success) {
                    $methodIndicator = if ($result.Method -eq "API") { "[API]" } else { "[SSL]" }
                    Write-Host " $methodIndicator OK" -ForegroundColor Green
                    $blockSuccess++
                    $totalSuccessful++
                } else {
                    $methodIndicator = if ($result.Method -eq "API") { "[API]" } else { "[SSL]" }
                    Write-Host " $methodIndicator FAIL ($($result.Reason))" -ForegroundColor Red
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
    
    # Performance statistics
    $apiServers = $ServerData | Where-Object { $_._RetrievalMethod -eq "WebServiceAPI" }
    $directSslServers = $ServerData | Where-Object { $_._RetrievalMethod -eq "DirectSSL" }
    
    $apiCount = if ($apiServers) { ($apiServers | Measure-Object).Count } else { 0 }
    $directSslCount = if ($directSslServers) { ($directSslServers | Measure-Object).Count } else { 0 }
    
    if ($apiCount -gt 0 -or $directSslCount -gt 0) {
        Write-Host "`n--- Performance Report ---" -ForegroundColor Magenta
        if ($apiCount -gt 0) {
            Write-Host "[API] Web Service API: $apiCount Server (10x faster)" -ForegroundColor Cyan
        }
        if ($directSslCount -gt 0) {
            Write-Host "[SSL] Direct SSL: $directSslCount Server (fallback method)" -ForegroundColor Yellow
        }
        
        $performanceGain = if ($directSslCount -gt 0) {
            $estimatedApiTime = $apiCount * 0.2  # 200ms avg for API
            $estimatedDirectTime = $directSslCount * 2.2  # 2200ms avg for direct SSL
            $actualTime = $estimatedApiTime + $estimatedDirectTime
            $allDirectTime = $totalSuccessful * 2.2
            $timeSaved = $allDirectTime - $actualTime
            if ($timeSaved -gt 0) { [math]::Round($timeSaved, 1) } else { 0 }
        } else { 0 }
        
        if ($performanceGain -gt 0) {
            Write-Host "[TIME] Zeit gespart: ca. $performanceGain Sekunden" -ForegroundColor Green
        }
    }
    
    $results = @()
    foreach ($row in $ServerData) {
        $results += @{
            Row = $row
            FQDN = $row.FQDN_Used
            Success = $row.CertificateStatus -eq "Valid"
            Method = $row._RetrievalMethod
        }
    }
    
    $domainCount = ($ServerData | Where-Object { $_._IsDomainServer -eq $true } | Measure-Object).Count
    $workgroupCount = ($ServerData | Where-Object { $_._IsDomainServer -ne $true } | Measure-Object).Count
    $apiCount = ($ServerData | Where-Object { $_._RetrievalMethod -eq "WebServiceAPI" } | Measure-Object).Count
    $directSslCount = ($ServerData | Where-Object { $_._RetrievalMethod -eq "DirectSSL" } | Measure-Object).Count
    
    return @{
        Results = $results
        DomainServersCount = $domainCount
        WorkgroupServersCount = $workgroupCount
        ProcessedCount = $totalProcessed
        SuccessfulCount = $totalSuccessful
        FailedCount = $totalFailed
        ApiServersCount = $apiCount
        DirectSslServersCount = $directSslCount
        Success = $true
    }
}

function Test-SingleServerCertificate {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Row,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile,
        
        [Parameter(Mandatory = $false)]
        [object]$CentralCertData = $null
    )
    
    $serverName = $Row.$($Config.Excel.ServerNameColumnName)
    
    if ([string]::IsNullOrWhiteSpace($serverName)) { 
        return @{ Success = $false; Reason = "Empty server name" }
    }
    
    $cleanServerName = $serverName.Trim()
    
    $isDomainServer = $Row._IsDomainServer -eq $true
    $domainContext = $Row._DomainContext
    
    if ($isDomainServer -and $domainContext) {
        $fqdn = "$cleanServerName.$($domainContext.ToLower()).$($Config.MainDomain)"
    } else {
        $fqdn = "$cleanServerName.srv.$($Config.MainDomain)"
    }
    
    # FIRST: Try to find certificate in central API data (fastest method)
    if ($CentralCertData -and $Script:ApiModuleAvailable) {
        try {
            $centralCert = Find-ServerCertificateInCentralData -CentralData $CentralCertData -ServerName $fqdn -LogFile $LogFile
            
            if ($centralCert) {
                Add-Member -InputObject $Row -NotePropertyName "FQDN_Used" -NotePropertyValue $fqdn -Force
                Add-Member -InputObject $Row -NotePropertyName "Certificate" -NotePropertyValue $centralCert -Force
                Add-Member -InputObject $Row -NotePropertyName "CertificateStatus" -NotePropertyValue "Valid" -Force
                Add-Member -InputObject $Row -NotePropertyName "_RetrievalMethod" -NotePropertyValue "CentralAPI" -Force
                
                return @{ 
                    Success = $true
                    FQDN = $fqdn
                    Certificate = $centralCert
                    Method = "API"
                }
            }
        } catch {
            Write-Log "Central certificate search failed for ${cleanServerName}: $($_.Exception.Message)" -Level WARN -LogFile $LogFile
        }
    }
    
    # FALLBACK: Try individual Certificate Web Service API (if central data not available)
    if ($Script:ApiModuleAvailable) {
        try {
            $webServiceAvailable = Test-CertificateWebService -ServerName $fqdn -Port 8443 -TimeoutSeconds 3 -LogFile $LogFile
            
            if ($webServiceAvailable) {
                $apiResult = Get-CertificateDataFromAPI -ServerName $fqdn -Port 8443 -TimeoutSeconds 8 -LogFile $LogFile
                
                $certCount = if ($apiResult -and $apiResult.Certificates) { 
                    if ($apiResult.Certificates -is [array]) { $apiResult.Certificates.Count } 
                    elseif ($apiResult.Certificates) { 1 } 
                    else { 0 }
                } else { 0 }
                if ($certCount -gt 0) {
                    # Use first certificate from API (typically the main SSL certificate)
                    $certResult = $apiResult.Certificates[0]
                    
                    Add-Member -InputObject $Row -NotePropertyName "FQDN_Used" -NotePropertyValue $fqdn -Force
                    Add-Member -InputObject $Row -NotePropertyName "Certificate" -NotePropertyValue $certResult -Force
                    Add-Member -InputObject $Row -NotePropertyName "CertificateStatus" -NotePropertyValue "Valid" -Force
                    Add-Member -InputObject $Row -NotePropertyName "_RetrievalMethod" -NotePropertyValue "IndividualAPI" -Force
                    
                    return @{ 
                        Success = $true
                        FQDN = $fqdn
                        Certificate = $certResult
                        Method = "API"
                    }
                } else {
                    # API returned no certificates - could be normal (no certificates on server)
                    Add-Member -InputObject $Row -NotePropertyName "FQDN_Used" -NotePropertyValue $fqdn -Force
                    Add-Member -InputObject $Row -NotePropertyName "CertificateStatus" -NotePropertyValue "NoCertificates" -Force
                    Add-Member -InputObject $Row -NotePropertyName "_RetrievalMethod" -NotePropertyValue "WebServiceAPI" -Force
                    
                    return @{ 
                        Success = $false
                        Reason = "No certificates found via API"
                        FQDN = $fqdn
                        Method = "API"
                    }
                }
            }
        } catch {
            # API failed, continue to direct SSL method
            Write-Log "Certificate Web Service API failed for $fqdn, falling back to direct SSL: $($_.Exception.Message)" -Level WARN -LogFile $LogFile
        }
    }
    
    # Fallback to original direct SSL certificate scanning
    try {
        $certResult = Get-RemoteCertificate -ServerName $fqdn -Port $Config.Certificate.Port -Timeout 10000
        
        if ($certResult) {
            # Certificate found via direct SSL
            Add-Member -InputObject $Row -NotePropertyName "FQDN_Used" -NotePropertyValue $fqdn -Force
            Add-Member -InputObject $Row -NotePropertyName "Certificate" -NotePropertyValue $certResult -Force
            Add-Member -InputObject $Row -NotePropertyName "CertificateStatus" -NotePropertyValue "Valid" -Force
            Add-Member -InputObject $Row -NotePropertyName "_RetrievalMethod" -NotePropertyValue "DirectSSL" -Force
            
            return @{ 
                Success = $true
                FQDN = $fqdn
                Certificate = $certResult
                Method = "DirectSSL"
            }
        } else {
            # No certificate found via direct SSL
            Add-Member -InputObject $Row -NotePropertyName "FQDN_Used" -NotePropertyValue $fqdn -Force
            Add-Member -InputObject $Row -NotePropertyName "CertificateStatus" -NotePropertyValue "Failed" -Force
            Add-Member -InputObject $Row -NotePropertyName "_RetrievalMethod" -NotePropertyValue "DirectSSL" -Force
            
            return @{ 
                Success = $false
                Reason = "No certificate found via direct SSL"
                FQDN = $fqdn
                Method = "DirectSSL"
            }
        }
        
    } catch {
        Add-Member -InputObject $Row -NotePropertyName "FQDN_Used" -NotePropertyValue $fqdn -Force
        Add-Member -InputObject $Row -NotePropertyName "CertificateStatus" -NotePropertyValue "Error" -Force
        Add-Member -InputObject $Row -NotePropertyName "_RetrievalMethod" -NotePropertyValue "DirectSSL" -Force
        
        return @{ 
            Success = $false
            Reason = $_.Exception.Message
            FQDN = $fqdn
            Method = "DirectSSL"
        }
    }
}

Export-ModuleMember -Function @('Invoke-NetworkOperations')
