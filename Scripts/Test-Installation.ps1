#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Test-Installation - Validiert Certificate WebService Installation
    
.DESCRIPTION
    Führt umfassende Tests der WebService-Installation durch:
    - HTTP/HTTPS Erreichbarkeit
    - JSON-Antworten validieren
    - Performance-Messung
    - Firewall-Regeln prüfen
    
.PARAMETER HttpPort
    HTTP-Port zum Testen (Standard: 9080)
    
.PARAMETER HttpsPort
    HTTPS-Port zum Testen (Standard: 9443)
    
.PARAMETER ServerName
    Server-Name für externe Tests (Standard: localhost)
    
.PARAMETER ExternalTest
    Auch externe Erreichbarkeit testen
    
.EXAMPLE
    .\Test-Installation.ps1
    
.EXAMPLE
    .\Test-Installation.ps1 -HttpPort 9180 -HttpsPort 9543 -ExternalTest
    
.NOTES
    Version: v1.0.3
    Regelwerk: v9.3.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$HttpPort = 9080,
    
    [Parameter(Mandatory = $false)]
    [int]$HttpsPort = 9443,
    
    [Parameter(Mandatory = $false)]
    [string]$ServerName = "localhost",
    
    [Parameter(Mandatory = $false)]
    [switch]$ExternalTest
)

