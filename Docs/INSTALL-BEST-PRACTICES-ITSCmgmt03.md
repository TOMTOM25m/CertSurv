# Certificate Surveillance System - ITSCmgmt03 Installation Best Practices

## Server Information

- **Zielserver:** ITSCmgmt03.srv.meduniwien.ac.at
- **CertSurv Version:** v1.3.1
- **Regelwerk:** v9.5.0
- **Installation Date:** 2025-09-24

---

## PHASE 1: PRE-INSTALLATION CHECKLIST

### 1.1 Server-Zugriff vorbereiten

```powershell
# RDP-Verbindung testen
Test-NetConnection -ComputerName "ITSCmgmt03.srv.meduniwien.ac.at" -Port 3389

# WinRM testen (falls Remote-Management gewuenscht)
Test-WSMan -ComputerName "ITSCmgmt03.srv.meduniwien.ac.at"
```

### 1.2 Berechtigungen validieren

**Erforderliche Berechtigungen auf ITSCmgmt03:**

- [ ] Lokale Administrator-Rechte
- [ ] Service-Installation-Berechtigung  
- [ ] Scheduled Task-Erstellung
- [ ] Registry-Schreibzugriff
- [ ] Netzwerkfreigabe-Zugriff auf ISO-Pfad

### 1.3 System-Requirements checken

```powershell
# PowerShell Version (min. 5.1)
$PSVersionTable.PSVersion

# .NET Framework Version (min. 4.7.2)
Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release

# Freier Speicherplatz (min. 500 MB)
Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"} | Select-Object @{Name="FreeGB";Expression={[math]::Round($_.FreeSpace/1GB,2)}}

# Netzwerkverbindung zur Domain
Test-ComputerSecureChannel
```

---

## PHASE 2: NETWORK PATH DEPLOYMENT

### 2.1 Netzwerkpfad auf ITSCmgmt03 erstellen

```powershell
# Als Administrator auf ITSCmgmt03 ausfuehren
$NetworkSharePath = "C:\ISO\CertSurv"
$ShareName = "CertSurv"

# Lokales Verzeichnis erstellen
New-Item -Path $NetworkSharePath -ItemType Directory -Force

# SMB-Share erstellen (falls gewuenscht)
New-SmbShare -Name $ShareName -Path $NetworkSharePath -FullAccess "Domain Admins" -ReadAccess "Domain Users"

# Firewall-Regel fuer SMB
New-NetFirewallRule -DisplayName "SMB-In" -Direction Inbound -Protocol TCP -LocalPort 445 -Action Allow
```

### 2.2 Von Entwicklungsrechner veroeffentlichen

```powershell
# Auf Entwicklungsrechner (f:\DEV\repositories\CertSurv)
cd "f:\DEV\repositories\CertSurv"

# Deployment auf ITSCmgmt03 (UNC-Pfad anpassen!)
.\Deploy-Network.ps1 -Action Publish -NetworkPath "\\ITSCmgmt03.srv.meduniwien.ac.at\C$\ISO\CertSurv"

# Alternative: Lokaler Admin-Share
.\Deploy-Network.ps1 -Action Publish -NetworkPath "\\ITSCmgmt03\CertSurv"
```

---

## PHASE 3: SERVER INSTALLATION (ITSCmgmt03)

### 3.1 Anmeldung und Vorbereitung

```cmd
REM RDP-Verbindung zu ITSCmgmt03
mstsc /v:ITSCmgmt03.srv.meduniwien.ac.at /admin

REM Oder PowerShell Remote Session
Enter-PSSession -ComputerName "ITSCmgmt03.srv.meduniwien.ac.at" -Credential (Get-Credential)
```

### 3.2 PowerShell Administrator-Session

```powershell
# PowerShell als Administrator starten
Start-Process PowerShell -Verb RunAs

# Execution Policy temporaer setzen
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Arbeitsverzeichnis setzen
Set-Location "C:\"
```

### 3.3 Installation ausfuehren

```powershell
# Methode 1: Automatische Installation mit Batch-Script
cd "C:\ISO\CertSurv"
.\Install-on-itscmgmt03.bat

# Methode 2: PowerShell Deployment-Script
.\Deploy-Network.ps1 -Action Install -NetworkPath "C:\ISO\CertSurv"

# Methode 3: Manuelle robocopy Installation
$SourcePath = "C:\ISO\CertSurv"
$TargetPath = "C:\Tools\CertSurv"
robocopy $SourcePath $TargetPath /E /R:3 /W:10 /NP /LOG:"C:\Temp\CertSurv-Install.log"
```

