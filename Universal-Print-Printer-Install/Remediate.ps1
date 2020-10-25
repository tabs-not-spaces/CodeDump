#region printer list
$availablePrinters = @(
    [pscustomobject]@{
        SharedID   = '2f8aa4d8-8c21-4d37-9506-3da446bcf9ea'
        SharedName = 'Printer A'
        IsDefault  = 'Yes'
    }
    [pscustomobject]@{
        SharedID   = 'c288bc70-8e14-4c5b-9f82-428ecf3ab63a'
        SharedName = 'Printer B'
        IsDefault  = $null
    }
    [pscustomobject]@{
        SharedID   = '478a29db-7bdd-46a7-a75e-e0d61167988c'
        SharedName = 'Printer C'
        IsDefault  = $null
    }
    [pscustomobject]@{
        SharedID   = '896262c5-59ca-4b92-becf-074feb25fccc'
        SharedName = 'Printer D'
        IsDefault  = $null
    }
)
#endregion
try {
    $configurationPath = "$env:appdata\UniversalPrintPrinterProvisioning\Configuration"
    if (!(Test-Path $configurationPath -ErrorAction SilentlyContinue)) {
        New-Item $configurationPath -ItemType Directory -Force | Out-Null
    }
    $printCfg = ($availablePrinters | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', "" } ) -join [System.Environment]::NewLine
    $printCfg | Out-File "$configurationPath\printers.csv" -Encoding ascii -NoNewline
    Start-Process "${env:ProgramFiles(x86)}\UniversalPrintPrinterProvisioning\Exe\UPPrinterInstaller.exe" -Wait -WindowStyle Hidden
}
catch {
    $errorMsg = $_.Exception.Message
}
finally {
    if ($errorMsg) {
        Write-Warning $errorMsg
        exit 1
    }
    else {
        Write-Host "Universal Printer Installer configured and launched. Printers should appear shortly.."
        exit 0
    }
}