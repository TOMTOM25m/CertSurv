# Quick Test Script for Certificate WebService with FQDN Support
param([string]$ServerName)

# Get server FQDN if no ServerName provided
if (-not $ServerName) {
    try {
        $domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
        $hostname = $env:COMPUTERNAME
        $ServerName = "$hostname.$domain"
        Write-Host "Using FQDN: $ServerName" -ForegroundColor Cyan
    } catch {
        $ServerName = $env:COMPUTERNAME
        Write-Host "Could not determine FQDN, using hostname: $ServerName" -ForegroundColor Yellow
    }
}

Write-Host "Testing Certificate WebService on $ServerName..." -ForegroundColor Green     

$endpoints = @(
    "http://$($ServerName):9080/api/certificates",
    "http://$($ServerName):9080/health.json",
    "http://$($ServerName):9080/summary.json",
    "https://$($ServerName):9443/api/certificates"
)

foreach ($endpoint in $endpoints) {
    try {
        Write-Host "Testing: $endpoint" -ForegroundColor Yellow
        
        # Skip HTTPS validation for self-signed certificates
        if ($endpoint -like "https://*") {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        }
        
        $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec 10     

        if ($response.StatusCode -eq 200) {
            Write-Host "  [+] SUCCESS - $($response.StatusCode)" -ForegroundColor Green  

            if ($endpoint -like "*certificates*") {
                $data = $response.Content | ConvertFrom-Json
                Write-Host "  [i] Found $($data.count) certificates" -ForegroundColor Cyan
            }
        }

    } catch {
        Write-Host "  [-] FAILED - $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
}

Write-Host "Test completed." -ForegroundColor Green
Write-Host ""
Write-Host "If tests failed, check:" -ForegroundColor Yellow
Write-Host "1. IIS is running: Get-Service W3SVC" -ForegroundColor White
Write-Host "2. Site is started: Get-IISSite -Name CertWebService" -ForegroundColor White 
Write-Host "3. Firewall allows ports 9080/9443" -ForegroundColor White
Write-Host "4. Certificate data exists: dir C:\inetpub\CertWebService\" -ForegroundColor White
Write-Host "5. Full endpoints:" -ForegroundColor White
Write-Host "   - HTTP:  http://$ServerName:9080/api/certificates" -ForegroundColor Cyan
Write-Host "   - HTTPS: https://$ServerName:9443/api/certificates" -ForegroundColor Cyan