---

## PHASE 4: POST-INSTALLATION CONFIGURATION

### 4.1 Konfiguration anpassen

```powershell
cd "C:\Tools\CertSurv"

# Haupt-Konfigurationsdatei editieren
notepad ".\Config\Config-Cert-Surveillance.json"
```

**Kritische Konfigurationsparameter fuer MedUniWien:**

```json
{
  "Environment": "Production",
  "Domain": "srv.meduniwien.ac.at",
  "ServerList": [
    "ITSCmgmt01.srv.meduniwien.ac.at",
    "ITSCmgmt02.srv.meduniwien.ac.at", 
    "ITSCmgmt03.srv.meduniwien.ac.at"
  ],
  "CertificateThreshold": 30,
  "LogLevel": "INFO",
  "ReportPath": "C:\\Reports\\CertSurv",
  "EmailSettings": {
    "SMTPServer": "mail.meduniwien.ac.at",
    "FromAddress": "certsurv@meduniwien.ac.at",
    "ToAddress": "it-admin@meduniwien.ac.at"
  },
  "ScheduleInterval": "Daily",
  "ScheduleTime": "02:00"
}
```

### 4.2 Service-Account konfigurieren

```powershell
# Service-Account erstellen (falls noch nicht vorhanden)
$ServiceAccount = "srv.meduniwien.ac.at\svc-certsurv"
$SecurePassword = ConvertTo-SecureString "PASSWORD" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($ServiceAccount, $SecurePassword)

# Service-Account Berechtigungen setzen
# - Log on as a service
# - Access this computer from the network
# - Certificate Store Read-Access
```

### 4.3 Erstkonfiguration ausfuehren

```powershell
# System-Setup starten
.\Setup.ps1 -Environment Production -Domain "srv.meduniwien.ac.at"

# Initiale Konfiguration validieren
.\Check.ps1 -ConfigOnly

# Test-Run im sicheren Modus
.\Main.ps1 -TestMode -Verbose
```

---

## PHASE 5: SCHEDULED TASK SETUP

### 5.1 Scheduled Task erstellen

```powershell
# Automatische Task-Erstellung
.\Setup.ps1 -CreateScheduledTask

# Oder manuell:
$TaskName = "CertSurv-DailyCheck"
$TaskPath = "C:\Tools\CertSurv\Main.ps1"
$TaskUser = "srv.meduniwien.ac.at\svc-certsurv"

$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$TaskPath`""
$Trigger = New-ScheduledTaskTrigger -Daily -At "02:00"
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -User $TaskUser -Password "PASSWORD"
```

### 5.2 Task-Validierung

```powershell
# Scheduled Task testen
Start-ScheduledTask -TaskName "CertSurv-DailyCheck"

# Task-Historie pruefen
Get-ScheduledTaskInfo -TaskName "CertSurv-DailyCheck"

# Logs ueberpruefen
Get-Content "C:\Tools\CertSurv\LOG\PROD_Main_$(Get-Date -Format 'yyyy-MM-dd').log" -Tail 20
```

---

## PHASE 6: SECURITY HARDENING

### 6.1 Dateisystem-Berechtigungen

```powershell
# CertSurv-Verzeichnis absichern
$Path = "C:\Tools\CertSurv"
$Acl = Get-Acl $Path

