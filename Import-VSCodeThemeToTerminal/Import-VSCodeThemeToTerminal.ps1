param (
    [parameter(Mandatory = $true)]
    [String]$themeName
)
#region Functions
function Get-VSCodeTheme {
    [cmdletbinding()]
    param (
        [System.IO.FileInfo]$themePath
    )
    try {
        $theme = (Get-Content "$themePath/package.json" -Raw | ConvertFrom-Json).contributes.themes
        $res = foreach ($t in $theme) {
            $themeConfigFile = (Get-Content (Resolve-Path $themePath/$($t.path)) -raw | ConvertFrom-Json)
            [pscustomobject]@{
                name       = $themeConfigFile.name
                type       = $themeConfigFile.type
                ansiColors = [pscustomobject]@{
                    name                = $themeConfigFile.name
                    background          = $themeConfigFile.colors.'terminal.background'
                    foreground          = $themeConfigFile.colors.'terminal.foreground'
                    Black               = $themeConfigFile.colors.'terminal.ansiBlack'
                    Blue                = $themeConfigFile.colors.'terminal.ansiBlue'
                    BrightBlack         = $themeConfigFile.colors.'terminal.ansiBrightBlack'
                    BrightBlue          = $themeConfigFile.colors.'terminal.ansiBrightBlue'
                    BrightCyan          = $themeConfigFile.colors.'terminal.ansiBrightCyan'
                    BrightGreen         = $themeConfigFile.colors.'terminal.ansiBrightGreen'
                    BrightPurple        = $themeConfigFile.colors.'terminal.ansiBrightMagenta'
                    BrightRed           = $themeConfigFile.colors.'terminal.ansiBrightRed'
                    BrightWhite         = $themeConfigFile.colors.'terminal.ansiBrightWhite'
                    BrightYellow        = $themeConfigFile.colors.'terminal.ansiBrightYellow'
                    Cyan                = $themeConfigFile.colors.'terminal.ansiCyan'
                    Green               = $themeConfigFile.colors.'terminal.ansiGreen'
                    Purple              = $themeConfigFile.colors.'terminal.ansiMagenta'
                    Red                 = $themeConfigFile.colors.'terminal.ansiRed'
                    White               = $themeConfigFile.colors.'terminal.ansiWhite'
                    Yellow              = $themeConfigFile.colors.'terminal.ansiYellow'
                    selectionBackground = $themeConfigFile.colors.'terminal.selectionBackground'
                }
            }
        }
        return $res
    }
    catch {
        Write-Warning $_
    }
}
function Import-VSCodeThemeToTerminal {
    [cmdletbinding()]
    param (
        [PSCustomObject]$theme
    )
    try {
        #region Set cmdlet parameters
        $params = @{ }
        if ( $null -ne $theme.ansiColors.name) {
            $params.name = $theme.ansiColors.name
        }
        if ( $null -ne $theme.ansiColors.background) {
            $params.background = $theme.ansiColors.background
        }
        if ( $null -ne $theme.ansiColors.foreground) {
            $params.foreground = $theme.ansiColors.foreground
        }
        if ( $null -ne $theme.ansiColors.Black) {
            $params.Black = $theme.ansiColors.Black
        }
        if ( $null -ne $theme.ansiColors.Blue) {
            $params.Blue = $theme.ansiColors.Blue
        }
        if ( $null -ne $theme.ansiColors.BrightBlack) {
            $params.BrightBlack = $theme.ansiColors.BrightBlack
        }
        if ( $null -ne $theme.ansiColors.BrightBlue) {
            $params.BrightBlue = $theme.ansiColors.BrightBlue
        }
        if ( $null -ne $theme.ansiColors.BrightCyan) {
            $params.BrightCyan = $theme.ansiColors.BrightCyan
        }
        if ( $null -ne $theme.ansiColors.BrightGreen) {
            $params.BrightGreen = $theme.ansiColors.BrightGreen
        }
        if ( $null -ne $theme.ansiColors.Brightpurple) {
            $params.Brightpurple = $theme.ansiColors.Brightpurple
        }
        if ( $null -ne $theme.ansiColors.BrightRed) {
            $params.BrightRed = $theme.ansiColors.BrightRed
        }
        if ( $null -ne $theme.ansiColors.BrightWhite) {
            $params.BrightWhite = $theme.ansiColors.BrightWhite
        }
        if ( $null -ne $theme.ansiColors.BrightYellow) {
            $params.BrightYellow = $theme.ansiColors.BrightYellow
        }
        if ( $null -ne $theme.ansiColors.Cyan) {
            $params.Cyan = $theme.ansiColors.Cyan
        }
        if ( $null -ne $theme.ansiColors.Green) {
            $params.Green = $theme.ansiColors.Green
        }
        if ( $null -ne $theme.ansiColors.purple) {
            $params.purple = $theme.ansiColors.purple
        }
        if ( $null -ne $theme.ansiColors.Red) {
            $params.Red = $theme.ansiColors.Red
        }
        if ( $null -ne $theme.ansiColors.White) {
            $params.White = $theme.ansiColors.White
        }
        if ( $null -ne $theme.ansiColors.Yellow) {
            $params.Yellow = $theme.ansiColors.Yellow
        }
        #endregion
        New-MSTerminalColorScheme @params
    }
    catch {
        Write-Warning $_
    }
}
#endregion
$themePath = (Resolve-Path "$env:UserProfile\.vscode\extensions\$themeName*").Path
$themes = Get-VSCodeTheme -themePath $themePath
$theme = $themes | Out-GridView -PassThru
Import-VSCodeThemeToTerminal -theme $theme