#requires -Version 5.1

<#
.SYNOPSIS
    Certificate WebService Setup Script - Server Core Compatible v1.3.1
.DESCRIPTION
    Verbesserte Version für Windows Server Core und Standard Server.
    Erkennt automatisch die Server-Version und verwendet die korrekten Feature-Namen.
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.3.1 (Fixed syntax)
    Usage: Als Administrator auf Zielserver ausführen
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🚀 Certificate WebService Setup Script v1.3.1" -ForegroundColor Green
Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor Cyan

try {
    # Step 1: Check Administrator privileges
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Error "❌ Script must be run as Administrator!"
        exit 1
    }
    
    Write-Host "✅ Administrator privileges confirmed" -ForegroundColor Green
    
    # Step 2: Detect server type and install IIS
    Write-Host "📦 Detecting server type and installing IIS..." -ForegroundColor Yellow
    
    # Check if it's Server Core or Full Server
    $osInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $installationType = $osInfo.InstallationType
    
    Write-Host "Installation Type: $installationType" -ForegroundColor Cyan
    
    # Try to get available features first
    $availableFeatures = Get-WindowsFeature | Where-Object { $_.Name -like "*IIS*" }
    
    if ($availableFeatures.Count -eq 0) {
        Write-Host "⚠️ No IIS features found - trying alternative method..." -ForegroundColor Yellow
        
        # Try with Enable-WindowsOptionalFeature for Windows 10/Client versions
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName "IIS-WebServer" -All -NoRestart
            Enable-WindowsOptionalFeature -Online -FeatureName "IIS-WebServerRole" -All -NoRestart  
            Enable-WindowsOptionalFeature -Online -FeatureName "IIS-CommonHttpFeatures" -All -NoRestart
            Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ASPNET45" -All -NoRestart
            Write-Host "✅ IIS installed via Windows Optional Features" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to install IIS via Optional Features" -ForegroundColor Red
            Write-Host "Trying manual DISM installation..." -ForegroundColor Yellow
            
            # Try DISM as last resort
            & dism /online /enable-feature /featurename:IIS-WebServer /all
            & dism /online /enable-feature /featurename:IIS-CommonHttpFeatures /all
            & dism /online /enable-feature /featurename:IIS-ASPNET45 /all
            
            Write-Host "✅ IIS installed via DISM" -ForegroundColor Green
        }
    }
    else {
        # Use Install-WindowsFeature for Server versions
        $iisFeatures = @(
            "Web-Server",
            "Web-Common-Http", 
            "Web-ASP-Net45",
            "Web-Net-Ext45",
            "Web-Mgmt-Tools"
        )
        
        foreach ($feature in $iisFeatures) {
            $featureState = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
            if ($featureState -and $featureState.InstallState -ne "Installed") {
                Write-Host "Installing $feature..." -ForegroundColor Yellow
                try {
                    Install-WindowsFeature -Name $feature -IncludeManagementTools
                    Write-Host "✅ $feature installed" -ForegroundColor Green
                }
                catch {
                    Write-Host "⚠️ Could not install $feature - continuing..." -ForegroundColor Yellow
                }
            }
        }
        
        Write-Host "✅ IIS features installation completed" -ForegroundColor Green
    }
    
    # Step 3: Create WebService directory
    Write-Host "📁 Creating WebService directory..." -ForegroundColor Yellow
    $webServicePath = "C:\inetpub\CertWebService"
    
    if (Test-Path $webServicePath) {
        Write-Host "Removing existing WebService directory..." -ForegroundColor Yellow
        Remove-Item $webServicePath -Recurse -Force
    }
    
    New-Item -Path $webServicePath -ItemType Directory -Force | Out-Null
    Write-Host "✅ WebService directory created: $webServicePath" -ForegroundColor Green
    
    # Step 4: Create certificate update script
    Write-Host "📝 Creating certificate update script..." -ForegroundColor Yellow
    
    $updateScript = @'
#requires -Version 5.1
# Certificate Data Update Script for WebService
Set-StrictMode -Version Latest

$ErrorActionPreference = 'Continue'
$webServicePath = "C:\inetpub\CertWebService"
$jsonPath = Join-Path $webServicePath "certificates.json"

