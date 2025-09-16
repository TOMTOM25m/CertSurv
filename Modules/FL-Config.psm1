#requires -Version 5.1

<#
.SYNOPSIS
    [DE] FL-Config Modul - Konfigurationsverwaltung für Cert-Surveillance
    [EN] FL-Config Module - Configuration management for Cert-Surveillance
.DESCRIPTION
    [DE] Stellt Funktionen für das Laden und Verwalten von JSON-Konfigurationsdateien bereit.
         Unterstützt mehrsprachige Lokalisierung und Konfigurationsvalidierung.
    [EN] Provides functions for loading and managing JSON configuration files.
         Supports multilingual localization and configuration validation.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.09.04
    Last modified:  2025.09.04
    Version:        v1.0.0
    MUW-Regelwerk:  v9.3.0
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

$ModuleName = "FL-Config"
$ModuleVersion = "v1.0.0"

#----------------------------------------------------------[Functions]----------------------------------------------------------

Function Get-ScriptConfiguration {
    <#
    .SYNOPSIS
        [DE] Lädt die Skript-Konfiguration und Lokalisierung.
        [EN] Loads script configuration and localization.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptDirectory
    )

    $configPath = Join-Path -Path $ScriptDirectory -ChildPath "Config"
    $configFile = Join-Path -Path $configPath -ChildPath "Config-Cert-Surveillance.json"

    if (-not (Test-Path $configFile)) {
        throw "FATAL: Configuration file not found at '$configFile'"
    }

    $config = Get-Content -Path $configFile | ConvertFrom-Json
    
    $langFile = Join-Path -Path $configPath -ChildPath "$($config.Language).json"
    if (-not (Test-Path $langFile)) {
        throw "FATAL: Language file not found for '$($config.Language)' at '$langFile'"
    }
    
    $localization = Get-Content -Path $langFile | ConvertFrom-Json

    return @{
        Config = $config
        Localization = $localization
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function Get-ScriptConfiguration

Write-Verbose "FL-Config module v$ModuleVersion loaded successfully"

# --- End of module --- v1.0.0 ; Regelwerk: v9.3.0 ---
