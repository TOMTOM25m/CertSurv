# FL-Certificate Module - Minimal Working Version
# Purpose: Provides certificate retrieval functionality for Certificate Surveillance System
# Author: Certificate Surveillance System
# Date: September 9, 2025

<#
.SYNOPSIS
    [DE] Holt SSL/TLS-Zertifikat von einem Remote-Server.
    [EN] Retrieves SSL/TLS certificate from a remote server.
#>
function Get-RemoteCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 443,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5000,
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableBrowserCheck = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableSocketCheck = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableAutoPortDetection = $false,
        
        [Parameter(Mandatory = $false)]
        [array]$CommonPorts = @(443, 8443, 9443, 8080, 8888, 9000)
    )
    
    Write-Verbose "Attempting to retrieve certificate from $ServerName`:$Port"
    
    # Simplified certificate retrieval - just try the basic method
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.ReceiveTimeout = $Timeout
        $tcpClient.SendTimeout = $Timeout
        
        # Connect to server
        $tcpClient.Connect($ServerName, $Port)
        
        # Create SSL stream
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, {
            param($sender, $certificate, $chain, $sslPolicyErrors)
            return $true  # Accept all certificates for retrieval
        })
        
        # Authenticate as client
        $sslStream.AuthenticateAsClient($ServerName)
        
        # Get certificate
        $cert = $sslStream.RemoteCertificate
        
        if ($cert) {
            $x509cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)
            
            # Create result object
            $result = [PSCustomObject]@{
                Subject = $x509cert.Subject
                Issuer = $x509cert.Issuer
                NotBefore = $x509cert.NotBefore
                NotAfter = $x509cert.NotAfter
                Thumbprint = $x509cert.Thumbprint
                SerialNumber = $x509cert.SerialNumber
                SignatureAlgorithm = $x509cert.SignatureAlgorithm.FriendlyName
                Version = $x509cert.Version
                HasPrivateKey = $x509cert.HasPrivateKey
                ServerName = $ServerName
                Port = $Port
                RetrievalMethod = "Socket"
                RetrievalTime = Get-Date
                DaysUntilExpiry = ($x509cert.NotAfter - (Get-Date)).Days
            }
            
            Write-Verbose "Certificate retrieved successfully from $ServerName`:$Port"
            return $result
        }
    }
    catch {
        Write-Verbose "Failed to retrieve certificate from $ServerName`:$Port`: $($_.Exception.Message)"
        
        # Try alternative ports if enabled
        if ($EnableAutoPortDetection) {
            foreach ($alternativePort in $CommonPorts) {
                if ($alternativePort -ne $Port) {
                    Write-Verbose "Trying alternative port $alternativePort..."
                    try {
                        $altResult = Get-RemoteCertificate -ServerName $ServerName -Port $alternativePort -Timeout $Timeout -EnableAutoPortDetection $false
                        if ($altResult) {
                            $altResult | Add-Member -MemberType NoteProperty -Name "AutoDetectedPort" -Value $true -Force
                            $altResult | Add-Member -MemberType NoteProperty -Name "OriginalPort" -Value $Port -Force
                            return $altResult
                        }
                    }
                    catch {
                        Write-Verbose "Alternative port $alternativePort also failed"
                    }
                }
            }
        }
    }
    finally {
        # Cleanup
        if ($sslStream) { $sslStream.Close() }
        if ($tcpClient) { $tcpClient.Close() }
    }
    
    return $null
}

<#
.SYNOPSIS
    [DE] Vereinfachte Browser-basierte Zertifikatsabfrage (Placeholder).
    [EN] Simplified browser-based certificate retrieval (Placeholder).
#>
function Get-CertificateViaBrowser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 443,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5000
    )
    
    # For now, redirect to socket method
    return Get-RemoteCertificate -ServerName $ServerName -Port $Port -Timeout $Timeout -EnableBrowserCheck $false -EnableSocketCheck $true -EnableAutoPortDetection $false
}

<#
.SYNOPSIS
    [DE] Socket-basierte Zertifikatsabfrage.
    [EN] Socket-based certificate retrieval.
#>
function Get-CertificateViaSocket {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 443,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5000
    )
    
    return Get-RemoteCertificate -ServerName $ServerName -Port $Port -Timeout $Timeout -EnableBrowserCheck $false -EnableSocketCheck $true -EnableAutoPortDetection $false
}

# Export functions
Export-ModuleMember -Function @(
    'Get-RemoteCertificate',
    'Get-CertificateViaBrowser', 
    'Get-CertificateViaSocket'
)

# --- End of module --- Minimal Working Version ---
