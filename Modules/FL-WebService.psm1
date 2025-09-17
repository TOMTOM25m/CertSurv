#requires -Version 5.1

<#
.SYNOPSIS
    FL-WebService Module - IIS Certificate Web Service Management
.DESCRIPTION
    Provides functions for setting up and managing IIS-based certificate web services
    with HTTPS support and self-signed certificates for enhanced performance in
    certificate surveillance operations.
.AUTHOR
    System Administrator
.VERSION
    v1.0.0
.RULEBOOK
    v9.3.0
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Module-level variables
$script:ModuleName = "FL-WebService"
$script:ModuleVersion = "v1.0.0"

#----------------------------------------------------------[Functions]------------------------------------------------------------

<#
.SYNOPSIS
    Creates a new self-signed certificate for HTTPS binding
.DESCRIPTION
    Generates a self-signed SSL certificate with specified subject name and validity period
    for use with IIS HTTPS bindings in certificate surveillance operations.
.PARAMETER SubjectName
    The subject name for the certificate (e.g., "localhost", "servername.domain.com")
.PARAMETER ValidityDays
    Number of days the certificate should be valid (default: 365)
.PARAMETER LogFile
    Path to the log file for recording operations
.EXAMPLE
    New-SelfSignedCertificate -SubjectName "localhost" -ValidityDays 365 -LogFile "C:\Logs\webservice.log"
#>
function New-WebServiceCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubjectName,
        
        [Parameter(Mandatory = $false)]
        [int]$ValidityDays = 365,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    try {
        Write-Log "Creating self-signed certificate for subject: $SubjectName" -LogFile $LogFile
        
        # Create self-signed certificate
        $cert = New-SelfSignedCertificate -DnsName $SubjectName -CertStoreLocation "Cert:\LocalMachine\My" -NotAfter (Get-Date).AddDays($ValidityDays)
        
        # Copy certificate to Trusted Root Certification Authorities
        $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::Root, [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
        $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $rootStore.Add($cert)
        $rootStore.Close()
        
        Write-Log "Self-signed certificate created successfully. Thumbprint: $($cert.Thumbprint)" -LogFile $LogFile
        
        return @{
            Certificate = $cert
            Thumbprint = $cert.Thumbprint
            Subject = $cert.Subject
            NotAfter = $cert.NotAfter
        }
    }
    catch {
        Write-Log "Failed to create self-signed certificate: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
        throw
    }
}

<#
.SYNOPSIS
    Sets up IIS web service for certificate surveillance
.DESCRIPTION
    Creates and configures an IIS website with HTTPS binding for serving certificate
    data via web interface. Includes proper authentication and firewall configuration.
.PARAMETER SiteName
    Name of the IIS website to create
.PARAMETER SitePath
    Physical path for the website files
.PARAMETER HttpPort
    HTTP port for the website (default: 8080)
.PARAMETER HttpsPort
    HTTPS port for the website (default: 8443)
.PARAMETER Certificate
    SSL certificate object for HTTPS binding
.PARAMETER Config
    Configuration object containing web service settings
.PARAMETER LogFile
    Path to the log file for recording operations
.EXAMPLE
    Install-CertificateWebService -SiteName "CertSurveillance" -SitePath "C:\inetpub\wwwroot\certificates" -Certificate $cert -Config $config -LogFile $logFile
