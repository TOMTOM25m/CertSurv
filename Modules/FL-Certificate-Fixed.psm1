# FL-Certificate.psm1 - Certificate Operations Module
# Version: v1.0.0 (Fixed)
# Date: 2025.09.09

$ModuleVersion = "v1.0.0"

<#
.SYNOPSIS
    [DE] FL-Certificate Modul - Zertifikatsoperationen für das Certificate Surveillance System
    [EN] FL-Certificate Module - Certificate operations for the Certificate Surveillance System
.DESCRIPTION
    [DE] Stellt Funktionen für das Abrufen und Validieren von SSL/TLS-Zertifikaten von Remote-Servern bereit.
    [EN] Provides functions to retrieve and validate SSL/TLS certificates from remote servers.
.NOTES
    Author: Flecki (Tom) Garnreiter
    Created: 2025.09.04
    Last Modified: 2025.09.09
    Version: v1.0.0
    Architecture: Modular Certificate Operations
    Dependencies: .NET Framework System.Net.Security, System.Security.Cryptography
#>

function Get-RemoteCertificate {
    <#
    .SYNOPSIS
        [DE] Holt SSL/TLS-Zertifikat von einem Remote-Server
        [EN] Retrieves SSL/TLS certificate from a remote server
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [object]$Config = $null
    )
    
    try {
        Write-Verbose "Attempting to retrieve certificate from $ServerName`:$Port"
        
        # Default configuration if not provided
        if (-not $Config) {
            $Config = @{
                Certificate = @{
                    Timeout = 30
                    EnableAutoPortDetection = $true
                    CommonPorts = @(443, 9443, 8443, 4443, 10443, 8080, 8081)
                    EnableBrowserCheck = $true
                }
            }
        }
        
        $timeout = if ($Config.Certificate.Timeout) { $Config.Certificate.Timeout } else { 30 }
        $enableAutoPort = if ($Config.Certificate.EnableAutoPortDetection) { $Config.Certificate.EnableAutoPortDetection } else { $true }
        $commonPorts = if ($Config.Certificate.CommonPorts) { $Config.Certificate.CommonPorts } else { @(443, 9443, 8443, 4443, 10443, 8080, 8081) }
        
        # Try socket method first
        $result = Get-CertificateViaSocket -ServerName $ServerName -Port $Port -Timeout $timeout
        
        if ($result) {
            return $result
        }
        
        # If auto port detection is enabled and primary port failed
        if ($enableAutoPort) {
            Write-Verbose "Primary port $Port failed, trying automatic port detection..."
            
            foreach ($testPort in $commonPorts) {
                if ($testPort -eq $Port) { continue } # Skip already tried port
                
                Write-Verbose "Trying port $testPort..."
                $result = Get-CertificateViaSocket -ServerName $ServerName -Port $testPort -Timeout $timeout
                
                if ($result) {
                    Write-Verbose "✓ Certificate retrieved successfully on port $testPort (auto-detected)"
                    $result | Add-Member -MemberType NoteProperty -Name "AutoDetectedPort" -Value $true -Force
                    $result | Add-Member -MemberType NoteProperty -Name "OriginalPort" -Value $Port -Force
                    return $result
                }
            }
            
            Write-Warning "No SSL certificate found on any common ports for $ServerName (tried: $($commonPorts -join ', '))"
        }
        
        return $null
    }
    catch {
        Write-Verbose "Error retrieving certificate from $ServerName`:$Port - $($_.Exception.Message)"
        return $null
    }
}

function Get-CertificateViaSocket {
    <#
    .SYNOPSIS
        [DE] Holt Zertifikat über direkte Socket-Verbindung.
        [EN] Retrieves certificate via direct socket connection.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $true)]
        [int]$Timeout
    )
    
    $tcpClient = $null
    $sslStream = $null
    $remoteCert = $null
    
    try {
        # Create TCP client with timeout
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($ServerName, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($Timeout * 1000, $false)
        
        if (-not $wait) {
            Write-Verbose "Connection timeout after $Timeout seconds"
            return $null
        }
        
        $tcpClient.EndConnect($connect)
        
        if (-not $tcpClient.Connected) {
            Write-Verbose "Failed to connect to $ServerName`:$Port"
            return $null
        }
        
        # Create SSL stream
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream())
        $sslStream.AuthenticateAsClient($ServerName)
        
        $remoteCert = $sslStream.RemoteCertificate
        
        if ($remoteCert) {
            $x509Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($remoteCert)
            
            return @{
                Success = $true
                Certificate = $x509Cert
                ServerName = $ServerName
                Port = $Port
                Method = "Socket"
                Timestamp = Get-Date
            }
        }
        
        return $null
    }
    catch {
        Write-Verbose "Socket certificate retrieval failed: $($_.Exception.Message)"
        return $null
    }
    finally {
        if ($sslStream) { $sslStream.Close() }
        if ($tcpClient) { $tcpClient.Close() }
    }
}

