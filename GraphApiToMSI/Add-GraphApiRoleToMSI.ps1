#region Functions
function Add-GraphApiRoleToMSI {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ApplicationName,

        [parameter(Mandatory = $true)]
        [string[]]$GraphApiRole,

        [parameter(mandatory = $true)]
        [string]$Token
    )

    $baseUri = 'https://graph.microsoft.com/v1.0/servicePrincipals'
    $graphAppId = '00000003-0000-0000-c000-000000000000'
    $spSearchFiler = '"displayName:{0}" OR "appId:{1}"' -f $ApplicationName, $graphAppId

    try {
        $msiParams = @{
            Method  = 'Get'
            Uri     = '{0}?$search={1}' -f $baseUri, $spSearchFiler
            Headers = @{Authorization = "Bearer $Token"; ConsistencyLevel = "eventual" }
        }
        $spList = (Invoke-RestMethod @msiParams).Value
        $msiId = ($spList | Where-Object { $_.displayName -eq $applicationName }).Id
        $GraphId = ($spList | Where-Object { $_.appId -eq $graphAppId }).Id
        $msiItem = Invoke-RestMethod @msiParams -Uri "$($baseUri)/$($msiId)?`$expand=appRoleAssignments"

        $graphRoles = (Invoke-RestMethod @msiParams -Uri "$baseUri/$($GraphId)/appRoles").Value | 
        Select-Object AllowedMemberTypes, id, value
        foreach ($role in $GraphApiRole) {
            $roleItem = $graphRoles | Where-Object { $_.value -eq $role }
            if ($roleItem.id -notIn $msiItem.appRoleAssignments.appRoleId) {
                Write-Host "Adding role ($($roleItem.value)) to identity: $($applicationName).."
                $params = @{
                    ManagedIdentityId = $msiId
                    GraphId           = $GraphId
                    ApiRoleId         = $roleItem.id
                    Token             = $Token
                }
                Send-RoleToMSI @params
            }
            else {
                Write-Host "role ($($roleItem.value)) already found in $($applicationName).."
            }
        }
        
    }
    catch {
        Write-Warning $_.Exception.Message
    }

}
function Send-RoleToMSI {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ManagedIdentityId,

        [parameter(Mandatory = $true)]
        [string]$GraphId,

        [parameter(Mandatory = $true)]
        [string]$ApiRoleId,

        [parameter(Mandatory = $true)]
        [string]$Token
    )
    try {
        $baseUri = 'https://graph.microsoft.com/v1.0/servicePrincipals'
        $body = @{
            "principalId" = $ManagedIdentityId
            "resourceId"  = $GraphId
            "appRoleId"   = $ApiRoleId
        } | ConvertTo-Json
        $restParams = @{
            Method      = "Post"
            Uri         = "$baseUri/$($GraphId)/appRoleAssignedTo"
            Body        = $body
            Headers     = @{Authorization = "Bearer $Token" }
            ContentType = 'Application/Json'
        }
        $roleRequest = Invoke-RestMethod @restParams
        return $roleRequest
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}
#endregion
Connect-AzAccount -Tenant "powers-hell.com"
$token = Get-AzAccessToken
$roles = @(
    "DeviceManagementApps.ReadWrite.All", 
    "DeviceManagementConfiguration.Read.All", 
    "DeviceManagementManagedDevices.Read.All", 
    "DeviceManagementRBAC.Read.All", 
    "DeviceManagementServiceConfig.ReadWrite.All", 
    "GroupMember.Read.All"
)
Add-GraphApiRoleToMSI -ApplicationName "FunctionAppExample" -GraphApiRole $roles -Token $token.Token
