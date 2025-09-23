# Certificate WebService Deployment Package Creator
# This script creates a deployment package for easy distribution

param(
    [string]$OutputPath = "C:\Temp\CertWebService-Deployment"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "📦 Creating Certificate WebService Deployment Package..." -ForegroundColor Green

# Create output directory
if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Recurse -Force
}
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null

# Copy setup script
$setupScriptSource = Join-Path $PSScriptRoot "Setup-WebService.ps1"
$setupScriptDest = Join-Path $OutputPath "Setup-WebService.ps1"
Copy-Item $setupScriptSource $setupScriptDest

# Create README file  
$readmeLines = @(
    "Certificate WebService Deployment Package v1.2.0",
    "====================================================",
    "",
    "INSTALLATION INSTRUCTIONS:",
    "",
    "1. Copy this folder to the target server",
    "2. Run as Administrator: Install-WebService.bat",
    "3. Test with: Test-WebService.ps1",
    "",
    "REQUIREMENTS:",
    "- Windows Server 2012 R2+",
    "- PowerShell 5.1+", 
    "- Administrator privileges",
    "",
    "API ENDPOINTS (after installation):",
    "- https://[SERVER]:9080/certificates.json",
    "- https://[SERVER]:9080/health.json", 
    "- https://[SERVER]:9080/summary.json",
    "",
    "PORTS:",
    "- 9080 (HTTP)",
    "- 9443 (HTTPS)",
    "",
    "AUTOMATIC UPDATES:",
    "- Daily at 6:00 and 18:00",
    "- Manual: C:\inetpub\CertWebService\Update-CertificateData.ps1",
    "",
    "SUPPORT:",
    "- IT Systems Management",
    "- Server: itscmgmt03.srv.meduniwien.ac.at"
)

$readmeLines | Set-Content -Path (Join-Path $OutputPath "README.txt") -Encoding UTF8

# Create deployment batch file
$batchContent = @"
@echo off
echo Certificate WebService Deployment v1.2.0
echo ==========================================
echo.

REM Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Administrator privileges confirmed
    echo.
) else (
    echo ERROR: This script must be run as Administrator!
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo Starting PowerShell setup script...
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup-WebService.ps1"

echo.
echo Deployment completed. Check output above for results.
pause
"@

$batchContent | Set-Content -Path (Join-Path $OutputPath "Install-WebService.bat") -Encoding UTF8

# Create quick test script
$testContent = @"
# Quick Test Script for Certificate WebService
param([string]$ServerName = $env:COMPUTERNAME)

Write-Host "Testing Certificate WebService on $ServerName..." -ForegroundColor Green

$endpoints = @(
    "https://$($ServerName):9080/certificates.json",
    "https://$($ServerName):9080/health.json",
    "https://$($ServerName):9080/summary.json"
)

foreach ($endpoint in $endpoints) {
    try {
        Write-Host "Testing: $endpoint" -ForegroundColor Yellow
        $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec 10
        
        if ($response.StatusCode -eq 200) {
            Write-Host "  ✅ SUCCESS - $($response.StatusCode)" -ForegroundColor Green
            
            if ($endpoint -like "*certificates.json") {
                $data = $response.Content | ConvertFrom-Json
                Write-Host "  📊 Found $($data.certificate_count) certificates" -ForegroundColor Cyan
            }
        }
        
    } catch {
        Write-Host "  ❌ FAILED - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "Test completed." -ForegroundColor Green
"@

$testContent | Set-Content -Path (Join-Path $OutputPath "Test-WebService.ps1") -Encoding UTF8

# Create server list template
$serverListContent = @"
# Server List for Mass Deployment
# Copy this file and customize for your environment

# Domain Servers (UVW)
SUCCESSXPROD01.uvw.meduniwien.ac.at
UVWDC001.uvw.meduniwien.ac.at
C-APP01.uvw.meduniwien.ac.at
C-APP02.uvw.meduniwien.ac.at

# Domain Servers (AD)  
ADDC01P.ad.meduniwien.ac.at
ADDC02P.ad.meduniwien.ac.at

# Workgroup Servers (SRV)
itscmgmt03.srv.meduniwien.ac.at
cafm-prod.srv.meduniwien.ac.at
cafm-test.srv.meduniwien.ac.at

# Add your servers here...
# Format: servername.domain.meduniwien.ac.at
"@

$serverListContent | Set-Content -Path (Join-Path $OutputPath "ServerList.txt") -Encoding UTF8

Write-Host "✅ Deployment package created successfully!" -ForegroundColor Green
Write-Host "📁 Location: $OutputPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Package contents:" -ForegroundColor Yellow
Get-ChildItem $OutputPath | ForEach-Object {
    Write-Host "  📄 $($_.Name)" -ForegroundColor White
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "1. Copy the entire folder to each target server" -ForegroundColor White
Write-Host "2. Run Install-WebService.bat as Administrator" -ForegroundColor White  
Write-Host "3. Test with Test-WebService.ps1" -ForegroundColor White
Write-Host "4. Verify integration with Certificate Surveillance System" -ForegroundColor White