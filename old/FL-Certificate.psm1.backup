#requires -Version 5.1

<#
.SYNOPSIS
    [DE] FL-Certificate Modul - Abruf und Validierung von Remote SSL/TLS-Zertifikaten
    [EN] FL-Certificate Module - Remote SSL/TLS certificate retrieval and validation
.DESCRIPTION
    [DE] Stellt Funktionen zum Abrufen und Validieren von SSL/TLS-Zertifikaten von Remote-Servern bereit.
         Unterstützt konfigurierbare Ports, Timeouts und Retry-Mechanismen.
    [EN] Provides functions to retrieve and validate SSL/TLS certificates from remote servers.
         Supports configurable ports, timeouts, and retry mechanisms.
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
$ModuleVersion = "v1.0.0"

function Get-RemoteCertificate {
    <#
    .SYNOPSIS
        [DE] Ruft das SSL/TLS-Zertifikat von einem Remote-Server ab (Socket-basiert).
        [EN] Retrieves the SSL/TLS certificate from a remote server (socket-based).
    .DESCRIPTION
        [DE] Stellt eine direkte Socket-Verbindung zu einem Server her, führt einen TLS-Handshake durch und gibt die Details des Serverzertifikats zurück.
             Unterstützt automatische Port-Erkennung für häufige SSL-Ports wenn der Standard-Port fehlschlägt.
        [EN] Establishes a direct socket connection to a server, performs a TLS handshake, and returns the server certificate details.
             Supports automatic port detection for common SSL ports if the default port fails.
    .PARAMETER ServerName
        [DE] Der vollqualifizierte Domänenname (FQDN) des Zielservers.
        [EN] The fully qualified domain name (FQDN) of the target server.
    .PARAMETER Port
        [DE] Der Port für die Verbindung. Standard ist 443. Bei Fehlschlag wird automatische Port-Erkennung versucht.
        [EN] The port to connect to. Default is 443. On failure, automatic port detection is attempted.
    .PARAMETER Method
        [DE] Abfragemethode: 'Socket' (Standard) oder 'Browser' für Browser-basierte Abfrage.
        [EN] Query method: 'Socket' (default) or 'Browser' for browser-based query.
    .PARAMETER EnableAutoPortDetection
        [DE] Aktiviert automatische Port-Erkennung wenn der Standard-Port fehlschlägt.
        [EN] Enables automatic port detection if the default port fails.
    .EXAMPLE
        Get-RemoteCertificate -ServerName "www.google.com"
        [DE] Ruft das SSL-Zertifikat von Google per Socket ab, mit automatischer Port-Erkennung.
        [EN] Retrieves the SSL certificate from Google via socket, with automatic port detection.
    .EXAMPLE
        Get-RemoteCertificate -ServerName "server.example.com" -Method Browser -EnableAutoPortDetection $true
        [DE] Ruft das SSL-Zertifikat per Browser-Request ab und probiert verschiedene Ports automatisch.
        [EN] Retrieves the SSL certificate via browser request and tries different ports automatically.
    .OUTPUTS
        [DE] PSCustomObject mit Zertifikatsdetails.
        [EN] PSCustomObject with certificate details.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $false)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Socket', 'Browser')]
        [string]$Method = 'Socket',
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableAutoPortDetection = $true,
        
        [Parameter(Mandatory = $false)]
        [object]$Config
    )
    process {
        # [DE] Konfigurationswerte setzen oder Standardwerte verwenden
        # [EN] Set configuration values or use defaults
        if ($Config) {
            if (-not $Port) { $Port = $Config.Certificate.Port }
            if (-not $Timeout) { $Timeout = $Config.Certificate.Timeout }
            if ($Config.Certificate.PSObject.Properties['EnableAutoPortDetection']) {
                $EnableAutoPortDetection = $Config.Certificate.EnableAutoPortDetection
            }
        } else {
            if (-not $Port) { $Port = 443 }
            if (-not $Timeout) { $Timeout = 10000 }
        }
        
        # [DE] Standard SSL-Ports für automatische Erkennung
        # [EN] Common SSL ports for automatic detection
        $commonSSLPorts = if ($Config -and $Config.Certificate.CommonSSLPorts) {
            $Config.Certificate.CommonSSLPorts
        } else {
            @(443, 9443, 8443, 4443, 10443, 8080, 8081)
        }
        
        # [DE] Methode wählen: Socket oder Browser
        # [EN] Choose method: Socket or Browser
        switch ($Method) {
            'Socket' {
                return Get-CertificateWithAutoPort -ServerName $ServerName -Port $Port -Timeout $Timeout -EnableAutoPortDetection $EnableAutoPortDetection -CommonPorts $commonSSLPorts -Method 'Socket'
            }
            'Browser' {
                return Get-CertificateWithAutoPort -ServerName $ServerName -Port $Port -Timeout $Timeout -EnableAutoPortDetection $EnableAutoPortDetection -CommonPorts $commonSSLPorts -Method 'Browser'
            }
        }
    }
}

