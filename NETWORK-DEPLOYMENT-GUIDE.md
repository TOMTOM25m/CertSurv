# Certificate Surveillance System - Network Deployment Guide

## Version Information

- **CertSurv Version:** v1.3.1
- **CertWebService Version:** v2.1.0
- **Deployment Script:** v1.1.0
- **Regelwerk Compliance:** v9.5.0
- **Datum:** 2025-09-24

---

## 1. VORBEREITUNG - Netzwerkpfad vorbereiten

### Schritt 1: Netzwerkordner erstellen

```powershell
# Beispiel Netzwerkpfad (anpassen je nach Infrastructure)
$NetworkPath = "\\itscmgmt03\iso\CertSurv"

# Verzeichnis erstellen falls nicht vorhanden
New-Item -Path $NetworkPath -ItemType Directory -Force
```

### Schritt 2: Berechtigungen setzen

- **Lesezugriff:** Domain Users, Administrators
- **Schreibzugriff:** IT-Administratoren, Service-Accounts
- **Vollzugriff:** Domain Admins

---

## 2. DEPLOYMENT - Vom Entwicklungsrechner

### Schritt 1: CertSurv auf Netzwerkpfad veroeffentlichen

```powershell
# Im CertSurv-Verzeichnis ausfuehren
cd "f:\DEV\repositories\CertSurv"

# Veroeffentlichung starten
.\Deploy-Network.ps1 -Action Publish -NetworkPath "\\itscmgmt03\iso\CertSurv"
```

### Schritt 2: Deployment verifizieren

```powershell
# Veroeffentlichung ueberpruefen
.\Deploy-Network.ps1 -Action Verify -NetworkPath "\\itscmgmt03\iso\CertSurv"
```

**Wichtige Dateien die kopiert werden:**

- `Cert-Surveillance.ps1` - Haupt-Surveillance-Script (Main)
- `Setup.ps1` - Installations- und Konfigurationsskript  
- `Setup-CertSurv.ps1` - GUI für Config-Bearbeitung
- `Manage.ps1` - Management und Wartungsfunktionen
- `Deploy.ps1` - Deployment-Funktionen
- `Check.ps1` - System-Checks und Validierung
- `Config/` - Konfigurationsdateien (inkl. Config-Cert-Surveillance.json)
- `Modules/` - PowerShell-Module (FL-*)
- `README.md` - Dokumentation
- `CHANGELOG.md` - Aenderungsprotokoll
- `NETWORK-DEPLOYMENT-GUIDE.md` - Dieses Handbuch

**Ausgeschlossene Dateien:**

- `.git/` - Git-Repository-Daten
- `LOG/` - Entwicklungs-Logdateien
- `old/` - Veraltete Skripte

---

## 2.1 CERTWEBSERVICE DEPLOYMENT - Zusätzlicher Service

### CertWebService v2.1.0 auf Netzwerk deployen

```powershell
# CertWebService auf Netzwerkpfad bereitstellen
robocopy "f:\DEV\repositories\CertWebService" "\\itscmgmt03\iso\CertWebService" /E /NFL /NDL /NJH /NJS /NC /NS /NP
```

**CertWebService Dateien:**
- `Setup.ps1` - Unified WebService Setup mit IIS-Integration
- `Install.bat` - Robocopy-basierter Installer mit lokaler Ausführung
- `Test.ps1` - Umfassende Endpoint-Tests
- `Setup-ScheduledTask-CertScan.ps1` - Automatische Task-Erstellung
- `README.txt` - WebService-Dokumentation
- `VERSION.txt` - Paket-Informationen

**Installation auf Zielservern:**
```cmd
# Auf Zielserver (als Administrator)
cd \\itscmgmt03\iso\CertWebService
Install.bat
```

---

## 3. INSTALLATION - Auf itscmgmt03 Server

### Schritt 1: Auf itscmgmt03 anmelden

```cmd
# RDP oder Direct Console Access
mstsc /v:itscmgmt03
```

### Schritt 2: PowerShell als Administrator oeffnen

```powershell
# PowerShell als Administrator starten
Start-Process PowerShell -Verb RunAs
```

### Schritt 3: Installation von Netzwerkpfad

```powershell
# Wechsel zum Netzwerkverzeichnis
cd "\\itscmgmt03\iso\CertSurv"

# Installation starten
.\Deploy-Network.ps1 -Action Install -NetworkPath "\\itscmgmt03\iso\CertSurv"
```

**Alternative manuelle Installation:**

```powershell
# Lokales Installationsverzeichnis erstellen
$InstallPath = "C:\Tools\CertSurv"
New-Item -Path $InstallPath -ItemType Directory -Force

# Dateien mit robocopy kopieren (Regelwerk v9.5.0)
robocopy "\\itscmgmt03\iso\CertSurv" $InstallPath /E /R:3 /W:10 /NP

# Setup ausfuehren
cd $InstallPath
.\Setup.ps1
```

