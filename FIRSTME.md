# Project Brief: Cert-Surveillance.ps1

## 1. Project Goal

The primary objective is to create a new PowerShell script, `Cert-Surveillance.ps1`, for monitoring certificate expiration. This script will replace and enhance the functionality of the existing `seekCertReNewDay.ps1` script.

## 2. Guiding Principles

- **Standardization:** The script must strictly adhere to the development standards outlined in `Regelwerk9.0.9.md`. This includes project structure, logging, configuration, and modularization.
- **Foundation:** The existing, functional script `seekCertReNewDay.ps1` should be used as a template for the basic certificate checking logic.
- **New Core Logic:** The main enhancement is a new method for dynamically constructing server FQDNs from a specific Excel file.

## 3. Core Task: FQDN Generation from Excel

The script needs to read an Excel file and build the Fully Qualified Domain Names (FQDNs) for servers before checking their certificates.

### Input Data Source

- **File Path:** `\\itscmgmt03.srv.meduniwien.ac.at\iso\WIndowsServerListe\Serverliste2025FQDN.xlsx`
- **Relevant Columns:**
  - `Server Name`: Contains the server's short name (e.g., `UVWDC001`) or a domain identifier (e.g., `(Domain)UVW`).
  - `OS_Name`
  - `FQDN`

### Logic for FQDN Construction

The FQDN for each server will be constructed from three parts:

1. **Part 1: Server Name (`$ServerName`)**
   - This is the server's individual name, like `UVWDC001`.

2. **Part 2: Sub-Domain (`$DomainName`)**
   - This is derived from special rows in the `Server Name` column.
   - Find a cell containing a value like `(Domain)UVW`.
   - Extract the sub-domain part by removing the `(Domain)` prefix.
   - Example: `(Domain)UVW` -> `UVW`.

3. **Part 3: Main Domain (`$MainDomain`)**
   - This value is static and will be retrieved from the script's JSON configuration file.
   - Example: `meduniwien.ac.at`.

### Example of FQDN Assembly

Given the following variables:

- `$ServerName = "UVWDC001"`
- `$DomainName = "UVW"`
- `$MainDomain = "meduniwien.ac.at"`

The final FQDN is assembled as follows:

```powershell
$FQDN = "$($ServerName).$($DomainName).$($MainDomain)"
# Result: "UVWDC001.UVW.meduniwien.ac.at"
```

## 4. Final Integration and Data Output

This phase integrates the FQDN generation with the certificate surveillance logic and defines how to write the results back into the source Excel file.

- **Certificate Query:**
  - For each server, use the newly constructed `$FQDN` to perform the certificate check, using the logic from the `seekCertReNewDay.ps1` script as a basis.
  - The script must also query the server to discover if any additional server certificates are present.

- **Excel Sheet Update:**
  - The primary, constructed `$FQDN` must be written into the `FQDN` column of the corresponding server's row in the Excel sheet.
  - If additional certificates are found, their names (e.g., Subject Name or SANs) should also be appended to the cell in the `FQDN` column, separated by a semicolon or another clear delimiter.

## 5. Configuration (`Config-Cert-Surveillance.json`)

The script will be driven by the following JSON configuration structure.

```json
{
  "Version": "v01.00.00",
  "RunMode": "PRODto",
  "Language": "EN",
  "DebugMode": true,
  "LastModuleCheck": "",
  "Paths": {
    "ConfigFile": "F:\\DEV\\repositories\\CertSurv\\Config\\Config-Cert-Surveillance.json",
    "PathTo7Zip": "C:\\Program Files\\7-Zip\\7z.exe",
    "LogoDirectory": "\\\\itscmgmt03.srv.meduniwien.ac.at\\iso\\MUWLogo",
    "ReportDirectory": "reports",
    "LogDirectory": "LOG"
  },
  "Excel": {
    "ExcelPath": "\\\\itscmgmt03.srv.meduniwien.ac.at\\iso\\WIndowsServerListe\\Serverliste2025FQDN.xlsx",
    "SheetName": "Serverliste2025",
    "HeaderRow": 1,
    "CertificateColumnName": "FQDN",
    "ServerNameColumnName": "Servername",
    "AlwaysUseConfigPath": true
  },
  "Network": {
    "DnsServer": "149.148.55.55",
    "TlsVersion": "SystemDefault"
  },
  "Intervals": {
    "DaysUntilUrgent": 10,
    "DaysUntilCritical": 30,
    "DaysUntilWarning": 60,
    "ArchiveLogsOlderThanDays": 30,
    "DeleteZipArchivesOlderThanDays": 90
  },
  "Mail": {
    "Enabled": true,
    "SmtpServer": "smtpi.meduniwien.ac.at",
    "SmtpPort": 25,
    "UseSsl": false,
    "SenderAddress": "ITSCMGMT03@meduniwien.ac.at",
    "DevTo": "thomas.garnreiter@meduniwien.ac.at",
    "ProdTo": "win-admin@meduniwien.ac.at",
    "SubjectPrefix": "[Zertifikats-Report]",
    "CredentialFilePath": "C:\\Script\\Zertifikate\\Config\\secure.smtp.cred.xml"
  },
  "CorporateDesign": {
    "PrimaryColor": "#111d4e",
    "HoverColor": "#5fb4e5"
  }
}
```