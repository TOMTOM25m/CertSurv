#requires -Version 5.1
#requires -RunAsAdministrator

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "FL-ActiveDirectory - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

<#
.SYNOPSIS
    [DE] FL-ActiveDirectory Modul - Active Directory-Funktionen für Cert-Surveillance
    [EN] FL-ActiveDirectory Module - Active Directory functions for Cert-Surveillance
.DESCRIPTION
    [DE] Stellt Funktionen für Active Directory-Abfragen und -Operationen bereit.
         Unterstützt die Unterscheidung zwischen Domain-, Domain-ADsync- und Workgroup-Servern.
    [EN] Provides functions for Active Directory queries and operations.
         Supports distinction between Domain, Domain-ADsync, and Workgroup servers.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.09.04
    Last modified:  2025.09.04
    Version:        v1.0.0
    MUW-Regelwerk:  v9.3.0
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Module Variables
$ModuleName = "FL-ActiveDirectory"
$ModuleVersion = "v1.1.0"

#----------------------------------------------------------[Functions]------------------------------------------------------------

<#
.SYNOPSIS
    Testet die Verfügbarkeit von Active Directory-Modulen
.DESCRIPTION
    Überprüft, ob die erforderlichen AD-Module verfügbar sind
.EXAMPLE
    Test-ADModuleAvailability
.OUTPUTS
    Boolean - True wenn AD-Module verfügbar sind
#>
function Test-ADModuleAvailability {
    [CmdletBinding()]
    param()
    
    try {
        # Test for ActiveDirectory module
        $adModule = Get-Module -ListAvailable -Name ActiveDirectory
        if ($adModule) {
            Write-Verbose "ActiveDirectory module found: $($adModule.Version)"
            return $true
        } else {
            Write-Warning "ActiveDirectory module not found. AD operations will be limited."
            return $false
        }
    }
    catch {
        Write-Warning "Error checking AD module availability: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Bestimmt den Servertyp basierend auf Excel-Daten
.DESCRIPTION
    Analysiert Excel-Zeilen um zwischen Domain-, Domain-ADsync- und Workgroup-Servern zu unterscheiden
.PARAMETER ServerName
    Name des Servers
.PARAMETER DomainStatusValue
    Wert aus der Domain-Status-Spalte (z.B. "Domain", "Domain-ADsync", "Workgroup")
.EXAMPLE
    Get-ServerType -ServerName "SERVER01" -DomainStatusValue "Domain-ADsync"
.OUTPUTS
    PSCustomObject mit ServerType, RequiresAD, IsADSync Properties
#>
function Get-ServerType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $false)]
        [string]$DomainStatusValue
    )
    
    $result = [PSCustomObject]@{
        ServerType = "Unknown"
        RequiresAD = $false
        IsADSync = $false
        IsWorkgroup = $false
        IsDomain = $false
    }
    
    # Normalize only if the value contains expected keywords; otherwise ignore
    $usedStatus = $null
    if (-not [string]::IsNullOrWhiteSpace($DomainStatusValue)) {
        if ($DomainStatusValue -match "(?i)workgroup") { $usedStatus = "Workgroup" }
        elseif ($DomainStatusValue -match "(?i)domain-?adsync") { $usedStatus = "Domain-ADsync" }
        elseif ($DomainStatusValue -match "(?i)domain") { $usedStatus = "Domain" }
    }

    if ($usedStatus) {
        switch ($usedStatus) {
            "Workgroup" {
                $result.ServerType = "Workgroup"
                $result.IsWorkgroup = $true
                $result.RequiresAD = $false
            }
            "Domain-ADsync" {
                $result.ServerType = "Domain"  # Einheitlich als "Domain" klassifizieren
                $result.IsADSync = $true       # Aber ADsync-Flag setzen
                $result.IsDomain = $true
                $result.RequiresAD = $true
            }
            "Domain" {
                $result.ServerType = "Domain"
                $result.IsDomain = $true
                $result.RequiresAD = $true
            }
        }
    }

    if (-not $usedStatus) {
        # Fallback to server name pattern analysis
        if ($ServerName -like "*(Workgroup)*") {
            $result.ServerType = "Workgroup"
            $result.IsWorkgroup = $true
            $result.RequiresAD = $false
        } elseif ($ServerName -like "*Domain-ADsync*" -or $ServerName -like "*ADsync*" -or $ServerName -like "*AD-sync*") {
            $result.ServerType = "Domain"  # Einheitlich als "Domain" klassifizieren
            $result.IsADSync = $true       # Aber ADsync-Flag setzen
            $result.IsDomain = $true
            $result.RequiresAD = $true
        } elseif ($ServerName -like "*(Domain)*") {
            $result.ServerType = "Domain"
            $result.IsDomain = $true
            $result.RequiresAD = $true
        } else {
            # WICHTIG: Nur explizit als Domain markierte Server werden als Domain behandelt
            # Unbekannte Server werden als Workgroup behandelt (sicherer Standard)
            $result.ServerType = "Workgroup"
            $result.IsWorkgroup = $true
            $result.RequiresAD = $false
        }
    }
    
    return $result
}

<#
.SYNOPSIS
    Führt Active Directory-Abfragen für Domain-Server durch
