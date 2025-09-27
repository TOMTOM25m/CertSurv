#requires -Version 5.1

<#
.SYNOPSIS
    Simple WebService Setup Script - Manuell auf jeden Server kopieren
.DESCRIPTION
    Einfaches Skript zum manuellen Deployment des Certificate WebService.
    Kopieren Sie dieses Skript auf jeden Server und führen Sie es als Administrator aus.
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.2.0
    Usage: Als Administrator auf Zielserver ausführen
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🚀 Certificate WebService Setup Script v1.2.0" -ForegroundColor Green
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
    
    # Step 2: Install IIS if needed
    Write-Host "📦 Checking IIS installation..." -ForegroundColor Yellow
    
    $iisFeatures = @(
        "IIS-WebServer",
        "IIS-WebServerRole", 
        "IIS-CommonHttpFeatures",
        "IIS-HttpFeatures",
        "IIS-NetFxExtensibility45",
        "IIS-ASPNET45"
    )
    
    foreach ($feature in $iisFeatures) {
        $featureState = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
        if (-not $featureState -or $featureState.InstallState -ne "Installed") {
            Write-Host "Installing $feature..." -ForegroundColor Yellow
            Install-WindowsFeature -Name $feature -IncludeManagementTools
        }
    }
    
    Write-Host "✅ IIS features installed" -ForegroundColor Green
    
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
    
    # Get certificates from LocalMachine\My store
    $certificates = Get-ChildItem Cert:\LocalMachine\My | Where-Object {
        ($_.NotAfter -gt (Get-Date)) -and
        ($_.Subject -notlike '*Microsoft*') -and
        ($_.Subject -notlike '*Windows*') -and
        ($_.Subject -notlike '*DO_NOT_TRUST*') -and
        ($_.Subject -notlike '*WMSvc*')
    }
    
    $certificateData = foreach ($cert in $certificates) {
        $daysRemaining = [math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
        
        @{
            Subject = $cert.Subject
            Issuer = $cert.Issuer
            NotBefore = $cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss')
            NotAfter = $cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
            DaysRemaining = $daysRemaining
            Status = if ($daysRemaining -lt 30) { "WARNING" } elseif ($daysRemaining -lt 7) { "CRITICAL" } else { "OK" }
            Thumbprint = $cert.Thumbprint
            HasPrivateKey = $cert.HasPrivateKey
            Store = 'LocalMachine\My'
            KeyUsage = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Key Usage" } | ForEach-Object { $_.Format($false) }
        }
    }
    
    # Also check WebHosting store
    $webHostingCerts = Get-ChildItem Cert:\LocalMachine\WebHosting -ErrorAction SilentlyContinue | Where-Object {
        ($_.NotAfter -gt (Get-Date)) -and
        ($_.Subject -notlike '*Microsoft*') -and
        ($_.Subject -notlike '*Windows*')
    }
    
    foreach ($cert in $webHostingCerts) {
        $daysRemaining = [math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
        
        $certificateData += @{
            Subject = $cert.Subject
            Issuer = $cert.Issuer
            NotBefore = $cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss')
            NotAfter = $cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
            DaysRemaining = $daysRemaining
            Status = if ($daysRemaining -lt 30) { "WARNING" } elseif ($daysRemaining -lt 7) { "CRITICAL" } else { "OK" }
            Thumbprint = $cert.Thumbprint
            HasPrivateKey = $cert.HasPrivateKey
            Store = 'LocalMachine\WebHosting'
            KeyUsage = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Key Usage" } | ForEach-Object { $_.Format($false) }
        }
    }
    
    # Create response object
    $response = @{
        status = "ready"
        message = "Certificate Web Service is operational"
        version = "v1.2.0"
        generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        server_name = $env:COMPUTERNAME
        server_fqdn = $env:COMPUTERNAME + "." + $env:USERDNSDOMAIN
        certificate_count = $certificateData.Count
        certificates = $certificateData
        total_count = $certificateData.Count
        summary = @{
            ok = ($certificateData | Where-Object { $_.Status -eq "OK" }).Count
            warning = ($certificateData | Where-Object { $_.Status -eq "WARNING" }).Count
            critical = ($certificateData | Where-Object { $_.Status -eq "CRITICAL" }).Count
        }
        filters_applied = @(
            "exclude_microsoft_certs", 
            "exclude_root_certs", 
            "active_certificates_only",
            "exclude_wmsvc_certs"
        )
        endpoints = @{
            certificates = "/certificates.json"
            summary = "/summary.json"
            health = "/health.json"
            api_info = "/api.json"
        }
        last_updated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
    
    # Save to JSON file
    $response | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
    
    Write-Host "✅ Certificate data updated successfully"
    Write-Host "   Total certificates: $($certificateData.Count)"
    Write-Host "   OK: $($response.summary.ok), Warning: $($response.summary.warning), Critical: $($response.summary.critical)"
    Write-Host "   JSON saved to: $jsonPath"
    
} catch {
    Write-Error "❌ Failed to update certificate data: $($_.Exception.Message)"
    
    # Create error response
    $errorResponse = @{
        status = "error"
        message = "Failed to update certificate data: $($_.Exception.Message)"
        version = "v1.2.0"
        generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        server_name = $env:COMPUTERNAME
        certificate_count = 0
        certificates = @()
        error_details = $_.Exception.Message
    }
    
    $errorResponse | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
}
'@
    
    $updateScript | Set-Content -Path "$webServicePath\Update-CertificateData.ps1" -Encoding UTF8
    Write-Host "✅ Certificate update script created" -ForegroundColor Green
    
    # Step 5: Create additional API endpoints
    Write-Host "🔧 Creating API endpoints..." -ForegroundColor Yellow
    
    # Create summary endpoint
    $summaryScript = @'
# Summary API endpoint
$certificatesPath = "C:\inetpub\CertWebService\certificates.json"

if (Test-Path $certificatesPath) {
    $data = Get-Content $certificatesPath | ConvertFrom-Json
    
    $summary = @{
        server_name = $data.server_name
        total_certificates = $data.total_count
        last_updated = $data.last_updated
        summary = $data.summary
        status = $data.status
        version = $data.version
    }
    
    $summary | ConvertTo-Json -Depth 5
} else {
    @{
        error = "Certificates data not found"
        status = "error"
    } | ConvertTo-Json
}
'@
    
    $summaryScript | Set-Content -Path "$webServicePath\summary.json.ps1" -Encoding UTF8
    
    # Create health check endpoint
    $healthScript = @'
# Health check endpoint
@{
    status = "healthy"
    server = $env:COMPUTERNAME
    timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    services = @{
        iis = if (Get-Service W3SVC -ErrorAction SilentlyContinue) { "running" } else { "stopped" }
        webservice = if (Test-Path "C:\inetpub\CertWebService\certificates.json") { "available" } else { "unavailable" }
    }
    version = "v1.2.0"
} | ConvertTo-Json -Depth 5
'@
    
    $healthScript | Set-Content -Path "$webServicePath\health.json.ps1" -Encoding UTF8
    Write-Host "✅ API endpoints created" -ForegroundColor Green
    
    # Step 6: Configure IIS
    Write-Host "🌐 Configuring IIS..." -ForegroundColor Yellow
    
    Import-Module WebAdministration -Force
    
    # Remove existing configuration if present
    if (Get-IISAppPool -Name "CertWebService" -ErrorAction SilentlyContinue) {
        Write-Host "Removing existing App Pool..." -ForegroundColor Yellow
        Remove-IISAppPool -Name "CertWebService" -Confirm:$false
    }
    
    if (Get-IISSite -Name "CertWebService" -ErrorAction SilentlyContinue) {
        Write-Host "Removing existing Site..." -ForegroundColor Yellow
        Remove-IISSite -Name "CertWebService" -Confirm:$false
    }
    
    # Create new App Pool
    Write-Host "Creating IIS App Pool..." -ForegroundColor Yellow
    New-IISAppPool -Name "CertWebService" -Force
    Set-ItemProperty -Path "IIS:\AppPools\CertWebService" -Name processModel.identityType -Value ApplicationPoolIdentity
    
    # Create new Website
    Write-Host "Creating IIS Site..." -ForegroundColor Yellow
    New-IISSite -Name "CertWebService" -PhysicalPath $webServicePath -BindingInformation "*:9080:" -ApplicationPool "CertWebService"
    
    # Add HTTPS binding (if certificate available)
    try {
        New-IISSiteBinding -Name "CertWebService" -BindingInformation "*:9443:" -Protocol https -ErrorAction SilentlyContinue
        Write-Host "HTTPS binding added (certificate required for SSL)" -ForegroundColor Yellow
    } catch {
        Write-Host "HTTPS binding skipped (no certificate available)" -ForegroundColor Yellow
    }
    
    Write-Host "✅ IIS configured" -ForegroundColor Green
    
    # Step 7: Configure Firewall
    Write-Host "🔥 Configuring Windows Firewall..." -ForegroundColor Yellow
    
    # Remove existing rules
    Remove-NetFirewallRule -DisplayName "Certificate WebService HTTP" -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -DisplayName "Certificate WebService HTTPS" -ErrorAction SilentlyContinue
    
    # Add new rules
    New-NetFirewallRule -DisplayName "Certificate WebService HTTP" -Direction Inbound -Protocol TCP -LocalPort 9080 -Action Allow -Profile Any
    New-NetFirewallRule -DisplayName "Certificate WebService HTTPS" -Direction Inbound -Protocol TCP -LocalPort 9443 -Action Allow -Profile Any
    
    Write-Host "✅ Firewall rules configured" -ForegroundColor Green
    
    # Step 8: Start services
    Write-Host "▶️ Starting IIS services..." -ForegroundColor Yellow
    
    Start-IISAppPool -Name "CertWebService"
    Start-IISSite -Name "CertWebService"
    
    Write-Host "✅ IIS services started" -ForegroundColor Green
    
    # Step 9: Generate initial certificate data
    Write-Host "📊 Generating initial certificate data..." -ForegroundColor Yellow
    & "$webServicePath\Update-CertificateData.ps1"
    
    # Step 10: Create scheduled task for automatic updates
    Write-Host "⏰ Creating scheduled task for automatic updates..." -ForegroundColor Yellow
    
    try {
        # Remove existing task
        Unregister-ScheduledTask -TaskName "Update-CertificateData" -Confirm:$false -ErrorAction SilentlyContinue
        
        # Create new task
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$webServicePath\Update-CertificateData.ps1`""
        $taskTrigger = @(
            New-ScheduledTaskTrigger -Daily -At "06:00"    # Daily at 6 AM
            New-ScheduledTaskTrigger -Daily -At "18:00"    # Daily at 6 PM
        )
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask -TaskName "Update-CertificateData" -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force
        
        Write-Host "✅ Scheduled task created (runs daily at 6:00 and 18:00)" -ForegroundColor Green
        
    } catch {
        Write-Host "⚠️ Scheduled task creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Step 11: Test the WebService
    Write-Host "🧪 Testing WebService..." -ForegroundColor Yellow
    
    Start-Sleep -Seconds 3  # Wait for IIS to stabilize
    
    try {
        $localTest = Invoke-WebRequest -Uri "https://localhost:9080/certificates.json" -UseBasicParsing -TimeoutSec 10
        if ($localTest.StatusCode -eq 200) {
            $data = $localTest.Content | ConvertFrom-Json
            Write-Host "✅ WebService test successful!" -ForegroundColor Green
            Write-Host "   Found $($data.certificate_count) certificates" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️ Local test failed, but WebService should be accessible externally" -ForegroundColor Yellow
    }
    
    # Final summary
    Write-Host ""
    Write-Host "🎉 WebService Setup Completed Successfully!" -ForegroundColor Green
    Write-Host "════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor Cyan
    Write-Host "Service Path: $webServicePath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "API Endpoints:" -ForegroundColor Yellow
    Write-Host "  HTTP:  https://$env:COMPUTERNAME:9080/certificates.json" -ForegroundColor White
    Write-Host "  HTTPS: https://$env:COMPUTERNAME:9443/certificates.json" -ForegroundColor White
    Write-Host "  Health: https://$env:COMPUTERNAME:9080/health.json" -ForegroundColor White
    Write-Host "  Summary: https://$env:COMPUTERNAME:9080/summary.json" -ForegroundColor White
    Write-Host ""
    Write-Host "Automatic Updates: Scheduled daily at 6:00 and 18:00" -ForegroundColor Yellow
    Write-Host "Manual Update: $webServicePath\Update-CertificateData.ps1" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "✅ Ready for Certificate Surveillance monitoring!" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check the error details above and retry as Administrator." -ForegroundColor Yellow
    exit 1
}