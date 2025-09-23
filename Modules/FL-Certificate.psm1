#requires -Version 5.1

<#
.SYNOPSIS
    FL-Certificate Module v1.2.0 - Certificate Processing Core Functions
.DESCRIPTION
    Core certificate processing functions for the Certificate Surveillance System.
    Handles local and remote certificate enumeration, validation, and analysis.
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.2.0
    Regelwerk: v9.4.0 (PowerShell Version Adaptation)
    Dependencies: FL-Logging, FL-Config, FL-Utils
#>

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "FL-Certificate - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

#----------------------------------------------------------[Initialisations]--------------------------------------------------------
Set-StrictMode -Version Latest

# Global module information
$Global:ModuleVersion = "v1.2.0"
$Global:RulebookVersion = "v9.4.0"

#----------------------------------------------------------[Functions]--------------------------------------------------------

function Get-LocalCertificates {
    <#
    .SYNOPSIS
        Retrieves certificates from local certificate stores
    .DESCRIPTION
        Enumerates certificates from LocalMachine and CurrentUser stores
    .PARAMETER StoreLocation
        Certificate store location (LocalMachine, CurrentUser, or Both)
    .PARAMETER StoreName
        Certificate store name (My, Root, CA, etc.)
    .PARAMETER ExcludeMicrosoft
        Exclude Microsoft certificates
    .EXAMPLE
        Get-LocalCertificates -StoreLocation LocalMachine -StoreName My
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('LocalMachine', 'CurrentUser', 'Both')]
        [string]$StoreLocation = 'LocalMachine',
        
        [Parameter(Mandatory = $false)]
        [string]$StoreName = 'My',
        
        [Parameter(Mandatory = $false)]
        [switch]$ExcludeMicrosoft,
        
        [Parameter(Mandatory = $false)]
        [switch]$ActiveOnly
    )
    
    try {
        $certificates = @()
        $storeLocations = switch ($StoreLocation) {
            'Both' { @('LocalMachine', 'CurrentUser') }
            default { @($StoreLocation) }
        }
        
        foreach ($location in $storeLocations) {
            Write-Verbose "Checking store: $location\$StoreName"
            
            try {
                $store = Get-ChildItem "Cert:\$location\$StoreName" -ErrorAction SilentlyContinue
                
                foreach ($cert in $store) {
                    # Apply filters
                    if ($ActiveOnly -and $cert.NotAfter -le (Get-Date)) {
                        continue
                    }
                    
                    if ($ExcludeMicrosoft -and (
                        $cert.Subject -like '*Microsoft*' -or
                        $cert.Issuer -like '*Microsoft*' -or
                        $cert.Subject -like '*Windows*' -or
                        $cert.Subject -like '*DO_NOT_TRUST*'
                    )) {
                        continue
                    }
                    
                    $certificates += @{
                        Subject = $cert.Subject
                        Issuer = $cert.Issuer
                        NotBefore = $cert.NotBefore
                        NotAfter = $cert.NotAfter
                        DaysRemaining = [math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
                        Thumbprint = $cert.Thumbprint
                        HasPrivateKey = $cert.HasPrivateKey
                        Store = "$location\$StoreName"
                        SerialNumber = $cert.SerialNumber
                        KeyAlgorithm = $cert.PublicKey.Oid.FriendlyName
                        SignatureAlgorithm = $cert.SignatureAlgorithm.FriendlyName
                        Version = $cert.Version
                        Extensions = $cert.Extensions.Count
                    }
                }
            } catch {
                Write-Warning "Failed to access certificate store ${location}\${StoreName}: $($_.Exception.Message)"
            }
        }
        
        Write-Verbose "Found $($certificates.Count) certificates in $StoreLocation\$StoreName"
        return $certificates
        
    } catch {
        Write-Error "Failed to retrieve local certificates: $($_.Exception.Message)"
        throw
    }
}

