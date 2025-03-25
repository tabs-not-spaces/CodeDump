using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Get tenant id from url
$tenantId = $TriggerMetadata.tenantId

#region auth
if ($env:MSI_SECRET) {
    # request msi access token
    # most guides reference $env:IDENTITY_ENDPOINT and $env:IDENTITY_HEADER
    # but for clarity, the values in MSI_ENDPOINT and MSI_SECRET are exactly the same.
    # MSI_ENDPOINT is a uri pointing to an internal api endpoint on the app service
    # which is usually something like http://localhost:{PORT_NUMBER}/MSI/token/
    # MSI_SECRET is a key that is rotated periodically and is used to protect against SSRF attacks
    $resourceUri = 'api://AzureADTokenExchange'
    $tokenUri = '{0}?resource={1}&api-version=2019-08-01' -f $env:MSI_ENDPOINT, $resourceURI
    $tokenHeader = @{ "X-IDENTITY-HEADER" = $env:MSI_SECRET }
    $msiTokenReq = Invoke-RestMethod -Method Get -Headers $tokenHeader -Uri $tokenUri
    Write-Host $msiTokenReq
    $msiToken = $msiTokenReq.access_token

    # swap msi token for graph access token
    $clientTokenReqBody = @{
        client_id             = $env:CLIENT_ID
        scope                 = 'https://graph.microsoft.com/.default'
        grant_type            = "client_credentials"
        client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
        client_assertion      = $msiToken
    }
    Write-Host $clientTokenReqBody
    $azueAuthURI = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $clientAccessTokenReq = Invoke-RestMethod -Method Post -Uri $azueAuthURI -Form $clientTokenReqBody
    Write-Host $clientAccessTokenReq
    $token = $clientAccessTokenReq.access_token
}
#endregion

#region main process
try {
    $devicesUri = 'https://graph.microsoft.com/beta/devices'
    $headers = @{ Authorization = "Bearer $token" }
    $graphReq = Invoke-RestMethod -Method Get -uri $devicesUri -Headers $headers -ContentType 'application/json'
    Write-Output "Devices Found: $($graphReq.value.count)"
    $resp = $graphReq.value | ConvertTo-Json -Depth 100
    $statusCode = [HttpStatusCode]::OK
    $body = $resp
}
catch {
    Write-Output $_.Exception.Message
    $statusCode = [HttpStatusCode]::BadRequest
    $body = $_.Exception.Message
}
#endregion

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $statusCode ?? [HttpStatusCode]::OK
    Body = $body
})
