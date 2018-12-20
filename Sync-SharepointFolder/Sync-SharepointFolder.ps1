#region Config
$AppName = "SharepointSync"
$client = "Contoso"
$logPath = "$env:ProgramData\$client\logs"
$logFile = "$logPath\$appName.log"
#endregion
#region Functions
function Sync-SharepointLocation {
    param (
        [guid]$siteId,
        [guid]$webId,
        [guid]$listId,
        [mailaddress]$userEmail,
        [string]$webUrl,
        [string]$webTitle,
        [string]$listTitle,
        [string]$syncPath
    )
    try {
        Add-Type -AssemblyName System.Web
        #Encode site, web, list, url & email
        [string]$siteId = [System.Web.HttpUtility]::UrlEncode($siteId)
        [string]$webId = [System.Web.HttpUtility]::UrlEncode($webId)
        [string]$listId = [System.Web.HttpUtility]::UrlEncode($listId)
        [string]$userEmail = [System.Web.HttpUtility]::UrlEncode($userEmail)
        [string]$webUrl = [System.Web.HttpUtility]::UrlEncode($webUrl)
        #build the URI
        $uri = New-Object System.UriBuilder
        $uri.Scheme = "odopen"
        $uri.Host = "sync"
        $uri.Query = "siteId=$siteId&webId=$webId&listId=$listId&userEmail=$userEmail&webUrl=$webUrl&listTitle=$listTitle&webTitle=$webTitle"
        #launch the process from URI
        Write-Host $uri.ToString()
        start-process -filepath $($uri.ToString())
    }
    catch {
        $errorMsg = $_.Exception.Message
    }
    if ($errorMsg) {
        Write-Warning "Sync failed."
        Write-Warning $errorMsg
    }
    else {
        Write-Host "Sync completed."
        while (!(Get-ChildItem -Path $syncPath -ErrorAction SilentlyContinue)) {
            Start-Sleep -Seconds 2
        }
        return $true
    }    
}
#endregion
#region Logging
if (!(Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path $logFile -Force
#endregion
#region Main Process
try {
    #region Sharepoint Sync
    [mailaddress]$userUpn = cmd /c "whoami/upn"
    $params = @{
        siteId    = "{ab867466-d662-4024-9d74-a7934bf3e87d}"
        webId     = "{bbaf78b9-80cc-481c-9262-b36c08a788e8}"
        listId    = "{5c7f5444-44ba-4b1f-a994-e110b3ec841f}"
        userEmail = $userUpn
        webUrl    = "https://contoso.sharepoint.com"
        webTitle  = "contoso"
        listTitle = "FolderTitle"
        syncPath  = "$env:HOMEPATH\$($userUpn.Host)\Contoso - Foldertitle"
    }
    Write-Host "SharePoint params:"
    $params | Format-Table
    if (!(Test-Path $($params.syncPath))) {
        Write-Host "Sharepoint folder not found locally, will now sync.." -ForegroundColor Yellow
        $sp = Sync-SharepointLocation @params
        if (!($sp)) {
            Throw "Sharepoint sync failed."
        }
    }
    else {
        Write-Host "Location already syncronized: $($oarams.syncPath)" -ForegroundColor Yellow
    }
    #endregion
    #region SharedTemplate Path
    $regKeys = @(
        [PSCustomObject]@{
            Path  = "HKCU:\software\Microsoft\Office\16.0\Common\General"
            Name  = "SharedTemplates"
            Type  = "ExpandString"
            value = "%systemdrive%%homepath%\$($userUpn.Host)\$($params.webTitle) - $($params.listTitle)"
        }
    )
    foreach ($key in $regKeys) {
        Write-Host "Setting SharedTemplates.." -ForegroundColor Green
        if (!(Test-Path $($key.Path))) {
            Write-Host "Registry path not found. Creating: $($key.Path)" -ForegroundColor Green
            New-Item -Path $($key.Path) -Force | Out-Null
            Write-Host "Creating item property:`nName: $($key.Name)`nType: $($key.Type)`nValue: $($key.Value)" -ForegroundColor Green
            New-ItemProperty -Path $($key.Path) -Name $($key.Name) -Value $($key.value) -PropertyType $($key.Type) -Force | Out-Null
        }
        else {
            Write-Host "Registry path found: $($key.Path)" -ForegroundColor Green
            Write-Host "Creating item property:`nName: $($key.Name)`nType: $($key.Type)`nValue: $($key.Value)" -ForegroundColor Green
            New-ItemProperty -Path $($key.Path) -Name $($key.Name) -Value $($key.value) -PropertyType $($key.Type) -Force | Out-Null
        }
    }
    #endregion
}
catch {
    $errorMsg = $_.Exception.Message
}
finally {
    if ($errorMsg) {
        Write-Warning $errorMsg
        Stop-Transcript
        Throw $errorMsg
    }
    else {
        Write-Host "Completed successfully.."
        Stop-Transcript
    }
}
#endregion