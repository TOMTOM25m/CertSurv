#requires -Version 5.1

<#
.SYNOPSIS
    Regelwerk v9.5.0 Compliance Check fuer Certificate Surveillance System
.DESCRIPTION
    Prüft die vollständige Compliance des Certificate Surveillance Systems 
    mit dem MUW-Regelwerk v9.5.0 fuer strict modularity
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.09.17
    Version:        v1.1.0
    Target:         Regelwerk v9.5.0 Compliance
#>

param(
    [switch]$DetailedReport = $true,
    [switch]$FixIssues = $false
)

Write-Host "`n=================================" -ForegroundColor Cyan
Write-Host "Regelwerk v9.5.0 Compliance Check" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$complianceResults = @{}

# 1. Hauptskript-Größe prüfen (unter 300 Zeilen)
Write-Host "`n[CHECK 1] Hauptskript-Größe (strict modularity)" -ForegroundColor Yellow
$mainScript = Join-Path $ScriptDirectory "Cert-Surveillance.ps1"
if (Test-Path $mainScript) {
    $lineCount = (Get-Content $mainScript | Measure-Object -Line).Lines
    $complianceResults["MainScriptSize"] = @{
        "Current" = $lineCount
        "Required" = "< 300 Zeilen"
        "Compliant" = $lineCount -lt 300
        "Status" = if ($lineCount -lt 300) { "PASS" } else { "FAIL" }
    }
    
    if ($lineCount -lt 300) {
        Write-Host "  ✅ PASS: Hauptskript hat $lineCount Zeilen (< 300)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ FAIL: Hauptskript hat $lineCount Zeilen (sollte < 300 sein)" -ForegroundColor Red
    }
} else {
    Write-Host "  ❌ ERROR: Hauptskript nicht gefunden" -ForegroundColor Red
}

# 2. Module-Struktur prüfen
Write-Host "`n[CHECK 2] FL-* Module Struktur" -ForegroundColor Yellow
$moduleDir = Join-Path $ScriptDirectory "Modules"
$expectedModules = @(
    'FL-Config.psm1',
    'FL-CoreLogic.psm1', 
    'FL-Compatibility.psm1',
    'FL-ActiveDirectory.psm1',
    'FL-DataProcessing.psm1',
    'FL-Logging.psm1',
    'FL-Maintenance.psm1',
    'FL-NetworkOperations.psm1',
    'FL-Reporting.psm1',
    'FL-Security.psm1',
    'FL-Utils.psm1',
    'FL-CertificateAPI.psm1'
)

$foundModules = @()
$missingModules = @()

foreach ($module in $expectedModules) {
    $modulePath = Join-Path $moduleDir $module
    if (Test-Path $modulePath) {
        $foundModules += $module
        Write-Host "  ✅ $module" -ForegroundColor Green
    } else {
        $missingModules += $module
        Write-Host "  ❌ $module (nicht gefunden)" -ForegroundColor Red
    }
}

$complianceResults["ModuleStructure"] = @{
    "Expected" = $expectedModules.Count
    "Found" = $foundModules.Count
    "Missing" = $missingModules
    "Compliant" = $missingModules.Count -eq 0
    "Status" = if ($missingModules.Count -eq 0) { "PASS" } else { "FAIL" }
}

# 3. Konfigurationsdateien prüfen
Write-Host "`n[CHECK 3] Konfigurationsdateien" -ForegroundColor Yellow
$configDir = Join-Path $ScriptDirectory "Config"
$configFiles = @(
    'Config-Cert-Surveillance.json',
    'de-DE.json',
    'en-US.json'
)

$configCompliant = $true
foreach ($configFile in $configFiles) {
    $configPath = Join-Path $configDir $configFile
    if (Test-Path $configPath) {
        Write-Host "  ✅ $configFile" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $configFile (nicht gefunden)" -ForegroundColor Red
        $configCompliant = $false
    }
}

$complianceResults["Configuration"] = @{
    "Compliant" = $configCompliant
    "Status" = if ($configCompliant) { "PASS" } else { "FAIL" }
}

# 4. Setup-GUI prüfen
Write-Host "`n[CHECK 4] Setup-GUI Verfügbarkeit" -ForegroundColor Yellow
$setupScript = Join-Path $ScriptDirectory "Setup-CertSurv.ps1"
$setupCompliant = Test-Path $setupScript

if ($setupCompliant) {
    Write-Host "  ✅ Setup-CertSurv.ps1 verfügbar" -ForegroundColor Green
} else {
    Write-Host "  ❌ Setup-CertSurv.ps1 nicht gefunden" -ForegroundColor Red
}

$complianceResults["SetupGUI"] = @{
    "Compliant" = $setupCompliant
    "Status" = if ($setupCompliant) { "PASS" } else { "FAIL" }
}

# 5. WebService Integration prüfen
Write-Host "`n[CHECK 5] WebService Integration" -ForegroundColor Yellow
$configPath = Join-Path $configDir "Config-Cert-Surveillance.json"
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        $webServiceEnabled = $config.Certificate.WebService.Enabled
        $centralServer = $config.Certificate.WebService.PrimaryServer
        
        if ($webServiceEnabled -and $centralServer -ne "localhost") {
            Write-Host "  ✅ WebService aktiviert: $centralServer" -ForegroundColor Green
            $webServiceCompliant = $true
        } else {
            Write-Host "  ⚠️  WebService nicht konfiguriert oder localhost" -ForegroundColor Yellow
            $webServiceCompliant = $false
        }
    } catch {
        Write-Host "  ❌ Konfiguration nicht lesbar" -ForegroundColor Red
        $webServiceCompliant = $false
    }
} else {
    $webServiceCompliant = $false
}

