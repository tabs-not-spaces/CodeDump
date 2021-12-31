function Get-RemoteFileAndConfirmHashValidationLocally {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [uri]$FileUrl,

        [parameter(Mandatory = $true)]
        [System.IO.FileInfo]$OutputFolder
    )

    try {
        $fileDownload = Invoke-WebRequest -Method Get -Uri $FileUrl
        if ($fileDownload.StatusCode -ne 200) { throw [System.Net.WebException]::new('Failed to download content') }
        $fileDownload.Content | Out-File "$OutputFolder\$($FileUrl.Segments[-1])"
        $localHash = Get-ComputedMD5 -FilePath "$OutputFolder\$($FileUrl.Segments[-1])"
        if ($localHash -ne $fileDownload.Headers['Content-MD5']) {throw [System.Net.WebException]::new('hash mismatch.')}
    }
    catch [System.Net.WebException] {
        Write-Warning $_.Exception.Message
        Remove-Item -Path "$OutputFolder\$($FileUrl.Segments[-1])"
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}

function Get-ComputedMD5 {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [System.IO.FileInfo]$FilePath
    )
    try {
        $rawMD5 = (Get-FileHash -Path $FilePath -Algorithm MD5).Hash
        $hashBytes = [system.convert]::FromHexString($rawMD5)
        return [system.convert]::ToBase64String($hashBytes)
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}

$params = @{
    FileUrl      = 'https://icanhazcstorage.blob.core.windows.net/containerName/file.txt'
    OutputFolder = $env:TEMP
}
Get-RemoteFileAndConfirmHashValidationLocally @params