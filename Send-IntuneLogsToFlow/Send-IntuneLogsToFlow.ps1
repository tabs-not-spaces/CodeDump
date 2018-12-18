#region Function
function Send-IntuneLogsToFlow {
    param (
        $inputObject,
        $metaData
    )
    $Uri = "https://azure.flow.url.com";
    try {
        $jsonMetaData = $metaData | ConvertTo-Json -Compress
        if (Test-Path $inputObject) {
            $fileBytes = [System.IO.File]::ReadAllBytes("$inputObject")
            $fileEnc = [System.Text.Encoding]::GetEncoding('UTF-8').GetString($fileBytes)
        }
        else {
            throw "Error accessing input object: $inputObject"
        }
        $boundary = [System.Guid]::NewGuid().ToString()
        $lf = "`r`n"
        $bodyLines = (
            "--$boundary",
            "Content-Disposition: form-data; name=`"$(split-path $inputObject -leaf)`"; filename=`"$(split-path $inputObject -leaf)`"",
            "Content-Type: application/octet-stream$lf",
            $fileEnc,
            "--$boundary",
            "Content-Disposition: form-data; name=`"MetaData`"",
            "Content-Type: application/json$lf",
            $jsonMetaData,
            "--$boundary--$lf"
        ) -join $lf
        $req = Invoke-WebRequest -Uri $uri -Method Post -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines
        return $req
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}
#endregion
#region Process block
$logFile = "Path\To\Logfile.log"
$metaData = [PSCustomObject]@{
        hostName = $env:COMPUTERNAME
        clientName = "Contoso"
        appName = "ApplicationName"
        logFileName = "$env:COMPUTERNAME`_$(Split-Path $logFile -leaf)"
}
#endregion