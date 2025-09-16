#requires -Version 5.1

Write-Host "=== SSL Port Auto-Detection Test ===" -ForegroundColor Cyan

# Script Directory
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Import Certificate Module
Import-Module (Join-Path $ScriptDirectory "Modules\FL-Certificate.psm1") -Force
Write-Host "Certificate module loaded" -ForegroundColor Green

Write-Host ""

# Test Case 1: Normal port (should work)
Write-Host "--- Test 1: Normal HTTPS Port 443 ---" -ForegroundColor Yellow
try {
    $result1 = Get-RemoteCertificate -ServerName "www.google.com" -Port 443 -Method Browser
    if ($result1) {
        Write-Host "SUCCESS: Certificate found on port 443" -ForegroundColor Green
        Write-Host "Subject: $($result1.Subject)" -ForegroundColor Gray
        Write-Host "Port: $($result1.Port)" -ForegroundColor Gray
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test Case 2: Non-standard port with auto-detection
Write-Host "--- Test 2: Auto-Detection Test ---" -ForegroundColor Yellow
Write-Host "Testing with invalid port 9999 to trigger auto-detection..." -ForegroundColor Gray

try {
    $testConfig = @{
        Certificate = @{
            Port = 9999
            Timeout = 5000
            EnableAutoPortDetection = $true
            CommonSSLPorts = @(443, 9443, 8443, 4443)
            Method = "Browser"
        }
    }
    
    $result2 = Get-RemoteCertificate -ServerName "www.google.com" -Config $testConfig -Method Browser
    if ($result2) {
        Write-Host "SUCCESS: Auto-detection worked!" -ForegroundColor Green
        Write-Host "Subject: $($result2.Subject)" -ForegroundColor Gray
        Write-Host "Final Port: $($result2.Port)" -ForegroundColor Gray
        if ($result2.AutoDetectedPort) {
            Write-Host "Auto-detected from original port: $($result2.OriginalPort)" -ForegroundColor Magenta
        }
    } else {
        Write-Host "FAILED: Auto-detection did not find certificate" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
