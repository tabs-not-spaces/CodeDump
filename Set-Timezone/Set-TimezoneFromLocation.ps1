$apiKey = '000000000000000000000000000000' #use a subscription key from your Azure Maps Account
function ConvertFrom-IanaName {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$apiKey,
        [parameter(Mandatory = $true, ValueFromPipeline)]
        [string]$IanaName
    )
    $tzList = Invoke-RestMethod -Method Get -Uri "https://atlas.microsoft.com/timezone/enumWindows/json?subscription-key=$apiKey&api-version=1.0" -ContentType 'Application/Json'
    $result = $tzList | Where-Object { $IanaName -in $_.IanaIds }
    return $result
}

try {
    Add-Type -AssemblyName System.Device
    $gw = New-Object System.Device.Location.GeoCoordinateWatcher
    $gw.Start()
    while (($gw.Status -ne 'Ready') -and ($gw.Permission -ne 'Denied')) {
        Start-Sleep -Milliseconds 100 #Wait for discovery.
    }

    if ($gw.Permission -eq 'Denied') {
        Throw 'Access Denied for Location Information'
    }
    else {
        $baseUri = "https://atlas.microsoft.com/timezone"
        $locData = Invoke-RestMethod -Method Get -Uri "$baseUri/byCoordinates/json?subscription-key=$apiKey&api-version=1.0&query=$($gw.Position.Location.Latitude),$($gw.Position.Location.Longitude)" -ContentType 'Application/Json'
        $timezone = ConvertFrom-IanaName -apiKey $apiKey -IanaName $locData.TimeZones.id
        Write-Host "Setting timezone to $($timezone.WindowsId)"
        Set-Timezone -Id $timezone.WindowsId
    }
}
catch {
    Write-Warning $_.Exception.Message
}
finally {
    $gw.Dispose()
}

