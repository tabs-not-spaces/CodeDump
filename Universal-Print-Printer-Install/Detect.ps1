#region printer list
$availablePrinters = @("HP Universal Printing PCL 6")
$notFound = 0
#endregion
#region check the printers exist
try {
    foreach ($p in $availablePrinters) {
        if (!(Get-Printer -Name $p -ErrorAction SilentlyContinue)) {
            $notFound ++
        }
    }
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
        if ($notFound) {
            Write-Warning "$notFound printers not found locally.."
            exit 1
        }
        else {
            Write-Host "All printers detected.."
            exit 0
        }
    }
}

#endregion