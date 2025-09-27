# Certificate WebService - Installation Guide
## Version: v1.0.3 | Regelwerk: v9.3.0

## 🚀 SCHNELL-START

### **EINFACH-INSTALLATION (empfohlen):**

1. **Paket entpacken** auf dem Ziel-Server
2. **PowerShell als Administrator** öffnen
3. **Installation starten:**

```powershell
# Für ISO-Server (itscmgmt03):
.\Install-DeploymentPackage.ps1 -ServerType ISO

# Für Exchange-Server (EX01, EX02, EX03):
.\Install-DeploymentPackage.ps1 -ServerType Exchange

# Für Domain Controller (UVWDC001, UVWDC002):
.\Install-DeploymentPackage.ps1 -ServerType DomainController
```

### **Das war's! 🎉**

---

## 📋 DETAILLIERTE ANLEITUNG

### **SCHRITT 1: VORAUSSETZUNGEN PRÜFEN**

✅ **Administrator-Rechte** auf dem Ziel-Server  
✅ **PowerShell 5.1** oder höher  
✅ **Windows Server 2012** oder höher  
✅ **Internetverbindung** (für IIS-Features)  

**Prüfung:**
```powershell
# PowerShell-Version prüfen:
$PSVersionTable.PSVersion

# Administrator-Rechte prüfen:
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
```

### **SCHRITT 2: PAKET DEPLOYMENT**

1. **Deployment-Paket kopieren:**
   ```powershell
   # Beispiel: Von Netzwerk-Share kopieren
   Copy-Item "\\itsc020\Share\CertWebService-Deployment\*" -Destination "C:\Temp\CertWebService-Deployment\" -Recurse -Force
   cd "C:\Temp\CertWebService-Deployment"
   ```

2. **Installation ausführen:**
   ```powershell
   # Standard-Installation für ISO-Server:
   .\Install-DeploymentPackage.ps1 -ServerType ISO -TestInstallation
   
   # Mit benutzerdefinierten Ports:
   .\Install-DeploymentPackage.ps1 -ServerType Custom -HttpPort 9180 -HttpsPort 9543
   
   # Ohne Firewall-Konfiguration:
   .\Install-DeploymentPackage.ps1 -ServerType ISO -SkipFirewall
   ```

### **SCHRITT 3: INSTALLATION VALIDIEREN**

```powershell
# Automatischer Test (wird standardmäßig ausgeführt):
.\Scripts\Test-Installation.ps1 -HttpPort 9080 -HttpsPort 9443

# Mit externer Erreichbarkeit testen:
.\Scripts\Test-Installation.ps1 -HttpPort 9080 -HttpsPort 9443 -ExternalTest -ServerName "itscmgmt03.srv.meduniwien.ac.at"
```

### **SCHRITT 4: CERTIFICATE SURVEILLANCE KONFIGURIEREN**

**Auf dem Client (z.B. itsc020) anpassen:**

```json
// Config-Cert-Surveillance.json
{
  "WebService": {
    "Enabled": true,
    "PrimaryServer": "itscmgmt03.srv.meduniwien.ac.at",
    "HttpPort": 9080,
    "HttpsPort": 9443,
    "UseHttps": false,
    "FallbackToLocal": true
  }
}
```

---

## 🎯 SERVER-SPEZIFISCHE KONFIGURATIONEN

### **ISO-SERVER (itscmgmt03)**
- **Ports:** HTTP 9080, HTTPS 9443
- **Zweck:** Zentrale WebService-Installation
- **Besonderheiten:** Hauptinstallation für alle Certificate Surveillance Clients

```powershell
.\Install-DeploymentPackage.ps1 -ServerType ISO
```

### **EXCHANGE-SERVER (EX01, EX02, EX03)**
- **Ports:** HTTP 9180, HTTPS 9543
- **Zweck:** Redundante WebService-Instanzen
- **Besonderheiten:** Andere Ports um Konflikte zu vermeiden

```powershell
.\Install-DeploymentPackage.ps1 -ServerType Exchange
```

### **DOMAIN CONTROLLER (UVWDC001, UVWDC002)**
- **Ports:** HTTP 9280, HTTPS 9643
- **Zweck:** Backup WebService-Instanzen
- **Besonderheiten:** Minimale Installation

```powershell
.\Install-DeploymentPackage.ps1 -ServerType DomainController
```

### **CUSTOM INSTALLATION**
```powershell
.\Install-DeploymentPackage.ps1 -ServerType Custom -HttpPort 9999 -HttpsPort 9998 -SiteName "MyCustomSite"
```