# Nur Administratoren und Service-Account Vollzugriff
$AccessRule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$AccessRule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("svc-certsurv", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")

$Acl.SetAccessRule($AccessRule1)
$Acl.SetAccessRule($AccessRule2)
Set-Acl -Path $Path -AclObject $Acl
```

### 6.2 Firewall-Konfiguration

```powershell
# Ausgehende HTTPS-Verbindungen erlauben (fuer Certificate-Checks)
New-NetFirewallRule -DisplayName "CertSurv-HTTPS-Out" -Direction Outbound -Protocol TCP -RemotePort 443 -Action Allow

# Eingehende Verbindungen blockieren (falls nicht benoetigt)
New-NetFirewallRule -DisplayName "CertSurv-Block-In" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Block
```

### 6.3 Audit-Logging aktivieren

```powershell
# File Access Auditing
auditpol /set /subcategory:"File System" /success:enable /failure:enable

# Process Tracking
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable
```

---

## PHASE 7: MONITORING & MAINTENANCE

### 7.1 System-Monitoring einrichten

```powershell
# Performance Counter fuer CertSurv
$CounterPath = "\Process(powershell)\% Processor Time"
Get-Counter -Counter $CounterPath -SampleInterval 5 -MaxSamples 10

# Event Log Monitoring
Get-WinEvent -LogName Application -FilterHashtable @{ProviderName="CertSurv"} -MaxEvents 10
```

### 7.2 Health-Check-Script erstellen

```powershell
# Automatischer Health-Check
$HealthCheckScript = @"
# CertSurv Health Check
`$ErrorActionPreference = 'Stop'
try {
    # Service Running?
    Get-ScheduledTask -TaskName 'CertSurv-DailyCheck' | Where-Object {`$_.State -eq 'Running'}
    
    # Log File aktuell?
    `$LogFile = Get-ChildItem 'C:\Tools\CertSurv\LOG\PROD_*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ((Get-Date) - `$LogFile.LastWriteTime -gt [TimeSpan]::FromHours(25)) {
        throw 'Log file is too old'
    }
    
    # Certificate Store accessible?
    Get-ChildItem Cert:\LocalMachine\My | Select-Object -First 1
    
    Write-Host '[OK] CertSurv Health Check passed' -ForegroundColor Green
} catch {
    Write-Host '[FAIL] CertSurv Health Check failed: `$_' -ForegroundColor Red
    exit 1
}
"@

$HealthCheckScript | Out-File "C:\Tools\CertSurv\HealthCheck.ps1" -Encoding ASCII
```

### 7.3 Backup-Strategie

```powershell
# Konfiguration-Backup
$BackupPath = "C:\Backup\CertSurv\$(Get-Date -Format 'yyyy-MM-dd')"
robocopy "C:\Tools\CertSurv\Config" "$BackupPath\Config" /E /R:3 /W:5

# Log-Archivierung (monatlich)
$LogArchivePath = "C:\Archive\CertSurv-Logs\$(Get-Date -Format 'yyyy-MM')"
robocopy "C:\Tools\CertSurv\LOG" $LogArchivePath *.log /MOV /R:3 /W:5
```

---

## PHASE 8: PRODUCTION DEPLOYMENT STEPS

### 8.1 Schritt-fuer-Schritt Installation

#### Schritt 1: RDP-Verbindung etablieren

```cmd
mstsc /v:ITSCmgmt03.srv.meduniwien.ac.at /admin
```

#### Schritt 2: Administrator-PowerShell oeffnen

```powershell
# PowerShell ISE als Administrator (empfohlen fuer längere Sessions)
Start-Process PowerShell_ISE -Verb RunAs

# Execution Policy konfigurieren
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
```

#### Schritt 3: Netzwerkzugriff validieren

```powershell
# Test network path (anpassen je nach tatsaechlichem Pfad!)
$ISOPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv"  # PRODUKTIVER PFAD!
# Alternative lokale Pfade:
# $ISOPath = "C:\ISO\CertSurv"  # Falls lokal kopiert
# $ISOPath = "\\ITSCmgmt03\C$\ISO\CertSurv"  # Admin-Share

Test-Path $ISOPath
dir $ISOPath
```

#### Schritt 4: Installation durchfuehren

```powershell
# Wechsel zum ISO-Verzeichnis
cd $ISOPath

# Installation starten (empfohlene Methode)
.\Install-on-itscmgmt03.bat

# Alternative PowerShell-Installation
.\Deploy-Network.ps1 -Action Install -NetworkPath $ISOPath
```

#### Schritt 5: Installation verifizieren

```powershell
# Installation pruefen
cd "C:\Tools\CertSurv"
dir

# System-Check ausfuehren
.\Check.ps1 -Full

# Module-Import testen
Import-Module ".\Modules\FL-Config.psm1" -Force
Import-Module ".\Modules\FL-Certificate.psm1" -Force
```

---

## PHASE 9: INITIAL CONFIGURATION

### 9.1 Umgebungsspezifische Konfiguration

```powershell
cd "C:\Tools\CertSurv"

# Konfigurationsdatei anpassen
$ConfigPath = ".\Config\Config-Cert-Surveillance.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

# MedUniWien-spezifische Anpassungen
$Config.Environment = "Production"
$Config.Domain = "srv.meduniwien.ac.at"
$Config.LogLevel = "INFO"
$Config.ReportPath = "C:\Reports\CertSurv"

# Server-Liste fuer MedUniWien
$Config.ServerList = @(
    "ITSCmgmt01.srv.meduniwien.ac.at",
    "ITSCmgmt02.srv.meduniwien.ac.at", 
    "ITSCmgmt03.srv.meduniwien.ac.at",
    "DC01.srv.meduniwien.ac.at",
    "DC02.srv.meduniwien.ac.at",
    "Exchange01.srv.meduniwien.ac.at",
    "SQL01.srv.meduniwien.ac.at"
)

