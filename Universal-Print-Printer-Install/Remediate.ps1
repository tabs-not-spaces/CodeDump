#region printer list
$availablePrinters = @(
    [pscustomobject]@{
        SharedID   = '6f4387af-dadb-4391-a984-477fa3c40224'
        SharedName = 'HP Universal Printing PCL 6'
        IsDefault  = 'Yes'
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