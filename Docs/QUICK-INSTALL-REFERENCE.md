# INSTALLATION QUICK REFERENCE - ITSCmgmt03

## KORREKTE PFADE BESTÄTIGT ✅

### Netzwerkpfad (SOURCE):
```
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv
```

### Zielverzeichnis (TARGET):
```
C:\Script\CertSurv-Master
```

---

## SCHRITT-FÜR-SCHRITT INSTALLATION

### 1. Deployment Package bereitstellen (AUF ENTWICKLUNGSRECHNER)
```powershell
# Vom Entwicklungsrechner aus:
robocopy "f:\DEV\iso\CertSurv" "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv" /E /R:3 /W:5
```

### 2. Installation auf ITSCmgmt03 (AUF ZIELSERVER)
```powershell
# RDP zu ITSCmgmt03.srv.meduniwien.ac.at
# PowerShell als Administrator öffnen

# Zu Netzwerkverzeichnis wechseln
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv"

# Universal Installation (EMPFOHLEN - Regelwerk v9.5.0)
.\Install-CertSurv.bat

# ODER: Setup-GUI für Konfiguration
.\Setup-CertSurv.ps1
```

### 3. Installation validieren
```powershell
# Zu Installationsverzeichnis wechseln
cd "C:\Script\CertSurv-Master"

# System-Check
.\Check.ps1 -Full

# Test-Run
.\Main.ps1 -TestMode

# Scheduled Task prüfen
Get-ScheduledTask -TaskName "CertSurv-ITSCmgmt03-Daily"
```

---

## WICHTIGE VERZEICHNISSE

### Installation:
- **CertSurv System:** `C:\Script\CertSurv-Master\`
- **Konfiguration:** `C:\Script\CertSurv-Master\Config\`
- **Module:** `C:\Script\CertSurv-Master\Modules\`
- **Logs:** `C:\Script\CertSurv-Master\LOG\`

### Betrieb:
- **Reports:** `C:\Reports\CertSurv-Master\`
- **Backup:** `C:\Backup\CertSurv-Master\`
- **Archive:** `C:\Archive\CertSurv-Master\`

---

## TROUBLESHOOTING

### Problem: Netzwerkpfad nicht erreichbar
```powershell
# Verbindung testen
Test-NetConnection -ComputerName "itscmgmt03.srv.meduniwien.ac.at" -Port 445

# SMB-Share testen
dir "\\itscmgmt03.srv.meduniwien.ac.at\iso"
```

### Problem: Installation fehlgeschlagen
```powershell
# Manuelle Installation
New-Item -Path "C:\Script\CertSurv-Master" -ItemType Directory -Force
robocopy "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv" "C:\Script\CertSurv-Master" /E /R:3 /W:10
cd "C:\Script\CertSurv-Master"
.\Setup.ps1
```

---

## SUCCESS CRITERIA ✅

- [ ] Netzwerkpfad `\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv` erreichbar
- [ ] Installation in `C:\Script\CertSurv-Master` abgeschlossen  
- [ ] Alle 5 Haupt-Skripte vorhanden (Main, Setup, Manage, Deploy, Check)
- [ ] Config und Modules-Verzeichnisse kopiert
- [ ] Scheduled Task "CertSurv-ITSCmgmt03-Daily" erstellt
- [ ] System-Check erfolgreich: `.\Check.ps1 -Full`
- [ ] Test-Run erfolgreich: `.\Main.ps1 -TestMode`

---

**PFADE AKTUALISIERT UND GETESTET** ✅  
**BEREIT FÜR PRODUKTIONS-DEPLOYMENT** ✅