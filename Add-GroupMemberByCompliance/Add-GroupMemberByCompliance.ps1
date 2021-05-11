[cmdletbinding()]
param (
    [parameter(Mandatory = $true)]
    [string]$Tenant,

    [parameter(Mandatory = $true)]
    [string]$ClientId,

    [parameter(Mandatory = $true)]
    [securestring]$ClientSec,

    [parameter(Mandatory = $true)]
    [string]$SecGrpId,

    [parameter(Mandatory = $true)]
    [int32]$HourOffset
)
#region Config
[datetime]$date = (Get-Date).AddHours($HourOffset).ToUniversalTime()
[string]$dateFormatted = $date.ToString('o')
[string]$baseGraphUri = 'https://graph.microsoft.com/beta'
#endregion
#region Functions
function Invoke-GraphRequest {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $false)]
        [ValidateSet('Get','Post','Patch','Delete')]
        [string]$Method = 'Get',

        [parameter(Mandatory = $true)]
        [string]$Query,

        [parameter(Mandatory = $false)]
        [string]$Body
    )
    $params = @{
        Method      = $Method
        Uri         = $Query
        Headers     = $script:autHheader
        ContentType = 'Application/Json'
    }
    if ($Body) {
        $params.Body = $Body
    }
    try {
        $request = Invoke-RestMethod @params
        return $request
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}
#endregion
try {
    #region Authenticate
    $auth = Get-MsalToken -ClientId $ClientId -ClientSecret $ClientSec -TenantId $Tenant
    $script:autHheader = @{ 
        Authorization = $auth.CreateAuthorizationHeader() 
    }
    #endregion
    #region Get group & group members
    $query = '{0}/groups({1})' -f $baseGraphUri, $("'$SecGrpId'")
    $grpData = Invoke-GraphRequest -Query $query
    $query = '{0}/members' -f $query
    $grpMembers = Invoke-GraphRequest -Query $query
    #endregion
    #region Get devices based on enrolledDateTime
    $query = '{0}/deviceManagement/managedDevices?$filter=enrolledDateTime ge {1}' -f $baseGraphUri, $dateFormatted
    $deviceResults = Invoke-GraphRequest -Query $query
    #endregion
    #region Process results
    $deviceResults.value | Where-Object { $_.complianceState -eq 'compliant' } | ForEach-Object {
        $device = $_
        #region Grab the AAD object
        $query = '{0}/devices?$filter=deviceId eq {1}' -f $baseGraphUri, $("'$($device.azureADDeviceId)'")
        $aadObject = Invoke-GraphRequest -Query $query
        if ($aadObject.value[0].deviceId -notin $grpMembers.value.deviceId) {
            Write-Host "Adding device $($aadObject.value[0].displayName) to group $($grpData.displayName)"
            $query = '{0}/groups/{1}/members/$ref' -f $baseGraphUri, $SecGrpId
            $body = @{
                '@odata.id' = 'https://graph.microsoft.com/beta/directoryObjects/{0}' -f $aadObject.value[0].id
            } | ConvertTo-Json -Depth 20
            Invoke-GraphRequest -Method 'Post' -Query $query -Body $body
        }
        else {
            Write-Host "Device $($aadObject.value[0].displayName) already a member of group $($grpData.displayName)"
        }
        #endregion
    }
    #endregion
}
catch {
    Write-Warning $_.Exception.Message
}
