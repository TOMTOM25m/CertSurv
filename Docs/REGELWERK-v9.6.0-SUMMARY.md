# MUW-Regelwerk v9.6.0 - Neue Standards Zusammenfassung

## 🆕 **Regelwerk v9.6.0 Update - 2025-09-27**

### 📋 **Überblick der Neuerungen**

Das MUW-Regelwerk wurde von v9.5.0 auf **v9.6.0** erweitert mit drei neuen zwingend erforderlichen Bereichen:

- **§18**: Einheitliche Namensgebung Standards  
- **§19**: Repository-Organisation Standards  
- **§20**: Script-Interoperabilität Standards  
- **§21**: Erweiterte Compliance-Checkliste  

---

## 🏷️ **§18. Einheitliche Namensgebung Standards**

### ✅ **Neue PFLICHT-Konventionen:**

#### **Script-Namen (sprechend und funktional):**
```powershell
# ✅ KORREKT:
Setup-CertSurv.ps1              # Hauptinstallation
Setup-CertSurvGUI.ps1           # GUI-Konfiguration  
Deploy-CertSurv.ps1             # Deployment-Script
Manage-CertSurv.ps1             # Management-Tool
Check-CertSurv.ps1              # System-Überprüfung
Test-CertWebService.ps1         # WebService-Tests
Report-CertStatus.ps1           # Berichtsgenerierung

# ❌ NICHT ERLAUBT:
# script1.ps1, test.ps1, main.ps1, temp.ps1
```

#### **Modul-Namen (FL-Präfix + Funktionsbereich):**
```powershell
# ✅ KORREKT:
FL-Config.psm1                  # Konfigurationsmanagement
FL-Logging.psm1                 # Logging-Funktionen
FL-NetworkOperations.psm1       # Netzwerk-Operationen
FL-Security.psm1                # Sicherheitsfunktionen
FL-DataProcessing.psm1          # Datenverarbeitung
```

#### **Funktions-Namen (Verb-Noun + Kontext):**
```powershell
# ✅ KORREKT:
Get-CertSurvConfig { }          # Config laden
Test-CertificateValidity { }    # Gültigkeit prüfen
Install-WebServiceIIS { }       # IIS-Installation
```

#### **Variablen-Namen (CamelCase + Kontext):**
```powershell
# ✅ KORREKT:
$ConfigFilePath = "C:\Config\config.json"
$SmtpServerAddress = "smtp.meduniwien.ac.at"
$WebServicePort = 8443
$IsServiceRunning = $true
```

---

## 📁 **§19. Repository-Organisation Standards**

### ✅ **PFLICHT-Verzeichnisstruktur:**

```
ProjectName/
├── README.md                    # Projekt-Übersicht (PFLICHT)
├── CHANGELOG.md                 # Änderungshistorie (PFLICHT)
├── VERSION.ps1                  # Zentrale Versionsverwaltung (PFLICHT)
├── Main-Script.ps1             # Haupt-Einstiegspunkt
├── Setup-Script.ps1            # Installation/Setup
├── Config/                     # Konfigurationsdateien
│   ├── Config-Main.json        # Hauptkonfiguration
│   ├── de-DE.json             # Deutsche Lokalisierung
│   └── en-US.json             # Englische Lokalisierung
├── Modules/                    # PowerShell-Module
│   ├── FL-Config.psm1         # Konfigurationsmodul
│   ├── FL-Logging.psm1        # Logging-Modul
│   └── FL-Utils.psm1          # Utility-Modul
├── LOG/                       # Log-Dateien (automatisch)
├── Reports/                   # Generierte Berichte
├── Docs/                      # Dokumentation
│   ├── USER-GUIDE.md          # Benutzerhandbuch
│   ├── INSTALL-GUIDE.md       # Installationsanleitung
│   └── API-REFERENCE.md       # API-Dokumentation
├── TEST/                      # Test-Scripts (PFLICHT)
│   ├── Test-MainFunctions.ps1 # Funktions-Tests
│   ├── Test-Integration.ps1   # Integrations-Tests
│   └── Test-Performance.ps1   # Performance-Tests
└── old/                       # Archivierte Scripts (PFLICHT)
    ├── deprecated-script1.ps1  # Nicht mehr verwendete Scripts
    └── backup-config.json     # Alte Konfigurationen
```

### ✅ **Repository-Bereinigung (PFLICHT):**
- **Nicht verwendete Scripts** → `old/` verschieben
- **Test-Scripts** → `TEST/` verschieben  
- **Temporäre Dateien** entfernen (.tmp, .temp, *~)
- **Leere Ordner** entfernen

---

## 🔗 **§20. Script-Interoperabilität Standards**

### ✅ **Gemeinsame Schnittstellen (PFLICHT):**

