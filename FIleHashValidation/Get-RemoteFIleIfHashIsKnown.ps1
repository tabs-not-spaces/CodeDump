function Get-RemoteFileIfHashIsKnown {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [uri]$FileUrl,

        [parameter(Mandatory = $true)]
        [string]$MD5,

        [parameter(Mandatory = $true)]
        [System.IO.FileInfo]$OutputFolder
    )
    try {
        $hashCheck = Invoke-WebRequest -Method Head -Uri $FileUrl
        if ($hashCheck.StatusCode -ne 200) { throw [System.Net.WebException]::new('Failed to get header content.') }

        Write-Host "Remote Hash: " -ForegroundColor Cyan -NoNewline
        Write-Host "$($hashCheck.Headers['Content-MD5'])" -ForegroundColor Green
        Write-Host "Known Hash: " -ForegroundColor Cyan -NoNewline
        Write-Host "$($MD5)" -ForegroundColor $(($hashCheck.Headers['Content-MD5'] -ne $MD5) ? "red" : "green")

        if ($hashCheck.Headers['Content-MD5'] -ne $MD5) { throw [System.Net.WebException]::new("hash mismatch") }

        Invoke-RestMethod -Method Get -Uri $FileUrl -OutFile "$OutputFolder\$($FileUrl.Segments[-1])"
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}

###
$params = @{
    FileUrl      = 'https://icanhazcstorage.blob.core.windows.net/containerName/file.txt'
    MD5          = 'NXnI2n8eCtlGVudsiG5DJQ=='
    OutputFolder = $env:TEMP
}
Get-RemoteFileIfHashIsKnown @params