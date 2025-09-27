Certificate WebService Deployment Package v1.4.0
====================================================

🆕 REGELWERK v9.5.0 COMPLIANT VERSION

INSTALLATION INSTRUCTIONS:

1. Copy this folder to the target server
2. Run as Administrator: Install-WebService-v1.4.0.bat (RECOMMENDED)
3. Test with: Test-WebService.ps1

REQUIREMENTS:
- Windows Server 2012 R2+
- PowerShell 5.1+
- Administrator privileges

NEW in v1.4.0:
+ Regelwerk v9.5.0 Compliance
+ Robocopy Integration
+ Version Display & Tracking
+ Enhanced Error Handling
+ PowerShell Version Detection

API ENDPOINTS (after installation):
- http://[SERVER]:9080/certificates.json
- http://[SERVER]:9080/health.json
- http://[SERVER]:9080/summary.json

PORTS:
- 9080 (HTTP)
- 9443 (HTTPS)

AUTOMATIC UPDATES:
- Daily at 6:00 and 18:00
- Manual: C:\inetpub\CertWebService\Update-CertificateData.ps1

FILES IN THIS PACKAGE:
- Setup-WebService-v1.4.0.ps1       : Regelwerk v9.5.0 compliant main script (RECOMMENDED)
- Setup-WebService-ServerCore.ps1    : Server Core compatible version (Legacy)
- Setup-WebService.ps1               : Standard installation script (Legacy)
- Install-WebService-v1.4.0.bat     : Regelwerk compliant installer (RECOMMENDED)
- Install-WebService-ServerCore.bat  : Server Core specific installer
- Install-WebService.bat             : Standard batch installer
- Test-WebService.ps1                : API testing script
- Test-Simple.ps1                    : Basic compatibility test
- VERSION.txt                        : Package version information
- README.txt                         : This file

RECOMMENDED INSTALLATION:
Use Install-WebService-v1.4.0.bat for full Regelwerk v9.5.0 compliance

LEGACY COMPATIBILITY:
For older environments use Install-WebService-ServerCore.bat

INSTALLATION PROCESS:
1. IIS features are installed automatically
2. WebService directory created: C:\inetpub\CertWebService
3. IIS site "CertWebService" created on ports 9080/9443
4. Firewall rules added for ports 9080 and 9443
5. Scheduled task created for automatic certificate updates
6. Initial certificate scan performed

INTEGRATION WITH CERTIFICATE SURVEILLANCE:
The Certificate Surveillance System will automatically detect 
and use the WebService API for fast certificate retrieval.

TROUBLESHOOTING:
- Check IIS: Get-Service W3SVC
- Check site: Get-IISSite -Name "CertWebService"  
- Check firewall: Test-NetConnection localhost -Port 9080
- Manual update: C:\inetpub\CertWebService\Update-CertificateData.ps1

SUPPORT:
- IT Systems Management
- Server: itscmgmt03.srv.meduniwien.ac.at

VERSION: v1.2.0
AUTHOR: Flecki (Tom) Garnreiter