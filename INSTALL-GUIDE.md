# Install-CertSurv.bat - Universal Installation Script

## Übersicht
Das `Install-CertSurv.bat` Script ist die **universelle Version** des Certificate Surveillance System Installers. Es kann auf verschiedenen Servern und in unterschiedlichen Netzwerkumgebungen verwendet werden.

## Konfiguration

### 📝 Anpassung der Pfade
Bearbeiten Sie die **CONFIGURATION SECTION** am Anfang des Scripts:

```batch
REM =================================================================
REM CONFIGURATION SECTION - ANPASSEN JE NACH INFRASTRUCTURE!
REM =================================================================
set DEFAULT_NETWORK_PATH=\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv
set DEFAULT_LOCAL_PATH=C:\Script\CertSurv-Master
```

### 🎯 Beispiel-Konfigurationen

**Für verschiedene Server:**
```batch
REM ITSCmgmt03 (Standard)
set DEFAULT_NETWORK_PATH=\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv

REM Anderer Fileserver
set DEFAULT_NETWORK_PATH=\\fileserver01.domain.com\software\CertSurv

REM Lokales Netzlaufwerk
set DEFAULT_NETWORK_PATH=\\nas01\share\Applications\CertSurv
```

**Für verschiedene lokale Pfade:**
```batch
REM Standard C: Drive
set DEFAULT_LOCAL_PATH=C:\Script\CertSurv-Master

REM Alternative D: Drive
set DEFAULT_LOCAL_PATH=D:\Applications\CertSurv-Master

REM Programme Ordner
set DEFAULT_LOCAL_PATH=C:\Program Files\CertSurv
```

## Verwendung

### 1. **Vorbereitung**
- Script als Administrator ausführen
- Netzwerkverbindung zum Quell-Server sicherstellen
- Pfade in CONFIGURATION SECTION anpassen

### 2. **Installation**
```cmd
# Als Administrator ausführen
Install-CertSurv.bat
```

### 3. **Nach Installation**
```cmd
# GUI-Konfiguration
PowerShell.exe -ExecutionPolicy Bypass -File "Setup-CertSurv.ps1"

# System testen
PowerShell.exe -ExecutionPolicy Bypass -File "Check.ps1"

# System starten
PowerShell.exe -ExecutionPolicy Bypass -File "Cert-Surveillance.ps1"
```

## Features

### ✅ Universal einsetzbar
- Konfigurierbare Netzwerk- und lokale Pfade
- Automatische Pfad-Validierung
- Fehlerbehandlung für verschiedene Umgebungen

### ✅ Robocopy Deployment (Regelwerk v9.5.0)
- Netzwerk-resiliente Dateiübertragung
- Retry-Mechanismus (3 Versuche, 10s Wartezeit)
- Exit-Code Validierung

### ✅ Automatische Setup Integration
- Ausführung von Setup.ps1
- GUI-Konfiguration verfügbar
- Vollständige Installations-Pipeline

## Deployment

### Für ITSCmgmt03:
```
Netzwerk: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\Install-CertSurv.bat
Lokal: C:\Script\CertSurv-Master\
```

### Für andere Server:
1. CONFIGURATION SECTION anpassen
2. Script auf Ziel-Netzlaufwerk kopieren
3. Auf Ziel-Server ausführen

## Version
- **Script Version:** v1.3.1
- **Regelwerk:** v9.5.0
- **Datum:** 2025-09-24
- **Kompatibilität:** Windows Server 2016+, PowerShell 5.1+