# Certificate WebService - Deployment Package
## Version: v1.0.3 | Regelwerk: v9.3.0

# 🚀 AUTOMATISIERTES DEPLOYMENT-PAKET

Dieses Paket installiert den Certificate WebService automatisch auf Windows Server mit IIS.

## 📦 PAKET-INHALT

```
CertWebService-Deployment/
├── Install-DeploymentPackage.ps1      # Haupt-Installer
├── WebService/                        # WebService-Dateien
│   ├── certificates.aspx
│   ├── certificates.json
│   ├── web.config
│   └── bin/
├── Scripts/                           # Installations-Skripte
│   ├── Install-IIS.ps1
│   ├── Configure-Firewall.ps1
│   └── Test-Installation.ps1
├── Config/                            # Konfigurations-Vorlagen
│   ├── Default-Config.json
│   └── Server-Profiles.json
└── Documentation/                     # Dokumentation
    ├── INSTALLATION.md
    ├── TROUBLESHOOTING.md
    └── SERVER-LIST.md
```

## ⚡ SCHNELL-INSTALLATION

```powershell
# 1. Paket entpacken auf Ziel-Server
# 2. PowerShell als Administrator öffnen
# 3. Installation starten:
.\Install-DeploymentPackage.ps1 -ServerType ISO -HttpPort 9080 -HttpsPort 9443
```

## 🎯 SERVER-PROFILE

### ISO-Server (itscmgmt03):
```powershell
.\Install-DeploymentPackage.ps1 -ServerType ISO -HttpPort 9080 -HttpsPort 9443
```

### Exchange-Server (EX01, EX02, EX03):
```powershell
.\Install-DeploymentPackage.ps1 -ServerType Exchange -HttpPort 9180 -HttpsPort 9543
```

### Domain Controller (UVWDC001, UVWDC002):
```powershell
.\Install-DeploymentPackage.ps1 -ServerType DomainController -HttpPort 9280 -HttpsPort 9643
```

## ✅ FEATURES

- ✅ **Automatische IIS-Installation** und Konfiguration
- ✅ **Firewall-Regeln** automatisch gesetzt
- ✅ **SSL-Zertifikat** automatisch erstellt
- ✅ **Port-Konflikte** automatisch vermieden
- ✅ **Rollback-Funktion** bei Fehlern
- ✅ **Installations-Validation** mit Tests
- ✅ **Multi-Server Support** mit verschiedenen Port-Ranges

## 📞 SUPPORT

Bei Problemen: Siehe `Documentation/TROUBLESHOOTING.md`

---
**Erstellt:** 2025-09-17 | **Version:** v1.0.3 | **Ziel:** Produktive WebService Distribution