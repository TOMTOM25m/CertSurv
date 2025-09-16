#requires -Version 5.1

<#
.SYNOPSIS
    FL-Security Module - Certificate and security operations
.DESCRIPTION
    Handles SSL certificate discovery, validation, and security-related operations
.AUTHOR
    System Administrator
.VERSION
    v1.0.0
.RULEBOOK
    v9.3.0
#>

$ModuleName = "FL-Security"
$ModuleVersion = "v1.0.0"

#----------------------------------------------------------[Functions]----------------------------------------------------------

<#
.SYNOPSIS
    Performs certificate discovery and validation for servers
.DESCRIPTION
    Main orchestration function for certificate operations
#>
function Invoke-CertificateOperations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$NetworkResults,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Starting certificate operations for $($NetworkResults.Count) servers..." -LogFile $LogFile
    
    $allCertificates = @()
    
    foreach ($result in $NetworkResults) {
        $serverName = $result.ServerName
        $fqdn = $result.FQDN
        $serverType = $result.ServerType
        $adQueryResult = $result.ADQueryResult
        
        Write-Log "Processing certificates for server: $serverName ($fqdn)" -LogFile $LogFile
        
        # Get certificates
        $certificates = Get-Certificates -FQDN $fqdn -Config $Config
        
        if ($certificates) {
            foreach ($cert in $certificates) {
                $certObject = [PSCustomObject]@{
                    ServerName = $serverName
                    FQDN = $fqdn
                    ServerType = $serverType
                    RequiresAD = $result.RequiresAD
                    CertificateSubject = $cert.Subject
                    NotAfter = $cert.NotAfter
                    DaysRemaining = ($cert.NotAfter - (Get-Date)).Days
                    # AD Information
                    ADQueryExecuted = $(if ($adQueryResult) { $adQueryResult.ADQueryExecuted } else { $false })
                    ADQuerySuccess = $(if ($adQueryResult) { $adQueryResult.ADQuerySuccess } else { $false })
                    OperatingSystem = $(if ($adQueryResult -and $adQueryResult.ADQuerySuccess) { $adQueryResult.OperatingSystem } else { $null })
                    LastLogon = $(if ($adQueryResult -and $adQueryResult.ADQuerySuccess) { $adQueryResult.LastLogon } else { $null })
                    ADErrorMessage = $(if ($adQueryResult) { $adQueryResult.ErrorMessage } else { $null })
                }
                
                $allCertificates += $certObject
                Write-Log "Found certificate: $($cert.Subject) expires $($cert.NotAfter)" -LogFile $LogFile
            }
            
            # Update Excel row with additional certificate subjects
            if ($certificates.Count -gt 1) {
                $additionalSubjects = ($certificates | Select-Object -Skip 1 | ForEach-Object { $_.Subject }) -join "; "
                $result.Row.$($Config.Excel.FqdnColumnName) += "; $additionalSubjects"
                Write-Log "Additional certificates found: $additionalSubjects" -LogFile $LogFile
            }
        }
        else {
            Write-Log "No certificates found for: $fqdn" -Level WARN -LogFile $LogFile
        }
    }
    
    Write-Log "Certificate operations complete - found $($allCertificates.Count) certificates" -LogFile $LogFile
    
    return @{
        Certificates = $allCertificates
        ServerCount = $NetworkResults.Count
    }
}

<#
.SYNOPSIS
    Retrieves SSL certificates from a server
.DESCRIPTION
    Queries SSL certificate on configured port and local certificate store
#>
function Get-Certificates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FQDN,
        
        [Parameter(Mandatory = $false)]
        [object]$Config
    )
    
    $certificates = @()
    
    # [DE] Port aus Konfiguration oder Standard verwenden / [EN] Use port from config or default
    $port = if ($Config -and $Config.Certificate -and $Config.Certificate.Port) {
        $Config.Certificate.Port
    } else {
        443
    }
    
    try {
        # Try to get SSL certificate from configured port
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($FQDN, $port)
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, ({ $true }))
        $sslStream.AuthenticateAsClient($FQDN)
        
        $certificates += $sslStream.RemoteCertificate
        $sslStream.Close()
        $tcpClient.Close()
    }
    catch {
        # SSL certificate not available or connection failed
        Write-Verbose "Could not retrieve SSL certificate from $FQDN`:$port - $($_.Exception.Message)"
    }
    
    try {
        # Try to query local certificate store remotely
        $remoteCertPath = "\\$FQDN\Cert:\LocalMachine\My"
        if (Test-Path $remoteCertPath) {
            $localCerts = Get-ChildItem -Path $remoteCertPath -ErrorAction SilentlyContinue
            $certificates += $localCerts
        }
    }
    catch {
        # Remote certificate store not accessible
        Write-Verbose "Could not access remote certificate store on $FQDN - $($_.Exception.Message)"
    }
    
    return $certificates | Where-Object { $_ -ne $null } | Sort-Object NotAfter -Descending
}

<#
.SYNOPSIS
    Validates certificate expiration status
.DESCRIPTION
    Categorizes certificates based on remaining days until expiration
#>
function Get-CertificateStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Certificate,
        
        [Parameter(Mandatory = $true)]
        [object]$Config
    )
    
    $daysRemaining = ($Certificate.NotAfter - (Get-Date)).Days
    
    $status = if ($daysRemaining -le $Config.Intervals.DaysUntilUrgent) {
        "Urgent"
    }
    elseif ($daysRemaining -le $Config.Intervals.DaysUntilCritical) {
        "Critical"
    }
    elseif ($daysRemaining -le $Config.Intervals.DaysUntilWarning) {
        "Warning"
    }
    else {
        "Valid"
    }
    
    return @{
        Status = $status
        DaysRemaining = $daysRemaining
        ExpirationDate = $Certificate.NotAfter
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------
Export-ModuleMember -Function @(
    'Invoke-CertificateOperations',
    'Get-Certificates',
    'Get-CertificateStatus'
)

# --- End of module --- v1.0.0 ; Regelwerk: v9.3.0 ---
