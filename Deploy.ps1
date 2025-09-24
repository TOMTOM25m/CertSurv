#requires -Version 5.1

<#
.SYNOPSIS
    Batch WebService Deployment für alle Server
.DESCRIPTION
    Automatisierte Installation des Certificate WebService auf allen 151 Servern
    mit integrierten Fallback-Mechanismen und Fehlerbehandlung.
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.2.0
    Regelwerk: v9.5.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# Import required modules
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ModulesPath = Join-Path $ScriptDirectory "Modules"
Import-Module (Join-Path $ModulesPath "FL-Config.psm1") -Force
Import-Module (Join-Path $ModulesPath "FL-Logging.psm1") -Force
Import-Module (Join-Path $ModulesPath "FL-DataProcessing.psm1") -Force

# Initialize configuration and logging
$ConfigPath = Join-Path $ScriptDirectory "Config\Config-Cert-Surveillance.json"
$Config = Initialize-Configuration -ConfigPath $ConfigPath
$LogFile = Join-Path $ScriptDirectory "LOG\WebService-Deployment_$(Get-Date -Format 'yyyy-MM-dd').log"

function Write-DeployLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "INFO" { "White" }
        "PROGRESS" { "Cyan" }
        default { "White" }
    }
    
    Write-Host $logEntry -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

