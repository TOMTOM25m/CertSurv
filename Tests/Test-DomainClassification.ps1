#requires -Version 5.1

<#
.SYNOPSIS
    Block 2: Server-Name basierte Domain-Klassifizierung
.DESCRIPTION
    Da keine Excel-Header existieren, klassifizieren wir basierend auf Server-Namen-Mustern
#>

# Set up paths
$ScriptDirectory = "F:\DEV\repositories\CertSurv"
$ModulesPath = Join-Path -Path $ScriptDirectory -ChildPath "Modules"

# Import required modules
Import-Module (Join-Path -Path $ModulesPath -ChildPath "FL-Config.psm1") -Force

# Load configuration
$ScriptConfig = Get-ScriptConfiguration -ScriptDirectory $ScriptDirectory
$Config = $ScriptConfig.Config

Write-Host "Block 2: Server-Name basierte Domain-Klassifizierung..." -ForegroundColor Cyan

try {
    # Import server data
    $serverData = Import-Excel -Path $Config.Excel.ExcelPath -WorksheetName $Config.Excel.SheetName -HeaderRow 1
    
    Write-Host "`nServer-Name Analyse für Domain-Klassifizierung:" -ForegroundColor Yellow
    
    # Define domain classification rules based on server name patterns
    $domainRules = @{
        "UVW" = @{
            "Patterns" = @("UVW*", "*uvw*", "na0fs1bkp")  # na0fs1bkp ist explizit UVW Domain
            "Type" = "Domain"
        }
        "NEURO" = @{
            "Patterns" = @("NEURO*", "*neuro*")
            "Type" = "Domain"
        }
        "EX" = @{
            "Patterns" = @("EX*", "*ex*")
            "Type" = "Domain"
        }
        "DGMW" = @{
            "Patterns" = @("DGMW*", "*dgmw*")
            "Type" = "Domain"
        }
        "AD" = @{
            "Patterns" = @("ADDC*", "*ad*", "sync*")
            "Type" = "Domain"
        }
        "SRV" = @{
            "Patterns" = @("*")  # Default fallback
            "Type" = "Workgroup"
        }
    }
    
    $testServers = @("na0fs1bkp", "UVWDC001", "UVWDC002", "UVWDC003", "NEURODC01", "EXDC01", "ADDC01P")
    
    foreach ($serverName in $testServers) {
        $serverRow = $serverData | Where-Object { $_.ServerName -eq $serverName }
        
        if ($serverRow) {
            Write-Host "`nServer: $serverName" -ForegroundColor White
            
            # Apply classification rules
            $classified = $false
            foreach ($domain in $domainRules.Keys) {
                if ($domain -eq "SRV") { continue }  # Skip default rule for now
                
                foreach ($pattern in $domainRules[$domain].Patterns) {
                    if ($serverName -like $pattern) {
                        $domainType = $domainRules[$domain].Type
                        Write-Host "  ✅ Matched pattern '$pattern' -> Domain: $domain, Type: $domainType" -ForegroundColor Green
                        $classified = $true
                        break
                    }
                }
                if ($classified) { break }
            }
            
            if (-not $classified) {
                Write-Host "  ❌ No pattern matched -> Domain: SRV, Type: Workgroup (default)" -ForegroundColor Red
            }
        } else {
            Write-Host "`nServer: $serverName - NOT FOUND in Excel data" -ForegroundColor Red
        }
    }
    
    Write-Host "`n=== Spezifische na0fs1bkp Analyse ===" -ForegroundColor Magenta
    $na0Server = $serverData | Where-Object { $_.ServerName -eq "na0fs1bkp" }
    if ($na0Server) {
        Write-Host "✅ na0fs1bkp gefunden in Excel-Daten" -ForegroundColor Green
        Write-Host "   ServerName: $($na0Server.ServerName)" -ForegroundColor Gray
        Write-Host "   OS_Name: $($na0Server.OS_Name)" -ForegroundColor Gray
        Write-Host "   FQDN: $($na0Server.FQDN)" -ForegroundColor Gray
        Write-Host "   👉 SOLL klassifiziert werden als: Domain=UVW, Type=Domain" -ForegroundColor Yellow
    } else {
        Write-Host "❌ na0fs1bkp NICHT in Excel-Daten gefunden!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nBlock 2 completed!" -ForegroundColor Cyan
