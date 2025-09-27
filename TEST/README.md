# Certificate Surveillance System - Test Suite

## 📋 Übersicht

Dieses Verzeichnis enthält alle Test-Scripts für das Certificate Surveillance System entsprechend **Regelwerk v9.6.0 §19** (Repository-Organisation Standards).

## 🧪 **Test-Scripts**

### **1. Test-Simple.ps1**
**Zweck:** Basis-Funktionalitätstests  
**Beschreibung:** Einfache Tests für grundlegende System-Funktionen  
**Verwendung:** Schnelle Validierung nach Installation

### **2. Test-ClientManagement.ps1**
**Zweck:** Client-Server Management Tests  
**Beschreibung:** Tests für das Management-Tool und Client-Server Interaktion  
**Verwendung:** Validierung der Manage.ps1 Funktionalität

### **3. Test-CentralWebServiceIntegration.ps1**
**Zweck:** WebService Integration Tests  
**Beschreibung:** Tests für die zentrale WebService-Integration und Kommunikation  
**Verwendung:** Validierung der WebService-Deployment und -Funktionalität

### **4. Deploy-TestServer.ps1**
**Zweck:** Test-Server Deployment  
**Beschreibung:** Deployment-Script für Testumgebungen  
**Verwendung:** Einrichtung von Test-Servern für Validierung

## 🚀 **Test-Ausführung**

### **Alle Tests ausführen:**
```powershell
# Alle Test-Scripts nacheinander ausführen
Get-ChildItem "TEST\Test-*.ps1" | ForEach-Object {
    Write-Host "Executing: $($_.Name)" -ForegroundColor Green
    & $_.FullName
}
```

### **Einzelne Tests ausführen:**
```powershell
# Basis-Tests:
.\TEST\Test-Simple.ps1

# Management-Tests:
.\TEST\Test-ClientManagement.ps1

# WebService-Tests:
.\TEST\Test-CentralWebServiceIntegration.ps1

# Test-Server Deployment:
.\TEST\Deploy-TestServer.ps1
```

## 📊 **Test-Kategorien**

### **🔍 Unit Tests (Test-Simple.ps1)**
- Modul-Import Tests
- Konfiguration-Validation Tests
- Logging-Funktionalität Tests
- Basis-Utility Tests

### **🌐 Integration Tests (Test-CentralWebServiceIntegration.ps1)**
- WebService-Konnektivität Tests
- Certificate-Collection Tests
- HTTPS/HTTP Endpoint Tests
- Cross-Server Communication Tests

### **⚙️ Management Tests (Test-ClientManagement.ps1)**
- Excel-Integration Tests
- Server-Discovery Tests
- WinRM-Connection Tests
- Progress-Tracking Tests

### **🚀 Deployment Tests (Deploy-TestServer.ps1)**
- Test-Environment Setup
- Server-Configuration Tests
- Installation-Validation Tests
- End-to-End Workflow Tests

## ✅ **Test-Standards (Regelwerk v9.6.0)**

### **Namenskonventionen:**
- **Test-Scripts**: `Test-[Funktionsbereich].ps1`
- **Deployment-Scripts**: `Deploy-[Environment].ps1`
- **Funktionen**: `Test-[Komponente][Aktion]`

### **Struktur-Standards:**
```powershell
# Standard Test-Script Struktur:

#region Test Script Header (MANDATORY - Regelwerk v9.6.0)
$ScriptVersion = "1.0.0"
$RegelwerkVersion = "v9.6.0"
$BuildDate = "2025-09-27"
$Author = "Flecki (Tom) Garnreiter"
$TestCategory = "Integration" # Unit/Integration/Management/Deployment
#endregion

# Test-Funktionen
function Test-ComponentFunction {
    param([string]$TestName)
    
    try {
        Write-Host "Running test: $TestName" -ForegroundColor Yellow
        # Test-Logik hier
        Write-Host "✅ PASSED: $TestName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ FAILED: $TestName - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Test-Ausführung
$TestResults = @()
$TestResults += Test-ComponentFunction "Basic Configuration Loading"
$TestResults += Test-ComponentFunction "Module Import Validation"

# Ergebnis-Summary
$PassedTests = ($TestResults | Where-Object { $_ -eq $true }).Count
$TotalTests = $TestResults.Count
Write-Host "Test Summary: $PassedTests/$TotalTests tests passed" -ForegroundColor Cyan
```

## 📝 **Test-Dokumentation Standards**

### **Jeder Test muss dokumentieren:**
- **Zweck**: Was wird getestet
- **Voraussetzungen**: System-Requirements  
- **Erwartete Ergebnisse**: Success-Kriterien
- **Abhängigkeiten**: Benötigte Module/Services
- **Cleanup**: Aufräumen nach Test-Ausführung

### **Test-Logging:**
```powershell
# Standard Test-Logging (PFLICHT):
Import-Module "..\.Modules\FL-Logging.psm1"

function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$TestName = ""
    )
    
    $LogMessage = if ($TestName) { "[$TestName] $Message" } else { $Message }
    Write-Log $LogMessage -Level $Level
}

# Verwendung:
Write-TestLog "Test started" -Level INFO -TestName "WebService Connection"
Write-TestLog "✅ Test passed" -Level INFO -TestName "WebService Connection"
Write-TestLog "❌ Test failed: Connection timeout" -Level ERROR -TestName "WebService Connection"
```

## 🔧 **Test-Umgebung Setup**

### **Voraussetzungen für Test-Ausführung:**
- PowerShell 5.1+ (kompatibel mit 7.x)
- Administrative Rechte (für Integration Tests)
- Netzwerk-Zugriff zu Test-Servern
- Certificate Surveillance System installiert

### **Test-Konfiguration:**
```json
{
  "TestEnvironment": {
    "TestServers": [
      "testserver1.meduniwien.ac.at",
      "testserver2.meduniwien.ac.at"
    ],
    "TestWebServicePort": 8443,
    "TestLogLevel": "DEBUG",
    "MaxTestTimeout": 300,
    "CleanupAfterTests": true
  }
}
```

---

## 📈 **Continuous Testing**

### **Automatisierte Test-Ausführung:**
```powershell
# Tägliche Test-Routine (empfohlen):
.\TEST\Test-Simple.ps1           # Basis-Validierung
.\TEST\Test-ClientManagement.ps1 # Management-Funktionalität  
.\TEST\Test-CentralWebServiceIntegration.ps1 # WebService-Tests

# Wöchentliche Test-Routine:
.\TEST\Deploy-TestServer.ps1     # End-to-End Deployment Test
```

### **Test-Berichte:**
- **Location**: `Reports\Test-Results-[Datum].json`
- **Format**: Strukturierte JSON-Berichte
- **Retention**: 30 Tage automatische Archivierung

---

## 📚 **Regelwerk-Compliance**

✅ **Regelwerk v9.6.0 §19 konform:**
- Test-Scripts in separatem TEST/ Verzeichnis
- Sprechende Namensgebung für alle Test-Scripts
- Strukturierte Test-Organisation nach Kategorien
- Einheitliche Dokumentation und Logging-Standards

---

**Erstellt:** 2025-09-27  
**Autor:** Flecki (Tom) Garnreiter  
**Regelwerk:** v9.6.0 | **Version:** 1.0.0  
**Letzte Aktualisierung:** TEST/ Verzeichnis Organisation