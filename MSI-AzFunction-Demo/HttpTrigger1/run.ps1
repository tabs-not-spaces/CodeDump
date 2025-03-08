using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

#region auth
if ($env:MSI_SECRET) { $token = (Get-AzAccessToken -resourceUrl "https://graph.microsoft.com/").Token }
else {
    Disable-AzContextAutosave -Scope Process | Out-Null
    $cred = New-Object System.Management.Automation.PSCredential $env:appId, ($env:secret | ConvertTo-SecureString -AsPlainText -Force)
    Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $env:tenantId
    $token = (Get-AzAccessToken -resourceUrl "https://graph.microsoft.com/").Token
}
$authHeader = @{ Authorization = "Bearer $token" }
#endregion
#region main process
try {
    $restParams = @{
        Method      = 'Get'
        Uri         = 'https://graph.microsoft.com/beta/devices'
        Headers     = $authHeader
        ContentType = 'application/json'
    }
    $restCall = Invoke-RestMethod @restParams
    Write-Output "Devices Found: $($restCall.value.count)"
    $resp = $restCall.value | ConvertTo-Json -Depth 100
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