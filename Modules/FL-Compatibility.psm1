#requires -Version 5.1

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "FL-Compatibility - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

<#
.SYNOPSIS
    [DE] FL-Compatibility Modul - PowerShell-Versionskompatibilität und Cross-Version-Funktionen
    [EN] FL-Compatibility Module - PowerShell version compatibility and cross-version functions
.DESCRIPTION
    [DE] Stellt PowerShell-versionsspezifische Funktionen und Kompatibilitäts-Layer für PowerShell 5.1 und 7+ bereit.
         Implementiert Wrapper-Funktionen für unterschiedliche PowerShell-Versionen und Version-Detection.
    [EN] Provides PowerShell version-specific functions and compatibility layer for PowerShell 5.1 and 7+.
         Implements wrapper functions for different PowerShell versions and version detection.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.09.04
    Last modified:  2025.09.04
    Version:        v1.0.0
    MUW-Regelwerk:  v9.4.0 (PowerShell Version Adaptation)
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Module Variables
$ModuleName = "FL-Compatibility"
$ModuleVersion = "v1.1.0"

#----------------------------------------------------------[Version Detection]------------------------------------------------------------

<#
.SYNOPSIS
    Initializes PowerShell version detection variables
.DESCRIPTION
    Sets global variables for PowerShell version compatibility checking
.EXAMPLE
    Initialize-PowerShellCompatibility
.OUTPUTS
    None - Sets global variables
#>
function Initialize-PowerShellCompatibility {
    [CmdletBinding()]
    param()
    
    # Detect PowerShell version and set compatibility flags
    $Global:PowerShellVersion = $PSVersionTable.PSVersion
    $Global:IsPowerShell5 = $PSVersionTable.PSVersion.Major -eq 5
    $Global:IsPowerShell7Plus = $PSVersionTable.PSVersion.Major -ge 7
    $Global:IsWindowsPowerShell = $PSVersionTable.PSEdition -eq 'Desktop'
    $Global:IsPowerShellCore = $PSVersionTable.PSEdition -eq 'Core'
    
    Write-Verbose "PowerShell Version: $($Global:PowerShellVersion)"
    Write-Verbose "Edition: $($PSVersionTable.PSEdition)"
    if ($Global:IsPowerShell7Plus) {
        Write-Verbose "Platform: $($PSVersionTable.Platform)"
    }
    
    # Log compatibility information
    $compatInfo = @{
        Version = $Global:PowerShellVersion.ToString()
        Edition = $PSVersionTable.PSEdition
        Major = $PSVersionTable.PSVersion.Major
        Platform = if ($Global:IsPowerShell7Plus) { $PSVersionTable.Platform } else { "Windows" }
    }
    
    Write-Verbose "PowerShell Compatibility initialized: $($compatInfo | ConvertTo-Json -Compress)"
}

#----------------------------------------------------------[Parser Functions]------------------------------------------------------------

<#
.SYNOPSIS
    Tests PowerShell script syntax across versions
.DESCRIPTION
    Uses the appropriate parser for PowerShell 5.1 (PSParser) or PowerShell 7+ (Language.Parser)
.PARAMETER FilePath
    Path to the PowerShell script file to test
.EXAMPLE
    Test-ScriptSyntaxCompatible -FilePath "C:\Scripts\Test.ps1"
.OUTPUTS
    Boolean - True if syntax is valid
#>
function Test-ScriptSyntaxCompatible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return $false
    }
    
    try {
        if ($Global:IsPowerShell7Plus) {
            # PowerShell 7+ uses Language.Parser
            $errors = @()
            [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$errors)
            
            if ($errors.Count -gt 0) {
                Write-Verbose "PowerShell 7+ parser found $($errors.Count) errors"
                $errors | ForEach-Object {
                    Write-Verbose "Line $($_.Extent.StartLineNumber): $($_.Message)"
                }
                return $false
            }
            
            Write-Verbose "PowerShell 7+ syntax check passed"
            return $true
        } else {
            # PowerShell 5.1 uses PSParser
            $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
            [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) | Out-Null
            Write-Verbose "PowerShell 5.1 syntax check passed"
            return $true
        }
    }
    catch {
        Write-Verbose "Syntax check failed: $($_.Exception.Message)"
        return $false
    }
}