# E-Mail-Konfiguration
$Config.EmailSettings = @{
    "SMTPServer" = "mail.meduniwien.ac.at"
    "SMTPPort" = 587
    "EnableSSL" = $true
    "FromAddress" = "certsurv@meduniwien.ac.at"
    "ToAddress" = @("it-security@meduniwien.ac.at", "system-admin@meduniwien.ac.at")
    "CCAddress" = @("tom.garnreiter@meduniwien.ac.at")
}

# Certificate-Schwellenwerte
$Config.CertificateThreshold = 30  # 30 Tage vor Ablauf warnen
$Config.CriticalThreshold = 7      # 7 Tage = kritisch

# Konfiguration speichern
$Config | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Encoding ASCII
```

### 9.2 Verzeichnisstruktur erstellen

```powershell
# Reports-Verzeichnis
New-Item -Path "C:\Reports\CertSurv" -ItemType Directory -Force

# Backup-Verzeichnis
New-Item -Path "C:\Backup\CertSurv" -ItemType Directory -Force

# Temp-Verzeichnis für CertSurv
New-Item -Path "C:\Temp\CertSurv" -ItemType Directory -Force
```

---

## PHASE 10: SERVICE ACTIVATION

### 10.1 Scheduled Task Setup (Production-Mode)

```powershell
cd "C:\Tools\CertSurv"

# Service-Account Credentials (SICHER EINGEBEN!)
$ServiceUser = "srv.meduniwien.ac.at\svc-certsurv"
$ServicePassword = Read-Host -AsSecureString -Prompt "Service Account Password"

# Scheduled Task fuer taegliche Ueberpruefung
$TaskName = "CertSurv-Daily-Surveillance"
$ScriptPath = "C:\Tools\CertSurv\Main.ps1"
$LogPath = "C:\Tools\CertSurv\LOG"

$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -Environment Production -LogPath `"$LogPath`""

$Trigger = New-ScheduledTaskTrigger -Daily -At "02:00"

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)

$Principal = New-ScheduledTaskPrincipal -UserId $ServiceUser -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal
```

### 10.2 Windows Service Installation (Optional)

```powershell
# Windows Service Setup
.\Setup.ps1 -InstallService -ServiceAccount $ServiceUser

# Service-Status pruefen
Get-Service -Name "CertSurv" | Select-Object Name, Status, StartType

# Service starten
Start-Service -Name "CertSurv"
```

---

## PHASE 11: INITIAL TESTING & VALIDATION

### 11.1 Funktionstest

```powershell
cd "C:\Tools\CertSurv"

# Test 1: Konfiguration validieren
.\Check.ps1 -ConfigOnly
Write-Host "[TEST 1] Configuration validation completed" -ForegroundColor Green

# Test 2: Netzwerkverbindungen testen
.\Check.ps1 -NetworkOnly  
Write-Host "[TEST 2] Network connectivity test completed" -ForegroundColor Green

# Test 3: Certificate Store Access
.\Check.ps1 -CertificateOnly
Write-Host "[TEST 3] Certificate store access test completed" -ForegroundColor Green

# Test 4: Vollstaendiger Testlauf
.\Main.ps1 -TestMode -Verbose
Write-Host "[TEST 4] Full test run completed" -ForegroundColor Green
```

### 11.2 Log-Validierung

```powershell
# Aktuelle Log-Datei anzeigen
$LatestLog = Get-ChildItem "C:\Tools\CertSurv\LOG\PROD_*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content $LatestLog.FullName -Tail 50

# Log-Level und Fehler pruefen
Select-String -Path $LatestLog.FullName -Pattern "\[ERROR\]|\[FAIL\]|\[CRITICAL\]"
```

---

## PHASE 12: PRODUCTION GO-LIVE

### 12.1 Go-Live Checklist

- [ ] Alle Tests erfolgreich abgeschlossen
- [ ] Konfiguration fuer Produktionsumgebung angepasst
- [ ] Scheduled Task aktiv und getestet
- [ ] Log-Monitoring eingerichtet
- [ ] Backup-Strategie implementiert
- [ ] Incident-Response-Plan dokumentiert
- [ ] Team-Schulung durchgefuehrt

### 12.2 Monitoring Dashboard starten

```powershell
# Management-Interface oeffnen
.\Manage.ps1 -ShowDashboard

