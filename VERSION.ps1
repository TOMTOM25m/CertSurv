#region Script Version Information (MANDATORY - Regelwerk v9.6.0)
# VERSION.ps1 - Certificate Surveillance System Version Management
# Author: Flecki (Tom) Garnreiter
# Version: 1.4.0
# Date: 2025-09-27
# Regelwerk: v9.6.0

<#
.VERSION HISTORY
1.4.0 - 2025-09-27 - Regelwerk v9.6.0 compliance update, script naming conventions
1.3.0 - 2025-09-24 - Enhanced version management, Regelwerk v9.5.0 compliance
1.2.0 - 2025-09-22 - Added component versioning and build metadata
1.1.0 - 2025-09-20 - Initial version management system
1.0.0 - 2025-09-18 - Basic version schema
#>

#region Global Version Variables (Regelwerk v9.6.0 Compliant)
$Global:CertSurvSystemVersion = "1.4.0-STABLE"    # Overall System Version
$Global:CertSurvBuildDate = "2025-09-27"          # Build Date
$Global:CertSurvRegelwerkVersion = "v9.6.0"       # Rulebook Version
$Global:CertSurvAuthor = "Flecki (Tom) Garnreiter" # Author

# Script Component Versions (Updated Names - Regelwerk v9.6.0 §18.1)
$Global:CertSurvMainVersion = "1.4.0"             # Cert-Surveillance-Main.ps1 - Core Logic
$Global:CertSurvSetupVersion = "1.3.0"            # Setup-CertSurv-System.ps1 - System Setup  
$Global:CertSurvCheckVersion = "1.3.0"            # Check-CertSurv-Compliance.ps1 - Compliance Check
$Global:CertSurvDeployVersion = "1.3.0"           # Deploy-CertSurv-Network.ps1 - Network Deployment
$Global:CertSurvManageVersion = "1.3.0"           # Manage-CertSurv-Servers.ps1 - Server Management
$Global:CertSurvGUIVersion = "1.3.0"              # Setup-CertSurvGUI.ps1 - Configuration GUI
$Global:CertSurvInstallerVersion = "1.1.0"        # Install-CertSurv.bat - Universal Installer
$Global:CertSurvWebServiceVersion = "2.1.0"       # WebService Integration

# === COMPLIANCE VERSIONS ===
$Global:CertSurvRegelwerkVersion = "9.5.0"        # Current Regelwerk Compliance
$Global:CertSurvMinPowerShell = "5.1"             # Minimum PowerShell Version
$Global:CertSurvTargetFramework = ".NET 4.8"      # Target Framework

# === BUILD METADATA ===
$Global:CertSurvBuildNumber = "20250924.1"        # Build: YYYYMMDD.sequence
$Global:CertSurvCommitHash = "main"                # Git Commit Reference
$Global:CertSurvAuthor = "Flecki Garnreiter"      # System Author
$Global:CertSurvLicense = "MIT"                    # License Type

# === VERSION FUNCTIONS ===
function Get-CertSurvVersion {
    return @{
        System = $Global:CertSurvSystemVersion
        ReleaseDate = $Global:CertSurvReleaseDate  
        Status = $Global:CertSurvReleaseStatus
        Regelwerk = $Global:CertSurvRegelwerkVersion
        BuildNumber = $Global:CertSurvBuildNumber
        FullVersion = "$($Global:CertSurvSystemVersion)-$($Global:CertSurvReleaseStatus)"
    }
}

function Show-CertSurvVersionBanner {
    param([string]$ComponentName = "Certificate Surveillance System")
    
    $version = Get-CertSurvVersion
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "$ComponentName v$($version.System)" -ForegroundColor Green
    Write-Host "Regelwerk: v$($version.Regelwerk) | PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "Build: $($version.BuildNumber) | Status: $($version.Status)" -ForegroundColor Gray  
    Write-Host "=" * 70 -ForegroundColor Cyan
}

# === SCRIPT USAGE READY ===
# Functions and variables are now available in global scope when dot-sourced

# === VERSION HISTORY ===
<#
v1.4.0 (2025-09-24) - STABLE
- Unified version management system
- Regelwerk v9.5.0 compliance
- Complete GUI configuration tool
- Universal network installer
- WebService integration v2.1.0

v1.3.1 (2025-09-23) - STABLE  
- Network deployment fixes
- Encoding standardization
- Installation pipeline improvements

v1.3.0 (2025-09-22) - STABLE
- WebService integration
- Scheduled task automation
- Multi-threading support

v1.2.x (2025-09-21) - STABLE
- GUI configuration tools
- Setup automation
- Documentation overhaul

v1.1.x (2025-09-20) - STABLE
- Core monitoring functionality
- Email notifications
- Basic reporting

v1.0.0 (2025-09-19) - STABLE
- Initial release
- Certificate discovery
- Basic monitoring
#>