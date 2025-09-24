# Certificate Surveillance System

**Version:** v1.3.1  
**Author:** © Flecki Garnreiter  
**Rulebook:** v9.5.0  
**License:** MIT License  
**Build Date:** 2025-09-24

---

## Project Overview / Projektübersicht

**[EN]** The Certificate Surveillance System is a comprehensive PowerShell solution for monitoring SSL/TLS certificates across your server infrastructure. It provides automated certificate discovery, expiration monitoring, reporting, and notification capabilities through a modular architecture.

**[DE]** Das Certificate Surveillance System ist eine umfassende PowerShell-Lösung zur Überwachung von SSL/TLS-Zertifikaten in Ihrer Server-Infrastruktur. Es bietet automatische Zertifikatserkennung, Ablaufüberwachung, Berichterstattung und Benachrichtigungsfunktionen durch eine modulare Architektur.

---

## 2. Core Features / Kernfunktionen

- **[EN]** **Dynamic FQDN Generation:** Automatically constructs server FQDNs from a central Excel file, simplifying server management.
- **[DE]** **Dynamische FQDN-Generierung:** Erstellt automatisch Server-FQDNs aus einer zentralen Excel-Datei, was die Serververwaltung vereinfacht.

- **[EN]** **Comprehensive Certificate Discovery:** Queries the primary SSL certificate on port 443 and remotely queries the server's local certificate store (`Cert:\LocalMachine\My`) to find additional certificates.
- **[DE]** **Umfassende Zertifikatserkennung:** Fragt das primäre SSL-Zertifikat auf Port 443 ab und durchsucht zusätzlich den lokalen Zertifikatsspeicher des Servers (`Cert:\LocalMachine\My`) nach weiteren Zertifikaten.

- **[EN]** **Automated Excel Updates:** Writes the constructed FQDNs and any additional discovered certificate names directly back into the source Excel file.
- **[DE]** **Automatische Excel-Aktualisierung:** Schreibt die erstellten FQDNs und die Namen zusätzlich gefundener Zertifikate direkt in die Excel-Quelldatei zurück.

- **[EN]** **Rich HTML Reporting:** Generates a user-friendly HTML report with color-coded statuses for certificate validity (Urgent, Critical, Warning).
- **[DE]** **Detaillierte HTML-Berichte:** Erstellt einen benutzerfreundlichen HTML-Bericht mit farbcodierten Statusanzeigen für die Gültigkeit von Zertifikaten (Dringend, Kritisch, Warnung).

- **[EN]** **Email Notifications:** Sends the HTML report as an attachment to designated recipients.
- **[DE]** **E-Mail-Benachrichtigungen:** Versendet den HTML-Bericht als Anhang an definierte Empfänger.

- **[EN]** **Modular & Configurable:** All settings, paths, and thresholds are managed via external JSON configuration files.
- **[DE]** **Modular & Konfigurierbar:** Alle Einstellungen, Pfade und Schwellenwerte werden über externe JSON-Konfigurationsdateien verwaltet.

- **[EN]** **Automated Maintenance:** Archives old log files and deletes outdated archives to keep the script directory clean.
- **[DE]** **Automatisierte Wartung:** Archiviert alte Log-Dateien und löscht veraltete Archive, um das Skriptverzeichnis sauber zu halten.

- **[EN]** **WebService Integration:** Central certificate collection via itscmgmt03 WebService API for enhanced performance.
- **[DE]** **WebService-Integration:** Zentrale Zertifikatssammlung über itscmgmt03 WebService API für verbesserte Performance.

- **[EN]** **Setup GUI:** Graphical configuration interface for easy parameter adjustment via Setup-CertSurv.ps1.
- **[DE]** **Setup-GUI:** Grafische Konfigurationsoberfläche für einfache Parameter-Anpassung über Setup-CertSurv.ps1.

- **[EN]** **Network Deployment:** Robocopy-based deployment system compliant with Regelwerk v9.5.0.
- **[DE]** **Netzwerk-Deployment:** Robocopy-basiertes Deployment-System konform mit Regelwerk v9.5.0.

---

## 3. Prerequisites / Voraussetzungen

- **[EN]** **PowerShell Version:** 5.1 or higher.
- **[DE]** **PowerShell-Version:** 5.1 oder höher.

- **[EN]** **Execution Policy:** The script must be allowed to run (e.g., `RemoteSigned`).
- **[DE]** **Ausführungsrichtlinie:** Das Ausführen von Skripten muss erlaubt sein (z. B. `RemoteSigned`).

