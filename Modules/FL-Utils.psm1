#Requires -version 5.1

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "FL-Utils - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

Function Send-MailNotification {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [object]$MailConfig,
        [Parameter(Mandatory = $true)]
        [string]$Subject,
        [Parameter(Mandatory = $true)]
        [string]$Body,
        [Parameter(Mandatory = $false)]
        [string[]]$Attachments
    )

    if (-not $MailConfig.Enabled) {
        Write-Log "Mail notifications are disabled in the config." -Level INFO
        return
    }

    $smtpParams = @{
        SmtpServer = $MailConfig.SmtpServer
        Port = $MailConfig.SmtpPort
        From = $MailConfig.SenderAddress
        To = if ($Global:Config.RunMode -eq 'PROD') { $MailConfig.ProdTo } else { $MailConfig.DevTo }
        Subject = "$($MailConfig.SubjectPrefix) $Subject"
        Body = $Body
        BodyAsHtml = $true
    }

    if ($MailConfig.UseSsl) {
        $smtpParams.UseSsl = $true
    }

    if ($Attachments) {
        $smtpParams.Attachments = $Attachments
    }
    
    if ($MailConfig.CredentialFilePath -and (Test-Path $MailConfig.CredentialFilePath)) {
        $credential = Import-CliXml -Path $MailConfig.CredentialFilePath
        $smtpParams.Credential = $credential
    }

    try {
        Send-MailMessage @smtpParams
        Write-Log "Email sent successfully to $($smtpParams.To)." -Level INFO
    }
    catch {
        Write-Log "Failed to send email. Error: $($_.Exception.Message)" -Level ERROR
    }
}

Function Get-Certificates {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$FQDN
    )

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($FQDN, 443)
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false)
        $sslStream.AuthenticateAsClient($FQDN)
        $cert = $sslStream.RemoteCertificate
        
        $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
        $chain.Build($cert)
        $allCerts = $chain.ChainElements | ForEach-Object { $_.Certificate }
        
        $tcpClient.Close()

        return $allCerts | Select-Object -Unique
    }
    catch {
        Write-Log "Could not retrieve certificate from '$FQDN' on port 443. Error: $($_.Exception.Message)" -Level ERROR
        return $null
    }
}


Export-ModuleMember -Function Send-MailNotification, Get-Certificates
