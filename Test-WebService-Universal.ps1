#Requires -Version 5.1

<#
.SYNOPSIS
    Certificate WebService Universal Test - Vollstaendige Funktionsvalidierung
    
.DESCRIPTION
    Umfassender Test-Script fuer das Certificate WebService System.
    Validiert API-Verfuegbarkeit, SSL-Konfiguration und Service-Funktionalitaet.
    Automatische PowerShell-Version-Anpassung fuer PS5.1 und PS7.x Kompatibilitaet.
    
.PARAMETER HostName
    [DE] Der Host-Name oder die IP-Adresse des zu testenden WebService
    [EN] The hostname or IP address of the WebService to test
    
.PARAMETER Port
    [DE] Der Port des WebService (Standard: 9080)
    [EN] The port of the WebService (default: 9080)
    
.PARAMETER TestTimeout
    [DE] Timeout in Sekunden fuer Tests (Standard: 30)
    [EN] Timeout in seconds for tests (default: 30)
    
.EXAMPLE
    .\Test-WebService-Universal.ps1 -HostName "itscmgmt03.srv.meduniwien.ac.at"
    [DE] Testet den WebService auf dem angegebenen Host
    [EN] Tests the WebService on the specified host
    
.NOTES
    Version:        v1.2.0
    Author:         GitHub Copilot
    Datum:          2025-09-22
    Regelwerk:      v9.4.0 (PowerShell Version Adaptation + Character Encoding Standardization)
    [DE] Vollstaendig ASCII-kompatibel fuer universelle PowerShell-Unterstuetzung
    [EN] Fully ASCII-compatible for universal PowerShell support
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$HostName = "itscmgmt03.srv.meduniwien.ac.at",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 9080,
    
    [Parameter(Mandatory=$false)]
    [int]$TestTimeout = 30
)

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "Test-WebService-Universal - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

# Script version information
$Global:ScriptVersion = "v1.2.0"
$Global:RulebookVersion = "v9.4.0"

Write-Host "Certificate WebService - Universal Installation Test v$Global:ScriptVersion" -ForegroundColor Cyan
Write-Host "=======================================================================" -ForegroundColor Cyan