# Live-Log-Monitoring
.\Manage.ps1 -TailLogs -Follow

# System-Status-Report
.\Main.ps1 -GenerateReport -SendEmail
```

---

## PHASE 13: TROUBLESHOOTING GUIDE

### 13.1 Haeufige Installationsprobleme

#### Problem: "ExecutionPolicy Restricted"

```powershell
# Loesung:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
# Oder temporaer:
PowerShell.exe -ExecutionPolicy Bypass -File "Setup.ps1"
```

#### Problem: "Module nicht gefunden"

```powershell
# Loesung:
$env:PSModulePath += ";C:\Tools\CertSurv\Modules"
Import-Module "C:\Tools\CertSurv\Modules\FL-Config.psm1" -Force
```

#### Problem: "Netzwerkpfad nicht erreichbar"

```powershell
# Diagnose:
Test-NetConnection -ComputerName "file-server" -Port 445
Get-SmbConnection
net use

# Loesung:
net use Z: \\file-server\ISO /persistent:yes
```

#### Problem: "Certificate Store Access denied"

```powershell
# Diagnose:
Get-Acl "Cert:\LocalMachine\My"
whoami /groups

# Loesung: Service-Account zu lokalen Administratoren hinzufuegen
net localgroup Administrators "srv.meduniwien.ac.at\svc-certsurv" /add
```

### 13.2 Performance-Optimierung

```powershell
# PowerShell-Performance optimieren
$env:PSModuleAnalysisCachePath = "C:\Temp\PSModuleCache"

# Concurrent-Operations limitieren
$MaxConcurrentJobs = [Environment]::ProcessorCount
```

---

## PHASE 14: MAINTENANCE PROCEDURES

### 14.1 Tägliche Wartung

```powershell
# Automatisch via Scheduled Task:
# - Certificate-Check aller Server
# - Log-Rotation
# - Report-Generierung
# - E-Mail-Benachrichtigung bei kritischen Certificates
```

### 14.2 Woechentliche Wartung

```powershell
# Manuell oder via separater Task:
.\Manage.ps1 -WeeklyMaintenance

# Tasks:
# - Vollstaendiger System-Check
# - Configuration-Backup
# - Performance-Report
# - Update-Check
```

### 14.3 Monatliche Wartung

```powershell
# Log-Archivierung
$ArchiveDate = Get-Date -Format "yyyy-MM"
robocopy "C:\Tools\CertSurv\LOG" "C:\Archive\CertSurv\$ArchiveDate" *.log /MOV

# Configuration-Review
.\Manage.ps1 -ReviewConfiguration -GenerateReport

# System-Updates pruefen
.\Manage.ps1 -CheckForUpdates
```

---

## EMERGENCY PROCEDURES

### Notfall-Kontakte

- **Primary Admin:** Flecki (Tom) Garnreiter
- **IT-Security:** <it-security@meduniwien.ac.at>  
- **System-Admin:** <system-admin@meduniwien.ac.at>

### Notfall-Kommandos

```powershell
# Service sofort stoppen
Stop-ScheduledTask -TaskName "CertSurv-Daily-Surveillance"
Stop-Service -Name "CertSurv" -Force

# Notfall-Certificate-Check
.\Main.ps1 -EmergencyMode -CriticalOnly

# System-Recovery
.\Setup.ps1 -RecoveryMode -RestoreFromBackup
```

---

## COMPLIANCE & DOCUMENTATION

### Compliance-Anforderungen MedUniWien

- [ ] DSGVO-Konformitaet gewaehrleistet
- [ ] IT-Security-Guidelines eingehalten
- [ ] Audit-Trail vollstaendig
- [ ] Dokumentation aktuell
- [ ] Change-Management-Prozess befolgt

### Dokumentation-Updates

- Installations-Log in Service-Management-System eintragen
- Konfiguration in Dokumentations-Repository aktualisieren
- Run-Book fuer Operations-Team erstellen
- Monitoring-Alerts in SIEM-System konfigurieren

---

**Installation Guide Version:** v1.0.0  
**CertSurv System Version:** v1.3.0  
**Regelwerk Compliance:** v9.5.0  
**Target Server:** ITSCmgmt03.srv.meduniwien.ac.at  
**Installation Date:** 2025-09-23  
**Administrator:** Flecki (Tom) Garnreiter

---

*Vollstaendig ASCII-kompatibel fuer universelle PowerShell-Unterstuetzung*
*Entspricht MedUniWien IT-Security und Operations Standards*