function Get-CertificateWithAutoPort {
    <#
    .SYNOPSIS
        [DE] Versucht Zertifikat-Abruf mit automatischer Port-Erkennung.
        [EN] Attempts certificate retrieval with automatic port detection.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $true)]
        [int]$Timeout,
        
        [Parameter(Mandatory = $true)]
        [bool]$EnableAutoPortDetection,
        
        [Parameter(Mandatory = $true)]
        [array]$CommonPorts,
        
        [Parameter(Mandatory = $true)]
        [string]$Method
    )
    
    # [DE] Versuche zuerst den angegebenen Port
    # [EN] Try the specified port first
    Write-Verbose "Attempting certificate retrieval from $ServerName`:$Port using $Method method"
    
    $result = $null
    if ($Method -eq 'Socket') {
        $result = Get-CertificateViaSocket -ServerName $ServerName -Port $Port -Timeout $Timeout
    } else {
        $result = Get-CertificateViaBrowser -ServerName $ServerName -Port $Port -Timeout $Timeout
    }
    
    if ($result) {
        Write-Verbose "✓ Certificate retrieved successfully on port $Port"
        return $result
    }
    
    # [DE] Wenn der Standard-Port fehlschlägt und Auto-Detection aktiviert ist
    # [EN] If the default port fails and auto-detection is enabled
    if ($EnableAutoPortDetection) {
        Write-Verbose "Standard port $Port failed, trying automatic port detection..."
        
        # [DE] Entferne den bereits probierten Port aus der Liste
        # [EN] Remove the already tried port from the list
        $portsToTry = $CommonPorts | Where-Object { $_ -ne $Port }
        
        foreach ($testPort in $portsToTry) {
            Write-Verbose "Trying port $testPort..."
            
            if ($Method -eq 'Socket') {
                $result = Get-CertificateViaSocket -ServerName $ServerName -Port $testPort -Timeout $Timeout
            } else {
                $result = Get-CertificateViaBrowser -ServerName $ServerName -Port $testPort -Timeout $Timeout
            }
            
            if ($result) {
                Write-Verbose "✓ Certificate retrieved successfully on port $testPort (auto-detected)"
                $result | Add-Member -MemberType NoteProperty -Name "AutoDetectedPort" -Value $true -Force
                $result | Add-Member -MemberType NoteProperty -Name "OriginalPort" -Value $Port -Force
                return $result
            }
        }
        
        Write-Warning "No SSL certificate found on any common ports for $ServerName (tried: $($CommonPorts -join ', '))"
    }
    
    return $null
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
            # [DE] Erstelle eine temporäre Callback-Funktion, um das Zertifikat während des Handshakes abzufangen
            # [EN] Create a temporary callback function to capture the certificate during the handshake
            $callback = {
                param($senderObj, $certificate, $chain, $sslPolicyErrors)
                $script:remoteCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificate)
                return $true
            }
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $callback
            
            # [DE] TCP-Verbindung mit Timeout herstellen
            # [EN] Establish TCP connection with timeout
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.ReceiveTimeout = $Timeout
            $tcpClient.SendTimeout = $Timeout
            
            $connectTask = $tcpClient.ConnectAsync($ServerName, $Port)
            if (-not $connectTask.Wait($Timeout)) {
                throw "Connection timeout after $Timeout ms"
            }
            
            # [DE] SSL-Stream über die TCP-Verbindung legen
            # [EN] Create SSL stream over the TCP connection
            $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream())
            $sslStream.AuthenticateAsClient($ServerName)
            Wait-Event -Timeout 5 | Out-Null
            
            if (-not $script:remoteCert) {
                throw "Could not retrieve certificate from server '$ServerName' on port '$Port'."
            }
            
            # [DE] SANs (Subject Alternative Names) aus den Erweiterungen extrahieren
            # [EN] Extract SANs (Subject Alternative Names) from extensions
            $sanExtension = $script:remoteCert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' }
            $sans = if ($sanExtension) {
                ($sanExtension.Format($true) -split ', ' | ForEach-Object { ($_ -split '=')[1].Trim() }) -join ", "
            } else {
                "Not available"
            }
            
            return [PSCustomObject]@{
                Server        = $ServerName
                Subject       = $script:remoteCert.Subject
                Issuer        = $script:remoteCert.Issuer
                NotBefore     = $script:remoteCert.NotBefore.ToString("yyyy.MM.dd HH:mm:ss")
                NotAfter      = $script:remoteCert.NotAfter.ToString("yyyy.MM.dd HH:mm:ss")
                Thumbprint    = $script:remoteCert.Thumbprint
                SANs          = $sans
                Method        = 'Socket'
                Port          = $Port
            }
        }
        catch {
            Write-Error "Error retrieving certificate for '$ServerName' via Socket: $($_.Exception.Message)"
            return $null
        }
        finally {
            # [DE] WICHTIG: Streams schließen und den Callback zurücksetzen
            # [EN] IMPORTANT: Close streams and reset the callback
            if ($sslStream) { $sslStream.Close() }
            if ($tcpClient) { $tcpClient.Close() }
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
            Remove-Variable -Name remoteCert -Scope Script -ErrorAction SilentlyContinue
        }
    }