#>
function Install-CertificateWebService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        
        [Parameter(Mandatory = $true)]
        [string]$SitePath,
        
        [Parameter(Mandatory = $false)]
        [int]$HttpPort = 8080,
        
        [Parameter(Mandatory = $false)]
        [int]$HttpsPort = 8443,
        
        [Parameter(Mandatory = $true)]
        [object]$Certificate,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    try {
        Write-Log "Starting IIS web service installation for certificate surveillance" -LogFile $LogFile
        
        # 1. Create website directory
        Write-Log "Creating website directory: $SitePath" -LogFile $LogFile
        if (-not (Test-Path -Path $SitePath)) {
            New-Item -Path $SitePath -ItemType Directory -Force | Out-Null
        }
        
        # 2. Enable IIS features if needed
        Write-Log "Checking IIS installation status" -LogFile $LogFile
        $iisFeature = Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
        if ($iisFeature.State -ne "Enabled") {
            Write-Log "Installing IIS Web Server Role" -LogFile $LogFile
            Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart
        }
        
        # 3. Import WebAdministration module
        Import-Module WebAdministration -Force
        
        # 4. Unlock authentication sections
        Write-Log "Configuring IIS authentication sections" -LogFile $LogFile
        Set-WebConfiguration -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/security/authentication/anonymousAuthentication" -Metadata "overrideMode" -Value "Allow"
        Set-WebConfiguration -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/security/authentication/windowsAuthentication" -Metadata "overrideMode" -Value "Allow"
        
        # 5. Remove existing website if it exists
        if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
            Write-Log "Removing existing website: $SiteName" -LogFile $LogFile
            Remove-Website -Name $SiteName
        }
        
        # 6. Create new website with HTTP binding
        Write-Log "Creating IIS website: $SiteName on HTTP port $HttpPort" -LogFile $LogFile
        New-Website -Name $SiteName -Port $HttpPort -PhysicalPath $SitePath | Out-Null
        
        # 7. Add HTTPS binding with certificate
        Write-Log "Adding HTTPS binding on port $HttpsPort with certificate thumbprint: $($Certificate.Thumbprint)" -LogFile $LogFile
        New-WebBinding -Name $SiteName -Protocol https -Port $HttpsPort -SslFlags 0
        
        # Bind certificate to HTTPS
        $binding = Get-WebBinding -Name $SiteName -Protocol https
        $binding.AddSslCertificate($Certificate.Thumbprint, "my")
        
        # 8. Configure authentication
        Write-Log "Configuring website authentication settings" -LogFile $LogFile
        Set-WebConfigurationProperty -PSPath "IIS:\Sites\$SiteName" -Filter "system.webServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $false
        Set-WebConfigurationProperty -PSPath "IIS:\Sites\$SiteName" -Filter "system.webServer/security/authentication/windowsAuthentication" -Name "enabled" -Value $true
        
        # 9. Create firewall rules
        Write-Log "Creating firewall rules for ports $HttpPort and $HttpsPort" -LogFile $LogFile
        $httpRuleName = "CertSurveillance HTTP ($HttpPort)"
        $httpsRuleName = "CertSurveillance HTTPS ($HttpsPort)"
        
        if (-not (Get-NetFirewallRule -DisplayName $httpRuleName -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $httpRuleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $HttpPort | Out-Null
        }
        
        if (-not (Get-NetFirewallRule -DisplayName $httpsRuleName -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $httpsRuleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $HttpsPort | Out-Null
        }
        
        Write-Log "IIS web service installation completed successfully" -LogFile $LogFile
        
        return @{
            SiteName = $SiteName
            SitePath = $SitePath
            HttpUrl = "http://$(hostname):$HttpPort"
            HttpsUrl = "https://$(hostname):$HttpsPort"
            Certificate = $Certificate
        }
    }
    catch {
        Write-Log "Failed to install IIS web service: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
        throw
    }
}

<#
.SYNOPSIS
    Generates certificate data in JSON format for web service consumption
.DESCRIPTION
    Extracts certificate information from the local machine certificate store,
    filters out standard and root certificates, and formats the data as JSON
    for consumption by the web service API.
.PARAMETER Config
    Configuration object containing certificate filtering settings
.PARAMETER LogFile
    Path to the log file for recording operations
.EXAMPLE
    $certData = Get-CertificateWebData -Config $config -LogFile $logFile
#>
function Get-CertificateWebData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    try {
        Write-Log "Extracting certificate data for web service" -LogFile $LogFile
        
        # Get certificates with enhanced filtering
        $certificates = Get-ChildItem -Path Cert:\LocalMachine\ -Recurse | Where-Object {
            (-not $_.PSIsContainer) -and
            ($_.Issuer -notlike 'CN=Microsoft*') -and
            ($_.Issuer -ne $_.Subject) -and
            ($_.NotAfter -gt (Get-Date)) -and
            ($_.Subject -notlike '*DO_NOT_TRUST*') -and
            ($_.Subject -notlike '*Test*')
        }
        
        # Convert to structured data
        $certificateData = foreach ($cert in $certificates) {
            @{
                Subject = $cert.Subject
                Issuer = $cert.Issuer
                NotBefore = $cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss')
                NotAfter = $cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
                DaysRemaining = [math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
                Thumbprint = $cert.Thumbprint
                Store = $cert.PSParentPath -replace '.*\\', ''
                HasPrivateKey = $cert.HasPrivateKey
                KeyUsage = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Key Usage' } | ForEach-Object { $_.Format($false) }
            }
        }
        
        $result = @{
            GeneratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            ServerName = $env:COMPUTERNAME
            CertificateCount = $certificateData.Count
            Certificates = $certificateData
        }
        
        Write-Log "Certificate data extraction completed. Found $($certificateData.Count) certificates" -LogFile $LogFile
        
        return $result
    }
    catch {
        Write-Log "Failed to extract certificate data: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
        throw
    }
}

<#
.SYNOPSIS
    Updates the web service with current certificate data
.DESCRIPTION
    Regenerates the HTML and JSON files for the certificate web service
    with the latest certificate information from the local machine store.
.PARAMETER SitePath
    Physical path of the IIS website
.PARAMETER Config
    Configuration object containing web service settings
.PARAMETER LogFile
    Path to the log file for recording operations