# 📊 TEST-KONFIGURATION
$testResults = @{
    HTTPLocal = $false
    HTTPSLocal = $false
    HTTPExternal = $false
    HTTPSExternal = $false
    JSONValid = $false
    Performance = $false
    Firewall = $false
    Overall = $false
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = ".\LOG\Test-Installation_$timestamp.log"
New-Item -Path ".\LOG" -ItemType Directory -Force | Out-Null

function Write-TestLog {
    param([string]$Message, [string]$Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

try {
    Write-TestLog "🧪 Certificate WebService Installation Test v1.0.3 gestartet"
    Write-TestLog "Test-Konfiguration: HTTP=$HttpPort, HTTPS=$HttpsPort, Server=$ServerName"
    
    # 🌐 HTTP LOCAL TEST
    Write-TestLog "🌐 Teste HTTP Local (localhost:$HttpPort)..."
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $httpResponse = Invoke-WebRequest -Uri "http://localhost:$HttpPort/health.json" -UseBasicParsing -TimeoutSec 10
        $stopwatch.Stop()
        
        if ($httpResponse.StatusCode -eq 200) {
            $testResults.HTTPLocal = $true
            Write-TestLog "✅ HTTP Local Test erfolgreich (Status: $($httpResponse.StatusCode), Zeit: $($stopwatch.ElapsedMilliseconds)ms)" "SUCCESS"
        } else {
            Write-TestLog "❌ HTTP Local Test fehlgeschlagen (Status: $($httpResponse.StatusCode))" "ERROR"
        }
    }
    catch {
        Write-TestLog "❌ HTTP Local Test fehlgeschlagen: $($_.Exception.Message)" "ERROR"
    }
    
    # 🔒 HTTPS LOCAL TEST
    Write-TestLog "🔒 Teste HTTPS Local (localhost:$HttpsPort)..."
    try {
        # Zertifikat-Validierung temporär deaktivieren für Self-Signed Certs
        $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $httpsResponse = Invoke-WebRequest -Uri "https://localhost:$HttpsPort/health.json" -UseBasicParsing -TimeoutSec 10
        $stopwatch.Stop()
        
        if ($httpsResponse.StatusCode -eq 200) {
            $testResults.HTTPSLocal = $true
            Write-TestLog "✅ HTTPS Local Test erfolgreich (Status: $($httpsResponse.StatusCode), Zeit: $($stopwatch.ElapsedMilliseconds)ms)" "SUCCESS"
        } else {
            Write-TestLog "❌ HTTPS Local Test fehlgeschlagen (Status: $($httpsResponse.StatusCode))" "ERROR"
        }
    }
    catch {
        Write-TestLog "❌ HTTPS Local Test fehlgeschlagen: $($_.Exception.Message)" "ERROR"
    }
    finally {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $originalCallback
    }
    
    # 🌍 EXTERNAL TESTS (wenn aktiviert)
    if ($ExternalTest -and $ServerName -ne "localhost") {
        Write-TestLog "🌍 Teste externe Erreichbarkeit..."
        
        # External HTTP Test
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $httpExtResponse = Invoke-WebRequest -Uri "http://$ServerName:$HttpPort/health.json" -UseBasicParsing -TimeoutSec 15
            $stopwatch.Stop()
            
            if ($httpExtResponse.StatusCode -eq 200) {
                $testResults.HTTPExternal = $true
                Write-TestLog "✅ HTTP External Test erfolgreich (Status: $($httpExtResponse.StatusCode), Zeit: $($stopwatch.ElapsedMilliseconds)ms)" "SUCCESS"
            } else {
                Write-TestLog "❌ HTTP External Test fehlgeschlagen (Status: $($httpExtResponse.StatusCode))" "ERROR"
            }
        }
        catch {
            Write-TestLog "❌ HTTP External Test fehlgeschlagen: $($_.Exception.Message)" "ERROR"
        }
        
        # External HTTPS Test
        try {
            $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $httpsExtResponse = Invoke-WebRequest -Uri "https://$ServerName:$HttpsPort/health.json" -UseBasicParsing -TimeoutSec 15
            $stopwatch.Stop()
            
            if ($httpsExtResponse.StatusCode -eq 200) {
                $testResults.HTTPSExternal = $true
                Write-TestLog "✅ HTTPS External Test erfolgreich (Status: $($httpsExtResponse.StatusCode), Zeit: $($stopwatch.ElapsedMilliseconds)ms)" "SUCCESS"
            } else {
                Write-TestLog "❌ HTTPS External Test fehlgeschlagen (Status: $($httpsExtResponse.StatusCode))" "ERROR"
            }
        }
        catch {
            Write-TestLog "❌ HTTPS External Test fehlgeschlagen: $($_.Exception.Message)" "ERROR"
        }
        finally {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $originalCallback
        }
    }
    
    # 📄 JSON VALIDATION TEST
    Write-TestLog "📄 Teste JSON-Antworten..."
    try {
        $endpoints = @("health.json", "certificates.json", "summary.json")
        $validResponses = 0
        
        foreach ($endpoint in $endpoints) {
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:$HttpPort/$endpoint" -UseBasicParsing -TimeoutSec 10
                $json = $response.Content | ConvertFrom-Json
                
                if ($json) {
                    $validResponses++
                    Write-TestLog "  ✅ $endpoint - Gültiges JSON empfangen"
                } else {
                    Write-TestLog "  ❌ $endpoint - Ungültiges JSON" "WARNING"
                }
            }
            catch {
                Write-TestLog "  ❌ $endpoint - Fehler: $($_.Exception.Message)" "WARNING"
            }
        }
        
        if ($validResponses -eq $endpoints.Count) {
            $testResults.JSONValid = $true
            Write-TestLog "✅ JSON Validation erfolgreich ($validResponses/$($endpoints.Count) Endpoints)" "SUCCESS"
        } else {
            Write-TestLog "⚠️ JSON Validation teilweise erfolgreich ($validResponses/$($endpoints.Count) Endpoints)" "WARNING"
        }
    }
    catch {
        Write-TestLog "❌ JSON Validation fehlgeschlagen: $($_.Exception.Message)" "ERROR"
    }
    
    # ⚡ PERFORMANCE TEST
    Write-TestLog "⚡ Teste Performance..."
    try {
        $performanceResults = @()
        
        for ($i = 1; $i -le 5; $i++) {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-WebRequest -Uri "http://localhost:$HttpPort/certificates.json" -UseBasicParsing -TimeoutSec 10
            $stopwatch.Stop()
            
            if ($response.StatusCode -eq 200) {
                $performanceResults += $stopwatch.ElapsedMilliseconds
                Write-TestLog "  Test $i: $($stopwatch.ElapsedMilliseconds)ms"
            }
        }
        
        if ($performanceResults.Count -gt 0) {
            $avgTime = ($performanceResults | Measure-Object -Average).Average
            $maxTime = ($performanceResults | Measure-Object -Maximum).Maximum
            $minTime = ($performanceResults | Measure-Object -Minimum).Minimum
            
            if ($avgTime -lt 1000) {  # Unter 1 Sekunde ist gut
                $testResults.Performance = $true
                Write-TestLog "✅ Performance Test erfolgreich - Durchschnitt: $([math]::Round($avgTime))ms (Min: $minTime ms, Max: $maxTime ms)" "SUCCESS"
            } else {
                Write-TestLog "⚠️ Performance suboptimal - Durchschnitt: $([math]::Round($avgTime))ms (Min: $minTime ms, Max: $maxTime ms)" "WARNING"
            }
        }
    }
    catch {
        Write-TestLog "❌ Performance Test fehlgeschlagen: $($_.Exception.Message)" "ERROR"
    }
    
    # 🔥 FIREWALL TEST
    Write-TestLog "🔥 Teste Firewall-Regeln..."
    try {
        $httpRule = Get-NetFirewallRule -DisplayName "*CertSurveillance*HTTP*$HttpPort*" -ErrorAction SilentlyContinue
        $httpsRule = Get-NetFirewallRule -DisplayName "*CertSurveillance*HTTPS*$HttpsPort*" -ErrorAction SilentlyContinue
        
        $httpRuleExists = $httpRule -and $httpRule.Enabled -eq "True"
        $httpsRuleExists = $httpsRule -and $httpsRule.Enabled -eq "True"
        
        if ($httpRuleExists -and $httpsRuleExists) {
            $testResults.Firewall = $true
            Write-TestLog "✅ Firewall-Regeln korrekt konfiguriert" "SUCCESS"
        } elseif ($httpRuleExists -or $httpsRuleExists) {
            Write-TestLog "⚠️ Firewall-Regeln teilweise konfiguriert" "WARNING"
        } else {
            Write-TestLog "❌ Firewall-Regeln nicht gefunden" "ERROR"
        }
    }
    catch {
        Write-TestLog "❌ Firewall Test fehlgeschlagen: $($_.Exception.Message)" "ERROR"
    }
    
    # 📊 GESAMTERGEBNIS
    Write-TestLog ""
    Write-TestLog "📊 TEST-ZUSAMMENFASSUNG:"
    Write-TestLog "   HTTP Local:    $(if($testResults.HTTPLocal){'✅ PASS'}else{'❌ FAIL'})"
    Write-TestLog "   HTTPS Local:   $(if($testResults.HTTPSLocal){'✅ PASS'}else{'❌ FAIL'})"
    if ($ExternalTest) {
        Write-TestLog "   HTTP External: $(if($testResults.HTTPExternal){'✅ PASS'}else{'❌ FAIL'})"
        Write-TestLog "   HTTPS External:$(if($testResults.HTTPSExternal){'✅ PASS'}else{'❌ FAIL'})"
    }
    Write-TestLog "   JSON Valid:    $(if($testResults.JSONValid){'✅ PASS'}else{'❌ FAIL'})"
    Write-TestLog "   Performance:   $(if($testResults.Performance){'✅ PASS'}else{'❌ FAIL'})"
    Write-TestLog "   Firewall:      $(if($testResults.Firewall){'✅ PASS'}else{'❌ FAIL'})"
    
    # Gesamtergebnis berechnen
    $requiredTests = @('HTTPLocal', 'HTTPSLocal', 'JSONValid', 'Performance')
    $passedTests = $requiredTests | Where-Object { $testResults[$_] }
    $testResults.Overall = $passedTests.Count -eq $requiredTests.Count
    
    Write-TestLog ""
    if ($testResults.Overall) {
        Write-TestLog "🎉 INSTALLATION ERFOLGREICH VALIDIERT!" "SUCCESS"
        Write-TestLog "   Certificate WebService ist betriebsbereit"
        Write-TestLog "   HTTP URL:  http://$env:COMPUTERNAME:$HttpPort"
        Write-TestLog "   HTTPS URL: https://$env:COMPUTERNAME:$HttpsPort"
    } else {
        Write-TestLog "⚠️ INSTALLATION BENÖTIGT NACHBESSERUNG" "WARNING"
        Write-TestLog "   Bitte beheben Sie die fehlgeschlagenen Tests"
    }
    
    Write-TestLog ""
    Write-TestLog "📁 Detaillierte Logs: $logFile"
    
    # Exit Code setzen
    if ($testResults.Overall) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-TestLog "❌ TEST FEHLGESCHLAGEN: $($_.Exception.Message)" "ERROR"
    Write-TestLog "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}