function Get-RemoteCertificates {
    <#
    .SYNOPSIS
        Retrieves certificates from remote servers
    .DESCRIPTION
        Uses PowerShell remoting to get certificates from remote servers
    .PARAMETER ComputerName
        Remote computer name or FQDN
    .PARAMETER Credential
        Credentials for remote access
    .EXAMPLE
        Get-RemoteCertificates -ComputerName "server01.domain.com"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [string]$StoreName = 'My',
        
        [Parameter(Mandatory = $false)]
        [switch]$ExcludeMicrosoft,
        
        [Parameter(Mandatory = $false)]
        [switch]$ActiveOnly
    )
    
    try {
        $sessionParams = @{
            ComputerName = $ComputerName
            ErrorAction = 'Stop'
        }
        
        if ($Credential) {
            $sessionParams.Credential = $Credential
        }
        
        $session = New-PSSession @sessionParams
        
        try {
            $certificates = Invoke-Command -Session $session -ScriptBlock {
                param($StoreName, $ExcludeMicrosoft, $ActiveOnly)
                
                try {
                    $certs = Get-ChildItem "Cert:\LocalMachine\$StoreName" -ErrorAction SilentlyContinue
                    $results = @()
                    
                    foreach ($cert in $certs) {
                        # Apply filters
                        if ($ActiveOnly -and $cert.NotAfter -le (Get-Date)) {
                            continue
                        }
                        
                        if ($ExcludeMicrosoft -and (
                            $cert.Subject -like '*Microsoft*' -or
                            $cert.Issuer -like '*Microsoft*' -or
                            $cert.Subject -like '*Windows*' -or
                            $cert.Subject -like '*DO_NOT_TRUST*'
                        )) {
                            continue
                        }
                        
                        $results += @{
                            Subject = $cert.Subject
                            Issuer = $cert.Issuer
                            NotBefore = $cert.NotBefore
                            NotAfter = $cert.NotAfter
                            DaysRemaining = [math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
                            Thumbprint = $cert.Thumbprint
                            HasPrivateKey = $cert.HasPrivateKey
                            Store = "LocalMachine\$StoreName"
                            SerialNumber = $cert.SerialNumber
                            ServerName = $env:COMPUTERNAME
                        }
                    }
                    
                    return $results
                    
                } catch {
                    throw "Failed to retrieve certificates: $($_.Exception.Message)"
                }
                
            } -ArgumentList $StoreName, $ExcludeMicrosoft.IsPresent, $ActiveOnly.IsPresent
            
            Write-Verbose "Retrieved $($certificates.Count) certificates from $ComputerName"
            return $certificates
            
        } finally {
            Remove-PSSession $session
        }
        
    } catch {
        Write-Error "Failed to retrieve certificates from ${ComputerName}: $($_.Exception.Message)"
        throw
    }
}

function Test-CertificateExpiry {
    <#
    .SYNOPSIS
        Tests certificate expiry and returns warning levels
    .DESCRIPTION
        Analyzes certificate expiration dates and returns appropriate warning levels
    .PARAMETER Certificate
        Certificate object to test
    .PARAMETER WarningDays
        Days before expiry to trigger warning
    .PARAMETER CriticalDays
        Days before expiry to trigger critical alert
    .EXAMPLE
        Test-CertificateExpiry -Certificate $cert -WarningDays 30 -CriticalDays 7
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Certificate,
        
        [Parameter(Mandatory = $false)]
        [int]$WarningDays = 30,
        
        [Parameter(Mandatory = $false)]
        [int]$CriticalDays = 7
    )
    
    try {
        $daysRemaining = $Certificate.DaysRemaining
        
        $status = @{
            DaysRemaining = $daysRemaining
            IsExpired = $daysRemaining -le 0
            IsCritical = $daysRemaining -le $CriticalDays -and $daysRemaining -gt 0
            IsWarning = $daysRemaining -le $WarningDays -and $daysRemaining -gt $CriticalDays
            IsValid = $daysRemaining -gt $WarningDays
            Level = switch ($true) {
                ($daysRemaining -le 0) { 'EXPIRED' }
                ($daysRemaining -le $CriticalDays) { 'CRITICAL' }
                ($daysRemaining -le $WarningDays) { 'WARNING' }
                default { 'OK' }
            }
            Color = switch ($true) {
                ($daysRemaining -le 0) { 'Red' }
                ($daysRemaining -le $CriticalDays) { 'Red' }
                ($daysRemaining -le $WarningDays) { 'Yellow' }
                default { 'Green' }
            }
        }
        
        return $status
        
    } catch {
        Write-Error "Failed to test certificate expiry: $($_.Exception.Message)"
        throw
    }
}

function Get-CertificateHealth {
    <#
    .SYNOPSIS
        Performs comprehensive certificate health check
    .DESCRIPTION
        Analyzes certificate for various health indicators
    .PARAMETER Certificate
        Certificate object to analyze
    .EXAMPLE
        Get-CertificateHealth -Certificate $cert
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Certificate
    )
    
    try {
        $health = @{
            Subject = $Certificate.Subject
            Thumbprint = $Certificate.Thumbprint
            IsValid = $true
            Issues = @()
            Recommendations = @()
            Score = 100
        }
        
        # Check expiry
        $expiryStatus = Test-CertificateExpiry -Certificate $Certificate
        if ($expiryStatus.IsExpired) {
            $health.Issues += "Certificate has expired"
            $health.Score -= 50
            $health.IsValid = $false
        } elseif ($expiryStatus.IsCritical) {
            $health.Issues += "Certificate expires in $($Certificate.DaysRemaining) days"
            $health.Score -= 30
        } elseif ($expiryStatus.IsWarning) {
            $health.Issues += "Certificate expires soon ($($Certificate.DaysRemaining) days)"
            $health.Score -= 10
        }
        
        # Check private key
        if (-not $Certificate.HasPrivateKey) {
            $health.Issues += "No private key present"
            $health.Score -= 20
        }
        
        # Check signature algorithm
        if ($Certificate.SignatureAlgorithm -like '*SHA1*') {
            $health.Issues += "Uses weak SHA1 signature algorithm"
            $health.Recommendations += "Upgrade to SHA256 or higher"
            $health.Score -= 15
        }
        
        # Check key length (basic heuristic)
        if ($Certificate.KeyAlgorithm -like '*RSA*' -and $Certificate.Subject -notlike '*1024*' -and $Certificate.Subject -notlike '*2048*' -and $Certificate.Subject -notlike '*4096*') {
            # Can't easily determine key length from basic certificate object
            $health.Recommendations += "Verify RSA key length (minimum 2048 bits recommended)"
        }
        
        # Overall health determination
        $health.OverallHealth = switch ($health.Score) {
            {$_ -ge 90} { 'EXCELLENT' }
            {$_ -ge 70} { 'GOOD' }
            {$_ -ge 50} { 'FAIR' }
            {$_ -ge 30} { 'POOR' }
            default { 'CRITICAL' }
        }
        
        return $health
        
    } catch {
        Write-Error "Failed to analyze certificate health: $($_.Exception.Message)"
        throw
    }
}