- **[EN]** **Administrator Privileges:** The script requires administrative rights to run correctly.
- **[DE]** **Administratorrechte:** Das Skript benötigt administrative Rechte für die korrekte Ausführung.

- **[EN]** **PowerShell Module:** The `ImportExcel` module must be installed. You can install it with the following command:
- **[DE]** **PowerShell-Modul:** Das Modul `ImportExcel` muss installiert sein. Sie können es mit folgendem Befehl installieren:

  ```powershell
  Install-Module -Name ImportExcel -Scope CurrentUser
  ```

- **[EN]** **Network Access:** The script needs network access to the target servers on port 443 and for PowerShell Remoting (WinRM).
- **[DE]** **Netzwerkzugriff:** Das Skript benötigt Netzwerkzugriff auf die Zielserver über Port 443 sowie für PowerShell-Remoting (WinRM).

---

## 4. How to Use / Anwendung

### [EN] Standard Execution

To run the script with the default configuration, simply execute it from the project directory:

### [DE] Standardausführung

Um das Skript mit der Standardkonfiguration auszuführen, starten Sie es einfach aus dem Projektverzeichnis:

```powershell
.\Cert-Surveillance.ps1
```

### [EN] Overriding the Excel File Path

You can specify a different Excel file at runtime using the `-ExcelPath` parameter:

### [DE] Überschreiben des Excel-Dateipfads

Sie können zur Laufzeit eine andere Excel-Datei über den `-ExcelPath`-Parameter angeben:

```powershell
.\Cert-Surveillance.ps1 -ExcelPath "C:\temp\MyCustomServerList.xlsx"
```

---

## 5. Automated Execution with Task Scheduler / Automatisierte Ausführung mit der Aufgabenplanung

**[EN]**
To run the script automatically on a schedule, you can create a task in the Windows Task Scheduler.

**[DE]**
Um das Skript automatisch nach einem Zeitplan auszuführen, können Sie eine Aufgabe in der Windows-Aufgabenplanung erstellen.

1. **[EN]** **Open Task Scheduler:** Press `Win + R`, type `taskschd.msc`, and press Enter.
    **[DE]** **Aufgabenplanung öffnen:** Drücken Sie `Win + R`, geben Sie `taskschd.msc` ein und drücken Sie Enter.

2. **[EN]** **Create Task:** In the "Actions" pane, click "Create Task...".
    **[DE]** **Aufgabe erstellen:** Klicken Sie im Bereich "Aktionen" auf "Aufgabe erstellen...".

3. **[EN]** **General Tab:**
    **[DE]** **Reiter "Allgemein":**
    - **Name:** Give the task a descriptive name (e.g., "Certificate Surveillance"). / Geben Sie der Aufgabe einen aussagekräftigen Namen (z. B. "Zertifikatsüberwachung").
    - Select **"Run whether user is logged on or not"**. / Wählen Sie **"Unabhängig von der Benutzeranmeldung ausführen"**.
    - Check the box for **"Run with highest privileges"**. / Aktivieren Sie die Option **"Mit höchsten Berechtigungen ausführen"**.

4. **[EN]** **Triggers Tab:**
    **[DE]** **Reiter "Trigger":**
    - Click "New...". / Klicken Sie auf "Neu...".
    - Configure the schedule as needed (e.g., "Daily" at a specific time). / Konfigurieren Sie den Zeitplan nach Bedarf (z. B. "Täglich" zu einer bestimmten Uhrzeit).
    - Click "OK". / Klicken Sie auf "OK".

5. **[EN]** **Actions Tab:**
    **[DE]** **Reiter "Aktionen":**
    - Click "New...". / Klicken Sie auf "Neu...".
    - **Action:** Select "Start a program". / **Aktion:** Wählen Sie "Programm starten".
    - **Program/script:** Enter `powershell.exe`. / **Programm/Skript:** Geben Sie `powershell.exe` ein.
    - **Add arguments (optional):** / **Argumente hinzufügen (optional):**

        ```powershell
        -NoProfile -ExecutionPolicy Bypass -File "F:\DEV\repositories\CertSurv\Cert-Surveillance.ps1"
        ```

        _*[EN]* Make sure to replace the path with the actual location of your `Cert-Surveillance.ps1` file. / _[DE]_ Stellen Sie sicher, dass Sie den Pfad durch den tatsächlichen Speicherort Ihrer `Cert-Surveillance.ps1`-Datei ersetzen._
    - Click "OK". / Klicken Sie auf "OK".

