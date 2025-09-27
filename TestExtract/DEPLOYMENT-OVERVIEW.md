# Certificate WebService - Deployment Overview
## Version: v1.0.3 | Datum: 2025-09-17 | Regelwerk: v9.3.0

## 🎯 VERFÜGBARE DATEIEN AUF ISO-SHARE

**Network-Share:** `\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment\`

```
CertDeployment/
├── CertWebService-Deployment-2025-09-17.zip    # 📦 Komplettes Deployment-Paket
├── DEPLOYMENT-README.md                         # 📖 Deployment-Übersicht
├── INSTALLATION-GUIDE.md                       # 📚 Detaillierte Installations-Anleitung
└── DEPLOYMENT-OVERVIEW.md                      # 📋 Diese Übersichtsdatei
```

---

## 🚀 SCHNELL-INSTALLATION

### **SCHRITT 1: PAKET HERUNTERLADEN**
```powershell
# Von Network-Share kopieren:
Copy-Item "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment\CertWebService-Deployment-2025-09-17.zip" -Destination "C:\Temp\"

# Entpacken:
Expand-Archive -Path "C:\Temp\CertWebService-Deployment-2025-09-17.zip" -DestinationPath "C:\Temp\"
cd "C:\Temp\CertWebService-Deployment"
```

### **SCHRITT 2: INSTALLATION (als Administrator)**
```powershell
# Für ISO-Server (itscmgmt03):
.\Install-DeploymentPackage.ps1 -ServerType ISO

# Für Exchange-Server (EX01, EX02, EX03):
.\Install-DeploymentPackage.ps1 -ServerType Exchange

# Für Domain Controller (UVWDC001, UVWDC002):
.\Install-DeploymentPackage.ps1 -ServerType DomainController
```

### **SCHRITT 3: VALIDIERUNG**
```powershell
# Installation testen:
.\Scripts\Test-Installation.ps1 -ExternalTest
```

---

## 🎯 SERVER-KONFIGURATIONEN

| Server-Typ | HTTP-Port | HTTPS-Port | Ziel-Server |
|------------|-----------|------------|-------------|
| **ISO** | 9080 | 9443 | itscmgmt03 |
| **Exchange** | 9180 | 9543 | EX01, EX02, EX03 |
| **DomainController** | 9280 | 9643 | UVWDC001, UVWDC002 |
| **Application** | 9380 | 9743 | C-APP01, C-APP02 |

---

## ✅ WAS DAS PAKET MACHT

- ✅ **Automatische IIS-Installation** und Konfiguration
- ✅ **SSL-Zertifikat** automatisch erstellt
- ✅ **Firewall-Regeln** automatisch gesetzt
- ✅ **WebService-Dateien** komplett installiert
- ✅ **Performance-Tests** nach Installation
- ✅ **Rollback** bei Fehlern
- ✅ **Detaillierte Logs** für Troubleshooting

---

## 🔗 NACH DER INSTALLATION

**Certificate Surveillance konfigurieren (auf Client-Systemen):**

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

## 📞 SUPPORT

**Bei Problemen:**
1. **Installations-Logs prüfen:** `C:\Temp\CertWebService-Deployment\LOG\*.log`
2. **Test-Skript ausführen:** `.\Scripts\Test-Installation.ps1`
3. **Detaillierte Anleitung:** `INSTALLATION-GUIDE.md`

---

## 🎉 ERFOLGSMELDUNG

**Installation erfolgreich wenn:**
- ✅ HTTP-Endpoint erreichbar (http://SERVERNAME:9080)
- ✅ HTTPS-Endpoint erreichbar (https://SERVERNAME:9443)
- ✅ JSON-APIs liefern gültige Daten
- ✅ Response-Zeit unter 500ms

**Test-URL:** `http://SERVERNAME:9080/health.json`

---

**Erstellt:** 2025-09-17 | **Version:** v1.0.3 | **Share:** \\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment\