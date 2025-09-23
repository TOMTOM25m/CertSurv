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
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$setupScriptSource = Join-Path $scriptDirectory "Setup-WebService.ps1"
$setupScriptDest = Join-Path $OutputPath "Setup-WebService.ps1"

if (Test-Path $setupScriptSource) {
    Copy-Item $setupScriptSource $setupScriptDest
    Write-Host "✅ Setup script copied" -ForegroundColor Green
} else {
    Write-Host "⚠️ Setup-WebService.ps1 not found, creating placeholder" -ForegroundColor Yellow
    "# Setup-WebService.ps1 placeholder - copy from source" | Set-Content -Path $setupScriptDest
}

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
    "- http://[SERVER]:9080/certificates.json",
    "- http://[SERVER]:9080/health.json", 
    "- http://[SERVER]:9080/summary.json",
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
Write-Host "2. Run Setup-WebService.ps1 as Administrator on each server" -ForegroundColor White  
Write-Host "3. Verify Certificate Surveillance System integration" -ForegroundColor White