6. **[EN]** **Conditions and Settings Tabs:** Review the default settings. For most cases, they are sufficient.
    **[DE]** **Reiter "Bedingungen" und "Einstellungen":** Überprüfen Sie die Standardeinstellungen. In den meisten Fällen sind diese ausreichend.

7. **[EN]** **Save the Task:** Click "OK" to save the task. You may be prompted to enter your user password.
    **[DE]** **Aufgabe speichern:** Klicken Sie auf "OK", um die Aufgabe zu speichern. Möglicherweise werden Sie zur Eingabe Ihres Benutzerpassworts aufgefordert.

---

## 5.1. Setup GUI / Setup-Benutzeroberfläche

**[EN]** For easier configuration, you can use the graphical setup interface:
**[DE]** Für eine einfachere Konfiguration können Sie die grafische Setup-Oberfläche verwenden:

```powershell
.\Setup-CertSurv.ps1
```

**[EN]** The Setup GUI allows you to:
**[DE]** Die Setup-GUI ermöglicht Ihnen:

- **[EN]** Edit all parameters in Config-Cert-Surveillance.json
- **[DE]** Alle Parameter in Config-Cert-Surveillance.json zu bearbeiten
- **[EN]** Deploy updated configuration to network share
- **[DE]** Aktualisierte Konfiguration auf Netzlaufwerk zu deployen
- **[EN]** Visual validation of configuration changes
- **[DE]** Visuelle Validierung von Konfigurationsänderungen

---

## 6. Configuration / Konfiguration

**[EN]** The script's behavior is controlled by `Config\Config-Cert-Surveillance.json`.
**[DE]** Das Verhalten des Skripts wird durch die Datei `Config\Config-Cert-Surveillance.json` gesteuert.

### [EN] Key Configuration Sections

### [DE] Wichtige Konfigurationsbereiche

- **`MainDomain`**: [EN] The primary domain suffix (e.g., "meduniwien.ac.at") used to construct FQDNs. / [DE] Das primäre Domain-Suffix (z. B. "meduniwien.ac.at"), das zur Erstellung von FQDNs verwendet wird.
- **`Paths`**: [EN] Defines all necessary paths for logs, reports, and external tools like 7-Zip. / [DE] Definiert alle notwendigen Pfade für Protokolle, Berichte und externe Werkzeuge wie 7-Zip.
- **`Excel`**:
  - `ExcelPath`: [EN] Path to the master server list. / [DE] Pfad zur Master-Serverliste.
  - `SheetName`: [EN] The name of the worksheet to read. / [DE] Der Name des zu lesenden Arbeitsblatts.
  - `ServerNameColumnName`: [EN] The name of the column containing server short names and `(Domain)` identifiers. / [DE] Der Name der Spalte, die Server-Kurznamen und `(Domain)`-Bezeichner enthält.
  - `FqdnColumnName`: [EN] The name of the column where the script will write the discovered FQDNs. / [DE] Der Name der Spalte, in die das Skript die gefundenen FQDNs schreibt.
- **`Intervals`**:
  - `DaysUntilUrgent`, `DaysUntilCritical`, `DaysUntilWarning`: [EN] Thresholds for the report's color-coding. / [DE] Schwellenwerte für die Farbcodierung des Berichts.
  - `ArchiveLogsOlderThanDays`, `DeleteZipArchivesOlderThanDays`: [EN] Settings for automated log maintenance. / [DE] Einstellungen für die automatische Protokollwartung.
- **`Mail`**:
  - `Enabled`: [EN] Set to `true` or `false` to enable/disable email notifications. / [DE] Auf `true` oder `false` setzen, um E-Mail-Benachrichtigungen zu aktivieren/deaktivieren.
  - `SmtpServer`, `SmtpPort`, `SenderAddress`: [EN] Standard SMTP settings. / [DE] Standard-SMTP-Einstellungen.
  - `DevTo`, `ProdTo`: [EN] Recipient addresses, chosen based on the `RunMode` setting. / [DE] Empfängeradressen, die basierend auf der `RunMode`-Einstellung ausgewählt werden.