function Get-CertificateViaBrowser {
    <#
    .SYNOPSIS
        [DE] Holt Zertifikat über Browser-basierte HTTP-Anfrage.
        [EN] Retrieves certificate via browser-based HTTP request.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 30
    )
    
    try {
        $url = "https://$ServerName`:$Port"
        Write-Verbose "Attempting browser-based certificate retrieval from $url"
        
        # Create web request
        $request = [System.Net.WebRequest]::Create($url)
        $request.Timeout = $Timeout * 1000
        $request.Method = "HEAD"
        
        # Set TLS protocols
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        
        # Get response (this will establish SSL connection)
        $response = $request.GetResponse()
        
        # Get certificate from service point
        $servicePoint = [System.Net.ServicePointManager]::FindServicePoint($url)
        $cert = $servicePoint.Certificate
        
        if ($cert) {
            $x509Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)
            
            return @{
                Success = $true
                Certificate = $x509Cert
                ServerName = $ServerName
                Port = $Port
                Method = "Browser"
                Timestamp = Get-Date
            }
        }
        
        return $null
    }
    catch {
        Write-Verbose "Browser certificate retrieval failed: $($_.Exception.Message)"
        return $null
    }
    finally {
        if ($response) { $response.Close() }
    }
}

function Get-CertificateComparison {
    <#
    .SYNOPSIS
        [DE] Vergleicht zwei Zertifikate und gibt Unterschiede zurück.
        [EN] Compares two certificates and returns differences.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate1,
        
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate2
    )
    
    $comparison = @{
        IsSameCertificate = $false
        SubjectMatch = $false
        IssuerMatch = $false
        ThumbprintMatch = $false
        ExpiryMatch = $false
        Differences = @()
    }
    
    # Compare subjects
    $comparison.SubjectMatch = ($Certificate1.Subject -eq $Certificate2.Subject)
    if (-not $comparison.SubjectMatch) {
        $comparison.Differences += "Subject: '$($Certificate1.Subject)' vs '$($Certificate2.Subject)'"
    }
    
    # Compare issuers
    $comparison.IssuerMatch = ($Certificate1.Issuer -eq $Certificate2.Issuer)
    if (-not $comparison.IssuerMatch) {
        $comparison.Differences += "Issuer: '$($Certificate1.Issuer)' vs '$($Certificate2.Issuer)'"
    }
    
    # Compare thumbprints
    $comparison.ThumbprintMatch = ($Certificate1.Thumbprint -eq $Certificate2.Thumbprint)
    if (-not $comparison.ThumbprintMatch) {
        $comparison.Differences += "Thumbprint: '$($Certificate1.Thumbprint)' vs '$($Certificate2.Thumbprint)'"
    }
    
    # Compare expiry dates
    $comparison.ExpiryMatch = ($Certificate1.NotAfter -eq $Certificate2.NotAfter)
    if (-not $comparison.ExpiryMatch) {
        $comparison.Differences += "Expiry: '$($Certificate1.NotAfter)' vs '$($Certificate2.NotAfter)'"
    }
    
    # Overall comparison
    $comparison.IsSameCertificate = ($comparison.SubjectMatch -and $comparison.IssuerMatch -and $comparison.ThumbprintMatch -and $comparison.ExpiryMatch)
    
    return $comparison
}

Export-ModuleMember -Function @(
    'Get-RemoteCertificate',
    'Get-CertificateViaSocket', 
    'Get-CertificateViaBrowser',
    'Get-CertificateComparison'
)

Write-Verbose "FL-Certificate module v$ModuleVersion loaded successfully"

# --- End of module --- v1.0.0 ; Regelwerk: v9.3.0 ---
