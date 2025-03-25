using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Get the tenant Id from the URL route.
$tenantId = $TriggerMetadata.tenantId

# using the managed identity token, get an auth token for the tenant
if ($env:MSI_SECRET) {
    # get a token for the MSI
    $msiToken = Get-AzAccessToken -ResourceUrl "api://AzureADTokenExchange" -AsSecureString
    
    # using the MSI token, connect to remote tenant.
    Connect-azAccount -Tenant $tenantId -ApplicationId $env:CLIENT_ID -FederatedToken $($msiToken.Token | ConvertFrom-SecureString)
    
    # get an access token for graph
    $token = Get-AzAccessToken -ResourceTypeName MSGraph -AsSecureString
}

#region main process
try {
    $devicesUri = 'https://graph.microsoft.com/beta/devices'
    $headers = @{ Authorization = "Bearer $($token | ConvertFrom-SecureString)" }
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

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = $statusCode
        Body       = $body
    })
#endregion