function Get-CertificateViaBrowser {
    <#
    .SYNOPSIS
        [DE] Holt Zertifikat über Browser-ähnlichen HTTP(S) Request.
        [EN] Retrieves certificate via browser-like HTTP(S) request.
    .DESCRIPTION
        [DE] Verwendet WebRequest/HttpWebRequest um das Zertifikat wie ein Browser abzurufen.
             Diese Methode zeigt das Zertifikat, das ein echter Browser sehen würde.
        [EN] Uses WebRequest/HttpWebRequest to retrieve the certificate like a browser would.
             This method shows the certificate that a real browser would see.
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
        # [DE] URL konstruieren (normalerweise HTTPS für Zertifikatsabfrage)
        # [EN] Construct URL (usually HTTPS for certificate query)
        $url = if ($Port -eq 443) {
            "https://$ServerName"
        } else {
            "https://$ServerName`:$Port"
        }
        
        Write-Verbose "Retrieving certificate via Browser method from: $url"
        
        # [DE] ServicePointManager konfigurieren für Zertifikatszugriff
        # [EN] Configure ServicePointManager for certificate access
        $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
        $originalSecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol
        
        # [DE] Alle TLS-Versionen aktivieren (Best Practice: System Default verwenden)
        # [EN] Enable all TLS versions (Best Practice: use system default)
        if ($Global:IsPowerShell5) {
            # PowerShell 5.1 benötigt explizite TLS-Konfiguration
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12, [System.Net.SecurityProtocolType]::Tls13 # DevSkim: ignore DS440000 # DevSkim: ignore DS440020 # DevSkim: ignore DS440020
        }
        # PowerShell 7+ verwendet automatisch die neuesten TLS-Versionen
        
        # [DE] Callback zum Zertifikat abfangen
        # [EN] Callback to capture certificate
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {
            param($senderObj, $certificate, $chain, $sslPolicyErrors)
            $script:remoteCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificate)
            return $true  # Accept all certificates to get the certificate data
        }
        
        # [DE] HTTP Request erstellen
        # [EN] Create HTTP request
        $request = [System.Net.HttpWebRequest]::Create($url)
        $request.Method = "HEAD"  # Only need headers, not content
        $request.Timeout = $Timeout
        $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Certificate-Surveillance/1.0"
        $request.AllowAutoRedirect = $false  # Don't follow redirects
        
        # [DE] Request ausführen
        # [EN] Execute request
        try {
            $response = $request.GetResponse()
        } catch [System.Net.WebException] {
            # [DE] Auch bei HTTP-Fehlern können wir das Zertifikat erhalten haben
            # [EN] Even with HTTP errors, we might have obtained the certificate
            $response = $_.Exception.Response
        }
        
        if (-not $script:remoteCert) {
            throw "Could not retrieve certificate from server '$ServerName' via Browser method."
        }
        
        # [DE] SANs (Subject Alternative Names) aus den Erweiterungen extrahieren
        # [EN] Extract SANs (Subject Alternative Names) from extensions
        $sanExtension = $script:remoteCert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' }
        $sans = if ($sanExtension) {
            ($sanExtension.Format($true) -split ', ' | ForEach-Object { ($_ -split '=')[1].Trim() }) -join ", "
        } else {
            "Not available"
        }
        
        # [DE] Browser-spezifische Informationen hinzufügen
        # [EN] Add browser-specific information
        $statusCode = if ($response) { 
            try { $response.StatusCode } catch { "Unknown" } 
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
        Write-Error "Error retrieving certificate for '$ServerName' via Browser: $($_.Exception.Message)"
        return $null
    }
    finally {
        # [DE] ServicePointManager zurücksetzen
        # [EN] Reset ServicePointManager
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $originalCallback
        [System.Net.ServicePointManager]::SecurityProtocol = $originalSecurityProtocol
        
        if ($response) { 
            try { $response.Close() } catch { }
        }
        Remove-Variable -Name remoteCert -Scope Script -ErrorAction SilentlyContinue
    }
}

