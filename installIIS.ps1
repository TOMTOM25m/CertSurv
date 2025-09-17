#==============================================================================
# GESAMTSKRIPT: IIS-Webseite zur Anzeige von Zertifikats-Ablaufdaten
# (Filtert Standard- & Root-Zertifikate heraus)
#==============================================================================

# --- 1. Konfiguration ---
$siteName = "Zertifikatsuebersicht"
$sitePort = 8081
$sitePath = "C:\inetpub\wwwroot\Zertifikate"

# --- 2. Verzeichnis für Webseite erstellen ---
Write-Host "1. Erstelle Verzeichnis unter '$sitePath'..."
if (-not (Test-Path -Path $sitePath)) {
    New-Item -Path $sitePath -ItemType Directory -Force
}
Write-Host "Verzeichnis erstellt." -ForegroundColor Green

# --- 3. HTML-Datei mit stark gefilterten Zertifikatsdaten generieren ---
Write-Host "2. Generiere index.html mit gefilterten Zertifikatsdaten..."
$htmlHeader = @"
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <title>Zertifikatsübersicht</title>
    <style>
        body { font-family: sans-serif; margin: 2em; background-color: #f4f4f4; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #0078D4; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Zertifikatsübersicht (ohne Standard- & Root-Zertifikate)</h1>
    <p>Stand: $(Get-Date -Format 'yyyy.MM.dd HH:mm:ss')</p>
    <table>
        <tr>
            <th>Zertifikatsname (Subject)</th>
            <th>Gültig bis</th>
            <th>Aussteller (Issuer)</th>
        </tr>
"@
$htmlFooter = "</table></body></html>"

# HIER IST DIE ZUSÄTZLICHE ÄNDERUNG:
# Ein weiterer Filter, um Root-Zertifikate auszuschliessen (Issuer ist gleich Subject).
$htmlRows = Get-ChildItem -Path Cert:\LocalMachine\ -Recurse |
    Where-Object {
        (-not $_.PSIsContainer) -and
        ($_.Issuer -notlike 'CN=Microsoft*') -and
        ($_.Issuer -ne $_.Subject)
    } |
    ForEach-Object {
        "        <tr><td>$($_.Subject)</td><td>$($_.NotAfter.ToString('yyyy.MM.dd'))</td><td>$($_.Issuer)</td></tr>"
    }

$htmlHeader + ($htmlRows -join "`r`n") + $htmlFooter | Set-Content -Path "$sitePath\index.html" -Encoding UTF8
Write-Host "HTML-Datei wurde erfolgreich erstellt." -ForegroundColor Green

# --- 4. IIS-Konfiguration ---
Write-Host "3. Konfiguriere IIS..."

# 4a. Authentifizierungs-Sektionen auf Server-Ebene entsperren
Write-Host "   - Entsperre Authentifizierungs-Sektionen..."
Set-WebConfiguration -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/security/authentication/anonymousAuthentication" -Metadata "overrideMode" -Value "Allow"
Set-WebConfiguration -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/security/authentication/windowsAuthentication" -Metadata "overrideMode" -Value "Allow"

# 4b. IIS-Webseite erstellen
Write-Host "   - Erstelle Webseite '$siteName' auf Port $sitePort..."
New-Website -Name $siteName -Port $sitePort -PhysicalPath $sitePath -Force

# 4c. Authentifizierung für die Webseite konfigurieren
Write-Host "   - Konfiguriere Webseiten-Authentifizierung..."
Set-WebConfigurationProperty -PSPath "IIS:\Sites\$siteName" -Filter "system.webServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $false
Set-WebConfigurationProperty -PSPath "IIS:\Sites\$siteName" -Filter "system.webServer/security/authentication/windowsAuthentication" -Name "enabled" -Value $true
Write-Host "IIS-Konfiguration abgeschlossen." -ForegroundColor Green

# --- 5. Firewall-Regel erstellen ---
Write-Host "4. Erstelle Firewall-Regel für Port $sitePort..."
$ruleName = "IIS Zertifikate Port ($sitePort)"
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $sitePort
    Write-Host "Firewall-Regel '$ruleName' wurde erstellt." -ForegroundColor Green
} else {
    Write-Host "Firewall-Regel '$ruleName' existiert bereits." -ForegroundColor Yellow
}

# --- Skript Ende ---
Write-Host "`nAlle Schritte abgeschlossen.`nDie Webseite ist erreichbar unter: http://$(hostname):$sitePort" -ForegroundColor Cyan