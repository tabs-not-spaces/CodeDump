[cmdletbinding()]
param (
    $AgentLogPath = $(Join-Path $env:ProgramData "Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"),
    $DestinationPath = "C:\bin"
)
#region config
#$agentLogPath = Join-Path $env:ProgramData "Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
$stringToSearch = "<![LOG[Get content info from service,ret = {"
$path = $DestinationPath
#endregion
#region functions
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
function Expand-IntuneWin {
    [cmdletbinding()]
    param (
        $inputFile,
        $outputFolder,
        $encKey,
        $encIV
    )
    try {
        #region generate crypto and decrypt objects
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = [system.convert]::FromBase64String($encKey)
        $aes.IV = [system.convert]::FromBase64String($encIv)
        $decryptor = $aes.CreateDecryptor($aes.Key, $aes.IV)
        #endregion
        #region decrypt the target file
        $file = Get-Item $inputFile
        $destinationFile = "$(Split-Path -Path $file.FullName -Parent)\$($file.name -replace '.bin').zip"
        $fileStreamReader = New-Object System.IO.FileStream($File.FullName, [System.IO.FileMode]::Open)
        $fileStreamWriter = New-Object System.IO.FileStream($destinationFile, [System.IO.FileMode]::Create)
        $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($fileStreamWriter, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
        $fileStreamReader.CopyTo($cryptoStream)
        Expand-7Zip -ArchiveFileName $destinationFile -TargetPath "$outputFolder\$($file.name -replace '.bin')"
        #endregion
    }
    catch {
        Write-Warning $_.Exception.Message
    }
    finally {
        #region dispose of all open objects
        Write-Verbose "Cleaning everything up.."
        $cryptoStream.FlushFinalBlock()
        $cryptoStream.Dispose()
        $fileStreamReader.Dispose()
        $fileStreamWriter.Dispose()
        $aes.Dispose()
        #endregion
    }
}

function Invoke-FileDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [string]$Path
    )

    function convertFileSize {
        param(
            $bytes
        )

        if ($bytes -lt 1MB) {
            return "$([Math]::Round($bytes / 1KB, 2)) KB"
        }
        elseif ($bytes -lt 1GB) {
            return "$([Math]::Round($bytes / 1MB, 2)) MB"
        }
        elseif ($bytes -lt 1TB) {
            return "$([Math]::Round($bytes / 1GB, 2)) GB"
        }
    }

    Write-Verbose "URL set to ""$($Url)""."

    if (!($Path)) {
        Write-Verbose "Path parameter not set, parsing Url for filename."
        $URLParser = $Url | Select-String -Pattern ".*\:\/\/.*\/(.*\.{1}\w*).*" -List

        $Path = "./$($URLParser.Matches.Groups[1].Value)"
    }

    Write-Verbose "Path set to ""$($Path)""."

    #Load in the WebClient object.
    Write-Verbose "Loading in WebClient object."
    try {
        $Downloader = New-Object -TypeName System.Net.WebClient
    }
    catch [Exception] {
        Write-Error $_ -ErrorAction Stop
    }

    #Creating a temporary file.
    $TmpFile = New-TemporaryFile
    Write-Verbose "TmpFile set to ""$($TmpFile)""."

    try {

        #Start the download by using WebClient.DownloadFileTaskAsync, since this lets us show progress on screen.
        Write-Verbose "Starting download..."
        $FileDownload = $Downloader.DownloadFileTaskAsync($Url, $TmpFile)

        #Register the event from WebClient.DownloadProgressChanged to monitor download progress.
        Write-Verbose "Registering the ""DownloadProgressChanged"" event handle from the WebClient object."
        Register-ObjectEvent -InputObject $Downloader -EventName DownloadProgressChanged -SourceIdentifier WebClient.DownloadProgressChanged | Out-Null

        #Wait two seconds for the registration to fully complete
        Start-Sleep -Seconds 3

        if ($FileDownload.IsFaulted) {
            Write-Verbose "An error occurred. Generating error."
            Write-Error $FileDownload.GetAwaiter().GetResult()
            break
        }

        #While the download is showing as not complete, we keep looping to get event data.
        while (!($FileDownload.IsCompleted)) {

            if ($FileDownload.IsFaulted) {
                Write-Verbose "An error occurred. Generating error."
                Write-Error $FileDownload.GetAwaiter().GetResult()
                break
            }

            $EventData = Get-Event -SourceIdentifier WebClient.DownloadProgressChanged | Select-Object -ExpandProperty "SourceEventArgs" -Last 1

            $ReceivedData = ($EventData | Select-Object -ExpandProperty "BytesReceived")
            $TotalToReceive = ($EventData | Select-Object -ExpandProperty "TotalBytesToReceive")
            $TotalPercent = $EventData | Select-Object -ExpandProperty "ProgressPercentage"

            Write-Progress -Activity "Downloading File" -Status "Percent Complete: $($TotalPercent)%" -CurrentOperation "Downloaded $(convertFileSize -bytes $ReceivedData) / $(convertFileSize -bytes $TotalToReceive)" -PercentComplete $TotalPercent
        }
    }
    catch [Exception] {
        $ErrorDetails = $_

        switch ($ErrorDetails.FullyQualifiedErrorId) {
            "ArgumentNullException" {
                Write-Error -Exception "ArgumentNullException" -ErrorId "ArgumentNullException" -Message "Either the Url or Path is null." -Category InvalidArgument -TargetObject $Downloader -ErrorAction Stop
            }
            "WebException" {
                Write-Error -Exception "WebException" -ErrorId "WebException" -Message "An error occurred while downloading the resource." -Category OperationTimeout -TargetObject $Downloader -ErrorAction Stop
            }
            "InvalidOperationException" {
                Write-Error -Exception "InvalidOperationException" -ErrorId "InvalidOperationException" -Message "The file at ""$($Path)"" is in use by another process." -Category WriteError -TargetObject $Path -ErrorAction Stop
            }
            Default {
                Write-Error $ErrorDetails -ErrorAction Stop
            }
        }
    }
    finally {
        #Cleanup tasks
        Write-Verbose "Cleaning up..."
        Write-Progress -Activity "Downloading File" -Completed
        Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged

        if (($FileDownload.IsCompleted) -and !($FileDownload.IsFaulted)) {
            #If the download was finished without termination, then we move the file.
            Write-Verbose "Moved the downloaded file to ""$($Path)""."
            Move-Item -Path $TmpFile -Destination $Path -Force
        }
        else {
            #If the download was terminated, we remove the file.
            Write-Verbose "Cancelling the download and removing the tmp file."
            $Downloader.CancelAsync()
            Remove-Item -Path $TmpFile -Force
        }

        $Downloader.Dispose()
    }
}
#endreghion
#region main process
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
foreach ($r in $res) {
    Write-Host "downloading $(Split-Path $r.url -Leaf) .."
    $localPath = "$path\$(Split-Path $r.url -Leaf)"
    Invoke-FileDownload -Url $r.url -Path  $localPath
    Write-Host "Expanding $(Split-Path $r.url -Leaf) .."
    Expand-IntuneWin -inputFile $localPath -outputFolder C:\bin -encKey $r.Key -encIV $r.iv
}
#endregion