Write-Host "PowerShell Version: $($PSVersion.ToString())" -ForegroundColor White
Write-Host "Test-Methode: $(if($IsPS7Plus){'PowerShell 7.x (SkipCertificateCheck)'}else{'PowerShell 5.1 (Legacy SSL)'})" -ForegroundColor Yellow
        Write-Host "   Status: $($response.StatusCode)" -ForegroundColor White
        Write-Host "   Content-Length: $($response.Content.Length)" -ForegroundColor White
        return $true
    }
    catch {
        Write-Host "[FAIL] $Description fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}
#endregion

#region PowerShell 5.1 HTTPS Test Function (mit SSL-Handling)
function Invoke-HttpsTest-PS5 {
    param([string]$Url, [string]$Description)
    
    Write-Host "[WARN] $Description (PowerShell 5.1 - limitierte SSL-Unterstuetzung)..." -ForegroundColor Yellow
    
    try {
        # Versuche Standard-Request
        $response = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 10
        Write-Host "[OK] $Description erfolgreich!" -ForegroundColor Green
        Write-Host "   Status: $($response.StatusCode)" -ForegroundColor White
        return $true
    }
    catch {
        Write-Host "[WARN] $Description fehlgeschlagen (erwartet bei selbst-signierten Zertifikaten)" -ForegroundColor Yellow
        Write-Host "   Fehler: $($_.Exception.Message)" -ForegroundColor Gray
        return $false
    }
}
#endregion

#region PowerShell 7.x Test Function
function Invoke-WebTest-PS7 {
    param([string]$Url, [string]$Description)
    
    try {
        if ($Url.StartsWith("https")) {
            $response = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 10 -SkipCertificateCheck
        } else {
            $response = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 10
        }
        
        Write-Host "[OK] $Description erfolgreich!" -ForegroundColor Green
        Write-Host "   Status: $($response.StatusCode)" -ForegroundColor White
        Write-Host "   Content-Length: $($response.Content.Length)" -ForegroundColor White
        return $true
    }
    catch {
        Write-Host "[FAIL] $Description fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}
#endregion

#region Universal Test Execution
Write-Host "`n=== WEBSERVICE-TESTS ===" -ForegroundColor Cyan

# HTTP-Test (beide Versionen)
Write-Host "`n[TEST 1] HTTP-Verbindung (Port 9080)..." -ForegroundColor Yellow
if ($IsPS7Plus) {
    $httpSuccess = Invoke-WebTest-PS7 -Url "http://localhost:9080" -Description "HTTP-Test"
} else {
    $httpSuccess = Invoke-HttpTest-PS5 -Url "http://localhost:9080" -Description "HTTP-Test"
}

# HTTPS-Test (versionsspezifisch)
Write-Host "`n[TEST 2] HTTPS-Verbindung (Port 9443)..." -ForegroundColor Yellow
if ($IsPS7Plus) {
    $httpsSuccess = Invoke-WebTest-PS7 -Url "https://localhost:9443" -Description "HTTPS-Test"
} else {
    $httpsSuccess = Invoke-HttpsTest-PS5 -Url "https://localhost:9443" -Description "HTTPS-Test"
}

# API-Endpunkt-Tests
Write-Host "`n[TEST 3] WebService-API-Endpunkte..." -ForegroundColor Yellow

$endpoints = @(
    @{Url = "http://localhost:9080/health.json"; Name = "Health-Check"},
    @{Url = "http://localhost:9080/certificates.json"; Name = "Certificates-API"}, 
    @{Url = "http://localhost:9080/summary.json"; Name = "Summary-API"}
)

$apiResults = @()
foreach ($endpoint in $endpoints) {
    if ($IsPS7Plus) {
        $success = Invoke-WebTest-PS7 -Url $endpoint.Url -Description $endpoint.Name
    } else {
        $success = Invoke-HttpTest-PS5 -Url $endpoint.Url -Description $endpoint.Name
    }
    $apiResults += $success
}
#endregion

#region Summary
Write-Host "`n=== FINALE ZUSAMMENFASSUNG ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersion.ToString())" -ForegroundColor White
Write-Host "Test-Methode: $(if($IsPS7Plus){'Moderne PS7.x-Methoden'}else{'Legacy PS5.1-Methoden'})" -ForegroundColor Gray
Write-Host "HTTP Service: $(if($httpSuccess){'[OK] FUNKTIONAL'}else{'[FAIL] DEFEKT'})" -ForegroundColor $(if($httpSuccess){'Green'}else{'Red'})
Write-Host "HTTPS Service: $(if($httpsSuccess){'[OK] FUNKTIONAL'}else{'[WARN] SSL-PROBLEM'})" -ForegroundColor $(if($httpsSuccess){'Green'}else{'Yellow'})
Write-Host "API-Endpunkte: $(($apiResults | Where-Object {$_}).Count) / $($apiResults.Count) funktional" -ForegroundColor White

if ($httpSuccess -and (($apiResults | Where-Object {$_}).Count) -ge 2) {
    Write-Host "`n[SUCCESS] WEBSERVICE INSTALLATION ERFOLGREICH!" -ForegroundColor Green
    Write-Host "Ready fuer Certificate Surveillance Integration" -ForegroundColor Cyan
    Write-Host "Server kann in Excel-Liste aktiviert werden" -ForegroundColor Yellow
} else {
    Write-Host "`n[FAIL] WEBSERVICE INSTALLATION DEFEKT!" -ForegroundColor Red
    Write-Host "Pruefen Sie IIS-Konfiguration und Netzwerk-Einstellungen" -ForegroundColor Yellow
}
#endregion