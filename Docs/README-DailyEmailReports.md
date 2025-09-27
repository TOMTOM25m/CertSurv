# Tägliche E-Mail-Reports - Einrichtungsanleitung

## Überblick

Das Certificate Surveillance System v1.1.0 speichert alle Zertifikatsdaten in JSON-Format und sendet automatisch gefilterte E-Mail-Reports täglich um 06:00 Uhr.

## 🔧 Einrichtung

### 1. Automatische Einrichtung (Empfohlen)

Führen Sie das Setup-Skript als Administrator aus:

```powershell
# Als Administrator ausführen
.\Setup-DailyEmailTask.ps1
```

Das Skript:
- Erstellt eine geplante Aufgabe im Windows Task Scheduler
- Konfiguriert tägliche Ausführung um 06:00 Uhr
- Richtet entsprechende Berechtigungen ein

### 2. Manuelle Einrichtung

Falls die automatische Einrichtung nicht funktioniert:

1. **Windows Task Scheduler öffnen** (`taskschd.msc`)
2. **Neue Aufgabe erstellen:**
   - Name: `Certificate-Surveillance-DailyEmail`
   - Beschreibung: `Tägliche E-Mail-Versendung von Zertifikats-Reports um 06:00 Uhr`
   - Sicherheitsoptionen: "Unabhängig von der Benutzeranmeldung ausführen"

3. **Trigger konfigurieren:**
   - Täglich um 06:00 Uhr
   - Wiederholen: Nein

4. **Aktion konfigurieren:**
   - Programm: `PowerShell.exe`
   - Argumente: `-NoProfile -ExecutionPolicy Bypass -File "F:\DEV\repositories\CertSurv\DailyEmailScheduler.ps1"`

## 📊 Funktionsweise

### JSON-Datenspeicherung

```powershell
# Automatisch erstellt bei jeder Ausführung
LOG/CertificateData_2025-09-17.json
```

**JSON-Struktur:**
```json
{
  "Generated": "2025-09-17 14:30:00",
  "Version": "v1.1.0",
  "TotalServers": 151,
  "Summary": {
    "ValidCertificates": 145,
    "ExpiredCertificates": 2,
    "CriticalCertificates": 3,
    "WarningCertificates": 1
  },
  "Certificates": [...]
}
```

### E-Mail-Filter und Prioritäten

| Status | Beschreibung | Priorität | Icon |
|--------|--------------|-----------|------|
| **Expired** | Abgelaufen | 🔴 Höchste | 🔴 |
| **Urgent** | ≤ 10 Tage | 🟠 Hoch | 🟠 |
| **Critical** | ≤ 30 Tage | 🟡 Mittel | 🟡 |
| **Warning** | ≤ 60 Tage | 🟢 Niedrig | 🟢 |

### Zeitfenster

- **Geplante Zeit:** 06:00 Uhr
- **Toleranzfenster:** ±30 Minuten (05:30 - 06:30)
- **Fallback:** Verwendet Daten vom Vortag falls aktuell nicht verfügbar

## 📧 E-Mail-Konfiguration

### Empfänger

```json
{
  "Mail": {
    "DevTo": "thomas.garnreiter@meduniwien.ac.at",
    "ProdTo": "win-admin@meduniwien.ac.at",
    "DailyReport": {
      "ScheduledTime": "06:00",
      "IncludeStatuses": ["Expired", "Urgent", "Critical", "Warning"]
    }
  }
}
```

### E-Mail-Betreff-Beispiele

- `🔴 2 ABGELAUFENE Zertifikate!`
- `🟠 5 DRINGENDE Zertifikate!`
- `🟡 8 kritische Zertifikate`
- `🟢 12 Zertifikate zur Überwachung`
- `✅ Alle Zertifikate gültig`

## 🛠️ Verwaltungskommandos

### Task Scheduler Verwaltung

```powershell
# Status prüfen
Get-ScheduledTask -TaskName "Certificate-Surveillance-DailyEmail"

# Manuell ausführen
Start-ScheduledTask -TaskName "Certificate-Surveillance-DailyEmail"

# Task-Historie anzeigen
Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-TaskScheduler/Operational'; 
    ID=200,201
} | Select-Object -First 10

# Task löschen
Unregister-ScheduledTask -TaskName "Certificate-Surveillance-DailyEmail" -Confirm:$false
```