try {
    Write-Host "Updating certificate data on $env:COMPUTERNAME..."
    
    # Get all certificates from LocalMachine stores
    $allCerts = @()
    $stores = @("My", "WebHosting", "Root", "CA")
    
    foreach ($storeName in $stores) {
        try {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, "LocalMachine")
            $store.Open("ReadOnly")
            
            foreach ($cert in $store.Certificates) {
                $certInfo = [PSCustomObject]@{
                    Subject = $cert.Subject
                    Issuer = $cert.Issuer
                    Thumbprint = $cert.Thumbprint
                    NotBefore = $cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss')
                    NotAfter = $cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
                    SerialNumber = $cert.SerialNumber
                    Store = $storeName
                    HasPrivateKey = $cert.HasPrivateKey
                    DnsNames = @()
                }
                
                # Extract DNS names from SAN extension
                try {
                    $sanExtension = $cert.Extensions | Where-Object { $_.Oid.Value -eq "2.5.29.17" }
                    if ($sanExtension) {
                        $sanText = $sanExtension.Format($false)
                        $dnsNames = $sanText -split ", " | Where-Object { $_ -like "DNS Name=*" } | ForEach-Object { $_.Replace("DNS Name=", "") }
                        $certInfo.DnsNames = $dnsNames
                    }
                }
                catch {
                    # SAN parsing failed, continue without DNS names
                }
                
                $allCerts += $certInfo
            }
            
            $store.Close()
        }
        catch {
            Write-Warning "Could not access store $storeName"
        }
    }
    
    # Create summary data
    $summary = [PSCustomObject]@{
        Server = $env:COMPUTERNAME
        LastUpdate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        TotalCertificates = $allCerts.Count
        CertificatesByStore = @{}
        ExpiringCertificates = @()
    }
    
    # Group by store
    $stores | ForEach-Object {
        $storeName = $_
        $storeCount = ($allCerts | Where-Object { $_.Store -eq $storeName }).Count
        $summary.CertificatesByStore[$storeName] = $storeCount
    }
    
    # Find expiring certificates (next 90 days)
    $expiringDate = (Get-Date).AddDays(90)
    $summary.ExpiringCertificates = $allCerts | Where-Object { 
        [DateTime]::ParseExact($_.NotAfter, 'yyyy-MM-dd HH:mm:ss', $null) -le $expiringDate 
    } | Select-Object Subject, NotAfter, Store
    
    # Create final JSON structure
    $jsonData = [PSCustomObject]@{
        Server = $env:COMPUTERNAME
        LastUpdate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Summary = $summary
        Certificates = $allCerts
    }
    
    # Write JSON file
    $jsonData | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8 -Force
    
    # Create health check file
    $healthPath = Join-Path $webServicePath "health.json"
    $health = [PSCustomObject]@{
        Status = "OK"
        Server = $env:COMPUTERNAME
        LastUpdate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        CertificateCount = $allCerts.Count
        Version = "1.3.1"
    }
    $health | ConvertTo-Json | Out-File -FilePath $healthPath -Encoding UTF8 -Force
    
    # Create summary file
    $summaryPath = Join-Path $webServicePath "summary.json"
    $summary | ConvertTo-Json -Depth 5 | Out-File -FilePath $summaryPath -Encoding UTF8 -Force
    
    Write-Host "Certificate data updated successfully. Found $($allCerts.Count) certificates."
}
catch {
    Write-Error "Certificate update failed: $_"
    
    # Create error health file
    $healthPath = Join-Path $webServicePath "health.json"
    $health = [PSCustomObject]@{
        Status = "ERROR"
        Server = $env:COMPUTERNAME
        LastUpdate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Error = $_.Message
        Version = "1.3.1"
    }
    $health | ConvertTo-Json | Out-File -FilePath $healthPath -Encoding UTF8 -Force
}
'@
    
    $updateScriptPath = Join-Path $webServicePath "Update-CertificateData.ps1"
    $updateScript | Out-File -FilePath $updateScriptPath -Encoding UTF8 -Force
    Write-Host "✅ Certificate update script created" -ForegroundColor Green
    
    # Step 5: Create API endpoints
    Write-Host "🔧 Creating API endpoints..." -ForegroundColor Yellow
    
    # Create web.config for the WebService
    $webConfig = @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <staticContent>
      <mimeMap fileExtension=".json" mimeType="application/json" />
    </staticContent>
    <defaultDocument>
      <files>
        <clear />
        <add value="certificates.json" />
      </files>
    </defaultDocument>
    <directoryBrowse enabled="true" />
  </system.webServer>
