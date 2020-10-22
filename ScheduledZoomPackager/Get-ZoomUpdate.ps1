function Get-ZoomUpdate {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $false)]
        [string]$downloadPath
    )
    $content = Invoke-WebRequest -Method Get -Uri "https://support.zoom.us/hc/en-us/articles/201361953" -ContentType 'Application/Json' | Select-Object -ExpandProperty content
    $split = (($content.Split("Current Release</h2>")[1].Split("Download Type: Manual")[0] -replace '<br />',"`n") -replace '<[^>]+>',' ').trim().Split("`n")
    $val = @{
        VersionDate = $split[0].Split("version")[0].Trim().TrimEnd()
        VersionNumber = $split[0].Split("version")[1].Trim().TrimEnd()
        DownloadType = $split[1].Split("Download type:")[-1].Trim().TrimEnd()
        DownloadLink = [uri]"https://zoom.us/client/latest/ZoomInstallerFull.msi"
    }
    if ($downloadPath) {
        if (!(Test-Path $downloadPath -ErrorAction SilentlyContinue)) {
            New-Item $downloadPath -ItemType Directory -Force | Out-Null
        }
        $fileName = '{0}-{1}.msi' -f $($val.DownloadLink.Segments[-1].Split('.msi')[0]), $($val.VersionNumber.Split('(')[0].TrimEnd())
        $val.InstallationMedia = "$downloadPath\$fileName"
        Invoke-WebRequest -Method Get -Uri $val.DownloadLink -OutFile "$($val.InstallationMedia)"
        $val.ProductCode = (Get-MSIProperty -Path "$($val.InstallationMedia)"-Property ProductCode).value
        $val.ProductVersion = (Get-MSIProperty -Path "$($val.InstallationMedia)" -Property ProductVersion).value
        $val.FileSize = "$([math]::Round(((Get-ChildItem "$($val.InstallationMedia)").Length / 1mb)))Mb"
    }
    $res = New-Object PSCustomObject -Property $val
    return $res
}