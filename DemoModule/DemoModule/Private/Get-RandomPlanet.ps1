function Get-RandomPlanet {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$planetInt
    )
    $planets = @(
        "Mercury",
        "Venus",
        "Earth",
        "Mars",
        "Jupiter",
        "Saturn",
        "Uranus",
        "Neptune"
    )
    return $planets[$planetInt]
}