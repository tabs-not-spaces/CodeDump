[cmdletbinding()]
param (
    [Parameter(Mandatory = $true)]
    [guid]$clientId,

    [Parameter(Mandatory = $true)]
    [string]$tenantId
)
#region Get the auth token and build the auth header
$auth = Get-MsalToken -ClientId $clientId -TenantId $tenantId -Interactive
$authHeader = @{Authorization = $auth.CreateAuthorizationHeader()}
#endregion

#region Build the request and return the ID and Name of all win32 apps
$baseGraphUri = "https://graph.microsoft.com/beta/deviceappmanagement/mobileapps"
$results = (Invoke-RestMethod -Method Get -Uri "$baseGraphUri`?`$filter=isOf('microsoft.graph.win32LobApp')" -Headers $authHeader -ContentType 'Application/Json').value
$results | Select-Object id, displayName
#endregion