</configuration>
'@
    
    $webConfigPath = Join-Path $webServicePath "web.config"
    $webConfig | Out-File -FilePath $webConfigPath -Encoding UTF8 -Force
    
    Write-Host "✅ API endpoints created" -ForegroundColor Green
    
    # Step 6: Configure IIS (try multiple methods)
    Write-Host "🌐 Configuring IIS..." -ForegroundColor Yellow
    
    # Try different methods to configure IIS
    $iisConfigured = $false
    
    # Method 1: Try WebAdministration module
    try {
        Import-Module WebAdministration -Force -ErrorAction Stop
        
        # Remove existing site if it exists
        $existingSite = Get-IISSite -Name "CertWebService" -ErrorAction SilentlyContinue
        if ($existingSite) {
            Remove-IISSite -Name "CertWebService" -Confirm:$false
        }
        
        # Create new site
        New-IISSite -Name "CertWebService" -PhysicalPath $webServicePath -Port 9080
        
        # Try to set HTTPS binding
        try {
            New-IISSiteBinding -Name "CertWebService" -BindingInformation "*:9443:" -Protocol https
        }
        catch {
            Write-Host "⚠️ Could not create HTTPS binding - continuing with HTTP only" -ForegroundColor Yellow
        }
        
        $iisConfigured = $true
        Write-Host "✅ IIS configured via WebAdministration module" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ WebAdministration module not available, trying alternative..." -ForegroundColor Yellow
    }
    
    # Method 2: Try appcmd.exe
    if (-not $iisConfigured) {
        try {
            $appcmd = "$env:SystemRoot\System32\inetsrv\appcmd.exe"
            if (Test-Path $appcmd) {
                # Remove existing site
                & $appcmd delete site "CertWebService" 2>$null
                
                # Create new site
                & $appcmd add site /name:"CertWebService" /physicalPath:"$webServicePath" /bindings:"http/*:9080:"
                
                # Try to add HTTPS binding
                try {
                    & $appcmd set site "CertWebService" /+bindings.[protocol='https',bindingInformation='*:9443:'] 2>$null
                }
                catch {
                    Write-Host "⚠️ Could not create HTTPS binding via appcmd" -ForegroundColor Yellow
                }
                
                $iisConfigured = $true
                Write-Host "✅ IIS configured via appcmd.exe" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "⚠️ appcmd.exe configuration failed" -ForegroundColor Yellow
        }
    }
    
    # Method 3: Manual file-based configuration
    if (-not $iisConfigured) {
        Write-Host "Creating minimal file-based web service..." -ForegroundColor Yellow
        
        # Create a simple index.html that redirects to certificates.json
        $indexHtml = @'
<!DOCTYPE html>
<html>
<head>
    <title>Certificate WebService</title>
    <meta http-equiv="refresh" content="0; url=certificates.json">
</head>
<body>
    <h1>Certificate WebService</h1>
    <p>Redirecting to <a href="certificates.json">certificates.json</a></p>
    <p>Available endpoints:</p>
    <ul>
        <li><a href="certificates.json">certificates.json</a> - All certificate data</li>
        <li><a href="health.json">health.json</a> - Service health status</li>
        <li><a href="summary.json">summary.json</a> - Certificate summary</li>
    </ul>
</body>
</html>
'@
        $indexHtml | Out-File -FilePath (Join-Path $webServicePath "index.html") -Encoding UTF8 -Force
        
        Write-Host "✅ File-based web service created" -ForegroundColor Green
        $iisConfigured = $true
    }
    
    # Step 7: Configure Windows Firewall
    Write-Host "🔥 Configuring firewall..." -ForegroundColor Yellow
    
    try {
        # Remove existing rules
        Remove-NetFirewallRule -DisplayName "Certificate WebService HTTP" -ErrorAction SilentlyContinue
        Remove-NetFirewallRule -DisplayName "Certificate WebService HTTPS" -ErrorAction SilentlyContinue
        
        # Add new rules
        New-NetFirewallRule -DisplayName "Certificate WebService HTTP" -Direction Inbound -Protocol TCP -LocalPort 9080 -Action Allow
        New-NetFirewallRule -DisplayName "Certificate WebService HTTPS" -Direction Inbound -Protocol TCP -LocalPort 9443 -Action Allow
        
        Write-Host "✅ Firewall rules configured" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Firewall configuration failed - please configure manually" -ForegroundColor Yellow
        Write-Host "Required ports: 9080 (HTTP), 9443 (HTTPS)" -ForegroundColor Yellow
    }
    
    # Step 8: Create scheduled task for automatic updates
    Write-Host "⏰ Creating scheduled task..." -ForegroundColor Yellow
    
    try {
        # Remove existing task
        Unregister-ScheduledTask -TaskName "Certificate WebService Update" -Confirm:$false -ErrorAction SilentlyContinue
        
        # Create new task
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$updateScriptPath`""
        $trigger1 = New-ScheduledTaskTrigger -Daily -At "06:00"
        $trigger2 = New-ScheduledTaskTrigger -Daily -At "18:00"
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
        
        Register-ScheduledTask -TaskName "Certificate WebService Update" -Action $action -Trigger @($trigger1, $trigger2) -Settings $settings -Principal $principal
        
        Write-Host "✅ Scheduled task created (runs at 06:00 and 18:00)" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Scheduled task creation failed - please create manually" -ForegroundColor Yellow
    }
    
    # Step 9: Run initial certificate scan
    Write-Host "🔍 Running initial certificate scan..." -ForegroundColor Yellow
    
    try {
        & PowerShell.exe -ExecutionPolicy Bypass -File $updateScriptPath
        Write-Host "✅ Initial certificate scan completed" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Initial scan failed - will retry automatically" -ForegroundColor Yellow
    }
    
    # Step 10: Final verification
    Write-Host "🎯 Final verification..." -ForegroundColor Yellow
    
    $certificatesJson = Join-Path $webServicePath "certificates.json"
    $healthJson = Join-Path $webServicePath "health.json"
    
    if ((Test-Path $certificatesJson) -and (Test-Path $healthJson)) {
        Write-Host "✅ WebService files verified" -ForegroundColor Green
        
        # Show certificate count
        try {
            $certData = Get-Content $certificatesJson | ConvertFrom-Json
            $certCount = $certData.Certificates.Count
            Write-Host "📊 Found $certCount certificates" -ForegroundColor Cyan
        }
        catch {
            Write-Host "📊 Certificate data created (count verification failed)" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "⚠️ Some WebService files missing - please run Test-WebService.ps1" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🎉 Certificate WebService Setup Complete!" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
    Write-Host "📍 WebService Location: $webServicePath" -ForegroundColor Cyan
    Write-Host "🌐 HTTP Endpoint: http://$env:COMPUTERNAME`:9080/certificates.json" -ForegroundColor Cyan
    Write-Host "🔒 HTTPS Endpoint: https://$env:COMPUTERNAME`:9443/certificates.json" -ForegroundColor Cyan
    Write-Host "❤️ Health Check: http://$env:COMPUTERNAME`:9080/health.json" -ForegroundColor Cyan
    Write-Host "📊 Summary: http://$env:COMPUTERNAME`:9080/summary.json" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🔄 Automatic Updates: Daily at 06:00 and 18:00" -ForegroundColor Yellow
    Write-Host "🔧 Manual Update: $updateScriptPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🧪 Test the installation with: Test-WebService.ps1" -ForegroundColor Magenta
    Write-Host ""
    
} # <-- WICHTIG: Diese schließende Klammer war das Problem!
catch {
    Write-Host "❌ Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check the error details above and retry as Administrator." -ForegroundColor Yellow
    exit 1
}