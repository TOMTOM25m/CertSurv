# Certificate Surveillance System v1.1.0

## Regelwerk v9.3.1 Compliance Implementation (Updated - Extended Modularity)

### Übersicht / Overview

Das Certificate Surveillance System wurde vollständig auf das MUW-Regelwerk v9.3.0 mit **strict modularity** Prinzipien aktualisiert.

**[DE]** Das System folgt streng dem Prinzip der Modularität: Das Hauptskript ist minimalistisch (unter 300 Zeilen) und delegiert alle spezifischen Funktionen an spezialisierte FL-* Module.

**[EN]** The system strictly follows modularity principles: The main script is minimalistic (under 300 lines) and delegates all specific functions to specialized FL-* modules.

---

### Architektur / Architecture

Certificate Surveillance System
├── Cert-Surveillance.ps1          # Main orchestration script (strict modularity)
├── Setup-CertSurv.ps1            # Standalone setup GUI application
├── Config/
│   ├── Config-Cert-Surveillance.json  # Central configuration
│   ├── de-DE.json                     # German localization
│   └── en-US.json                     # English localization
└── Modules/                       # FL-* Specialized modules
    ├── FL-Certificate.psm1        # SSL/TLS certificate operations
    ├── FL-Config.psm1             # Configuration management
    ├── FL-CoreLogic.psm1          # Main workflow orchestration
    ├── FL-Compatibility.psm1      # PowerShell version compatibility
    ├── FL-ActiveDirectory.psm1    # AD integration functions
    ├── FL-DataProcessing.psm1     # Excel/CSV data processing
    ├── FL-Gui.psm1                # WPF setup GUI interface
    ├── FL-Logging.psm1            # Structured logging
    ├── FL-Maintenance.psm1        # System maintenance
    ├── FL-NetworkOperations.psm1  # Network connectivity
    ├── FL-Reporting.psm1          # Report generation
    ├── FL-Security.psm1           # Security functions
    └── FL-Utils.psm1              # Utility functions
```

Certificate Surveillance System
├── Cert-Surveillance.ps1          # Main orchestration script (strict modularity)
├── Setup-CertSurv.ps1            # Standalone setup GUI application
├── Config/
│   ├── Config-Cert-Surveillance.json  # Central configuration
│   ├── de-DE.json                     # German localization
│   └── en-US.json                     # English localization
└── Modules/                       # FL-* Specialized modules
    ├── FL-Certificate.psm1        # SSL/TLS certificate operations
    ├── FL-Config.psm1             # Configuration management
    ├── FL-CoreLogic.psm1          # Main workflow orchestration
    ├── FL-Compatibility.psm1      # PowerShell version compatibility
    ├── FL-ActiveDirectory.psm1    # AD integration functions
    ├── FL-DataProcessing.psm1     # Excel/CSV data processing
    ├── FL-Gui.psm1                # WPF setup GUI interface
    ├── FL-Logging.psm1            # Structured logging
    ├── FL-Maintenance.psm1        # System maintenance
    ├── FL-NetworkOperations.psm1  # Network connectivity
    ├── FL-Reporting.psm1          # Report generation
    ├── FL-Security.psm1           # Security functions
    └── FL-Utils.psm1              # Utility functions
```

---

### Regelwerk v9.3.0 Compliance Features

#### **Regelwerk Update September 2025**: Erweiterte Strict Modularity

Die ursprüngliche Grenze von 100 Zeilen wurde auf **300 Zeilen** erweitert, um moderne Enterprise-Anforderungen zu berücksichtigen:

- Umfangreichere Error-Handling-Strategien
- Erweiterte WebService-Integration
- Produktionsreife Logging-Mechanismen
- Komplexere Konfigurationsvalidierung

#### 1. **Strict Modularity Implementation (Updated)**

- ✅ Hauptskript unter 300 Zeilen (erweiterte Modularität für Enterprise-Umgebungen)
- ✅ Universelles Hauptskript ohne spezifische Logik
- ✅ Alle Funktionen in spezialisierte FL-* Module ausgelagert
- ✅ Klare Trennung zwischen Orchestrierung und Implementierung

#### 2. **PowerShell Version Compatibility**

- ✅ Automatische PowerShell-Versionserkennung
- ✅ Kompatibilität für PowerShell 5.1 und 7+
- ✅ Cross-Platform-Support (Windows/Linux/macOS für PS7+)
- ✅ Version-spezifische Funktionen in FL-Compatibility

#### 3. **Configuration Management**

- ✅ Vollständig externalisierte Konfiguration in JSON
- ✅ Keine Hard-coded-Werte im Code
- ✅ Mehrsprachige Lokalisierung (DE/EN)
- ✅ Validierung aller Konfigurationsparameter

