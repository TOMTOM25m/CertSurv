# Installation auf Server mit bestehender Website

## Problem
Sie haben einen Server der bereits eine Website auf Port 80/443 hostet und möchten den Certificate WebService zusätzlich installieren.

## Lösung: Port-Konflikte vermeiden

### **Option 1: Standard-Ports verwenden (Empfohlen)**
Verwenden Sie die vorkonfigurierten Ports **9080** (HTTP) und **9443** (HTTPS):

```powershell
# Auf dem Zielserver ausführen
.\Install-CertificateWebService.ps1
```

**Vorteile:**
- ✅ Keine Konflikte mit bestehenden Websites
- ✅ Standardkonfiguration funktioniert sofort
- ✅ Firewall-Regeln werden automatisch erstellt
- ✅ Kompatibel mit allen Client-Tools

### **Option 2: Benutzerdefinierte Ports**
Falls Ports 9080/9443 bereits belegt sind:

```powershell
# Konfiguration anpassen vor Installation
$config = Get-Content "Config\Config-CertificateWebService.json" | ConvertFrom-Json
$config.WebService.HttpPort = 9180    # Alternativer HTTP-Port
$config.WebService.HttpsPort = 9543   # Alternativer HTTPS-Port
$config | ConvertTo-Json -Depth 10 | Set-Content "Config\Config-CertificateWebService.json"

# Installation mit angepasster Konfiguration
.\Install-CertificateWebService.ps1
```

### **Option 3: IIS Virtual Directory (Fortgeschritten)**
Integration in bestehende IIS-Website:

```powershell
# Manuelle IIS-Konfiguration
Import-Module WebAdministration

# Virtual Directory in bestehender Website erstellen
New-WebVirtualDirectory -Site "Default Web Site" -Name "certificates" -PhysicalPath "C:\inetpub\CertWebService"

# API-Endpunkt verfügbar unter:
# https://servername/certificates/certificates.json
```

## 🔍 **Schritt-für-Schritt Installation:**

### **1. Voraussetzungen prüfen**
```powershell
# Bestehende IIS-Sites anzeigen
Get-IISSite

# Belegte Ports prüfen
netstat -an | findstr :80
netstat -an | findstr :443
netstat -an | findstr :9080
netstat -an | findstr :9443
```

### **2. Installation durchführen**
```powershell
# Als Administrator auf dem Zielserver
cd "C:\Script\CertWebService"
.\Install-CertificateWebService.ps1
```

### **3. Installation validieren**
```powershell
# Website-Status prüfen
Get-IISSite | Where-Object Name -eq "CertWebService"

# API-Test
Invoke-RestMethod -Uri "https://localhost:9443/certificates.json"
```

## 🛠️ **Troubleshooting bei bestehenden Websites:**

### **Port-Konflikte lösen**
```powershell
# Alle IIS-Bindings anzeigen
Get-IISSiteBinding

# Spezifische Ports prüfen
Get-IISSiteBinding | Where-Object bindingInformation -like "*:9080:*"
Get-IISSiteBinding | Where-Object bindingInformation -like "*:9443:*"
```

### **Application Pool Konflikte**
```powershell
# Bestehende Application Pools
Get-IISAppPool

# CertWebService Pool Status
Get-IISAppPool -Name "CertWebService"
```

### **Firewall-Probleme**
```powershell
# Firewall-Regeln prüfen
Get-NetFirewallRule | Where-Object DisplayName -like "*Certificate*"

# Manuelle Regel erstellen falls nötig
New-NetFirewallRule -DisplayName "Certificate WebService HTTP" -Direction Inbound -Protocol TCP -LocalPort 9080 -Action Allow
New-NetFirewallRule -DisplayName "Certificate WebService HTTPS" -Direction Inbound -Protocol TCP -LocalPort 9443 -Action Allow
```

## 📋 **Checkliste für bestehende Webserver:**

- [ ] **Ports 9080/9443 sind frei**
- [ ] **IIS ist installiert** (automatisch installiert falls nicht vorhanden)
- [ ] **Administrator-Rechte** für Installation verfügbar
- [ ] **PowerShell 5.1+** ist verfügbar
- [ ] **Firewall** erlaubt eingehende Verbindungen auf Ports 9080/9443
- [ ] **Bestehende Website** läuft weiterhin normal
- [ ] **Certificate WebService** ist über API erreichbar

## 🎯 **Erwartetes Ergebnis:**

Nach erfolgreicher Installation:

```
Bestehende Website:  https://servername:443      (bleibt unverändert)
Certificate API:     https://servername:9443/certificates.json  (neu)
Certificate Web-UI:  https://servername:9443     (neu)
```

**Beide Services laufen parallel ohne Konflikte!**