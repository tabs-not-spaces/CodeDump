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
        [string]$siteId = [System.Web.HttpUtility]::UrlEncode($siteId)
        [string]$webId = [System.Web.HttpUtility]::UrlEncode($webId)
        [string]$listId = [System.Web.HttpUtility]::UrlEncode($listId)
        [string]$userEmail = [System.Web.HttpUtility]::UrlEncode($userEmail)
        [string]$webUrl = [System.Web.HttpUtility]::UrlEncode($webUrl)

        $uri = New-Object System.UriBuilder
        $uri.Scheme = "odopen"
        $uri.Host = "sync"
        $uri.Query = "siteId=$siteId&webId=$webId&listId=$listId&userEmail=$userEmail&webUrl=$webUrl&listTitle=$listTitle&webTitle=$webTitle"

        Write-Host "Starting sync: $webTitle - $listTitle"
        Write-Host $uri.ToString()
        Start-Process -FilePath $($uri.ToString())
    }
    catch {
        Write-Warning "Sync failed for $webTitle - $listTitle"
        Write-Warning $_.Exception.Message
        return $false
    }

    # Wait for sync folder with timeout
    $timeout = 120
    $elapsed = 0
    while (!(Get-ChildItem -Path $syncPath -ErrorAction SilentlyContinue)) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        if ($elapsed -ge $timeout) {
            Write-Warning "Timed out waiting for: $syncPath"
            return $false
        }
    }
    Write-Host "Sync completed: $syncPath" -ForegroundColor Green
    return $true
}

function Wait-ForOneDrive {
    param ([int]$TimeoutSeconds = 120)
    $elapsed = 0
    while (!(Get-Process OneDrive -ErrorAction SilentlyContinue)) {
        Start-Sleep -Seconds 5
        $elapsed += 5
        if ($elapsed -ge $TimeoutSeconds) {
            Throw "OneDrive not running after ${TimeoutSeconds}s"
        }
    }
    # Allow time for full initialization
    Start-Sleep -Seconds 10
}
#endregion

#region Configuration
$libraries = @(
    @{
        siteId    = "{00000000-0000-0000-0000-000000000000}"
        webId     = "{00000000-0000-0000-0000-000000000000}"
        listId    = "{00000000-0000-0000-0000-000000000000}"
        webUrl    = "https://contoso.sharepoint.com/sites/Finance"
        webTitle  = "Finance"
        listTitle = "Shared Documents"
    },
    @{
        siteId    = "{00000000-0000-0000-0000-000000000000}"
        webId     = "{00000000-0000-0000-0000-000000000000}"
        listId    = "{00000000-0000-0000-0000-000000000000}"
        webUrl    = "https://contoso.sharepoint.com/sites/HR"
        webTitle  = "HR"
        listTitle = "Policies"
    },
    @{
        siteId    = "{00000000-0000-0000-0000-000000000000}"
        webId     = "{00000000-0000-0000-0000-000000000000}"
        listId    = "{00000000-0000-0000-0000-000000000000}"
        webUrl    = "https://contoso.sharepoint.com/sites/Operations"
        webTitle  = "Operations"
        listTitle = "Templates"
    }
)
#endregion

#region Main Process
Start-Transcript -Path "$env:TEMP\SharePointSync.log" -Append
try {
    [mailaddress]$userUpn = cmd /c "whoami /upn" 2>$null
    if (!$userUpn) {
        $userUpn = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1" -ErrorAction Stop).UserEmail
    }

    Wait-ForOneDrive

    $oneDriveRoot = Split-Path $env:OneDrive
    $results = @{ Success = @(); Failed = @(); Skipped = @() }

    foreach ($lib in $libraries) {
        $lib.userEmail = $userUpn
        $lib.syncPath = "$oneDriveRoot\$($userUpn.Host)\$($lib.webTitle) - $($lib.listTitle)"

        if (Test-Path $lib.syncPath) {
            Write-Host "Already synced: $($lib.webTitle) - $($lib.listTitle)" -ForegroundColor Yellow
            $results.Skipped += "$($lib.webTitle) - $($lib.listTitle)"
            continue
        }

        Write-Host "Syncing: $($lib.webTitle) - $($lib.listTitle)" -ForegroundColor Cyan
        $success = Sync-SharepointLocation @lib

        if ($success) {
            $results.Success += "$($lib.webTitle) - $($lib.listTitle)"
        }
        else {
            $results.Failed += "$($lib.webTitle) - $($lib.listTitle)"
        }

        # Stagger syncs to avoid overwhelming OneDrive
        Start-Sleep -Seconds 5
    }

    # Summary
    Write-Host "`n===== Sync Summary =====" -ForegroundColor Cyan
    Write-Host "Synced:  $($results.Success.Count)" -ForegroundColor Green
    Write-Host "Skipped: $($results.Skipped.Count)" -ForegroundColor Yellow
    Write-Host "Failed:  $($results.Failed.Count)" -ForegroundColor Red

    if ($results.Failed.Count -gt 0) {
        Write-Warning "Failed libraries: $($results.Failed -join ', ')"
        Throw "One or more libraries failed to sync."
    }
}
catch {
    Write-Warning $_.Exception.Message
    Stop-Transcript
    exit 1
}
finally {
    Stop-Transcript
}
#endregion