#### 4. **Setup GUI Interface**

- ✅ Eigenständige WPF-basierte Setup-Anwendung
- ✅ Alle Konfigurationsoptionen grafisch editierbar
- ✅ Integrierte Validierung und Test-Funktionen
- ✅ Mehrsprachige Benutzeroberfläche

---

### Konfigurationskategorien / Configuration Categories

| Kategorie | Parameter | Beschreibung |
|-----------|-----------|--------------|
| **Certificate** | Port, Timeout, WarningDays | SSL/TLS Zertifikat-Abruf |
| **Excel** | Path, Sheet, Columns | Excel-Datenquelle |
| **Mail** | SMTP, Recipients, Templates | E-Mail-Benachrichtigungen |
| **Report** | Output, Format, Templates | Bericht-Generierung |
| **ActiveDirectory** | Domain, Credentials | AD-Integration |
| **Network** | Proxy, DNS, Timeouts | Netzwerk-Konfiguration |
| **System** | Logging, Debug, Language | System-Einstellungen |

---

### Anwendung / Usage

#### Setup und Konfiguration

```powershell
# Setup GUI starten
.\Setup-CertSurv.ps1

# Oder interaktiver Setup-Modus
.\Cert-Surveillance.ps1 -Setup
```

#### Produktionsausführung

```powershell
# Standard-Modus
.\Cert-Surveillance.ps1

# Debug-Modus
.\Cert-Surveillance.ps1 -Debug

# Test-Modus
.\Cert-Surveillance.ps1 -Test
```

---

### Module Dependencies / Modul-Abhängigkeiten

```
Cert-Surveillance.ps1
├── FL-Config → Configuration loading
├── FL-Compatibility → Version detection
├── FL-CoreLogic → Main workflow
    ├── FL-DataProcessing → Excel processing
    ├── FL-Certificate → SSL/TLS operations
    ├── FL-NetworkOperations → Connectivity
    ├── FL-Reporting → Report generation
    ├── FL-Security → Security functions
    └── FL-Logging → Structured logging
```

---PowerShell

### PowerShell Compatibility Matrix

| Feature | PowerShell 5.1 | PowerShell 7+ |
|---------|----------------|---------------|
| **Core Functions** | ✅ Fully supported | ✅ Fully supported |
| **JSON Handling** | ✅ Standard | ✅ Enhanced (EnumsAsStrings) |
| **UTF-8 Files** | ✅ Workaround | ✅ Native support |
| **Cross-Platform** | ❌ Windows only | ✅ Windows/Linux/macOS |
| **Error Handling** | ✅ Standard | ✅ Enhanced features |
| **Module Loading** | ✅ Standard | ✅ SkipEditionCheck |

---

### Sicherheitsfeatures / Security Features

- 🔒 **Credential Management**: Secure handling of AD credentials
- 🔒 **Certificate Validation**: Full SSL/TLS certificate chain validation
- 🔒 **Network Security**: Configurable proxy and DNS settings
- 🔒 **Audit Logging**: Comprehensive logging of all operations
- 🔒 **Access Control**: RunAsAdministrator requirements where needed

---

### Performance Optimizations

- ⚡ **Parallel Processing**: Multiple certificate checks in parallel
- ⚡ **Caching**: Smart caching of AD queries and network operations
- ⚡ **Timeout Management**: Configurable timeouts for all network operations
- ⚡ **Memory Management**: Proper disposal of .NET objects
- ⚡ **Lazy Loading**: Modules loaded only when needed

---

### Wartung und Updates / Maintenance and Updates

#### Automatic Maintenance

- Log-Rotation mit konfigurierbarer Aufbewahrung
- Temporäre Datei-Bereinigung
- Performance-Metriken-Sammlung

#### Manual Maintenance

```powershell
# Module-Update
Import-Module .\Modules\FL-Maintenance.psm1
Invoke-SystemMaintenance

# Configuration Validation
Test-ConfigurationIntegrity

# Module Dependencies Check
Test-ModuleDependencies
```

---

### Best Practices Implementation

1. **Error Handling**: Umfassendes Try-Catch-Finally in allen Modulen
2. **Logging**: Strukturiertes Logging mit konfigurierbaren Levels
3. **Documentation**: Vollständige Inline-Dokumentation (DE/EN)
4. **Testing**: Integrierte Test-Funktionen in der Setup-GUI
5. **Versioning**: Konsistente Versionierung aller Komponenten

---

### Lizenz / License

MIT License - © 2025 Flecki (Tom) Garnreiter

---

**Version**: v1.0.0  
**Regelwerk**: v9.3.0  
**PowerShell**: 5.1+ | 7+  
**Platform**: Windows (PS5.1) | Cross-Platform (PS7+)
