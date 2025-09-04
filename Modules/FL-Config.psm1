#Requires -version 5.1
#Requires -RunAsAdministrator

Function Get-ScriptConfiguration {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptDirectory
    )

    $configPath = Join-Path -Path $ScriptDirectory -ChildPath "Config"
    $configFile = Join-Path -Path $configPath -ChildPath "Config-Cert-Surveillance.ps1.json"

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

Export-ModuleMember -Function Get-ScriptConfiguration
