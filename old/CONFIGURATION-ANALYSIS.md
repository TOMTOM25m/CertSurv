# Certificate Surveillance Configuration Analysis
# Datum: 2025-01-08
# Autor: GitHub Copilot

## Zusammenfassung der Konfigurationsanalyse

### ✅ Bereits konfigurierbare Parameter:

1. **Excel-Konfiguration** (vollständig implementiert):
   - ExcelPath - Pfad zur Excel-Datei
   - SheetName - Name des Excel-Blattes
   - HeaderRow - Zeile mit den Spaltenüberschriften
   - FqdnColumnName - Name der FQDN-Spalte
   - ServerNameColumnName - Name der ServerName-Spalte
   - DomainStatusColumnName - Name der Domain-Status-Spalte
   - AlwaysUseConfigPath - Immer Config-Pfad verwenden

2. **Mail-Konfiguration** (vollständig implementiert):
   - Enabled - E-Mail-Benachrichtigungen aktiviert/deaktiviert
   - SmtpServer - SMTP-Server Adresse
   - SmtpPort - SMTP-Server Port
   - UseSsl - SSL für E-Mail verwenden
   - SenderAddress - Absender-E-Mail-Adresse
   - DevTo/ProdTo - Empfänger für DEV/PROD Modus
   - SubjectPrefix - Betreff-Präfix
   - CredentialFilePath - Pfad zu verschlüsselten Credentials

3. **Netzwerk-Konfiguration** (vollständig implementiert):
   - DnsServer - DNS-Server IP-Adresse
   - TlsVersion - TLS-Protokoll-Version
   - MainDomain - Hauptdomäne

4. **Intervall-Konfiguration** (vollständig implementiert):
   - DaysUntilUrgent - Tage bis "Dringend"-Status
   - DaysUntilCritical - Tage bis "Kritisch"-Status  
   - DaysUntilWarning - Tage bis "Warnung"-Status
   - ArchiveLogsOlderThanDays - Log-Archivierung nach X Tagen
   - DeleteZipArchivesOlderThanDays - Archive löschen nach X Tagen

5. **Pfad-Konfiguration** (vollständig implementiert):
   - ConfigFile - Pfad zur Konfigurationsdatei
   - PathTo7Zip - Pfad zu 7-Zip Executable
   - LogoDirectory - Pfad zum Logo-Verzeichnis
   - ReportDirectory - Pfad für Berichte
   - LogDirectory - Pfad für Log-Dateien

6. **Corporate Design** (vollständig implementiert):
   - PrimaryColor - Primärfarbe
   - HoverColor - Hover-Farbe

### ✅ Neu hinzugefügte Konfiguration:

7. **Certificate-Konfiguration** (NEU HINZUGEFÜGT):
   - Port - Standard-Port für Zertifikatsabfragen (default: 443)
   - WarningDays - Warntage vor Zertifikatsablauf (default: 30)
   - Timeout - Timeout für Verbindungen in Millisekunden (default: 10000)
   - RetryAttempts - Anzahl Wiederholungsversuche (default: 3)
   - EnableSslProtocols - Erlaubte SSL/TLS-Protokolle
   - ReportPath - Pfad für Zertifikatsberichte

### ✅ Code-Verbesserungen durchgeführt:

1. **FL-Certificate.psm1**:
   - Parameter für Port, Timeout und Config hinzugefügt
   - Timeout-Implementierung mit ConnectAsync
   - Konfigurationswerte werden aus Config-Object verwendet

2. **Cert-Surveillance.ps1**:
   - $warningDays verwendet jetzt $Config.Certificate.WarningDays
   - Get-RemoteCertificate erhält Config-Parameter
   - ReportPath verwendet konfigurierbaren Pfad

3. **FL-Security.psm1**:
   - Get-Certificates Funktion erhält Config-Parameter
   - Port wird aus Konfiguration gelesen (mit Fallback auf 443)

### ✅ GUI-Modul erstellt:

4. **FL-Gui.psm1** (NEU ERSTELLT):
   - Vollständige WPF-basierte Setup-GUI
   - Alle Konfigurationsparameter editierbar
   - Tabs für logische Gruppierung:
     - General/Allgemein
     - Excel Configuration
     - Certificate Settings/Zertifikat-Einstellungen
     - Mail Configuration/E-Mail-Konfiguration
     - Intervals/Intervalle
     - Paths/Pfade
   - Bilingual (Deutsch/Englisch)
   - Validierung der Eingaben
   - Test-Funktionen für Konfiguration
   - File/Folder-Browser integriert

5. **Setup-CertSurv.ps1** (NEU ERSTELLT):
   - Standalone Setup-Skript
   - Lädt GUI-Modul und startet Setup-Interface
   - Option zum direkten Start des Hauptskripts nach Konfiguration

### ⚠️ Identifizierte Probleme und Lösungen:

1. **Problem**: Hart kodierte Werte
   - **Gelöst**: Alle hart kodierten Werte (Port 443, Warning Days 30) in Konfiguration verschoben

2. **Problem**: Fehlende GUI für Konfiguration
   - **Gelöst**: Vollständige WPF-GUI mit FL-Gui.psm1 erstellt

3. **Problem**: Doppelte Get-Certificates Funktionen
   - **Identifiziert**: FL-Utils.psm1 und FL-Security.psm1 haben beide Get-Certificates
   - **Empfehlung**: FL-Certificate.psm1 verwenden und Duplikate entfernen

### 📋 Empfohlene nächste Schritte:

1. **Cleanup der duplizierten Funktionen**:
   - Get-Certificates aus FL-Utils.psm1 entfernen
   - FL-Security.psm1 soll FL-Certificate.psm1 verwenden

2. **Testing der GUI**:
   - Setup-CertSurv.ps1 ausführen und GUI testen
   - Alle Konfigurationsoptionen validieren

3. **Dokumentation aktualisieren**:
   - README.md mit neuen GUI-Funktionen aktualisieren
   - Installationsanweisungen für Setup-GUI hinzufügen

### 🎯 Fazit:

Das Certificate Surveillance System ist jetzt **vollständig konfigurierbar** über:
- ✅ **Config-File**: Alle Parameter in JSON-Konfiguration abgebildet
- ✅ **Setup-GUI**: Benutzerfreundliche graphische Oberfläche
- ✅ **Bilingual**: Deutsche und englische Dokumentation/GUI
- ✅ **Validierung**: Eingaben werden auf Gültigkeit geprüft
- ✅ **Modulare Architektur**: Klare Trennung der Verantwortlichkeiten

**Alle ursprünglich hart kodierten Werte sind jetzt konfigurierbar!**