function Export-CertificateReport {
    <#
    .SYNOPSIS
        Exports certificate data to various formats
    .DESCRIPTION
        Creates reports in JSON, CSV, or HTML format
    .PARAMETER Certificates
        Array of certificate objects
    .PARAMETER OutputPath
        Output file path
    .PARAMETER Format
        Output format (JSON, CSV, HTML)
    .EXAMPLE
        Export-CertificateReport -Certificates $certs -OutputPath "report.json" -Format JSON
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Certificates,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('JSON', 'CSV', 'HTML')]
        [string]$Format = 'JSON'
    )
    
    try {
        $reportData = @{
            GeneratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            TotalCertificates = $Certificates.Count
            ModuleVersion = $Global:ModuleVersion
            Certificates = $Certificates
            Summary = @{
                Expired = ($Certificates | Where-Object { $_.DaysRemaining -le 0 }).Count
                Critical = ($Certificates | Where-Object { $_.DaysRemaining -le 7 -and $_.DaysRemaining -gt 0 }).Count
                Warning = ($Certificates | Where-Object { $_.DaysRemaining -le 30 -and $_.DaysRemaining -gt 7 }).Count
                Valid = ($Certificates | Where-Object { $_.DaysRemaining -gt 30 }).Count
            }
        }
        
        switch ($Format) {
            'JSON' {
                $reportData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
            }
            'CSV' {
                $Certificates | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
            }
            'HTML' {
                # Basic HTML report
                $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Certificate Report - $((Get-Date).ToString('yyyy-MM-dd'))</title>
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .expired { background-color: #ffebee; }
        .critical { background-color: #fff3e0; }
        .warning { background-color: #fffbf0; }
    </style>
</head>
<body>
    <h1>Certificate Report</h1>
    <p>Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))</p>
    <p>Total Certificates: $($Certificates.Count)</p>
    
    <h2>Summary</h2>
    <ul>
        <li>Expired: $($reportData.Summary.Expired)</li>
        <li>Critical (≤7 days): $($reportData.Summary.Critical)</li>
        <li>Warning (≤30 days): $($reportData.Summary.Warning)</li>
        <li>Valid (>30 days): $($reportData.Summary.Valid)</li>
    </ul>
    
    <h2>Certificate Details</h2>
    <table>
        <tr>
            <th>Subject</th>
            <th>Issuer</th>
            <th>Expires</th>
            <th>Days Remaining</th>
            <th>Status</th>
        </tr>
"@
                foreach ($cert in $Certificates) {
                    $cssClass = switch ($true) {
                        ($cert.DaysRemaining -le 0) { 'expired' }
                        ($cert.DaysRemaining -le 7) { 'critical' }
                        ($cert.DaysRemaining -le 30) { 'warning' }
                        default { '' }
                    }
                    
                    $html += @"
        <tr class="$cssClass">
            <td>$($cert.Subject)</td>
            <td>$($cert.Issuer)</td>
            <td>$($cert.NotAfter.ToString('yyyy-MM-dd'))</td>
            <td>$($cert.DaysRemaining)</td>
            <td>$(Test-CertificateExpiry -Certificate $cert | Select-Object -ExpandProperty Level)</td>
        </tr>
"@
                }
                
                $html += @"
    </table>
</body>
</html>
"@
                $html | Set-Content -Path $OutputPath -Encoding UTF8
            }
        }
        
        Write-Verbose "Certificate report exported to: $OutputPath"
        
    } catch {
        Write-Error "Failed to export certificate report: $($_.Exception.Message)"
        throw
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

# Export functions
Export-ModuleMember -Function @(
    'Get-LocalCertificates',
    'Get-RemoteCertificates', 
    'Test-CertificateExpiry',
    'Get-CertificateHealth',
    'Export-CertificateReport'
)

Write-Verbose "FL-Certificate module loaded successfully (v$Global:ModuleVersion - Regelwerk $Global:RulebookVersion)"

# --- End of module --- v1.2.0 ; Regelwerk: v9.4.0 ---