### Schritt 4: Konfiguration anpassen

```powershell
# Konfigurationsdatei editieren
notepad "C:\Tools\CertSurv\Config\Config-Main.json"
```

**Wichtige Konfigurationsparameter:**

- `ServerList`: Liste der zu ueberwachenden Server
- `CertificateThreshold`: Schwellenwert fuer Certificate-Warnung (Tage)
- `LogLevel`: Logging-Level (DEBUG, INFO, WARN, ERROR)
- `ReportPath`: Pfad fuer Reports
- `ScheduleInterval`: Intervall fuer automatische Checks

---

## 4. BETRIEB - System starten und testen

### Schritt 1: Erste Ausfuehrung testen

```powershell
cd "C:\Script\CertSurv-Master"

# System-Check ausfuehren
.\Check.ps1

# Setup-GUI für Konfiguration (optional)
.\Setup-CertSurv.ps1

# Erstes Surveillance-Run
.\Cert-Surveillance.ps1
```

### Schritt 2: Service-Installation (optional)

```powershell
# Scheduled Task erstellen
.\Setup.ps1 -CreateScheduledTask

# Oder als Windows Service
.\Setup.ps1 -InstallService
```

### Schritt 3: Monitoring einrichten

```powershell
# Management-Interface starten
.\Manage.ps1 -ShowDashboard

# Log-Monitoring
.\Manage.ps1 -TailLogs
```

---

## 5. WARTUNG - Regelmaessige Tasks

### Taeglich

- Log-Dateien pruefen: `.\Manage.ps1 -CheckLogs`
- System-Status: `.\Check.ps1 -Quick`

### Woechentlich

- Full System Check: `.\Check.ps1 -Full`
- Report-Generation: `.\Main.ps1 -GenerateReport`

### Monatlich

- Update-Check: `.\Manage.ps1 -CheckUpdates`
- Configuration-Review: `.\Manage.ps1 -ReviewConfig`

---

## 6. TROUBLESHOOTING - Haeufige Probleme

### Problem: Netzwerkzugriff fehlgeschlagen

```powershell
# Netzwerkverbindung testen
Test-NetConnection -ComputerName itscmgmt03 -Port 445

# Alternative Pfade testen
dir \\itscmgmt03\c$
dir \\itscmgmt03\iso
```

### Problem: PowerShell Execution Policy

```powershell
# Execution Policy temporaer aendern
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Oder mit Parameter
PowerShell.exe -ExecutionPolicy Bypass -File ".\Setup.ps1"
```

### Problem: Module nicht gefunden

```powershell
# Module-Pfad pruefen
$env:PSModulePath

# Module manuell importieren
Import-Module ".\Modules\FL-Config.psm1" -Force
```

---

## 7. SICHERHEIT - Security Guidelines

### Berechtigungen

- **Minimalprinzip**: Nur notwendige Berechtigungen vergeben
- **Service-Account**: Dedicated Service-Account verwenden
- **Audit-Trail**: Alle Aktionen loggen

### Netzwerk

- **SMB-Signing**: Aktiviert fuer Netzwerkzugriffe
- **Firewall**: Nur notwendige Ports freigeben
- **Monitoring**: Netzwerkzugriffe ueberwachen

### Logs

- **Retention**: 90 Tage Log-Aufbewahrung
- **Backup**: Regelmaessige Log-Backups
- **Analysis**: Anomalie-Detection

---

## 8. KOMMANDOREFERENZ - Schnellzugriff

### Deployment-Kommandos

```powershell
# Veroeffentlichen
.\Deploy-Network.ps1 -Action Publish -NetworkPath "\\server\iso\CertSurv"

# Installieren  
.\Deploy-Network.ps1 -Action Install -NetworkPath "\\server\iso\CertSurv"

# Verifizieren
.\Deploy-Network.ps1 -Action Verify -NetworkPath "\\server\iso\CertSurv"
```

### System-Kommandos

```powershell
# Setup und Konfiguration
.\Setup.ps1

# Setup-GUI für Config-Bearbeitung
.\Setup-CertSurv.ps1

# Haupt-Surveillance
.\Cert-Surveillance.ps1

# System-Management
.\Manage.ps1

# System-Checks
.\Check.ps1

# Deployment-Operationen
.\Deploy.ps1
```

---

## SUPPORT KONTAKT

**Administrator:** Flecki (Tom) Garnreiter  
**Version:** Certificate Surveillance System v1.3.1 + CertWebService v2.1.0  
**Regelwerk:** v9.5.0 (File Operations + Network Deployment Standards)  
**Datum:** 2025-09-24  
**Neue Features:** Setup-GUI, Robocopy-Deployment, Automatische Task-Erstellung

---

**Dieses Dokument ist vollstaendig ASCII-kompatibel fuer universelle PowerShell-Unterstuetzung*