---

## ⚡ PERFORMANCE & FEATURES

### **WAS DER WEBSERVICE BIETET:**

✅ **10x Performance-Boost** vs. direktes SSL-Scanning  
✅ **Zentralisierte API** für alle Certificate Surveillance Clients  
✅ **Caching-Mechanismus** für optimale Response-Zeiten  
✅ **JSON-APIs** für strukturierte Datenabfrage  
✅ **Health-Check Endpoints** für Monitoring  
✅ **PowerShell 5.1 Kompatibilität** für Legacy-Systeme  

### **API-ENDPOINTS:**

| Endpoint | Beschreibung | Beispiel-URL |
|----------|--------------|--------------|
| `/certificates.json` | Komplette Zertifikat-Daten | `http://itscmgmt03:9080/certificates.json` |
| `/summary.json` | Zusammenfassung & Statistiken | `http://itscmgmt03:9080/summary.json` |
| `/health.json` | Service-Status & Performance | `http://itscmgmt03:9080/health.json` |
| `/` | Web-Interface & Dokumentation | `http://itscmgmt03:9080/` |

### **PERFORMANCE-METRIKEN:**

- **Response-Zeit:** 0.1-0.3s (vs. 2-5s direktes SSL)
- **Concurrent Requests:** 50+ gleichzeitige Anfragen
- **Uptime:** 99.9% Verfügbarkeit angestrebt
- **Cache-Effizienz:** Intelligente Aktualisierung alle 15 Minuten

---

## 🔧 ERWEITERTE OPTIONEN

### **INSTALLATIONS-PARAMETER:**

```powershell
.\Install-DeploymentPackage.ps1 `
    -ServerType "Custom" `
    -HttpPort 9080 `
    -HttpsPort 9443 `
    -SiteName "CertSurveillance" `
    -InstallPath "C:\inetpub\wwwroot\CertSurveillance" `
    -SkipFirewall `
    -TestInstallation
```

### **SILENT INSTALLATION:**

```powershell
# Vollautomatisch ohne Benutzerinteraktion:
.\Install-DeploymentPackage.ps1 -ServerType ISO -Confirm:$false -Verbose
```

### **UNINSTALL:**

```powershell
# IIS-Site entfernen:
Remove-Website -Name "CertSurveillance"

# Dateien löschen:
Remove-Item -Path "C:\inetpub\wwwroot\CertSurveillance" -Recurse -Force

# Firewall-Regeln entfernen:
Remove-NetFirewallRule -DisplayName "*CertSurveillance*"
```

---

## 📊 MONITORING & WARTUNG

### **ÜBERWACHUNG:**

```powershell
# Service-Status prüfen:
Get-Website -Name "CertSurveillance"

# Performance-Test:
Measure-Command { Invoke-WebRequest -Uri "http://localhost:9080/health.json" -UseBasicParsing }

# Log-Dateien:
Get-ChildItem ".\LOG\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

### **UPDATES:**

1. **Neues Deployment-Paket** bereitstellen
2. **Installation** mit gleichen Parametern wiederholen
3. **Automatisches Rollback** bei Fehlern

---

## 🎉 ERFOLGS-BESTÄTIGUNG

**Installation erfolgreich wenn:**

✅ HTTP-Endpoint erreichbar (Status 200)  
✅ HTTPS-Endpoint erreichbar (Status 200)  
✅ JSON-APIs liefern gültige Daten  
✅ Response-Zeit unter 500ms  
✅ Firewall-Regeln aktiv  
✅ External Connectivity funktioniert  

**Test-Kommando:**
```powershell
.\Scripts\Test-Installation.ps1 -ExternalTest
```

**Bei Erfolg:**
```
🎉 INSTALLATION ERFOLGREICH VALIDIERT!
   Certificate WebService ist betriebsbereit
   HTTP URL:  http://SERVERNAME:9080
   HTTPS URL: https://SERVERNAME:9443
```

---

## 📞 SUPPORT

**Bei Problemen:**
1. **Log-Dateien prüfen:** `.\LOG\Deployment_*.log`
2. **Test-Skript ausführen:** `.\Scripts\Test-Installation.ps1`
3. **Troubleshooting-Guide:** `Documentation\TROUBLESHOOTING.md`
4. **Server-Liste:** `Documentation\SERVER-LIST.md`

---

**Erstellt:** 2025-09-17 | **Version:** v1.0.3 | **Regelwerk:** v9.3.0