using namespace System.Net
# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)
$result = [System.Collections.ArrayList]::new()
$expectedComplianceValue = "noncompliant"
<# 
Make sure the following application settings // 
variables are configured before running
| Variable Name     | Variable Value                                            |
|---                |---                                                        |
| TENANT_ID         | **Your tenant ID \ AAD domain name**                      |
| APPLICATION_ID    | **Your AAD application ID**                               |
| CLIENT_SECRET     | **Your AAD application client secret**                    |
| GROUP_ID          | **The object id of the security group you want to manage**| 
#>
#region functions
function Get-AuthHeader {
    param (
        [Parameter(mandatory = $true)]
        [string]$TenantId,
        [Parameter(mandatory = $true)]
        [string]$ClientId,
        [Parameter(mandatory = $true)]
        [string]$ClientSecret,
        [Parameter(mandatory = $true)]
        [string]$ResourceUrl
    )
    $body = @{
        resource      = $ResourceUrl
        client_id     = $ClientId
        client_secret = $ClientSecret
        grant_type    = "client_credentials"
        scope         = "openid"
    }
    try {
        $response = Invoke-RestMethod -Method post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/token" -Body $body -ErrorAction Stop
        $headers = @{ "Authorization" = "Bearer $($response.access_token)" }
        return $headers
    }
    catch {
        Write-Error $_.Exception
    }
}
function Invoke-GraphCall {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $false)]
        [ValidateSet('Get', 'Post', 'Delete')]
        [string]$Method = 'Get',

        [parameter(Mandatory = $false)]
        [hashtable]$Headers = $script:authHeader,

        [parameter(Mandatory = $true)]
        [string]$Uri,

        [parameter(Mandatory = $false)]
        [string]$ContentType = 'Application/Json',

        [parameter(Mandatory = $false)]
        [hashtable]$Body
    )
    try {
        $params = @{
            Method      = $Method
            Headers     = $Headers
            Uri         = $Uri
            ContentType = $ContentType
        }
        if ($Body) {
            $params.Body = $Body | ConvertTo-Json -Depth 20
        }
        $query = Invoke-RestMethod @params
        return $query
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}
function Format-Result {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$DeviceID,

        [parameter(Mandatory = $true)]
        [bool]$IsCompliant,

        [parameter(Mandatory = $true)]
        [bool]$IsMember,

        [parameter(Mandatory = $true)]
        [ValidateSet('Added', 'Removed', 'NoActionTaken')]
        [string]$Action
    )
    $result = [PSCustomObject]@{
        DeviceID    = $DeviceID
        IsCompliant = $IsCompliant
        IsMember    = $IsMember
        Action      = $Action
    }
    return $result
}
#endregion
#region authentication
$params = @{
    TenantId     = $env:TENANT_ID
    ClientId     = $env:CLIENT_ID
    ClientSecret = $env:CLIENT_SECRET
    ResourceUrl  = "https://graph.microsoft.com"
}
$script:authHeader = Get-AuthHeader @params
#endregion
#region get devices & group members
$graphUri = 'https://graph.microsoft.com/Beta/deviceManagement/managedDevices'
$query = Invoke-GraphCall -Uri $graphUri

$graphUri = "https://graph.microsoft.com/beta/groups/$env:GROUP_ID/members"
$groupMembers = Invoke-GraphCall -Uri $graphUri
#endregion
#region check each device.
foreach ($device in $query.value) {
    #region get aad object from intune object
    $graphUri = "https://graph.microsoft.com/beta/devices?`$filter=deviceId eq '$($device.azureADDeviceId)'"
    $AADDevice = (Invoke-GraphCall -Uri $graphUri).value
    #endregion
    if ($device.complianceState -eq $expectedComplianceValue) {
        if ($groupMembers.value.deviceId -notcontains $AADDevice.deviceId) {
            #region Device is compliant and not in the group
            $graphUri = "https://graph.microsoft.com/v1.0/groups/$env:GROUP_ID/members/`$ref"
            $body = @{"@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($AADDevice.id)" }
            Invoke-GraphCall -Uri $graphUri -Method Post -Body $body
            $result.Add($(Format-Result -DeviceID $device.id -IsCompliant $true -IsMember $true -Action Added)) | Out-Null
            #endregion
        }
        else {
            #region device is compliant and already a member
            $result.Add($(Format-Result -DeviceID $device.id -IsCompliant $true -IsMember $true -Action NoActionTaken)) | Out-Null
            #endregion
        }
    }
    else {
        if ($groupMembers.value.deviceId -contains $AADDevice.deviceId) {
            #region device not compliant and exists in group
            $graphUri = "https://graph.microsoft.com/v1.0/groups/$env:GROUP_ID/members/$($AADDevice.id)/`$ref"
            Invoke-GraphCall -Uri $graphUri -Method Delete
            $result.Add($(Format-Result -DeviceID $device.id -IsCompliant $false -IsMember $false -Action Removed)) | Out-Null
            #endregion
        }
        else {
            #region device not compliant and is not a member
            $result.Add($(Format-Result -DeviceID $device.id -IsCompliant $false -IsMember $false -Action NoActionTaken))
            #endregion
        }
    }
}
#endregion
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $result | ConvertTo-Json -Depth 20
    })