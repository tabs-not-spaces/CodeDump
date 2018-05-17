$requestBody = Get-Content $req -Raw | ConvertFrom-Json
$fp = $EXECUTION_CONTEXT_FUNCTIONDIRECTORY
$config = Get-Content "$fp/appConfig.json" -Raw | ConvertFrom-Json
$graphConnectorURI = $config.basicConfig.graphConnectorURI
$tenant = $requestBody.tenant
$ver = $config.basicConfig.graphVer
$query = "deviceManagement/$($requestBody.query)"
$graphURI = "$($graphConnectorURI)&tenant=$($tenant)&Ver=$($ver)&query=$($query)"
$objResult = Invoke-RestMethod -Method Get -Uri $graphURI

$objResult | ConvertTo-Json -Depth 20 | out-file -Encoding ascii -FilePath $outputBlob

if ($objResult) {
    $result = $true
}
else {
    $result = $false
}
$objReturn = [pscustomobject]@{
    Date = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    Result = $result
}
write-output $outputBlob
$objReturn | ConvertTo-Json | out-file -Encoding ascii -FilePath $res