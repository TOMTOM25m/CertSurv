# Certificate Surveillance v1.1.0 - Datei-Klassifikation

## ✅ CORE SYSTEM FILES (BEHALTEN)

### Main Scripts:
- `Cert-Surveillance.ps1` - Hauptskript v1.1.0 ✅
- `Setup-CertSurv.ps1` - WPF Setup GUI ✅

### Configuration:
- `Config/Config-Cert-Surveillance.json` - Hauptkonfiguration ✅
- `Config/de-DE.json` - Deutsche Lokalisierung ✅
- `Config/en-US.json` - Englische Lokalisierung ✅

### Core FL-Modules (v1.1.0):
- `FL-Config.psm1` - Konfigurationsverwaltung ✅
- `FL-Logging.psm1` - Strukturierte Protokollierung ✅
- `FL-CoreLogic.psm1` - Workflow-Orchestrierung ✅
- `FL-DataProcessing.psm1` - Excel/CSV-Datenverarbeitung ✅
- `FL-NetworkOperations.psm1` - Netzwerk-Konnektivitätsprüfungen ✅
- `FL-Reporting.psm1` - HTML/JSON-Berichtgenerierung ✅
- `FL-ActiveDirectory.psm1` - AD-Integration ✅
- `FL-Security.psm1` - SSL/TLS-Zertifikatsvalidierung ✅
- `FL-Maintenance.psm1` - System-Wartungsfunktionen ✅
- `FL-Utils.psm1` - Allgemeine Hilfsfunktionen ✅
- `FL-Compatibility.psm1` - PowerShell-Versionskompatibilität ✅
- `FL-CertificateAPI.psm1` - Zentrale WebService-Kommunikation ✅
- `FL-WebService.psm1` - IIS WebService Management ✅

### Testing & Validation:
- `Test-CentralWebServiceIntegration.ps1` - WebService-Integrationstests ✅
- `Check-RegelwerkCompliance.ps1` - Compliance-Prüfung ✅

### Documentation:
- `README.md` - Hauptdokumentation ✅
- `README-Regelwerk-v9.3.0.md` - Regelwerk-Dokumentation ✅
- `CHANGELOG.md` - Versionshistorie ✅
- `RELEASE-v1.1.0.md` - Release-Dokumentation ✅
- `JSON-Version-Control.md` - Versionskontrolle ✅

### Directories:
- `LOG/` - Protokolldateien ✅
- `Config/` - Konfigurationsdateien ✅

## 🗑️ OBSOLETE FILES (NACH OLD/ VERSCHIEBEN)

### Veraltete/Broken Module:
- `FL-Certificate-broken.psm1` - Defekte Version
- `FL-Certificate-Clean.psm1` - Veraltete Version  
- `FL-Certificate-Fixed.psm1` - Veraltete Version
- `FL-Certificate.psm1` - Veraltete Hauptversion
- `FL-Certificate.psm1.backup` - Backup-Datei
- `FL-Certificate-Minimal.psm1` - Minimalversion
- `FL-NetworkOperations-v1.1.psm1` - Veraltete Versionsnummer
- `FL-Gui.psm1` - GUI-Module (nicht mehr verwendet)

### Test/Development Scripts:
- `test-reporting.ps1` - Test-Script
- `test-mini-workflow.ps1` - Test-Script  
- `test.log` - Test-Logdatei
- `installIIS.ps1` - IIS-Installation (eigenständig)
- `Install-CertificateWebService.ps1` - Veraltetes WebService-Install
- `Setup-CertSurv-Clean.ps1` - Alternative Setup-Version

### Legacy/Unrelated:
- `seekCertReNewDay.ps1` - Legacy-Script (separates System)
- `Get-RemoteCertificate.ps1` - Standalone-Utility
- `FIRSTME.md` - Veraltete Dokumentation
- `CHANGELOG-AD-Integration.md` - Spezifische Integration-Doku
- `CONFIGURATION-ANALYSIS.md` - Analyse-Dokumentation

### Reports/Temp:
- `Cert-Report-2025-09-16.html` - Temporärer Report
- `reports/` - Report-Verzeichnis (falls temporär)
- `Tests/` - Test-Verzeichnis

### Legacy Config:
- `Config/Config-seekCertReNewDay.json` - Legacy-Konfiguration

## ✅ NEUE STRUKTUR NACH BEREINIGUNG:

```
CertSurv/
├── Cert-Surveillance.ps1
├── Setup-CertSurv.ps1
├── Test-CentralWebServiceIntegration.ps1
├── Check-RegelwerkCompliance.ps1
├── README.md
├── README-Regelwerk-v9.3.0.md
├── CHANGELOG.md
├── RELEASE-v1.1.0.md
├── JSON-Version-Control.md
├── Config/
│   ├── Config-Cert-Surveillance.json
│   ├── de-DE.json
│   └── en-US.json
├── Modules/
│   ├── FL-Config.psm1
│   ├── FL-Logging.psm1
│   ├── FL-CoreLogic.psm1
│   ├── FL-DataProcessing.psm1
│   ├── FL-NetworkOperations.psm1
│   ├── FL-Reporting.psm1
│   ├── FL-ActiveDirectory.psm1
│   ├── FL-Security.psm1
│   ├── FL-Maintenance.psm1
│   ├── FL-Utils.psm1
│   ├── FL-Compatibility.psm1
│   ├── FL-CertificateAPI.psm1
│   └── FL-WebService.psm1
├── LOG/
└── old/
    ├── [ALLE OBSOLETEN DATEIEN]
    └── seekCertReNewDay.ps1 (bereits vorhanden)
```