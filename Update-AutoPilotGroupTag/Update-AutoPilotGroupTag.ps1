function Get-AuthToken {
    <#
    .SYNOPSIS
    This function is used to authenticate with the Graph API REST interface
    .DESCRIPTION
    The function authenticate with the Graph API Interface with the tenant name
    .EXAMPLE
    Get-AuthToken
    Authenticates you with the Graph API interface
    .NOTES
    NAME: Get-AuthToken
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $user,

        [Parameter(Mandatory = $false)]
        [switch]$refreshSession
    )
    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $user
    $tenant = $userUpn.Host
    Write-Host "Checking for AzureAD module..."
    $aadModule = Get-Module -Name "AzureAD" -ListAvailable
    if ($aadModule -eq $null) {
        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $aadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    }
    if ($aadModule -eq $null) {
        write-host
        write-host "AzureAD Powershell module not installed..." -f Red
        write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
        write-host "Script can't continue..." -f Red
        write-host
        exit
    }
    # Getting path to ActiveDirectory Assemblies
    # If the module count is greater than 1 find the latest version
    if ($aadModule.count -gt 1) {
        $Latest_Version = ($aadModule | Select-Object version | Sort-Object)[-1]
        $aadModule = $aadModule | Where-Object { $_.version -eq $Latest_Version.version }
        # Checking if there are multiple versions of the same module found
        if ($aadModule.count -gt 1) {
            $aadModule = $aadModule | Select-Object -Unique
        }
        $adal = Join-Path $aadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $aadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }
    else {
        $adal = Join-Path $aadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $aadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }
    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$Tenant"
    try {
        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
        # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
        # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession
        if ($refreshSession) {
            $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "RefreshSession"
            
        }
        else {
            $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
        }
        $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $clientId, $redirectUri, $platformParameters, $userId).Result
        # If the accesstoken is valid then create the authentication header
        if ($authResult.AccessToken) {
            # Creating header for Authorization token
            $authHeader = @{
                'Content-Type'  = 'application/json'
                'Authorization' = "Bearer " + $authResult.AccessToken
                'ExpiresOn'     = $authResult.ExpiresOn
            }
            return $authHeader
        }
        else {
            Write-Host
            Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
            Write-Host
            break
        }
    }
    catch {
        write-host $_.Exception.Message -f Red
        write-host $_.Exception.ItemName -f Red
        write-host
        break
    }
}
function Update-AutoPilotGroupTag {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [string[]]$deviceSerial,
        
        [parameter(Mandatory = $false)]
        [string]$groupTag,
        
        [parameter(Mandatory = $false)]
        [switch]$sync
    )
    try {
        if (!($script:authToken)) {
            $script:authToken = Get-AuthToken -user $upn
        }
        $baseUri = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities'
        $apDevices = foreach ($sn in $deviceSerial) {
            #make sure the device identity exists
            $deviceId = (Invoke-RestMethod -Method Get -Uri "$baseUri`?`$filter=contains(serialNumber,'$sn')" -Headers $script:authToken).value
            if ($deviceId) {
                Write-Host "Found device with id: $deviceSerial"
                $deviceId
                $body = @{
                    groupTag = $(if ($groupTag) { $groupTag } else { '' })
                }
                $update = Invoke-WebRequest -Method Post -Uri "$baseUri/$($deviceId.id)/updateDeviceProperties" -Body ($body | ConvertTo-Json -Compress) -Headers $script:authToken -UseBasicParsing
                if ($update.StatusCode -eq 200) {
                   Write-Host "Updated device: $deviceSerial with grouptag: $groupTag"
                }
                else {
                    throw "Web requested failed with status code: $update.statusCode"
                }
            }
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
    }
    finally {
        if ($errorMsg) {
            Write-Warning $errorMsg
        }
        else {
            if ($sync) {
                Write-Host "Autopilot device sync requested.."
                Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotSettings/sync" -Headers $script:authToken
            }
        }
    }
}
$upn = 'ben@powers-hell.com'
$script:authToken = Get-AuthToken -user $upn
$serials = @(
    'Serial1',
    'Serial2',
    'Serial3'
)
Update-AutoPilotGroupTag -deviceSerial $serials -groupTag "EXCLUDE" -sync