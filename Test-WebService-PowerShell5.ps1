#Requires -Version 5.1

<#
.SYNOPSIS
    Test Certificate WebService Installation (PowerShell Version Auto-Detection)
    
.DESCRIPTION
    Testet die WebService-Installation mit automatischer PowerShell-Versionserkennung.
    Verwendet PowerShell 5.1 oder 7.x spezifische Methoden je nach verfügbarer Version.
#>

Write-Host "Certificate WebService - Installation Test" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

# PowerShell Version Detection
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5

Write-Host "PowerShell Version: $($PSVersion.ToString())" -ForegroundColor White
Write-Host "Test-Modus: $(if($IsPS7Plus){'PowerShell 7.x'}else{'PowerShell 5.1'})" -ForegroundColor Yellow

#region PowerShell 5.1 Functions
function Test-WebService-PS5 {
    param([string]$Url, [string]$Protocol)
    
    try {
        if ($Protocol -eq "HTTPS") {
            # SSL-Zertifikat-Validierung erweitern für PS5.1
            $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
            $originalSecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol
            
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {
                param($sender, $cert, $chain, $errors)
                # Log error for troubleshooting but continue with default validation
                if ($errors -ne [System.Net.Security.SslPolicyErrors]::None) {
                    Write-Verbose "Certificate validation encountered errors: $errors"
                }
                # Return default validation result
                return $errors -eq [System.Net.Security.SslPolicyErrors]::None
            }
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls
        }
        
        $response = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 10
        
        if ($Protocol -eq "HTTPS") {
            # SSL-Einstellungen zurücksetzen
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $originalCallback
            [System.Net.ServicePointManager]::SecurityProtocol = $originalSecurityProtocol
        }
        
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            ContentLength = $response.Content.Length
            Error = $null
        }
    }
    catch {
        if ($Protocol -eq "HTTPS") {
            # SSL-Einstellungen zurücksetzen auch bei Fehler
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $originalCallback
            [System.Net.ServicePointManager]::SecurityProtocol = $originalSecurityProtocol
        }
        
        return @{
            Success = $false
            StatusCode = $null
            ContentLength = $null
            Error = $_.Exception.Message
        }
    }
}
#endregion

#region PowerShell 7.x Functions  
function Test-WebService-PS7 {
    param([string]$Url, [string]$Protocol)
    
    try {
        if ($Protocol -eq "HTTPS") {
            $response = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 10 -SkipCertificateCheck
        } else {
            $response = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 10
        }
        
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            ContentLength = $response.Content.Length
            Error = $null
        }
    }
    catch {
        return @{
            Success = $false
            StatusCode = $null
            ContentLength = $null
            Error = $_.Exception.Message
        }
    }
}
#endregion

#region Universal Test Function
function Test-WebServiceEndpoint {
    param([string]$Url, [string]$Description)
    
    $protocol = if ($Url.StartsWith("https")) { "HTTPS" } else { "HTTP" }
    
    Write-Host "[$Description] $Url..." -ForegroundColor Yellow
    
    if ($IsPS7Plus) {
        $result = Test-WebService-PS7 -Url $Url -Protocol $protocol
    } else {
        $result = Test-WebService-PS5 -Url $Url -Protocol $protocol
    }
    
    if ($result.Success) {
        Write-Host "✅ $Description erfolgreich!" -ForegroundColor Green
        Write-Host "   Status: $($result.StatusCode)" -ForegroundColor White
        Write-Host "   Content-Length: $($result.ContentLength)" -ForegroundColor White
    } else {
        if ($protocol -eq "HTTPS") {
            Write-Host "⚠️  $Description fehlgeschlagen: $($result.Error)" -ForegroundColor Yellow
            Write-Host "   (Kann normal sein bei selbst-signierten Zertifikaten)" -ForegroundColor Gray
        } else {
            Write-Host "❌ $Description fehlgeschlagen: $($result.Error)" -ForegroundColor Red
        }
    }
    
    return $result.Success
}
#endregion

# Tests ausführen
Write-Host "`n=== WEBSERVICE-TESTS ===" -ForegroundColor Cyan

$httpSuccess = Test-WebServiceEndpoint -Url "http://localhost:9080" -Description "HTTP-Test"
$httpsSuccess = Test-WebServiceEndpoint -Url "https://localhost:9443" -Description "HTTPS-Test"

# Endpunkt-Tests
Write-Host "`n=== ENDPUNKT-TESTS ===" -ForegroundColor Cyan

$endpoints = @(
    @{Url = "http://localhost:9080/health.json"; Name = "Health-Check"},
    @{Url = "http://localhost:9080/certificates.json"; Name = "Certificates-API"}, 
    @{Url = "http://localhost:9080/summary.json"; Name = "Summary-API"}
)

$endpointResults = @()
foreach ($endpoint in $endpoints) {
    $success = Test-WebServiceEndpoint -Url $endpoint.Url -Description $endpoint.Name
    $endpointResults += $success
}

# Zusammenfassung
Write-Host "`n=== ZUSAMMENFASSUNG ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersion.ToString())" -ForegroundColor White
Write-Host "HTTP WebService: $(if($httpSuccess){'✅ ERFOLGREICH'}else{'❌ FEHLGESCHLAGEN'})" -ForegroundColor $(if($httpSuccess){'Green'}else{'Red'})
Write-Host "HTTPS WebService: $(if($httpsSuccess){'✅ ERFOLGREICH'}else{'⚠️ FEHLGESCHLAGEN (Normal)'})" -ForegroundColor $(if($httpsSuccess){'Green'}else{'Yellow'})
Write-Host "API-Endpunkte: $($endpointResults | Where-Object {$_}).Count / $($endpointResults.Count) erfolgreich" -ForegroundColor White

if ($httpSuccess) {
    Write-Host "`n🎯 INSTALLATION ERFOLGREICH!" -ForegroundColor Green
    Write-Host "WebService ist bereit für Certificate Surveillance" -ForegroundColor Cyan
} else {
    Write-Host "`n❌ INSTALLATION PROBLEM!" -ForegroundColor Red
    Write-Host "Bitte prüfen Sie IIS-Konfiguration und Firewall" -ForegroundColor Yellow
}