$complianceResults["WebServiceIntegration"] = @{
    "Compliant" = $webServiceCompliant
    "Status" = if ($webServiceCompliant) { "PASS" } else { "WARNING" }
}

# 6. Test-Modus Status prüfen
Write-Host "`n[CHECK 6] Produktions-Bereitschaft" -ForegroundColor Yellow
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        $testModeDisabled = -not $config.Certificate.TestMode.Enabled
        $prodMode = $config.RunMode -eq "PROD"
        $debugOff = -not $config.DebugMode
        
        $prodReady = $testModeDisabled -and $prodMode -and $debugOff
        
        Write-Host "  TestMode deaktiviert: $testModeDisabled" -ForegroundColor $(if($testModeDisabled){"Green"}else{"Red"})
        Write-Host "  RunMode PROD: $prodMode" -ForegroundColor $(if($prodMode){"Green"}else{"Red"})
        Write-Host "  DebugMode aus: $debugOff" -ForegroundColor $(if($debugOff){"Green"}else{"Red"})
        
    } catch {
        Write-Host "  ❌ Konfiguration nicht lesbar" -ForegroundColor Red
        $prodReady = $false
    }
} else {
    $prodReady = $false
}

$complianceResults["ProductionReadiness"] = @{
    "Compliant" = $prodReady
    "Status" = if ($prodReady) { "PASS" } else { "FAIL" }
}

# 7. PowerShell Compatibility prüfen
Write-Host "`n[CHECK 7] PowerShell Kompatibilität" -ForegroundColor Yellow
$compatibilityModule = Join-Path $moduleDir "FL-Compatibility.psm1"
$compatibilityCompliant = Test-Path $compatibilityModule

if ($compatibilityCompliant) {
    Write-Host "  ✅ FL-Compatibility.psm1 verfügbar" -ForegroundColor Green
    Write-Host "  ✅ PowerShell 5.1+ Unterstützung" -ForegroundColor Green
} else {
    Write-Host "  ❌ FL-Compatibility.psm1 nicht gefunden" -ForegroundColor Red
}

$complianceResults["PowerShellCompatibility"] = @{
    "Compliant" = $compatibilityCompliant
    "Status" = if ($compatibilityCompliant) { "PASS" } else { "FAIL" }
}

# Zusammenfassung
Write-Host "`n=================================" -ForegroundColor Cyan
Write-Host "Compliance Summary" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

$totalChecks = $complianceResults.Keys.Count
$passedChecks = ($complianceResults.Values | Where-Object { $_.Status -eq "PASS" }).Count
$failedChecks = ($complianceResults.Values | Where-Object { $_.Status -eq "FAIL" }).Count
$warningChecks = ($complianceResults.Values | Where-Object { $_.Status -eq "WARNING" }).Count

foreach ($check in $complianceResults.GetEnumerator()) {
    $status = $check.Value.Status
    $color = switch ($status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARNING" { "Yellow" }
        default { "White" }
    }
    Write-Host "$($check.Key): $status" -ForegroundColor $color
}

Write-Host "`nGesamtergebnis:" -ForegroundColor Cyan
Write-Host "  ✅ Bestanden: $passedChecks" -ForegroundColor Green
Write-Host "  ❌ Fehlgeschlagen: $failedChecks" -ForegroundColor Red
Write-Host "  ⚠️  Warnungen: $warningChecks" -ForegroundColor Yellow

$overallCompliance = ($failedChecks -eq 0)
Write-Host "`nRegelwerk v9.5.0 Compliance: " -NoNewline
if ($overallCompliance) {
    Write-Host "BESTANDEN" -ForegroundColor Green
} else {
    Write-Host "NICHT BESTANDEN" -ForegroundColor Red
}

# Empfehlungen ausgeben
if ($failedChecks -gt 0) {
    Write-Host "`n🔧 Empfohlene Korrekturen:" -ForegroundColor Yellow
    
    if ($complianceResults["MainScriptSize"].Status -eq "FAIL") {
        Write-Host "  • Hauptskript auf unter 300 Zeilen reduzieren (erweiterte strict modularity)" -ForegroundColor Yellow
    }
    
    if ($complianceResults["ModuleStructure"].Status -eq "FAIL") {
        Write-Host "  • Fehlende FL-* Module erstellen oder reparieren" -ForegroundColor Yellow
    }
    
    if ($complianceResults["Configuration"].Status -eq "FAIL") {
        Write-Host "  • Fehlende Konfigurationsdateien ergänzen" -ForegroundColor Yellow
    }
    
    if ($complianceResults["ProductionReadiness"].Status -eq "FAIL") {
        Write-Host "  • TestMode deaktivieren, RunMode auf PROD setzen, DebugMode ausschalten" -ForegroundColor Yellow
    }
}

Write-Host "`nPruefung abgeschlossen!" -ForegroundColor Cyan