# Copilot Instructions for CertSurv

## Projektüberblick

Das CertSurv-System ist eine modulare PowerShell-Lösung zur Überwachung von SSL/TLS-Zertifikaten in Server-Infrastrukturen. Die Hauptfunktionen umfassen automatische Zertifikatserkennung, Ablaufüberwachung, Excel-Integration, HTML-Berichte und E-Mail-Benachrichtigungen.

## Architektur & Komponenten

- **Hauptskript:** `Cert-Surveillance.ps1` steuert den gesamten Workflow.
- **Module:** Im Verzeichnis `Modules/` sind alle Kernfunktionen ausgelagert (z.B. Logging, Konfiguration, Wartung, Zertifikatslogik).
- **Konfiguration:** Einstellungen werden ausschließlich über JSON-Dateien in `Config/` verwaltet. Änderungen an Schwellenwerten, Pfaden, Mailadressen etc. erfolgen dort.
- **Datenflüsse:**
  - Servernamen werden aus einer Excel-Datei gelesen und zu FQDNs generiert.
  - Zertifikate werden remote abgefragt (Port 443 & Cert:\LocalMachine\My).
  - Ergebnisse werden in die Excel-Datei zurückgeschrieben und als HTML-Bericht ausgegeben.
  - Berichte werden per E-Mail versendet (SMTP-Konfiguration in JSON).
  - Logfiles und Reports werden automatisch archiviert und bereinigt.

## Entwickler-Workflows

- **Ausführung:**
  - Standard: `powershell .\Cert-Surveillance.ps1`
  - Mit individuellem Excel-Pfad: `powershell .\Cert-Surveillance.ps1 -ExcelPath <Pfad>`
- **Automatisierung:**
  - Windows Task Scheduler wird empfohlen (siehe README für Details zu Trigger, Aktionen und Argumenten).
- **Modulstruktur:**
  - Neue Funktionen sollten als eigene Module in `Modules/` angelegt werden.
  - Logging und Fehlerbehandlung erfolgen über die bestehenden Module (`FL-Logging.psm1`, `FL-Maintenance.psm1`).
- **Tests:**
  - Testskripte liegen in `old/Tests/` und können direkt mit PowerShell ausgeführt werden.

## Projektkonventionen

- **Konfiguration:** Keine Hardcodierung von Pfaden, Schwellenwerten oder Mailadressen im Code – alles über JSON.
- **Lokalisierung:** Sprachdateien in `Config/de-DE.json` und `Config/en-US.json`.
- **Berichte:** HTML-Reports werden in `reports/` abgelegt, Logs in `LOG/`.
- **Archivierung:** Alte Logs/Reports werden automatisch nach den in der Konfiguration definierten Intervallen archiviert/gelöscht.

## Integration & Abhängigkeiten

- **ImportExcel-Modul:** Muss installiert sein (`Install-Module -Name ImportExcel -Scope CurrentUser`).
- **SMTP:** Für E-Mail-Versand ist ein konfigurierter SMTP-Server erforderlich.
- **PowerShell Remoting:** Netzwerkzugriff auf Zielserver (Port 443, WinRM) notwendig.

## Wichtige Dateien & Beispiele

- `Config/Config-Cert-Surveillance.json`: zentrale Konfiguration
- `Modules/FL-Config.psm1`: Konfigurationslogik
- `Modules/FL-Logging.psm1`: Logging
- `Modules/FL-Maintenance.psm1`: Log-Archivierung
- `Modules/FL-Utils.psm1`: Hilfsfunktionen (Mail, Zertifikatsprüfung)
- `reports/`: HTML-Berichte
- `LOG/`: Logdateien

## Beispiel für einen typischen Ablauf

1. Excel-Datei mit Servernamen bereitstellen
2. Konfiguration in JSON anpassen
3. Skript ausführen (`Cert-Surveillance.ps1`)
4. Ergebnis: HTML-Bericht, Logdateien, ggf. E-Mail-Benachrichtigung

---

**Feedback:** Bitte prüfen, ob spezielle Workflows, Custom-Module oder Integrationspunkte fehlen. Unklare oder unvollständige Abschnitte können gezielt ergänzt werden.