- **`CorporateDesign`**: [EN] Colors used for styling the HTML report. / [DE] Farben für das Design des HTML-Berichts.
- **`Certificate.WebService`**:
  - `Enabled`: [EN] Enable/disable WebService integration / [DE] WebService-Integration aktivieren/deaktivieren
  - `PrimaryServer`: [EN] WebService server FQDN (e.g., "itscmgmt03.srv.meduniwien.ac.at") / [DE] WebService-Server FQDN
  - `HttpPort`: [EN] WebService HTTP port (default: 9080) / [DE] WebService HTTP-Port
  - `FallbackToLocal`: [EN] Fallback to local SSL query if WebService fails / [DE] Fallback auf lokale SSL-Abfrage bei WebService-Ausfall

---

## 6.1. Network Deployment / Netzwerk-Deployment

**[EN]** For enterprise deployment, refer to the comprehensive deployment guide:
**[DE]** Für Enterprise-Deployment siehe das umfassende Deployment-Handbuch:

```powershell
# Deploy to network share
.\Deploy.ps1 -Action Publish -NetworkPath "\\itscmgmt03\iso\CertSurv"

# Install from network share
.\Deploy.ps1 -Action Install -NetworkPath "\\itscmgmt03\iso\CertSurv"
```

**[EN]** See `NETWORK-DEPLOYMENT-GUIDE.md` for detailed instructions.
**[DE]** Siehe `NETWORK-DEPLOYMENT-GUIDE.md` für detaillierte Anweisungen.

---

## 7. Project Structure / Projektstruktur

``` File Strukture
CertSurv/
│
├── Cert-Surveillance.ps1       # [EN] Main executable script / [DE] Hauptausführungsskript
├── Setup.ps1                   # [EN] Installation and configuration script / [DE] Installations- und Konfigurationsskript
├── Setup-CertSurv.ps1          # [EN] GUI for config editing / [DE] GUI für Config-Bearbeitung
├── Check.ps1                   # [EN] System compliance check / [DE] System-Compliance-Prüfung
├── Deploy.ps1                  # [EN] Deployment operations / [DE] Deployment-Operationen
├── Manage.ps1                  # [EN] Management functions / [DE] Management-Funktionen
├── README.md                   # [EN] This file / [DE] Diese Datei
├── CHANGELOG.md                # [EN] Version history / [DE] Versionshistorie
├── NETWORK-DEPLOYMENT-GUIDE.md # [EN] Deployment guide / [DE] Deployment-Handbuch
├── FIRSTME.md                  # [EN] Original idea and requirements / [DE] Ursprungsidee und Anforderungen
│
├── Config/
│   ├── Config-Cert-Surveillance.json # [EN] Main configuration / [DE] Hauptkonfiguration
│   ├── de-DE.json                # [EN] German localization / [DE] Deutsche Lokalisierung
│   └── en-US.json                # [EN] English localization / [DE] Englische Lokalisierung
│
├── Modules/                    # [EN] FL-* PowerShell modules / [DE] FL-* PowerShell-Module
│   ├── FL-Config.psm1            # [EN] Configuration management / [DE] Konfigurationsverwaltung
│   ├── FL-Logging.psm1           # [EN] Logging functions / [DE] Logging-Funktionen
│   ├── FL-CoreLogic.psm1         # [EN] Main workflow logic / [DE] Haupt-Workflow-Logik
│   ├── FL-DataProcessing.psm1    # [EN] Excel/CSV processing / [DE] Excel/CSV-Verarbeitung
│   ├── FL-NetworkOperations.psm1 # [EN] Network connectivity / [DE] Netzwerk-Konnektivität
│   ├── FL-Reporting.psm1         # [EN] HTML/JSON reports / [DE] HTML/JSON-Berichte
│   ├── FL-ActiveDirectory.psm1   # [EN] AD integration / [DE] AD-Integration
│   ├── FL-Security.psm1          # [EN] SSL/TLS validation / [DE] SSL/TLS-Validierung
│   ├── FL-Maintenance.psm1       # [EN] System maintenance / [DE] System-Wartung
│   ├── FL-Utils.psm1             # [EN] Utility functions / [DE] Hilfsfunktionen
│   ├── FL-Compatibility.psm1     # [EN] PowerShell compatibility / [DE] PowerShell-Kompatibilität
│   └── FL-CertificateAPI.psm1    # [EN] WebService API integration / [DE] WebService-API-Integration
│
├── LOG/                        # [EN] Log files (created on first run) / [DE] Log-Dateien (beim ersten Start erstellt)
│
├── Reports/                    # [EN] HTML reports (created on first run) / [DE] HTML-Berichte (beim ersten Start erstellt)
│
└── old/
    └── seekCertReNewDay.ps1      # [EN] Original script for reference / [DE] Ursprungsskript als Referenz
```
