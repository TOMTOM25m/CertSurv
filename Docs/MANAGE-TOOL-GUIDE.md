# Certificate Surveillance - Management Tool Guide v1.3.0

## 📋 Übersicht

Das **Manage.ps1** Script ist das konsolidierte Tool für die manuelle, schrittweise Einrichtung aller Server aus dem Excel-Sheet. Es wurde aus drei verschiedenen Versionen zusammengeführt und optimiert.

## 🚀 Funktionen

### ✅ **Kern-Features:**
- **Interaktive Server-Verwaltung** für alle Server aus Excel-Liste
- **Fortschritt-Speicherung** mit automatischer Wiederaufnahme
- **Umfassende System-Checks** (Netzwerk, WinRM, IIS, PowerShell)
- **WebService-Installation** mit IIS-Konfiguration
- **WebService-Tests** (HTTPS/HTTP Fallback)
- **Regelwerk v9.5.0 konform** mit einheitlichem Logging

### 🔧 **System-Anforderungen:**
- PowerShell 5.1+ (kompatibel mit PowerShell 7.x)
- Administrativa Rechte für Remote-Server-Zugriff
- WinRM aktiviert auf Ziel-Servern
- Excel-Datei mit Server-Liste

## ⚙️ **Konfiguration**

### 📁 **Erforderliche Config-Struktur in `Config-Cert-Surveillance.json`:**

```json
{
  "Excel": {
    "ExcelPath": "C:\\Script\\CertSurv-Master\\Data\\Server-List.xlsx",
    "SheetName": "ServerList", 
    "ServerNameColumnName": "ServerName"
  },
  "MainDomain": "meduniwien.ac.at"
}
```

### 📊 **Excel-Datei Format:**
- **Arbeitsblatt:** "ServerList" (konfigurierbar)
- **Spalten:** Mindestens "ServerName" Spalte erforderlich
- **Zusätzlich:** Optional Domain-Kontext für verschiedene Domänen

## 🎮 **Verwendung**

### 1. **Start des Tools:**
```powershell
.\Manage.ps1
```

### 2. **Interaktive Menü-Optionen:**

#### 🔍 **[1] System-Check durchführen**
- Netzwerk-Konnektivität testen
- WinRM-Verfügbarkeit prüfen  
- IIS-Installation überprüfen
- PowerShell-Version ermitteln
- Systemressourcen analysieren

#### 🚀 **[2] WebService installieren**
- IIS automatisch installieren
- WebService-Verzeichnis erstellen
- Zertifikat-Sammlung einrichten
- Ports 9080 (HTTP) und 9443 (HTTPS) konfigurieren
- Firewall-Regeln erstellen

#### 🧪 **[3] WebService testen**
- HTTPS-Endpoint testen (bevorzugt)
- HTTP-Fallback bei Bedarf
- Zertifikat-Daten validieren
- Service-Status überprüfen

#### 🔧 **[4] Manuelle Befehle ausführen**
- PowerShell-Session Anleitungen
- Remote Desktop Verbindung
- Troubleshooting-Hinweise

#### ✅ **[5] Server als abgeschlossen markieren**
- Status auf "Completed" setzen
- Fortschritt automatisch speichern
- Zum nächsten Server wechseln

#### ⏭️ **[6] Server überspringen** 
- Bei Problemen Server überspringen
- Status auf "Failed" mit Notiz
- Später erneut bearbeitbar

#### 📝 **[7] Notizen hinzufügen**
- Bemerkungen für Server speichern
- Troubleshooting-Informationen
- Besonderheiten dokumentieren

## 📈 **Fortschritt-Tracking**

### 💾 **Automatische Speicherung:**
- **Datei:** `LOG/ClientProgress.json`
- **Inhalt:** Server-Status, Zeitstempel, Statistiken
- **Wiederaufnahme:** Automatisch beim nächsten Start

### 📊 **Statistiken:**
```
══════════════════════════════════════════════════════════════════
    SERVER-STATISTIKEN  
══════════════════════════════════════════════════════════════════
Gesamte Server: 151
✅ Abgeschlossen: 45 (29.8%)
❌ Fehlgeschlagen: 3 (2.0%) 
⏳ Ausstehend: 103 (68.2%)
```

## 🔧 **Technische Details**

### 🌐 **WebService-Konfiguration:**
- **HTTP Port:** 9080
- **HTTPS Port:** 9443  
- **Pfad:** `C:\inetpub\CertWebService`
- **Endpunkt:** `/certificates.json`
- **IIS AppPool:** CertWebService

### 📋 **Server-Erkennung:**
- **Domain-Server:** `server.domain.meduniwien.ac.at`
- **Workgroup-Server:** `server.srv.meduniwien.ac.at`
- **Automatische FQDN-Generierung** basierend auf Excel-Daten

### 🔒 **Sicherheit:**
- **WinRM-Authentifizierung** erforderlich
- **Administrative Rechte** für IIS-Installation
- **Firewall-Konfiguration** automatisch
- **HTTPS bevorzugt** für WebService-Tests

## 🚨 **Fehlerbehebung**

### ❗ **Häufige Probleme:**

#### 1. **Excel-Datei nicht gefunden**
```
Fehler: Excel-Datei nicht gefunden: C:\Script\...\Server-List.xlsx
```
**Lösung:** Pfad in `Config-Cert-Surveillance.json` überprüfen

#### 2. **WinRM nicht verfügbar**
```
Empfehlung: WinRM muss aktiviert werden (Enable-PSRemoting)
```
**Lösung:** Auf Zielserver `Enable-PSRemoting -Force` ausführen

#### 3. **Modul nicht gefunden**
```
Fehler: Modul FL-Config.psm1 nicht gefunden
```
**Lösung:** Alle Module im `Modules/` Verzeichnis überprüfen

#### 4. **WebService-Test fehlgeschlagen**
```
WebService Test fehlgeschlagen: [SSL/TLS secure channel...]
```
**Lösung:** HTTP-Fallback wird automatisch versucht

## 📚 **Regelwerk-Konformität**

### ✅ **Regelwerk v9.5.0 Standards:**
- **PowerShell Version Detection** integriert
- **Einheitliche Logging-Standards** umgesetzt
- **Unicode/ASCII Kompatibilität** gewährleistet  
- **Strukturierte Fehlerbehandlung** implementiert
- **Modulare Architektur** beibehalten

## 🏆 **Version History**

| Version | Datum | Änderungen |
|---------|-------|------------|
| v1.3.0 | 2025-09-27 | **Konsolidierte Version** - Zusammenführung aller Manage-Skripte |
| v1.2.0 | 2025-09-24 | Regelwerk v9.5.0 Updates, erweiterte System-Checks |
| v1.1.0 | 2025-09-20 | Basis-Implementation mit WebService-Installation |

---

## 👨‍💻 **Autor**
**Flecki (Tom) Garnreiter**  
Certificate Surveillance System  
Regelwerk: v9.5.0 | Build: 20250927.1