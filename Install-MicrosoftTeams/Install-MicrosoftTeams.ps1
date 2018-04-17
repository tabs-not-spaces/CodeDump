#config--
$appName = "Microsoft Teams Client"
$installerPath = "$ENV:ProgramData\AppInstalls\Cache"
$appInstallPath = "$($env:LOCALAPPDATA)\Microsoft\Teams"
$LogPath = "$ENV:ProgramData\AppInstalls\Logs"
$logFile = "$LogPath\$($appName).log"
#config--
function Get-MicrosoftTeamsClient {
    [CmdletBinding()]
    param(
        [parameter()]
        [ValidateSet(, "production")]
        [string]$env = "production",

        [parameter()]
        [ValidateSet(, "windows", "osx")]
        [string]$platform = "windows",

        [parameter()]
        [ValidateSet(, "x64", "x86")]
        [string]$osArch = "x64",

        [parameter(Mandatory = $true)]
        [string]$destinationPath
    )
    switch ($platform) {
        "windows" {
            $uri = "https://teams.microsoft.com/downloads/DesktopURL?env=$($env)&plat=$($platform)&arch=$($osArch)"
            break
        }
        "osx" {
            $uri = "https://teams.microsoft.com/downloads/DesktopURL?env=$($env)&plat=$($platform)"
            break
        }
    }
    
    $contentURI = Invoke-WebRequest -Uri $uri -UseBasicParsing
    $contentName = ($contentURI.content -split "/")[-1]
    $result = @{}
    $result.FilePath = "$destinationPath\$contentName"
    if (!(Test-Path $destinationPath)) {
        New-Item -Path $destinationPath -ItemType Directory -Force | out-null
    }
    Write-Host "Downloading $contentName" -ForegroundColor Green
    if (!(test-path "$($destinationPath)\$($contentName)")) {
        $bitsJob = Start-BitsTransfer -Source $($contentURI.content) -Destination "$($destinationPath)\$($contentName)" -Asynchronous
        start-sleep -Seconds 1
        Write-Host "Total filesize: $($bitsJob.BytesTotal)" -ForegroundColor Yellow
        While ($bitsJob | Where-Object {$bitsJob.JobState -eq "Transferring"}) {
            Start-Sleep -Seconds 2
        }
        Write-Host "Total transferred: $($bitsJob.BytesTransferred)" -ForegroundColor Green
        if ($bitsJob.BytesTotal -eq $bitsJob.BytesTransferred) {
            Get-BitsTransfer -JobId $bitsJob.JobId | Complete-BitsTransfer
            $result.result = "Downloaded"
            return $result
        }
        else {
            Write-Host "Error during download - file size mismatch" -ForegroundColor Red
            $result.result = "Failed"
            return $result
        }
    }
    else {
        Write-Host "$contentName already found at location: $destinationPath" -ForegroundColor Yellow
        $result.result = "Found"
        return $result
    }
}
if (!(Test-Path $logPath)){
    New-Item -Path $logPath  -ItemType Directory -Force | out-null
}
Start-Transcript -Path $logFile -Force
Write-Host "Installing $($appName)" -ForegroundColor Green

if ((Test-Path -Path "$appInstallPath\update.exe") -and (!(Test-Path -Path "$appInstallPath\.dead"))) {
    Write-Host "$appName detected on system: $true" -ForegroundColor Yellow
}
else {
    Write-Host "$appName detected on system: $false" -ForegroundColor Yellow
    $installFile = Get-MicrosoftTeamsClient -env "production" -platform "windows" -osArch "x64" -destinationPath $installerPath
    if ($installFile.result -eq "Failed") {
        Write-Host "Failed to download installation media. Will gracefully quit now." -ForegroundColor Red
    }
    else {
        Write-Host "Installation media downloaded. Lets rock." -ForegroundColor Green
        $proc = Start-Process -FilePath "$($installFile.FilePath)" -ArgumentList "-s" -PassThru -Wait
        while (get-process -Id $proc.Id -ErrorAction SilentlyContinue) {
            Start-Sleep -Seconds 2
        }
        start-sleep -Seconds 5
        Write-Host "App install process completed. checking for installation success.." -ForegroundColor Yellow
        if ((Test-Path -Path "$appInstallPath\update.exe") -and (!(Test-Path -Path "$appInstallPath\.dead"))) {
            Write-Host "Application installed: $true" -ForegroundColor Green
        } 
        else {
            Write-Host "Application installed: $false" -ForegroundColor Red
            throw "Installation was not detected, so we will exit with an error to advise Intune of this..."
        }
    }    
}
Stop-Transcript