#----------------------------------------------------------[JSON Functions]------------------------------------------------------------

<#
.SYNOPSIS
    Converts objects to JSON with version-specific optimizations
.DESCRIPTION
    Uses PowerShell 7+ features like -EnumsAsStrings when available, fallback for PS 5.1
.PARAMETER InputObject
    Object to convert to JSON
.PARAMETER Depth
    Maximum depth for nested objects
.EXAMPLE
    ConvertTo-JsonCompatible -InputObject $config -Depth 10
.OUTPUTS
    String - JSON representation
#>
function ConvertTo-JsonCompatible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject,
        
        [Parameter(Mandatory = $false)]
        [int]$Depth = 10
    )
    
    try {
        if ($Global:IsPowerShell7Plus) {
            # PowerShell 7+ has better JSON support
            return $InputObject | ConvertTo-Json -Depth $Depth -EnumsAsStrings
        } else {
            # PowerShell 5.1 fallback
            return $InputObject | ConvertTo-Json -Depth $Depth
        }
    }
    catch {
        Write-Error "JSON conversion failed: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Converts JSON to objects with version-specific optimizations
.DESCRIPTION
    Uses PowerShell 7+ features like -AsHashtable when available
.PARAMETER InputObject
    JSON string to convert
.PARAMETER AsHashtable
    Return as hashtable instead of PSCustomObject (PS7+ only)
.EXAMPLE
    ConvertFrom-JsonCompatible -InputObject $jsonString -AsHashtable
.OUTPUTS
    Object - Converted from JSON
#>
function ConvertFrom-JsonCompatible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputObject,
        
        [Parameter(Mandatory = $false)]
        [switch]$AsHashtable
    )
    
    try {
        if ($Global:IsPowerShell7Plus -and $AsHashtable) {
            # PowerShell 7+ hashtable support
            return $InputObject | ConvertFrom-Json -AsHashtable
        } else {
            # Standard conversion for both versions
            return $InputObject | ConvertFrom-Json
        }
    }
    catch {
        Write-Error "JSON parsing failed: $($_.Exception.Message)"
        throw
    }
}

#----------------------------------------------------------[File I/O Functions]------------------------------------------------------------

<#
.SYNOPSIS
    Saves text files with proper UTF-8 encoding across PowerShell versions
.DESCRIPTION
    Handles UTF-8 BOM issues between PS 5.1 and PS 7+
.PARAMETER Path
    File path to save to
.PARAMETER Content
    Text content to save
.PARAMETER NoBOM
    Force no BOM (default: true for PS7+, false for PS5.1)
.EXAMPLE
    Save-FileUTF8Compatible -Path "C:\file.txt" -Content "Hello World"
.OUTPUTS
    None
#>
function Save-FileUTF8Compatible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Content,
        
        [Parameter(Mandatory = $false)]
        [switch]$NoBOM
    )
    
    try {
        if ($Global:IsPowerShell7Plus) {
            # PowerShell 7+ has better UTF-8 support
            if ($NoBOM) {
                $Content | Out-File -FilePath $Path -Encoding utf8NoBOM -Force
            } else {
                $Content | Out-File -FilePath $Path -Encoding utf8 -Force
            }
        } else {
            # PowerShell 5.1 workaround for UTF-8 without BOM
            if ($NoBOM) {
                $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
                [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
            } else {
                $Content | Out-File -FilePath $Path -Encoding UTF8 -Force
            }
        }
        Write-Verbose "File saved successfully: $Path"
    }
    catch {
        Write-Error "Failed to save file '$Path': $($_.Exception.Message)"
        throw
    }
}

#----------------------------------------------------------[Module Management]------------------------------------------------------------

<#
.SYNOPSIS
    Imports modules with version-specific compatibility
.DESCRIPTION
    Handles module import differences between PowerShell versions
