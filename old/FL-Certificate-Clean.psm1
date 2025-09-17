#requires -Version 5.1

<#
.SYNOPSIS
    [DE] FL-Certificate Modul - SSL/TLS-Zertifikatsabruf mit automatischer Port-Erkennung
    [EN] FL-Certificate Module - SSL/TLS certificate retrieval with automatic port detection
.DESCRIPTION
    [DE] Stellt Funktionen zum Abrufen von SSL/TLS-Zertifikaten bereit.
         Unterstützt Socket- und Browser-basierte Methoden sowie automatische Port-Erkennung.
    [EN] Provides functions for retrieving SSL/TLS certificates.
         Supports socket and browser-based methods as well as automatic port detection.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.09.04
    Last modified:  2025.09.04
    Version:        v1.0.0
    MUW-Regelwerk:  v9.3.0
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

$ModuleName = "FL-Certificate"
$ModuleVersion = "v1.1.0"

#----------------------------------------------------------[Functions]----------------------------------------------------------

function Get-RemoteCertificate {
    <#
    .SYNOPSIS
        [DE] Ruft SSL/TLS-Zertifikat von einem Remote-Server ab.
        [EN] Retrieves SSL/TLS certificate from a remote server.
    .PARAMETER ServerName
        [DE] Der FQDN des Zielservers.
        [EN] The FQDN of the target server.
    .PARAMETER Port
        [DE] Der SSL-Port (Standard: 443).
        [EN] The SSL port (default: 443).
    .PARAMETER Method
        [DE] Methode: 'Socket' oder 'Browser'.
        [EN] Method: 'Socket' or 'Browser'.
    .PARAMETER Config
        [DE] Konfigurationsobjekt.
        [EN] Configuration object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 443,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Socket', 'Browser')]
        [string]$Method = 'Browser',
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 10000,
        
        [Parameter(Mandatory = $false)]
        [object]$Config
    )
    
    # Konfigurationswerte anwenden
    if ($Config -and $Config.Certificate) {
        if ($Config.Certificate.Port -and -not $PSBoundParameters.ContainsKey('Port')) {
            $Port = $Config.Certificate.Port
        }
        if ($Config.Certificate.Timeout -and -not $PSBoundParameters.ContainsKey('Timeout')) {
            $Timeout = $Config.Certificate.Timeout
        }
        if ($Config.Certificate.Method -and -not $PSBoundParameters.ContainsKey('Method')) {
            $Method = $Config.Certificate.Method
        }
    }
    
    # Auto-Port-Detection Parameter
    $enableAutoPort = $false
    $commonPorts = @(443, 9443, 8443, 4443, 10443, 8080)
    
    if ($Config -and $Config.Certificate) {
        if ($Config.Certificate.EnableAutoPortDetection) {
            $enableAutoPort = $Config.Certificate.EnableAutoPortDetection
        }
        if ($Config.Certificate.CommonSSLPorts) {
            $commonPorts = $Config.Certificate.CommonSSLPorts
        }
    }
    
    Write-Verbose "Attempting certificate retrieval: $ServerName`:$Port using $Method"
    
    # Erste Versuch mit dem angegebenen Port
    $result = $null
    if ($Method -eq 'Browser') {
        $result = Get-CertificateViaBrowser -ServerName $ServerName -Port $Port -Timeout $Timeout
    } else {
        $result = Get-CertificateViaSocket -ServerName $ServerName -Port $Port -Timeout $Timeout
    }
    
    # Wenn erfolgreich, zurückgeben
    if ($result) {
        Write-Verbose "Certificate retrieved successfully on port $Port"
        return $result
    }
    
    # Auto-Port-Detection wenn aktiviert
    if ($enableAutoPort) {
        Write-Verbose "Primary port failed, trying auto-detection..."
        $portsToTry = $commonPorts | Where-Object { $_ -ne $Port }
        
        foreach ($testPort in $portsToTry) {
            Write-Verbose "Trying port $testPort..."
            
            if ($Method -eq 'Browser') {
                $result = Get-CertificateViaBrowser -ServerName $ServerName -Port $testPort -Timeout $Timeout
            } else {
                $result = Get-CertificateViaSocket -ServerName $ServerName -Port $testPort -Timeout $Timeout
            }
            
            if ($result) {
                Write-Verbose "Certificate found on auto-detected port $testPort"
                $result | Add-Member -NotePropertyName 'AutoDetectedPort' -NotePropertyValue $true -Force
                $result | Add-Member -NotePropertyName 'OriginalPort' -NotePropertyValue $Port -Force
                return $result
            }
        }
        Write-Warning "No certificate found on any port for $ServerName"
    }
    
    return $null
}

