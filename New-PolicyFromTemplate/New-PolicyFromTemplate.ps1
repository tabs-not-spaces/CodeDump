[cmdletbinding()]
param (
    [string]$tenantId
)
$script:tick = [char]0x221a
$baseUrl = "https://graph.microsoft.com/beta/deviceManagement"
try {
#region auth
$auth = Get-MsalToken -ClientId 'd1ddf0e4-d672-4dae-b554-9d5bdfd93547' -Interactive -TenantId $tenantId -DeviceCode
$authHeader = @{Authorization = "Bearer $($auth.AccessToken)"}
#endregion auth
#region get BitLocker template from graph
Write-Host "Grabbing BitLocker template data.." -NoNewline -ForegroundColor Yellow
$bitlocker = Invoke-RestMethod -Method Get -Uri "$baseUrl/templates?`$filter=startswith(displayName,'BitLocker')" -Headers $authHeader
Write-Host "$script:tick ($($bitlocker.value.id))" -ForegroundColor Green
#endregion get BitLocker template from graph
#region new template instance
Write-Host "Creating new template instance.." -NoNewline -ForegroundColor Yellow
$request = @{
    displayName = "Win10_BitLocker_Example"
    description = "Win10 BitLocker Example for Powers-Hell.com"
    templateId = $bitlocker.value.id
} | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "$baseUrl/templates/$($bitlocker.value.id)/createInstance" -Headers $authHeader -ContentType 'Application/Json' -body $request
Write-Host "$script:tick ($($instance.id))" -ForegroundColor Green
#endregion new template instance
#region update instance settings
Write-Host "Updating instance with intent settings.." -NoNewline -ForegroundColor Yellow
$definitionBase = 'deviceConfiguration--windows10EndpointProtectionConfiguration_'
$request = @(
    @{
        "settings" = @(
            @{
                "@odata.type"  = "#microsoft.graph.deviceManagementBooleanSettingInstance"
                "definitionId" = "$($definitionBase)bitLockerEncryptDevice"
                "value"        = $true
            }
            @{
                "@odata.type"  = "#microsoft.graph.deviceManagementBooleanSettingInstance"
                "definitionId" = "$($definitionBase)bitLockerEnableStorageCardEncryptionOnMobile"
                "value"        = $true
            }
            @{
                "@odata.type"  = "#microsoft.graph.deviceManagementBooleanSettingInstance"
                "definitionId" = "$($definitionBase)bitLockerDisableWarningForOtherDiskEncryption"
                "value"        = $true
            }
            @{
                "@odata.type"  = "#microsoft.graph.deviceManagementBooleanSettingInstance"
                "definitionId" = "$($definitionBase)bitLockerAllowStandardUserEncryption"
                "value"        = $true
            }
            @{
                "@odata.type"  = "#microsoft.graph.deviceManagementStringSettingInstance"
                "definitionId" = "$($definitionBase)bitLockerRecoveryPasswordRotation"
                "value"        = "enabledForAzureAd"
            }
        )
    }
) | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$baseUrl/intents/$($instance.id)/updateSettings" -ContentType 'Application/JSON' -Headers $authHeader -Body $request | Out-Null
Write-Host $script:tick -ForegroundColor Green
#endregion update instance settings
}
catch {
    Write-Warning $_
}