.DESCRIPTION
    Führt spezifische AD-Abfragen basierend auf dem Servertyp durch
.PARAMETER ServerName
    Name des Servers
.PARAMETER ServerType
    Typ des Servers (Domain, Domain-ADsync, Workgroup)
.PARAMETER FQDN
    Vollqualifizierter Domain-Name des Servers
.EXAMPLE
    Invoke-ADQuery -ServerName "SERVER01" -ServerType "Domain-ADsync" -FQDN "server01.domain.company.com"
.OUTPUTS
    PSCustomObject mit AD-Informationen
#>
function Invoke-ADQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [string]$ServerType,
        
        [Parameter(Mandatory = $true)]
        [string]$FQDN
    )
    
    $result = [PSCustomObject]@{
        ServerName = $ServerName
        FQDN = $FQDN
        ServerType = $ServerType
        ADQueryExecuted = $false
        ADQuerySuccess = $false
        ComputerObject = $null
        LastLogon = $null
        OperatingSystem = $null
        ErrorMessage = $null
    }
    
    # Skip AD queries for Workgroup servers
    if ($ServerType -eq "Workgroup") {
        Write-Verbose "Skipping AD query for Workgroup server: $ServerName"
        $result.ADQueryExecuted = $false
        return $result
    }
    
    # Check if AD module is available
    if (-not (Test-ADModuleAvailability)) {
        $result.ErrorMessage = "ActiveDirectory module not available"
        return $result
    }
    
    try {
        # Import AD module if not already loaded
        if (-not (Get-Module -Name ActiveDirectory)) {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
        
        Write-Verbose "Executing AD query for $ServerType server: $ServerName"
        $result.ADQueryExecuted = $true
        
        # Query AD for computer object
        $computerObject = Get-ADComputer -Filter "Name -eq '$ServerName'" -Properties LastLogonDate, OperatingSystem, OperatingSystemVersion -ErrorAction Stop
        
        if ($computerObject) {
            $result.ADQuerySuccess = $true
            $result.ComputerObject = $computerObject
            $result.LastLogon = $computerObject.LastLogonDate
            $result.OperatingSystem = $computerObject.OperatingSystem
            
            Write-Verbose "AD query successful for $ServerName - OS: $($computerObject.OperatingSystem), Last Logon: $($computerObject.LastLogonDate)"
            
            # Special handling for ADsync servers
            if ($ServerType -eq "Domain-ADsync") {
                Write-Verbose "Special AD-Sync server processing for: $ServerName"
                # Add any special ADsync-specific queries here
            }
        } else {
            $result.ErrorMessage = "Computer object not found in Active Directory"
            Write-Warning "Computer object for '$ServerName' not found in AD"
        }
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
        Write-Error "AD query failed for '$ServerName': $($_.Exception.Message)"
    }
    
    return $result
}

<#
.SYNOPSIS
    Validiert die AD-Konnektivität
.DESCRIPTION
    Testet die Verbindung zu Active Directory
.EXAMPLE
    Test-ADConnectivity
.OUTPUTS
    Boolean - True wenn AD erreichbar ist
#>
function Test-ADConnectivity {
    [CmdletBinding()]
    param()
    
    try {
        if (-not (Test-ADModuleAvailability)) {
            return $false
        }
        
        # Import AD module if not already loaded
        if (-not (Get-Module -Name ActiveDirectory)) {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
        
        # Test basic AD connectivity
        $domain = Get-ADDomain -ErrorAction Stop
        Write-Verbose "AD connectivity test successful - Domain: $($domain.DNSRoot)"
        return $true
    }
    catch {
        Write-Warning "AD connectivity test failed: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Holt erweiterte Server-Informationen aus AD
.DESCRIPTION
    Sammelt umfassende Informationen über Server aus Active Directory
.PARAMETER ServerList
    Array von Server-Objekten mit Name und Typ
.EXAMPLE
    Get-ExtendedServerInfo -ServerList $servers
.OUTPUTS
    Array von PSCustomObjects mit erweiterten Server-Informationen
#>
function Get-ExtendedServerInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$ServerList
    )
    
    $results = @()
    
    # Test AD connectivity first
    $adAvailable = Test-ADConnectivity
    
    foreach ($server in $ServerList) {
        $serverInfo = [PSCustomObject]@{
            ServerName = $server.ServerName
            FQDN = $server.FQDN
            ServerType = $server.ServerType
            RequiresAD = $server.RequiresAD
            ADAvailable = $adAvailable
            ADQueryResult = $null
        }
        
        if ($server.RequiresAD -and $adAvailable) {
            $serverInfo.ADQueryResult = Invoke-ADQuery -ServerName $server.ServerName -ServerType $server.ServerType -FQDN $server.FQDN
        }
        
        $results += $serverInfo
    }
    
    return $results
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

# Export functions
Export-ModuleMember -Function @(
    'Test-ADModuleAvailability',
    'Get-ServerType',
    'Invoke-ADQuery',
    'Test-ADConnectivity',
    'Get-ExtendedServerInfo'
)

# Module information
Write-Verbose "$ModuleName $ModuleVersion loaded successfully"

# --- End of module --- v1.1.0 ; Regelwerk: v9.3.1 ---