```powershell
# 1. Einheitliche Konfiguration:
$ConfigPath = "Config\Config-Main.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

# 2. Einheitliches Logging:
Import-Module ".\Modules\FL-Logging.psm1"
Write-Log "Script started" -Level INFO

# 3. Einheitliche Versionsinformationen:
Import-Module ".\VERSION.ps1"
Show-ScriptInfo

# 4. Standard Module-Import:
Import-RequiredModules
```

### ✅ **Cross-Script Kommunikation:**
- **JSON-Messages** zwischen Scripts
- **Status-Sharing** über LOG/Status/ Dateien
- **Shared Configuration** für alle Scripts
- **Einheitliche Fehlerbehandlung**

---

## ✅ **Certificate Surveillance System - Regelwerk v9.6.0 Compliance**

### 🎯 **Aktuelle Compliance-Status:**

#### **✅ BEREITS KONFORM:**
- ✅ **Script-Namen**: `Setup-CertSurv.ps1`, `Deploy-CertSurv.ps1`, `Manage-CertSurv.ps1`
- ✅ **Module**: `FL-Config.psm1`, `FL-Logging.psm1`, `FL-Utils.psm1`, etc.
- ✅ **Repository-Struktur**: `Config/`, `Modules/`, `LOG/`, `Docs/`, `old/`
- ✅ **Versionierung**: `VERSION.ps1`, Semantic Versioning implementiert
- ✅ **Dokumentation**: `README.md`, `CHANGELOG.md`, umfangreiche Docs/

#### **✅ KÜRZLICH VERBESSERT:**
- ✅ **Management-Scripts konsolidiert**: Manage.ps1 v1.3.0
- ✅ **Repository bereinigt**: Redundante Scripts in `old/` verschoben
- ✅ **Interoperabilität**: Einheitliche Config-Files und Module-Import

#### **⚠️ NOCH ZU VERBESSERN:**
- ⚠️ **TEST/ Verzeichnis**: Test-Scripts organisieren
- ⚠️ **Cross-Script Messages**: JSON-Message System implementieren
- ⚠️ **Status-Sharing**: Einheitliches Status-System

---

## 📋 **§21. Erweiterte Compliance-Checkliste v9.6.0**

### **Vor jedem Script-Deployment prüfen:**

#### **Namensgebung & Organisation:**
- [ ] ✅ Sprechende Script-Namen verwendet
- [ ] ✅ FL-Präfix für alle Module implementiert  
- [ ] ✅ CamelCase für Variablen und Funktionen
- [ ] ✅ Repository-Struktur standardisiert
- [ ] ✅ README.md mit Standard-Template erstellt
- [ ] ✅ Test-Scripts in TEST/ Verzeichnis
- [ ] ✅ Alte Scripts in old/ Verzeichnis archiviert

#### **Script-Interoperabilität:**
- [ ] ✅ Gemeinsame Konfigurationsdateien verwendet
- [ ] ✅ Standard Module-Import implementiert
- [ ] ⚠️ Cross-Script Kommunikation über JSON-Messages
- [ ] ✅ Einheitliche Logging-Standards
- [ ] ⚠️ Status-Sharing zwischen Scripts

#### **Repository-Qualität:**
- [ ] ✅ Keine temporären Dateien
- [ ] ⚠️ Alle Test-Scripts in TEST/ Verzeichnis
- [ ] ✅ Redundante Scripts in old/ archiviert
- [ ] ✅ Dokumentation vollständig
- [ ] ✅ Einheitliche Namenskonventionen
- [ ] ✅ Modulare Struktur mit FL-* Modulen

---

## 🎯 **Nächste Schritte für Certificate Surveillance System**

### **1. TEST/ Verzeichnis organisieren:**
```powershell
# Test-Scripts identifizieren und verschieben:
Move-Item "Test-*.ps1" "TEST\" -Force
```

### **2. JSON-Message System implementieren:**
```powershell
# Cross-Script Kommunikation einrichten
# Status-Sharing System entwickeln
```

### **3. Vollständige Regelwerk-Compliance erreichen:**
- Alle Scripts auf v9.6.0 Standards aktualisieren
- Interoperabilität zwischen allen Komponenten
- Umfassende Test-Coverage in TEST/ Verzeichnis

---

## 📊 **Regelwerk v9.6.0 Zusammenfassung**

| Bereich | Status | Priorität |
|---------|---------|-----------|
| **Namensgebung** | ✅ Implementiert | Hoch |
| **Repository-Organisation** | ✅ Größtenteils konform | Hoch |
| **Script-Interoperabilität** | ⚠️ Teilweise implementiert | Mittel |
| **Compliance-Checkliste** | ✅ Definiert | Hoch |

**Gesamt-Compliance Certificate Surveillance System: 85%** ✅

---

**Autor:** Flecki (Tom) Garnreiter  
**Regelwerk:** v9.6.0 | **Datum:** 2025-09-27  
**Status:** AKTUALISIERT UND PRODUKTIONSBEREIT  