function Get-CertificateViaBrowser {
    <#
    .SYNOPSIS
        [DE] Holt Zertifikat über HTTP-Request (Browser-Simulation).
        [EN] Retrieves certificate via HTTP request (browser simulation).
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
    
    $remoteCert = $null
    $response = $null
    
    try {
        # URL konstruieren
        $url = if ($Port -eq 443) {
            "https://$ServerName"
        } else {
            "https://$ServerName`:$Port"
        }
        
        Write-Verbose "Browser method: Connecting to $url"
        
        # ServicePointManager konfigurieren
        $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
        
        # Zertifikat-Callback
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {
            param($senderObj, $certificate, $chain, $sslPolicyErrors)
            $script:remoteCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificate)
            return $true
        }
        
        # HTTP Request
        $request = [System.Net.HttpWebRequest]::Create($url)
        $request.Method = "HEAD"
        $request.Timeout = $Timeout
        $request.UserAgent = "Certificate-Surveillance/1.0"
        
        try {
            $response = $request.GetResponse()
        } catch [System.Net.WebException] {
            $response = $_.Exception.Response
        }
        
        if (-not $script:remoteCert) {
            throw "Could not retrieve certificate from $url"
        }
        
        # Certificate Details extrahieren
        $sanExtension = $script:remoteCert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' }
        $sans = if ($sanExtension) {
            ($sanExtension.Format($true) -split ', ' | ForEach-Object { ($_ -split '=')[1].Trim() }) -join ", "
        } else {
            "Not available"
        }
        
        $statusCode = if ($response) { 
            try { $response.StatusCode.ToString() } catch { "Unknown" } 
        } else { 
            "No Response" 
        }
        
        return [PSCustomObject]@{
            Server        = $ServerName
            Subject       = $script:remoteCert.Subject
            Issuer        = $script:remoteCert.Issuer
            NotBefore     = $script:remoteCert.NotBefore.ToString("yyyy.MM.dd HH:mm:ss")
            NotAfter      = $script:remoteCert.NotAfter.ToString("yyyy.MM.dd HH:mm:ss")
            Thumbprint    = $script:remoteCert.Thumbprint
            SANs          = $sans
            Method        = 'Browser'
            Port          = $Port
            URL           = $url
            StatusCode    = $statusCode
        }
    }
    catch {
        Write-Error "Browser method failed for ${ServerName}:${Port}: $($_.Exception.Message)"
        return $null
    }
    finally {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $originalCallback
        if ($response) { 
            try { $response.Close() } catch { }
        }
        Remove-Variable -Name remoteCert -Scope Script -ErrorAction SilentlyContinue
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
        Write-Verbose "Socket method: Connecting to ${ServerName}:${Port}"
        
        # TCP Client
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.ReceiveTimeout = $Timeout
        $tcpClient.SendTimeout = $Timeout
        
        # Verbindung herstellen
        $connectTask = $tcpClient.ConnectAsync($ServerName, $Port)
        if (-not $connectTask.Wait($Timeout)) {
            throw "Connection timeout after $Timeout ms"
        }
        
        # SSL Stream
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream())
        $sslStream.AuthenticateAsClient($ServerName)
        
        # Zertifikat abrufen
        $remoteCert = $sslStream.RemoteCertificate
        if (-not $remoteCert) {
            throw "No certificate received from server"
        }
        
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($remoteCert)
        
        # SANs extrahieren
        $sanExtension = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' }
        $sans = if ($sanExtension) {
            ($sanExtension.Format($true) -split ', ' | ForEach-Object { ($_ -split '=')[1].Trim() }) -join ", "
        } else {
            "Not available"
        }
        
        return [PSCustomObject]@{
            Server        = $ServerName
            Subject       = $cert.Subject
            Issuer        = $cert.Issuer
            NotBefore     = $cert.NotBefore.ToString("yyyy.MM.dd HH:mm:ss")
            NotAfter      = $cert.NotAfter.ToString("yyyy.MM.dd HH:mm:ss")
            Thumbprint    = $cert.Thumbprint
            SANs          = $sans
            Method        = 'Socket'
            Port          = $Port
        }
    }
    catch {
        Write-Error "Socket method failed for ${ServerName}:${Port}: $($_.Exception.Message)"
        return $null
    }
    finally {
        if ($sslStream) { $sslStream.Close() }
        if ($tcpClient) { $tcpClient.Close() }
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function @(
    'Get-RemoteCertificate',
    'Get-CertificateViaBrowser',
    'Get-CertificateViaSocket'
)

Write-Verbose "$ModuleName module v$ModuleVersion loaded successfully"

# --- End of module --- v1.1.0 ; Regelwerk: v9.3.1 ---
