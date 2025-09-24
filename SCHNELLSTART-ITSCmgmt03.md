# SCHNELLSTART: CertSurv Installation auf ITSCmgmt03

## SOFORT-INSTALLATION (3 Minuten)

### Schritt 1: Administrator-PowerShell oeffnen
```cmd
# Als Administrator auf ITSCmgmt03.srv.meduniwien.ac.at anmelden
# PowerShell als Administrator starten
```

### Schritt 2: Schnellinstallation starten
```powershell
# Zu diesem Verzeichnis wechseln (KORREKTER NETZWERKPFAD)
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv"

# Quick Setup ausfuehren
.\QuickSetup-ITSCmgmt03.ps1

# ODER: Batch-Installation
.\Install-on-itscmgmt03.bat
```

### Schritt 3: Installation pruefen
```powershell
# Zu Installationsverzeichnis wechseln  
cd "C:\Script\CertSurv-Master"

# System-Check ausfuehren
.\Check.ps1

# Test-Run starten
.\Main.ps1 -TestMode
```

---

## VERFUEGBARE INSTALLATIONSMETHODEN

### Methode 1: QuickSetup (EMPFOHLEN)
- **Datei:** `QuickSetup-ITSCmgmt03.ps1`
- **Vorteile:** Vollautomatisch, MedUniWien-Konfiguration, Scheduled Task
- **Dauer:** 2-3 Minuten

### Methode 2: Batch-Installation
- **Datei:** `Install-on-itscmgmt03.bat`  
- **Vorteile:** Einfach, keine PowerShell-Kenntnisse noetig
- **Dauer:** 3-5 Minuten

### Methode 3: PowerShell Deployment
- **Datei:** `Deploy-Network.ps1`
- **Vorteile:** Flexible Parameter, Expertensteuerung
- **Dauer:** 5-10 Minuten

### Methode 4: Manuelle Installation
- **Prozess:** Robocopy + Setup.ps1
- **Vorteile:** Vollstaendige Kontrolle
- **Dauer:** 10-15 Minuten

---

## WICHTIGE DATEIEN

### Installationsskripte:
- `QuickSetup-ITSCmgmt03.ps1` - Schnellinstallation fuer ITSCmgmt03
- `Install-on-itscmgmt03.bat` - Batch-Installation  
- `Deploy-Network.ps1` - Erweiterte Deployment-Optionen

### Haupt-System:
- `Main.ps1` - Certificate Surveillance Hauptprogramm
- `Setup.ps1` - System-Setup und Konfiguration
- `Manage.ps1` - Management-Interface
- `Check.ps1` - System-Validierung
- `Deploy.ps1` - Deployment-Funktionen

### Konfiguration:
- `Config/Config-Cert-Surveillance.json` - Hauptkonfiguration
- `Config/de-DE.json` - Deutsche Sprachdatei
- `Config/en-US.json` - Englische Sprachdatei

### Module:
- `Modules/FL-*.psm1` - PowerShell-Funktionsmodule

### Dokumentation:
- `README.md` - System-Dokumentation
- `CHANGELOG.md` - Versionshistorie
- `INSTALL-BEST-PRACTICES-ITSCmgmt03.md` - Detaillierte Anleitung

---

## TROUBLESHOOTING - Haeufige Probleme

### Problem: "Execution Policy Restricted"
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

### Problem: "Pfad nicht gefunden"
```powershell
# Aktuelles Verzeichnis pruefen
Get-Location

# Zu korrektem Pfad wechseln
cd "C:\ISO\CertSurv"
```

### Problem: "Netzwerkpfad nicht verfuegbar"
```powershell
# SMB-Verbindung testen
Test-NetConnection -ComputerName "file-server" -Port 445

# Admin-Share testen
dir \\ITSCmgmt03\C$\ISO\CertSurv
```

---

## SUPPORT

**Bei Problemen:**
1. Log pruefen: `C:\Temp\CertSurv-Install.log`
2. System-Check: `.\Check.ps1 -Verbose`
3. Detaillierte Anleitung: `INSTALL-BEST-PRACTICES-ITSCmgmt03.md`

**Kontakt:**
- **Administrator:** Flecki (Tom) Garnreiter
- **E-Mail:** tom.garnreiter@meduniwien.ac.at
- **System:** Certificate Surveillance v1.3.0

---

**Installation ready for ITSCmgmt03.srv.meduniwien.ac.at**  
**Regelwerk v9.5.0 compliant - ASCII encoded for universal compatibility**