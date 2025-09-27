#requires -Version 5.1

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "FL-Config - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

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
$ModuleVersion = "v1.1.0"

#region Universal JSON Functions (Regelwerk v9.4.0)
function ConvertFrom-JsonUniversal {
    param([string]$JsonString)
    
    if ($IsPS7Plus) {
        Write-Verbose "Using PowerShell 7.x ConvertFrom-Json with AsHashtable"
        return $JsonString | ConvertFrom-Json -AsHashtable
    } else {
        Write-Verbose "Using PowerShell 5.1 compatible ConvertFrom-Json"
        return $JsonString | ConvertFrom-Json
    }
}
#endregion

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

    $config = Get-Content -Path $configFile -Raw | ConvertFrom-Json
    
    # Get language setting with fallback
    $language = if ($config.Language -and ![string]::IsNullOrWhiteSpace($config.Language)) {
        $config.Language
    } else {
        Write-Warning "Language property is missing or empty in config. Defaulting to 'de-DE'"
        "de-DE"
    }
    
    $langFile = Join-Path -Path $configPath -ChildPath "$language.json"
    if (-not (Test-Path $langFile)) {
        throw "FATAL: Language file not found for '$language' at '$langFile'"
    }

    $localization = Get-Content -Path $langFile -Raw | ConvertFrom-Json
    
    return @{
        Config = $config
        Localization = $localization
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function Get-ScriptConfiguration

Write-Verbose "FL-Config module v$ModuleVersion loaded successfully"

# --- End of module --- v1.1.0 ; Regelwerk: v9.4.0 (PowerShell Version Adaptation) ---
