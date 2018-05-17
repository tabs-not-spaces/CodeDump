$fp = $EXECUTION_CONTEXT_FUNCTIONDIRECTORY
$config = Get-Content "$fp/appConfig.json" -Raw | ConvertFrom-Json
$tenant = $config.basicConfig.tenant
$query = $config.basicConfig.query
$graphConnectorURI = $config.basicConfig.graphConnectorURI
$graphVer = $config.basicConfig.graphVer
$graphQuery = "deviceManagement/$($query)"
$currentSnapshot = $ExecutionContext.InvokeCommand.ExpandString($config.basicConfig.currentSnapshot)
Function Compare-ObjectProperties {
    # cleaned up from https://blogs.technet.microsoft.com/janesays/2017/04/25/compare-all-properties-of-two-objects-in-windows-powershell/
    Param(
        [PSObject]$ReferenceObject,
        [PSObject]$DifferenceObject 
    )
    $objprops = $ReferenceObject | Get-Member -MemberType Property, NoteProperty | ForEach-Object Name
    $objprops += $DifferenceObject | Get-Member -MemberType Property, NoteProperty | ForEach-Object Name
    $objprops = $objprops | Sort-Object | Select-Object -Unique
    $diffs = @()
    foreach ($objprop in $objprops) {
        $diff = Compare-Object $ReferenceObject $DifferenceObject -Property $objprop
        if ($diff) {            
            $diffprops = @{
                PropertyName = $objprop
                RefValue     = ($diff | Where-Object {$_.SideIndicator -eq '<='} | ForEach-Object $($objprop))
                DiffValue    = ($diff | Where-Object {$_.SideIndicator -eq '=>'} | ForEach-Object $($objprop))
            }
            $diffs += New-Object PSObject -Property $diffprops
        }        
    }
    if ($diffs) {return ($diffs | Select-Object PropertyName, RefValue, DiffValue)}     
}

$intuneSnapshot = Invoke-RestMethod -Uri $currentSnapshot

$graphURI = "$($graphConnectorURI)&tenant=$($tenant)&Ver=$($graphVer)&query=$($graphQuery)"
$latestCapture = Invoke-RestMethod -Method Get -Uri $graphURI
$results = @()
for ($i = 0; $i -le ($intuneSnapshot.count - 1) ; $i ++) {
    $tmpCompare = Compare-ObjectProperties -ReferenceObject $intuneSnapshot[$i] -DifferenceObject $latestCapture[$i]
    if ($tmpCompare) {
        $tmpobject = [psCustomObject]@{
            TimeStamp         = Get-date -Format "yyyy-MM-ddTHH:mm:ss"
            Tenant            = $tenant
            ChangesFound      = $true
            SnapshotObject    = $intuneSnapshot[$i]
            ModifiedObject    = $latestCapture[$i]
            ChangedProperties = $tmpCompare
        }
        $results += $tmpobject
    }
}
if ($results) {
    return $results | ConvertTo-Json | out-file -encoding ascii -FilePath $res
}
else {
    $tmpObject = [psCustomObject]@{
        TimeStamp        = Get-date -Format "yyyy-MM-ddTHH:mm:ss"
        Tenant           = $tenant
        ChangesFound     = $false        
    }
    return $tmpObject | ConvertTo-Json | out-file -encoding ascii -FilePath $res
}