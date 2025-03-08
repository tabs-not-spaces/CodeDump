if (!(Get-Module -Name MSAL.PS -ListAvailable -ErrorAction SilentlyContinue)) {
    Install-Module -Name MSAL.PS -Scope CurrentUser -Force -AcceptLicense
}
$clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547" # well known Intune application Id
$auth = Get-MsalToken -ClientId $clientId -deviceCode #deviceCode requires interaction and solves MFA challenges
$token = @{ Authorization = $auth.CreateAuthorizationHeader() }

$graph = "https://graph.microsoft.com"
$deviceProps = (invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=DisplayName eq '$env:ComputerName'" -Headers $token).value
$owner = (Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/v1.0/devices/$($deviceProps.id)/registeredOwners" -Headers $token).value
$sidecarScripts = (Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts" -Headers $token).value
$deviceScriptStatus = @()
foreach ($script in $sidecarScripts) {
    $tmpItem = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Policies\$($owner.id)\$($script.id)" -ErrorAction SilentlyContinue
    if ($tmpItem) {
        $tmpObj = [PSCustomObject]@{
            displayName = $script.displayName
            fileName    = $script.fileName
            Result      = $tmpItem.Result
            id          = $script.id
            psPath      = $tmpItem.PSPath
        }
        $deviceScriptStatus += $tmpObj
    }
}
$intuneScriptToRerun = $deviceScriptStatus | Select-Object displayName,fileName,Result,id | Out-GridView -Title "Intune Script Configuration" -PassThru

foreach ($item in $intuneScriptToRerun){
    $itemPath = ($deviceScriptStatus | Where-Object {$_.displayName -eq $item.displayName}).psPath
    Remove-Item $itemPath -Force
}
Get-Service -Name IntuneManagementExtension | Restart-Service