function Get-CertificateComparison {
    <#
    .SYNOPSIS
        [DE] Vergleicht Zertifikate von Socket- und Browser-Methode.
        [EN] Compares certificates from Socket and Browser methods.
    .DESCRIPTION
        [DE] Ruft das Zertifikat sowohl über Socket als auch über Browser ab und vergleicht die Ergebnisse.
             Hilfreich um Unterschiede zwischen direkter SSL-Verbindung und Browser-Sicht zu erkennen.
        [EN] Retrieves the certificate via both Socket and Browser methods and compares the results.
             Helpful to detect differences between direct SSL connection and browser view.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 443,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 10000,
        
        [Parameter(Mandatory = $false)]
        [object]$Config
    )
    
    # [DE] Konfigurationswerte anwenden
    # [EN] Apply configuration values
    if ($Config) {
        if ($Config.Certificate.Port) { $Port = $Config.Certificate.Port }
        if ($Config.Certificate.Timeout) { $Timeout = $Config.Certificate.Timeout }
    }
    
    Write-Verbose "Comparing certificates for $ServerName using both Socket and Browser methods"
    
    # [DE] Beide Methoden parallel ausführen
    # [EN] Execute both methods in parallel
    $socketResult = Get-CertificateViaSocket -ServerName $ServerName -Port $Port -Timeout $Timeout
    $browserResult = Get-CertificateViaBrowser -ServerName $ServerName -Port $Port -Timeout $Timeout
    
    # [DE] Vergleichsergebnis erstellen
    # [EN] Create comparison result
    $comparison = [PSCustomObject]@{
        Server = $ServerName
        Port = $Port
        SocketResult = $socketResult
        BrowserResult = $browserResult
        CertificatesMatch = $false
        Differences = @()
    }
    
    if ($socketResult -and $browserResult) {
        # [DE] Zertifikate vergleichen
        # [EN] Compare certificates
        $comparison.CertificatesMatch = ($socketResult.Thumbprint -eq $browserResult.Thumbprint)
        
        if (-not $comparison.CertificatesMatch) {
            $comparison.Differences += "Different certificates: Socket=$($socketResult.Thumbprint) vs Browser=$($browserResult.Thumbprint)"
        }
        
        # [DE] Weitere Unterschiede prüfen
        # [EN] Check for other differences
        if ($socketResult.Subject -ne $browserResult.Subject) {
            $comparison.Differences += "Different subjects: Socket='$($socketResult.Subject)' vs Browser='$($browserResult.Subject)'"
        }
        
        if ($socketResult.Issuer -ne $browserResult.Issuer) {
            $comparison.Differences += "Different issuers: Socket='$($socketResult.Issuer)' vs Browser='$($browserResult.Issuer)'"
        }
    }
    
    return $comparison
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function @(
    'Get-RemoteCertificate',
    'Get-CertificateViaSocket', 
    'Get-CertificateViaBrowser',
    'Get-CertificateComparison'
)

Write-Verbose "FL-Certificate module v$ModuleVersion loaded successfully"

# --- End of module --- v1.0.0 ; Regelwerk: v9.3.0 ---
