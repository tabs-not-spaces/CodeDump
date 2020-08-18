function Invoke-PlanetGreeting {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $false)]
        [string]$planet = $script:randomInt
    )
    $planet = Get-RandomPlanet -PlanetInt $planet
    return "Hello $planet`!"
}