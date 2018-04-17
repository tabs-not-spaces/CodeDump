function Get-IntuneToken {
    param (
        $credential,
        $token
    )
    if (!(Get-Module -Name MSGraphIntuneManagement -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-Module -Name MSGraphIntuneManagement -Scope CurrentUser -Verbose -Force
    }
    $GMTDate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($(Get-Date), [System.TimeZoneInfo]::Local.Id, 'GMT Standard Time')
    if ($token -ne $null) {
        $tokenExpDate = ([System.DateTimeOffset]$token.ExpiresOn).DateTime
        if ($GMTDate -le $tokenExpDate) {
            write-host "Token is still fresh." -ForegroundColor Green
            return $token
        }
        #token is technically expired or never existed.
    }
    Write-Host "Token is stale or never existed." -ForegroundColor Red
    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    $token = Get-MSGraphAuthenticationToken -Credential $Credential -ClientId $ClientId
    return $token
}
if (!($cred)) {
    $cred = Get-Credential
}

$token = Get-IntuneToken -credential $cred -token $token

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