### Manuelle E-Mail-Versendung

```powershell
# Force-Modus (ignoriert Zeitfenster)
Import-Module .\Modules\FL-DataStorage.psm1
$config = Get-Content "Config\Config-Cert-Surveillance.json" | ConvertFrom-Json
Send-DailyCertificateReport -JsonFilePath "LOG\CertificateData_2025-09-17.json" -Config $config -LogFile "LOG\manual_email.log" -Force
```

## 📂 Dateien und Verzeichnisse

```
CertSurv/
├── DailyEmailScheduler.ps1          # Hauptskript für zeitgesteuerte E-Mails
├── Setup-DailyEmailTask.ps1         # Task Scheduler Einrichtung
├── Modules/
│   └── FL-DataStorage.psm1          # JSON-Speicherung und E-Mail-Funktionen
├── Config/
│   └── Config-Cert-Surveillance.json # Erweiterte Konfiguration
└── LOG/
    ├── CertificateData_YYYY-MM-DD.json # Tägliche JSON-Datendateien
    └── DailyEmailScheduler_YYYY-MM-DD.log # Scheduler-Logs
```

## 🔍 Troubleshooting

### Häufige Probleme

1. **Task wird nicht ausgeführt:**
   ```powershell
   # Prüfe Task-Status
   Get-ScheduledTask -TaskName "Certificate-Surveillance-DailyEmail" | Get-ScheduledTaskInfo
   
   # Prüfe Event Log
   Get-WinEvent -LogName "Microsoft-Windows-TaskScheduler/Operational" | 
       Where-Object {$_.Message -like "*Certificate-Surveillance-DailyEmail*"} | 
       Select-Object -First 5
   ```

2. **E-Mail wird nicht gesendet:**
   ```powershell
   # Prüfe SMTP-Konfiguration
   Test-NetConnection -ComputerName "smtpi.meduniwien.ac.at" -Port 25
   
   # Prüfe Credentials (falls SSL verwendet)
   Test-Path "C:\Script\Zertifikate\Config\secure.smtp.cred.xml"
   ```

3. **JSON-Datei nicht gefunden:**
   ```powershell
   # Liste verfügbare JSON-Dateien
   Get-ChildItem -Path "LOG" -Name "CertificateData_*.json" | Sort-Object -Descending
   ```

### Log-Dateien

- **Scheduler-Logs:** `LOG/DailyEmailScheduler_YYYY-MM-DD.log`
- **Haupt-Logs:** `LOG/DEV_Cert-Surveillance_YYYY-MM-DD.log`
- **Task Scheduler Events:** Windows Event Viewer → Applications and Services Logs → Microsoft → Windows → TaskScheduler → Operational

## 🔄 Wartung

### Automatische Bereinigung

- **JSON-Dateien:** Automatisch nach 90 Tagen gelöscht (konfigurierbar)
- **Log-Dateien:** Automatisch nach 30 Tagen gelöscht
- **Task-History:** Windows behält standardmäßig 30 Tage

### Manuelle Bereinigung

```powershell
# Alte JSON-Dateien löschen (älter als 90 Tage)
$cutoffDate = (Get-Date).AddDays(-90)
Get-ChildItem -Path "LOG" -Name "CertificateData_*.json" | ForEach-Object {
    $file = Join-Path "LOG" $_
    if ((Get-Item $file).CreationTime -lt $cutoffDate) {
        Remove-Item $file -Force
        Write-Host "Deleted: $_"
    }
}
```

---

## 📞 Support

Bei Problemen:
1. Prüfen Sie die Log-Dateien
2. Verifizieren Sie die Task Scheduler Konfiguration
3. Testen Sie SMTP-Verbindung
4. Kontaktieren Sie thomas.garnreiter@meduniwien.ac.at

---

**Version:** v1.1.0  
**Regelwerk:** v9.3.1  
**Autor:** Flecki (Tom) Garnreiter