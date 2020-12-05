function Decrypt($base64string) {
    [System.Reflection.Assembly]::LoadWithPartialName("System.Security") | Out-Null

    $content = [Convert]::FromBase64String($base64string)
    $envelopedCms = New-Object Security.Cryptography.Pkcs.EnvelopedCms
    $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $envelopedCms.Decode($content)
    $envelopedCms.Decrypt($certCollection)

    $utf8content = [text.encoding]::UTF8.getstring($envelopedCms.ContentInfo.Content)

    return $utf8content
}

$agentLogPath = Join-Path $env:ProgramData "Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
$stringToSearch = "<![LOG[Get content info from service,ret = {"

$res = Get-Content $agentLogPath | ForEach-Object {
    if ($nextLine) {
        $reply = "{$($_.ToString().TrimStart())}" | ConvertFrom-Json
        $responsePayload = ($reply.ResponsePayload | ConvertFrom-Json)
        $contentInfo = ($responsePayload.ContentInfo | ConvertFrom-Json)
        $decryptInfo = Decrypt(([xml]$responsePayload.DecryptInfo).EncryptedMessage.EncryptedContent) | ConvertFrom-Json
        [PSCustomObject]@{
            URL = $($contentInfo.UploadLocation)
            Key = $($decryptInfo.EncryptionKey)
            IV  = $($decryptInfo.IV)
        }
        # optional call:
        #. C:\bin\IntuneWinAppUtilDecoder.exe `"$($contentInfo.UploadLocation)`" /key:$($decryptInfo.EncryptionKey) /iv:$($decryptInfo.IV)

        $nextLine = $false
    }
    if ($_.ToString().StartsWith($stringToSearch) -eq $true) {
        $nextLine = $true
    }
}
return $res