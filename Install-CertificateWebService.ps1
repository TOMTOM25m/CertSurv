#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Certificate Web Service Installer - Enhanced Performance Solution
.DESCRIPTION
    Installs and configures an IIS-based web service for certificate surveillance
    with HTTPS support and self-signed certificates. This provides a fast,
    web-based alternative for certificate data retrieval across multiple servers.
.AUTHOR
    System Administrator
.VERSION
    v1.0.0
.RULEBOOK
    v9.3.0
.NOTES
    This script requires Administrator privileges for IIS configuration.
    It creates a secure HTTPS endpoint for certificate data access.
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Script metadata
$Global:ScriptName = "Install-CertificateWebService"
$Global:ScriptVersion = "v1.0.0"
$Global:RulebookVersion = "v9.3.0"

# Global paths
$Global:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$Global:sLogFile = Join-Path $Global:ScriptDirectory "LOG\DEV_Install-CertWebService_$(Get-Date -Format 'yyyy-MM-dd').log"

#----------------------------------------------------------[Imports]----------------------------------------------------------

# Import required modules
try {
    Import-Module "$Global:ScriptDirectory\Modules\FL-Config.psm1" -Force
    Import-Module "$Global:ScriptDirectory\Modules\FL-Logging.psm1" -Force  
    Import-Module "$Global:ScriptDirectory\Modules\FL-WebService.psm1" -Force
}
catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

#----------------------------------------------------------[Main Execution]----------------------------------------------------------

try {
    Write-Log "=== Certificate Web Service Installer $Global:ScriptVersion Started ===" -LogFile $Global:sLogFile
    Write-Log "Rulebook Version: $Global:RulebookVersion" -LogFile $Global:sLogFile
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -LogFile $Global:sLogFile
    
    # Load configuration
    $Config = Get-ScriptConfiguration -ScriptDirectory $Global:ScriptDirectory
    
    # Web service configuration
    $siteName = "CertificateSurveillance"
    $sitePath = "C:\inetpub\wwwroot\CertificateSurveillance"
    $subjectName = $env:COMPUTERNAME
    $httpPort = 8080
    $httpsPort = 8443
    
    Write-Host "🚀 Installing Certificate Web Service..." -ForegroundColor Cyan
    Write-Host "   Site Name: $siteName" -ForegroundColor Gray
    Write-Host "   HTTP Port: $httpPort" -ForegroundColor Gray  
    Write-Host "   HTTPS Port: $httpsPort" -ForegroundColor Gray
    Write-Host "   Subject: $subjectName" -ForegroundColor Gray
    
    # Step 1: Create self-signed certificate
    Write-Host "`n📜 Creating self-signed certificate..." -ForegroundColor Yellow
    $certificate = New-WebServiceCertificate -SubjectName $subjectName -ValidityDays 365 -LogFile $Global:sLogFile
    Write-Host "   ✅ Certificate created: $($certificate.Thumbprint)" -ForegroundColor Green
    
    # Step 2: Install IIS web service
    Write-Host "`n🌐 Installing IIS web service..." -ForegroundColor Yellow
    $webService = Install-CertificateWebService -SiteName $siteName -SitePath $sitePath -HttpPort $httpPort -HttpsPort $httpsPort -Certificate $certificate.Certificate -Config $Config -LogFile $Global:sLogFile
    Write-Host "   ✅ Web service installed successfully" -ForegroundColor Green
    
    # Step 3: Generate initial content
    Write-Host "`n📊 Generating initial certificate data..." -ForegroundColor Yellow
    $updateResult = Update-CertificateWebService -SitePath $sitePath -Config $Config -LogFile $Global:sLogFile
    Write-Host "   ✅ Found $($updateResult.CertificateCount) certificates" -ForegroundColor Green
    
    # Step 4: Display results
    Write-Host "`n🎉 Installation completed successfully!" -ForegroundColor Green
    Write-Host "`n📡 Access URLs:" -ForegroundColor Cyan
    Write-Host "   HTTP:  $($webService.HttpUrl)" -ForegroundColor White
    Write-Host "   HTTPS: $($webService.HttpsUrl)" -ForegroundColor White
    Write-Host "   API:   $($webService.HttpsUrl)/api/certificates.json" -ForegroundColor White
    
    Write-Host "`n⚠️  Important Notes:" -ForegroundColor Yellow
    Write-Host "   • Self-signed certificate was added to Trusted Root" -ForegroundColor Gray
    Write-Host "   • Firewall rules created for ports $httpPort and $httpsPort" -ForegroundColor Gray
    Write-Host "   • Windows Authentication is enabled" -ForegroundColor Gray
    Write-Host "   • Update certificate data with: Update-CertificateWebService" -ForegroundColor Gray
    
    Write-Log "Certificate Web Service installation completed successfully" -LogFile $Global:sLogFile
}
catch {
    $errorMessage = "Installation failed: $($_.Exception.Message)"
    Write-Host "❌ $errorMessage" -ForegroundColor Red
    Write-Log $errorMessage -Level ERROR -LogFile $Global:sLogFile
    exit 1
}

# --- End of Script --- old: v1.0.0 ; now: v1.0.0 ; Regelwerk: v9.3.0 ---