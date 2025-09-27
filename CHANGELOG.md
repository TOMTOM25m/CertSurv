# CHANGELOG - Certificate Surveillance System

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/) und dieses Projekt folgt [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.3.1] - 2025-09-24

### 🔧 Maintenance Release: CertWebService v2.1.0 & Setup-GUI Integration

#### Added ✨

- **Install-CertSurv.bat** - Universelle Installation für alle Server-Umgebungen
- **Setup-CertSurv.ps1** - Vollständige GUI für Config-Cert-Surveillance.json Bearbeitung
- **CertWebService v2.1.0** - Robocopy-basiertes Deployment mit lokaler Ausführung
- **Setup-ScheduledTask-CertScan.ps1** - Automatische Scheduled Task-Erstellung
- **Encoding-Fixes** - ASCII-Kompatibilität für alle Konfigurationsdateien
- **Network Deployment** - Vollautomatische Bereitstellung auf Netzlaufwerke
- **File Verification** - Automatische Überprüfung kopierter Dateien vor Installation
- **Multi-Threading** - Robocopy mit /MT:8 für optimierte Übertragungsgeschwindigkeit

#### Changed 🔄

- **Install-CertSurv.bat** - Universelle Installation mit Regelwerk v9.5.0 Compliance
- **Check.ps1** - Compliance-Logik erweitert für Main.ps1 und Setup.ps1 Akzeptanz
- **Install.bat** - Robocopy-Integration mit C:\Temp lokaler Ausführung
- **Setup-CertSurv.ps1** - Dynamische GUI-Generierung für alle Config-Parameter
- **Deployment-Methode** - Lokale Kopie zuerst, dann Installation (regelwerkkonform)
- **Installation Process** - Schritt 1: Robocopy, Schritt 2: Lokale Setup-Ausführung

#### Fixed 🐛

- **Encoding-Probleme** - Alle Scripts auf ASCII-Encoding konvertiert
- **Path-Format-Fehler** - Main.ps1 Pfad-Konfiguration korrigiert
- **UNC-Path-Support** - Robocopy-Parameter für korrekte Netzwerkpfad-Behandlung
- **Compliance-Check** - Setup-GUI Erkennung in Check.ps1 implementiert

#### Technical Improvements 🔧

- **Regelwerk v9.5.0 Compliance**: Lokale Kopie vor Installation (Sicherheitsstandard)
- **Universal Deployment**: Konfigurierbare Pfade für verschiedene Server-Umgebungen
- **Enhanced Error Handling**: Detaillierte Robocopy-Diagnose und PowerShell-Troubleshooting
- **Two-Step Installation**: Schritt 1 - Robocopy, Schritt 2 - Lokale Setup-Ausführung
- **File Integrity Checks**: Automatische Verifikation von Setup.ps1 und Cert-Surveillance.ps1
- **Lokale Ausführung**: Install.bat kopiert Dateien vor Ausführung lokal
- **Automatische Bereinigung**: Temporäre Installationsdateien werden automatisch gelöscht
- **Integrated Task Setup**: Scheduled Tasks werden automatisch während Installation erstellt
- **Dynamic Configuration**: GUI ermöglicht Bearbeitung aller Config-Parameter

## [v1.1.0] - 2025-09-17

### 🎯 Major Release: WebService Integration & Extended Modularity

#### Added✨