.EXAMPLE
    Update-CertificateWebService -SitePath "C:\inetpub\wwwroot\certificates" -Config $config -LogFile $logFile
#>
function Update-CertificateWebService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SitePath,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    try {
        Write-Log "Updating certificate web service content" -LogFile $LogFile
        
        # Get current certificate data
        $certData = Get-CertificateWebData -Config $Config -LogFile $LogFile
        
        # Generate JSON API endpoint
        $jsonPath = Join-Path $SitePath "api\certificates.json"
        $apiDir = Split-Path $jsonPath -Parent
        if (-not (Test-Path $apiDir)) {
            New-Item -Path $apiDir -ItemType Directory -Force | Out-Null
        }
        
        $certData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding UTF8
        
        # Generate HTML interface
        $htmlContent = @"
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Certificate Surveillance - $($env:COMPUTERNAME)</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #111d4e, #5fb4e5); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
        .stat-card { background: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; border-left: 4px solid #111d4e; }
        .stat-number { font-size: 2em; font-weight: bold; color: #111d4e; }
        .stat-label { color: #666; font-size: 0.9em; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #111d4e; color: white; font-weight: 600; }
        tr:hover { background-color: #f8f9fa; }
        .status-urgent { background-color: #dc3545; color: white; padding: 4px 8px; border-radius: 4px; font-size: 0.8em; }
        .status-warning { background-color: #ffc107; color: black; padding: 4px 8px; border-radius: 4px; font-size: 0.8em; }
        .status-valid { background-color: #28a745; color: white; padding: 4px 8px; border-radius: 4px; font-size: 0.8em; }
        .refresh-btn { background: #111d4e; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; }
        .refresh-btn:hover { background: #5fb4e5; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 Certificate Surveillance Dashboard</h1>
            <p>Server: <strong>$($env:COMPUTERNAME)</strong> | Generated: <strong>$($certData.GeneratedAt)</strong></p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-number">$($certData.CertificateCount)</div>
                <div class="stat-label">Total Certificates</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$(($certData.Certificates | Where-Object { $_.DaysRemaining -le 30 }).Count)</div>
                <div class="stat-label">Expiring in 30 Days</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$(($certData.Certificates | Where-Object { $_.DaysRemaining -le 7 }).Count)</div>
                <div class="stat-label">Expiring in 7 Days</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$(($certData.Certificates | Where-Object { $_.HasPrivateKey }).Count)</div>
                <div class="stat-label">With Private Key</div>
            </div>
        </div>
        
        <button class="refresh-btn" onclick="location.reload()">🔄 Refresh Data</button>
        
        <table id="certificateTable">
            <thead>
                <tr>
                    <th>Subject</th>
                    <th>Days Remaining</th>
                    <th>Expires</th>
                    <th>Issuer</th>
                    <th>Store</th>
                    <th>Private Key</th>
                </tr>
            </thead>
            <tbody>
"@

        # Add table rows
        foreach ($cert in ($certData.Certificates | Sort-Object DaysRemaining)) {
            $statusClass = if ($cert.DaysRemaining -le 7) { "status-urgent" } 
                          elseif ($cert.DaysRemaining -le 30) { "status-warning" } 
                          else { "status-valid" }
            
            $privateKeyIcon = if ($cert.HasPrivateKey) { "🔑" } else { "❌" }
            
            $htmlContent += @"
                <tr>
                    <td>$($cert.Subject)</td>
                    <td><span class="$statusClass">$($cert.DaysRemaining) days</span></td>
                    <td>$($cert.NotAfter)</td>
                    <td>$($cert.Issuer)</td>
                    <td>$($cert.Store)</td>
                    <td>$privateKeyIcon</td>
                </tr>
"@
        }
        
        $htmlContent += @"
            </tbody>
        </table>
        
        <div style="margin-top: 30px; padding: 15px; background: #e9ecef; border-radius: 6px; font-size: 0.9em; color: #666;">
            <strong>API Endpoint:</strong> <code>/api/certificates.json</code> - Access certificate data programmatically
        </div>
    </div>
</body>
</html>
"@
        
        $htmlPath = Join-Path $SitePath "index.html"
        $htmlContent | Set-Content -Path $htmlPath -Encoding UTF8
        
        Write-Log "Web service content updated successfully. HTML: $htmlPath, JSON: $jsonPath" -LogFile $LogFile
        
        return @{
            HtmlPath = $htmlPath
            JsonPath = $jsonPath
            CertificateCount = $certData.CertificateCount
        }
    }
    catch {
        Write-Log "Failed to update web service content: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
        throw
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function @(
    'New-WebServiceCertificate',
    'Install-CertificateWebService', 
    'Get-CertificateWebData',
    'Update-CertificateWebService'
)

# --- End of module --- v1.0.0 ; Regelwerk: v9.3.0 ---