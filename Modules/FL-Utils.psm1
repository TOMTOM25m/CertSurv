#Requires -version 5.1

Function Send-MailNotification {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [hashtable]$MailConfig,
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
        $tcpClient.Close()

        $allCerts = @($cert)
        
        # This is a simplified way to get more certs. A more robust solution might involve Invoke-Command
        try {
            $otherCerts = Invoke-Command -ComputerName $FQDN -ScriptBlock { Get-ChildItem -Path Cert:\\LocalMachine\\My } -ErrorAction SilentlyContinue
            if($otherCerts) {
                $allCerts += $otherCerts
            }
        } catch {
            Write-Log "Could not connect to '$FQDN' via remote PowerShell to find additional certificates. Error: $($_.Exception.Message)" -Level WARN
        }

        return $allCerts | Select-Object -Unique
    }
    catch {
        Write-Log "Could not retrieve certificate from '$FQDN' on port 443. Error: $($_.Exception.Message)" -Level ERROR
        return $null
    }
}


Export-ModuleMember -Function Send-MailNotification, Get-Certificates
