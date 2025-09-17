<#
.SYNOPSIS
    Liest die SSL-Zertifikatsdetails von einem Remote-Server aus.
.PARAMETER TargetFqdn
    Der FQDN des Servers, dessen Zertifikat geprüft werden soll.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$TargetFqdn
)

$port = 443
Write-Host "Prüfe Zertifikat von '$TargetFqdn' auf Port '$port'..."

try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect($TargetFqdn, $port)
    $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true })
    $sslStream.AuthenticateAsClient($TargetFqdn)
    $serverCertificate = $sslStream.RemoteCertificate

    if ($serverCertificate) {
        $heute = Get-Date
        $ablaufdatum = $serverCertificate.NotAfter
        $restlicheTage = ($ablaufdatum - $heute).Days
        
        [PSCustomObject]@{
            Server           = $TargetFqdn
            AusgestelltAn    = $serverCertificate.Subject
            GueltigAb        = $serverCertificate.NotBefore.ToString("yyyy.MM.dd")
            LaeuftAbAm       = $ablaufdatum.ToString("yyyy.MM.dd")
            Restgueltigkeit  = "$restlicheTage Tage"
        } | Format-List
    }
}
catch {
    Write-Error "Fehler bei der Verbindung mit '$TargetFqdn': $($_.Exception.Message)"
}
finally {
    if ($sslStream) { $sslStream.Close() }
    if ($tcpClient) { $tcpClient.Close() }
}