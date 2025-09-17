# CLIENT SERVER ROLLOUT PLAN v1.1.0

## Übersicht
- **Gesamt:** 151 Server aus Excel-Sheet
- **Domain-Server:** 63 (verschiedene Domains)
- **Workgroup-Server:** 88 (srv.meduniwien.ac.at)

## Rollout-Strategie

### Phase 1: Test-Server (empfohlen)
Beginnen Sie mit 3-5 Test-Servern aus verschiedenen Kategorien:

**Test-Kandidaten:**
1. `itscmgmt03.srv.meduniwien.ac.at` (Workgroup - Management)
2. `UVWDC001.uvw.meduniwien.ac.at` (Domain UVW - DC)
3. `NEURODC01.neuro.meduniwien.ac.at` (Domain NEURO - DC)
4. `testsrv01.srv.meduniwien.ac.at` (Workgroup - Test)
5. `EXMGMT02.ex.meduniwien.ac.at` (Domain EX - Management)

### Phase 2: Domain-Controller (wichtig)
- UVW Domain: 3 DCs
- NEURO Domain: 2 DCs  
- EX Domain: 3 DCs
- AD Domain: 4 DCs
- DGMW Domain: 2 DCs
- DIAWIN Domain: 2 DCs

### Phase 3: kritische Server
- File-Server (FS01, C-FS01, etc.)
- SQL-Server (C-SQL01, ZGASQL01, etc.)
- Application-Server (C-APP01, ZGAAPP01, etc.)

### Phase 4: Standard-Server
- Verbleibende Workgroup-Server
- Management-Server
- Test-/Dev-Server

## Manuelle Konfiguration pro Server

### 1. Server-Auswahl
```powershell
# Tool starten
.\Manage-ClientServers-Fixed.ps1  # (verwenden Sie die korrigierte Version)
```

### 2. Für jeden Server durchführen:
- **[1] System-Check:** Konnektivität und Voraussetzungen prüfen
- **[2] WebService installieren:** IIS + CertWebService auf Ports 9080/9443
- **[3] WebService testen:** API-Funktionalität validieren
- **[5] Als abgeschlossen markieren:** Server fertig

### 3. Individuelle Anpassungen
Da jeder Server unterschiedlich ist:
- **IIS:** Manche haben bereits IIS, andere benötigen Installation
- **Firewall:** Verschiedene Firewall-Konfigurationen
- **Permissions:** Domain vs. Workgroup Authentication
- **Ports:** Mögliche Port-Konflikte prüfen

### 4. Dokumentation
- **Notizen pro Server:** [7] im Tool verwenden
- **Fortschritt:** Automatisch in ClientProgress.json gespeichert
- **Probleme:** In Notizen dokumentieren für spätere Nachbearbeitung

## Deployment-Details

### WebService-Konfiguration:
- **HTTP:** Port 9080
- **HTTPS:** Port 9443
- **Pfad:** C:\inetpub\CertWebService
- **Endpunkt:** /certificates.json
- **Firewall:** Regeln für beide Ports

### Test-Validierung:
```powershell
# HTTP Test
Invoke-RestMethod -Uri "http://servername:9080/certificates.json"

# HTTPS Test  
Invoke-RestMethod -Uri "https://servername:9443/certificates.json"
```

## Zeitschätzung
- **Pro Server:** 15-30 Minuten (je nach Komplexität)
- **Test-Server (5):** 2-3 Stunden
- **Domain-Controller (16):** 1 Tag
- **Kritische Server (30):** 2-3 Tage
- **Standard-Server (100):** 1-2 Wochen

**Gesamt:** 2-3 Wochen bei kontinuierlicher Arbeit

## Erfolgs-Metriken
- **Completed:** Server erfolgreich mit WebService konfiguriert
- **Failed:** Server mit Problemen für spätere Bearbeitung
- **Response-Test:** API gibt gültige JSON-Antwort zurück

## Nächster Schritt
Starten Sie mit den 5 empfohlenen Test-Servern um den Prozess zu validieren!