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