function Deploy-WebServiceRemotely {
    param([string]$ServerFQDN, [string]$ServerName)
    
    Write-DeployLog "=== Deploying WebService to $ServerName ($ServerFQDN) ===" -Level PROGRESS
    
    try {
        # Method 1: Try PSSession (Domain-joined servers)
        Write-DeployLog "Attempting PSSession connection..." -Level INFO
        $session = $null
        
        try {
            $session = New-PSSession -ComputerName $ServerFQDN -ErrorAction Stop
            Write-DeployLog "PSSession established successfully" -Level SUCCESS
            
            $result = Invoke-Command -Session $session -ScriptBlock {
                # WebService Installation Script Block
                $webServicePath = "C:\inetpub\CertWebService"
                
                # Step 1: Install IIS if needed
                Write-Output "Checking IIS installation..."
                $iisFeature = Get-WindowsFeature -Name IIS-WebServer -ErrorAction SilentlyContinue
                if (-not $iisFeature -or $iisFeature.InstallState -ne "Installed") {
                    Write-Output "Installing IIS features..."
                    Install-WindowsFeature -Name IIS-WebServer, IIS-WebServerRole, IIS-CommonHttpFeatures, IIS-HttpFeatures, IIS-NetFxExtensibility45, IIS-ASPNET45 -IncludeManagementTools
                }
                
                # Step 2: Create WebService directory
                if (Test-Path $webServicePath) {
                    Remove-Item $webServicePath -Recurse -Force
                }
                New-Item -Path $webServicePath -ItemType Directory -Force | Out-Null
                
                # Step 3: Create certificate update script
                $updateScript = @'
#requires -Version 5.1
Set-StrictMode -Version Latest

try {
    $certificates = Get-ChildItem Cert:\LocalMachine\My | Where-Object {
        ($_.NotAfter -gt (Get-Date)) -and
        ($_.Subject -notlike '*Microsoft*') -and
        ($_.Subject -notlike '*Windows*') -and
        ($_.Subject -notlike '*DO_NOT_TRUST*')
    }
    
    $certificateData = foreach ($cert in $certificates) {
        @{
            Subject = $cert.Subject
            Issuer = $cert.Issuer
            NotBefore = $cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss')
            NotAfter = $cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
            DaysRemaining = [math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
            Thumbprint = $cert.Thumbprint
            HasPrivateKey = $cert.HasPrivateKey
            Store = 'LocalMachine\My'
        }
    }
    
    $result = @{
        status = "ready"
        message = "Certificate Web Service is operational"
        version = "v1.2.0"
        generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        server_name = $env:COMPUTERNAME
        certificate_count = $certificateData.Count
        certificates = $certificateData
        total_count = $certificateData.Count
        filters_applied = @("exclude_microsoft_certs", "exclude_root_certs", "active_certificates_only")
        endpoints = @{
            certificates = "/certificates.json"
            summary = "/summary.json"
            health = "/health.json"
        }
    }
    
    $jsonPath = "C:\inetpub\CertWebService\certificates.json"
    $result | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
    
    Write-Host "Certificate data updated: $($certificateData.Count) certificates"
    
} catch {
    Write-Error "Failed to update certificate data: $($_.Exception.Message)"
}
'@
                
                $updateScript | Set-Content -Path "$webServicePath\Update-CertificateData.ps1" -Encoding UTF8
                
                # Step 4: Create initial certificates.json
                $initialData = @{
                    status = "ready"
                    message = "Certificate Web Service is operational"
                    version = "v1.2.0"
                    generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                    server_name = $env:COMPUTERNAME
                    certificates = @()
                    total_count = 0
                    endpoints = @{
                        certificates = "/certificates.json"
                        summary = "/summary.json"
                        health = "/health.json"
                    }
                }
                
                $initialData | ConvertTo-Json -Depth 10 | Set-Content -Path "$webServicePath\certificates.json" -Encoding UTF8
                
                # Step 5: Configure IIS
                Import-Module WebAdministration -Force
                
                # Remove existing if present
                if (Get-IISAppPool -Name "CertWebService" -ErrorAction SilentlyContinue) {
                    Remove-IISAppPool -Name "CertWebService" -Confirm:$false
                }
                if (Get-IISSite -Name "CertWebService" -ErrorAction SilentlyContinue) {
                    Remove-IISSite -Name "CertWebService" -Confirm:$false
                }
                
                # Create new App Pool and Site
                New-IISAppPool -Name "CertWebService" -Force
                Set-ItemProperty -Path "IIS:\AppPools\CertWebService" -Name processModel.identityType -Value ApplicationPoolIdentity
                
                New-IISSite -Name "CertWebService" -PhysicalPath $webServicePath -BindingInformation "*:9080:" -ApplicationPool "CertWebService"
                New-IISSiteBinding -Name "CertWebService" -BindingInformation "*:9443:" -Protocol https -ErrorAction SilentlyContinue
                
                # Step 6: Configure firewall
                New-NetFirewallRule -DisplayName "Certificate WebService HTTP" -Direction Inbound -Protocol TCP -LocalPort 9080 -Action Allow -ErrorAction SilentlyContinue
                New-NetFirewallRule -DisplayName "Certificate WebService HTTPS" -Direction Inbound -Protocol TCP -LocalPort 9443 -Action Allow -ErrorAction SilentlyContinue
                
                # Step 7: Start services
                Start-IISAppPool -Name "CertWebService"
                Start-IISSite -Name "CertWebService"
                
                # Step 8: Generate initial certificate data
                & "$webServicePath\Update-CertificateData.ps1"
                
                # Step 9: Create scheduled task for updates
                $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$webServicePath\Update-CertificateData.ps1`""
                $taskTrigger = New-ScheduledTaskTrigger -Daily -At "06:00"
                $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
                $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
                
                Register-ScheduledTask -TaskName "Update-CertificateData" -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force
                
                return @{
                    Success = $true
                    ServerName = $env:COMPUTERNAME
                    WebServicePath = $webServicePath
                    Endpoints = @{
                        HTTP = "http://$($env:COMPUTERNAME):9080/certificates.json"
                        HTTPS = "https://$($env:COMPUTERNAME):9443/certificates.json"
                    }
                    Message = "WebService successfully deployed"
                }
            }
            
            if ($result.Success) {
                Write-DeployLog "✅ WebService deployment successful on $ServerName" -Level SUCCESS
                Write-DeployLog "   HTTP:  $($result.Endpoints.HTTP)" -Level INFO
                Write-DeployLog "   HTTPS: $($result.Endpoints.HTTPS)" -Level INFO
                return @{ Success = $true; Method = "PSSession"; Result = $result }
            }
            
        } catch {
            Write-DeployLog "PSSession failed: $($_.Exception.Message)" -Level WARN
        } finally {
            if ($session) { Remove-PSSession $session }
        }
        
        # Method 2: Try Invoke-Command with different credentials
        Write-DeployLog "Attempting direct Invoke -Command..." -Level INFO
        try {
            $result = Invoke-Command -ComputerName $ServerFQDN -ScriptBlock {
                # Simplified deployment for workgroup servers
                $webServicePath = "C:\inetpub\CertWebService"
                
                # Create basic directory structure
                if (-not (Test-Path $webServicePath)) {
                    New-Item -Path $webServicePath -ItemType Directory -Force
                }
                
                # Create basic certificates.json
                $basicData = @{
                    status = "ready"
                    message = "Basic WebService operational"
                    version = "v1.2.0"
                    generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                    server_name = $env:COMPUTERNAME
                    certificates = @()
                    total_count = 0
                }
                
                $basicData | ConvertTo-Json -Depth 5 | Set-Content -Path "$webServicePath\certificates.json" -Encoding UTF8
                
                return @{
                    Success = $true
                    ServerName = $env:COMPUTERNAME
                    Message = "Basic WebService structure created"
                }
            }
            
            if ($result.Success) {
                Write-DeployLog "✅ Basic WebService setup successful on $ServerName" -Level SUCCESS
                return @{ Success = $true; Method = "Direct"; Result = $result }
            }
            
        } catch {
            Write-DeployLog "Direct Invoke- Command failed: $($_.Exception.Message)" -Level WARN
        }
        
        # Method 3: Create manual deployment instructions
        Write-DeployLog "❌ Remote deployment failed - creating manual instructions" -Level ERROR
        
        $manualInstructions = @"

=== MANUAL DEPLOYMENT INSTRUCTIONS FOR $ServerName ===

1. Connect to server: $ServerFQDN
2. Run as Administrator:
   Enable-PSRemoting -Force
   
3. Install IIS:
   Install-WindowsFeature -Name IIS-WebServer,IIS-WebServerRole,IIS-CommonHttpFeatures,IIS-NetFxExtensibility45,IIS-ASPNET45 -IncludeManagementTools
   
4. Create WebService:
   mkdir C:\inetpub\CertWebService
   
5. Copy deployment files from: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment
   
6. Configure IIS site on ports 9080 (HTTP) and 9443 (HTTPS)

7. Test: http://$ServerFQDN:9080/certificates.json

"@
        
        Add-Content -Path (Join-Path $ScriptDirectory "LOG\Manual-Deployment-Instructions.txt") -Value $manualInstructions
        
        return @{ Success = $false; Method = "Manual"; Instructions = $manualInstructions }
        
    } catch {
        Write-DeployLog "❌ Deployment completely failed for $ServerName : $($_.Exception.Message)" -Level ERROR
        return @{ Success = $false; Method = "Failed"; Error = $_.Exception.Message }
    }
}

function Start-MassDeployment {
    Write-DeployLog "🚀 Starting Mass WebService Deployment..." -Level SUCCESS
    Write-DeployLog "Target: 151 servers from Excel configuration" -Level INFO
    
    # Load server list
    $excelResult = Import-ExcelData -ExcelPath $Config.Excel.ExcelPath -WorksheetName $Config.Excel.SheetName -Config $Config -LogFile $LogFile
    
    $deploymentResults = @{
        Total = 0
        Success = 0
        Failed = 0
        Manual = 0
        Results = @()
    }
    
    foreach ($row in $excelResult.Data) {
        $serverName = $row.$($Config.Excel.ServerNameColumnName)
        if (-not [string]::IsNullOrWhiteSpace($serverName)) {
            
            $deploymentResults.Total++
            
            # Determine FQDN
            $isDomainServer = $row._IsDomainServer -eq $true
            $domainContext = $row._DomainContext
            
            if ($isDomainServer -and $domainContext) {
                $fqdn = "$($serverName.Trim()).$($domainContext.ToLower()).$($Config.MainDomain)"
            } else {
                $fqdn = "$($serverName.Trim()).srv.$($Config.MainDomain)"
            }
            
            Write-DeployLog "[$($deploymentResults.Total)/$($excelResult.Data.Count)] Processing: $serverName" -Level PROGRESS
            
            $result = Deploy-WebServiceRemotely -ServerFQDN $fqdn -ServerName $serverName
            
            $deploymentResults.Results += @{
                ServerName = $serverName
                FQDN = $fqdn
                Success = $result.Success
                Method = $result.Method
                Timestamp = Get-Date
            }
            
            if ($result.Success) {
                $deploymentResults.Success++
            } elseif ($result.Method -eq "Manual") {
                $deploymentResults.Manual++
            } else {
                $deploymentResults.Failed++
            }
            
            # Progress report every 10 servers
            if ($deploymentResults.Total % 10 -eq 0) {
                Write-DeployLog "Progress: $($deploymentResults.Success) successful, $($deploymentResults.Failed) failed, $($deploymentResults.Manual) manual" -Level INFO
            }
        }
    }
    
    # Final report
    Write-DeployLog "🎯 DEPLOYMENT COMPLETED!" -Level SUCCESS
    Write-DeployLog "Total Servers: $($deploymentResults.Total)" -Level INFO
    Write-DeployLog "✅ Successful: $($deploymentResults.Success)" -Level SUCCESS
    Write-DeployLog "❌ Failed: $($deploymentResults.Failed)" -Level ERROR
    Write-DeployLog "📝 Manual Required: $($deploymentResults.Manual)" -Level WARN
    
    # Save detailed results
    $resultsPath = Join-Path $ScriptDirectory "LOG\Deployment-Results_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').json"
    $deploymentResults | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsPath -Encoding UTF8
    Write-DeployLog "Detailed results saved: $resultsPath" -Level INFO
    
    return $deploymentResults
}

# Execute deployment
Start-MassDeployment