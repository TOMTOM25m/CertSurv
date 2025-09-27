# Simple Test Script to verify basic functionality
Write-Host "Simple Test Script v1.0" -ForegroundColor Green
Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor Cyan

try {
    Write-Host "Test 1: Basic PowerShell functionality..." -ForegroundColor Yellow
    $test = Get-Date
    Write-Host "✅ Current time: $test" -ForegroundColor Green
    
    Write-Host "Test 2: Administrator check..." -ForegroundColor Yellow
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Write-Host "✅ Running as Administrator" -ForegroundColor Green
    } else {
        Write-Host "❌ NOT running as Administrator" -ForegroundColor Red
    }
    
    Write-Host "Test 3: Windows Features check..." -ForegroundColor Yellow
    try {
        $features = Get-WindowsFeature | Where-Object { $_.Name -like "*IIS*" } | Select-Object -First 3
        if ($features) {
            Write-Host "✅ Windows Features available: $($features.Count) IIS features found" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No IIS features found - might be Windows 10/Client" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ Get-WindowsFeature not available - trying alternative..." -ForegroundColor Yellow
        try {
            $optionalFeatures = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -like "*IIS*" } | Select-Object -First 3
            Write-Host "✅ Windows Optional Features available: $($optionalFeatures.Count) IIS features found" -ForegroundColor Green
        } catch {
            Write-Host "❌ Neither Get-WindowsFeature nor Get-WindowsOptionalFeature available" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "🎉 Simple test completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}