- **Zentrale WebService-Integration** auf `itscmgmt03.srv.meduniwien.ac.at:9080/9443`
- **FL-CertificateAPI.psm1** - Neues Modul für zentrale API-Kommunikation
- **FL-WebService.psm1** - IIS Certificate Web Service Management
- **Automated Deployment System** für WebService mit Robocopy UNC-Unterstützung
- **Network Share Distribution** über `\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment\`
- **Simple HTTP Test** für WebService-Validierung (Syntax-Fehler-frei)
- **Test-CentralWebServiceIntegration.ps1** - Umfassende Integrationstests

#### Changed🔄

- **Regelwerk v9.3.0 → v9.3.1**: Hauptskript-Limit von 100 auf **300 Zeilen** erweitert
- **TestMode.Enabled**: `true → false` (Vollständige Produktionsausführung)
- **RunMode**: `"DEV" → "PROD"` (Produktionsmodus aktiviert)
- **DebugMode**: `true → false` (Produktionsoptimierung)
- **WebService.PrimaryServer**: `"localhost" → "itscmgmt03.srv.meduniwien.ac.at"`
- **Server-Verarbeitung**: Von 1 Test-Server auf alle 151 Server erweitert

#### Fixed🐛

- **PowerShell 5.1 Emoji-Kompatibilität** - Alle Emojis durch ASCII-Zeichen ersetzt
- **Count Property Issues** - Measure-Object Pattern für PS 5.1 Kompatibilität
- **Test-Installation.ps1 Syntax-Fehler** - Ersetzt durch inline HTTP-Test
- **UNC Path Limitations** - Robocopy-Integration für CMD UNC-Unterstützung
- **Path Structure** - Korrekte Trennung: C:\Temp (Download) + C:\Script (Deployment)

#### Technical Improvements🔧

- **Zentrale Architektur**: Client → itscmgmt03 WebService → Fallback auf lokale SSL-Abfrage
- **Performance**: 87ms API-Antwortzeit für zentrale Zertifikatsdaten
- **Robustness**: Automatischer Fallback bei leerer zentraler Datenbank
- **Deployment**: Vollautomatisierte Installation mit `Install-CertWebService-ISO.bat`

---

## [v1.0.3] - 2025-09-04

### 🚀 Initial Release: Strict Modularity Implementation

#### Added ✨

- **FL-* Modular Architecture** - Vollständige Trennung von Hauptskript und Funktionslogik
- **FL-CoreLogic.psm1** - Zentrale Workflow-Orchestrierung
- **FL-Config.psm1** - Externalisierte Konfigurationsverwaltung
- **FL-Logging.psm1** - Strukturierte Protokollierung
- **FL-DataProcessing.psm1** - Excel/CSV-Datenverarbeitung
- **FL-NetworkOperations.psm1** - Netzwerk-Konnektivitätsprüfungen
- **FL-Reporting.psm1** - HTML/JSON-Berichtgenerierung
- **FL-ActiveDirectory.psm1** - AD-Integration und Domain-Klassifizierung
- **FL-Security.psm1** - SSL/TLS-Zertifikatsvalidierung
- **FL-Maintenance.psm1** - System-Wartungsfunktionen
- **FL-Utils.psm1** - Allgemeine Hilfsfunktionen
- **FL-Compatibility.psm1** - PowerShell-Versionskompatibilität
- **Setup-CertSurv.ps1** - Eigenständige WPF-Setup-GUI

#### Features 🎯

- **Multi-Domain Support** - UVW, NEURO, EX, AD, DGMW, DIAWIN Domain-Integration
- **Excel Integration** - Automatischer Import aus `Serverliste2025FQDN.xlsx`
- **Certificate Discovery** - Automatische SSL-Port-Erkennung (443, 8443, 9443, etc.)
- **Report Generation** - HTML-Reports mit Corporate Design
- **Email Notifications** - SMTP-Integration für automatische Benachrichtigungen
- **Test Mode** - Konfigurierbare Test-Einschränkungen für Entwicklung

#### Configuration 📋

- **Config-Cert-Surveillance.json** - Zentrale JSON-Konfiguration
- **de-DE.json / en-US.json** - Mehrsprachige Lokalisierung
- **Externalized Settings** - Keine Hard-coded-Werte im Code

#### Compliance ✅

- **Regelwerk v9.3.0** - Vollständige Konformität mit MUW-Standards
- **PowerShell 5.1+** - Rückwärtskompatibilität gewährleistet
- **Cross-Platform Ready** - PS7+ Linux/macOS Vorbereitung
- **Enterprise Security** - RunAsAdministrator, Credential Management

---

## [Unreleased] - Geplante Features

### 🔮 Roadmap

- **FL-Certificate-Enhanced.psm1** - Erweiterte Zertifikatsprüfungen
- **Dashboard Integration** - Real-time Web-Dashboard
- **API Extensions** - RESTful API für externe Integrationen
- **Advanced Reporting** - PDF-Reports und erweiterte Analysen
- **Notification Channels** - Teams/Slack Integration
- **Certificate Automation** - Automatische Zertifikatserneuerung

---

## Version History Summary

| Version    | Datum      | Beschreibung               | Hauptfeatures                                       |
| ---------- | ---------- | -------------------------- | --------------------------------------------------- |
| **v1.1.0** | 2025-09-17 | **WebService Integration** | Zentrale API, Extended Modularity, Production Ready |
| **v1.0.3** | 2025-09-04 | **Initial Release**        | FL-Modules, Strict Modularity, Regelwerk Compliance |

---

## Breaking Changes

### v1.1.0

- **Regelwerk Update**: Hauptskript-Limit von 100 auf 300 Zeilen erweitert
- **Configuration Changes**: WebService.PrimaryServer jetzt erforderlich
- **TestMode Default**: Standardmäßig deaktiviert (PROD-ready)

### v1.0.3

- **Initial Architecture**: Vollständige Umstellung auf FL-* Module
- **Configuration Format**: JSON-basierte Konfiguration erforderlich
- **PowerShell Requirements**: Minimum PowerShell 5.1

---

## Migration Guide

### Von v1.0.3 zu v1.1.0

1. **Konfiguration aktualisieren**: WebService-Einstellungen in `Config-Cert-Surveillance.json`
2. **Module ergänzen**: `FL-CertificateAPI.psm1` und `FL-WebService.psm1` hinzufügen
3. **TestMode prüfen**: Bei Bedarf TestMode.Enabled auf `true` setzen
4. **WebService-URL**: PrimaryServer-Einstellung auf zentrale API anpassen

### Neue Installation

1. **Download**: Latest Release von Network Share oder Repository
2. **Setup**: `Setup-CertSurv.ps1` für interaktive Konfiguration ausführen
3. **Test**: `Test-CentralWebServiceIntegration.ps1` für Verbindungsvalidierung
4. **Production**: `Cert-Surveillance.ps1` für produktive Ausführung

---

## Support & Documentation

- **Regelwerk**: `README-Regelwerk-v9.3.0.md` - Vollständige Compliance-Dokumentation
- **Configuration**: `Config-Cert-Surveillance.json` - Zentrale Konfigurationsdatei
- **Testing**: `Check-RegelwerkCompliance.ps1` - Automatische Compliance-Prüfung
- **Integration**: `Test-CentralWebServiceIntegration.ps1` - WebService-Validierung

---

**Autor**: Flecki (Tom) Garnreiter  
**Copyright**: © 2025 MedUni Wien  
**License**: MIT License  
**PowerShell**: 5.1+ | 7+ (Cross-Platform)