.PARAMETER ModuleName
    Name of the module to import
.PARAMETER Force
    Force reimport of the module
.EXAMPLE
    Import-ModuleCompatible -ModuleName "ImportExcel" -Force
.OUTPUTS
    Boolean - True if import successful
#>
function Import-ModuleCompatible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    try {
        $importParams = @{
            Name = $ModuleName
            ErrorAction = 'Stop'
        }
        
        if ($Force) {
            $importParams.Force = $true
        }
        
        if ($Global:IsPowerShell7Plus) {
            # PowerShell 7+ specific parameters
            $importParams.SkipEditionCheck = $true
        }
        
        Import-Module @importParams
        Write-Verbose "Module '$ModuleName' imported successfully"
        return $true
    }
    catch {
        Write-Warning "Module '$ModuleName' not available for PowerShell $($Global:PowerShellVersion): $($_.Exception.Message)"
        return $false
    }
}

#----------------------------------------------------------[Error Handling]------------------------------------------------------------

<#
.SYNOPSIS
    Writes errors with version-specific formatting
.DESCRIPTION
    Provides consistent error output across PowerShell versions
.PARAMETER Message
    Error message
.PARAMETER Exception
    Exception object (optional)
.PARAMETER Category
    Error category
.EXAMPLE
    Write-CompatibleError -Message "Something failed" -Exception $_.Exception
.OUTPUTS
    None
#>
function Write-CompatibleError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [Exception]$Exception,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorCategory]$Category = 'NotSpecified'
    )
    
    if ($Global:IsPowerShell7Plus -and $Exception) {
        Write-Error -Message $Message -Exception $Exception -Category $Category
    } elseif ($Exception) {
        Write-Error -Message "$Message : $($Exception.Message)"
    } else {
        Write-Error -Message $Message
    }
}

#----------------------------------------------------------[Utility Functions]------------------------------------------------------------

<#
.SYNOPSIS
    Gets PowerShell compatibility information
.DESCRIPTION
    Returns detailed information about PowerShell version and capabilities
.EXAMPLE
    Get-PowerShellCompatibilityInfo
.OUTPUTS
    PSCustomObject with version information
#>
function Get-PowerShellCompatibilityInfo {
    [CmdletBinding()]
    param()
    
    return [PSCustomObject]@{
        Version = $Global:PowerShellVersion.ToString()
        Major = $Global:PowerShellVersion.Major
        Minor = $Global:PowerShellVersion.Minor
        Build = $Global:PowerShellVersion.Build
        Edition = $PSVersionTable.PSEdition
        Platform = if ($Global:IsPowerShell7Plus) { $PSVersionTable.Platform } else { "Windows" }
        IsPowerShell5 = $Global:IsPowerShell5
        IsPowerShell7Plus = $Global:IsPowerShell7Plus
        IsWindowsPowerShell = $Global:IsWindowsPowerShell
        IsPowerShellCore = $Global:IsPowerShellCore
        SupportsNullConditional = $Global:IsPowerShell7Plus
        SupportsTernaryOperator = $Global:IsPowerShell7Plus
        SupportsPipelineChains = $Global:IsPowerShell7Plus
        SupportsEnhancedJSON = $Global:IsPowerShell7Plus
        SupportsUTF8NoBOM = $Global:IsPowerShell7Plus
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

# Export functions
Export-ModuleMember -Function @(
    'Initialize-PowerShellCompatibility',
    'Test-ScriptSyntaxCompatible',
    'ConvertTo-JsonCompatible',
    'ConvertFrom-JsonCompatible',
    'Save-FileUTF8Compatible',
    'Import-ModuleCompatible',
    'Write-CompatibleError',
    'Get-PowerShellCompatibilityInfo'
)

# Module initialization
Write-Verbose "$ModuleName $ModuleVersion loaded successfully"

# Auto-initialize compatibility if not already done
if (-not $Global:PowerShellVersion) {
    Initialize-PowerShellCompatibility
}

# --- End of module --- v1.1.0 ; Regelwerk: v9.3.1 ---
