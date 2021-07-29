#region Config
$AppName = "Registry-Modifications"
$client = "MegaCorp"
$logPath = "$env:ProgramData\$client\logs"
$logFile = "$logPath\$appName.log"
#region Keys
$hkcuKeys = @(
    [PSCustomObject]@{
        Guid  = "{fc996e2d-4931-42fe-8276-fbfa1967c008}"
        Name  = "PropertyA"
        Type  = "DWord"
        Value = 1
        Path  = "Software\Path\To\Registry\Key"
    }
    [PSCustomObject]@{
        Guid  = "{b94177b7-31e5-4499-94c1-0017425f0f59}"
        Name  = "propertyB"
        Type  = "DWord"
        Value = 1
        Path  = "Software\Path\To\Registry\Key"
    }
)
$hklmKeys = @(
    [PSCustomObject]@{
        Path  = "HKLM:\Software\Path\To\Registry\Key"
        Name  = "PropertyA"
        Type  = "DWORD"
        value = "1"
    }
    [PSCustomObject]@{
        Path  = "HKLM:\Software\Path\To\Registry\Key"
        Name  = "PropertyB"
        Type  = "DWORD"
        value = "1"
    }
)
#endregion
#endregion
#region Functions
function Set-RegistryValueForAllUsers {
    <#
    .SYNOPSIS
        This function uses Active Setup to create a "seeder" key which creates or modifies a user-based registry value
        for all users on a computer. If the key path doesn't exist to the value, it will automatically create the key and add the value.
    .EXAMPLE
        PS> Set-RegistryValueForAllUsers -RegistryInstance @{'Name' = 'Setting'; 'Type' = 'String'; 'Value' = 'someval'; 'Path' = 'SOFTWARE\Microsoft\Windows\Something'}
        This example would modify the string registry value 'Type' in the path 'SOFTWARE\Microsoft\Windows\Something' to 'someval'
        for every user registry hive.
    .PARAMETER RegistryInstance
         A hash table containing key names of 'Name' designating the registry value name, 'Type' to designate the type
        of registry value which can be 'String,Binary,Dword,ExpandString or MultiString', 'Value' which is the value itself of the
        registry value and 'Path' designating the parent registry key the registry value is in.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $RegistryInstance
    )
    try {
        New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null

        ## Change the registry values for the currently logged on user. Each logged on user SID is under HKEY_USERS
        $LoggedOnSids = $(Get-ChildItem HKU: | Where-Object { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | ForEach-Object { $_.Name })
        Write-Verbose "Found $($LoggedOnSids.Count) logged on user SIDs"
        foreach ($sid in $LoggedOnSids) {
            Write-Host "Loading the user registry hive for the logged on SID $sid"  -ForegroundColor Green
            foreach ($instance in $RegistryInstance) {
                ## Create the key path if it doesn't exist
                if (!(Test-Path "HKU:\$sid\$($instance.Path)")) {
                    New-Item -Path "HKU:\$sid\$($instance.Path | Split-Path -Parent)" -Name ($instance.Path | Split-Path -Leaf) -Force
                }
                ## Create (or modify) the value specified in the param
                Set-ItemProperty -Path "HKU:\$sid\$($instance.Path)" -Name $instance.Name -Value $instance.Value -Type $instance.Type -Force
            }
        }

        ## Create the Active Setup registry key so that the reg add cmd will get ran for each user
        ## logging into the machine.
        ## http://www.itninja.com/blog/view/an-active-setup-primer
        Write-Host "Setting Active Setup registry value to apply to all other users" -ForegroundColor Green
        foreach ($instance in $RegistryInstance) {
            ## Generate a unique value (usually a GUID) to use for Active Setup
            $Guid = $instance.Guid
            $ActiveSetupRegParentPath = 'HKLM:\Software\Microsoft\Active Setup\Installed Components'
            ## Create the GUID registry key under the Active Setup key
            $ActiveSetupRegPath = "HKLM:\Software\Microsoft\Active Setup\Installed Components\$Guid"
            if (!(Test-Path -Path "$ActiveSetupRegPath")) {
                New-Item -Path $ActiveSetupRegParentPath -Name $Guid -Force
            }
            Write-Verbose "Using registry path '$ActiveSetupRegPath'"
            ## Convert the registry value type to one that reg.exe can understand.  This will be the
            ## type of value that's created for the value we want to set for all users
            switch ($instance.Type) {
                'String' {
                    $RegValueType = 'REG_SZ'
                }
                'Dword' {
                    $RegValueType = 'REG_DWORD'
                }
                'Binary' {
                    $RegValueType = 'REG_BINARY'
                }
                'ExpandString' {
                    $RegValueType = 'REG_EXPAND_SZ'
                }
                'MultiString' {
                    $RegValueType = 'REG_MULTI_SZ'
                }
                default {
                    throw "Registry type '$($instance.Type)' not recognized"
                }
            }

            ## Build the registry value to use for Active Setup which is the command to create the registry value in all user hives
            $ActiveSetupValue = "reg add `"{0}`" /v {1} /t {2} /d {3} /f" -f "HKCU\$($instance.Path)", $instance.Name, $RegValueType, $instance.Value
            Write-Verbose -Message "Active setup value is '$ActiveSetupValue'"
            ## Create the necessary Active Setup registry values
            Set-ItemProperty -Path $ActiveSetupRegPath -Name '(Default)' -Value 'Active Setup Test' -Force
            Set-ItemProperty -Path $ActiveSetupRegPath -Name 'Version' -Value '1' -Force
            Set-ItemProperty -Path $ActiveSetupRegPath -Name 'StubPath' -Value $ActiveSetupValue -Force
        }
    }
    catch {
        Throw -Message $_.Exception.Message
    }
}
#endregion
#region Logging
if (!(Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}
$errorOccurred = $false
Start-Transcript -Path $logFile -ErrorAction SilentlyContinue -Force
#endregion
#region Process
try {
    if ($hkcuKeys) {
        Write-Host "Seting HKCU registry keys.." -ForegroundColor Green
        foreach ($key in $hkcuKeys) {
            Set-RegistryValueForAllUsers -RegistryInstance $hkcuKeys
            Write-Host "========"
        }
    }
    foreach ($key in $hklmKeys) {
        Write-Host "Setting HKLM registry keys.." -ForegroundColor Green
        if (!(Test-Path $($key.Path))) {
            Write-Host "Registry path not found. Creating now." -ForegroundColor Green
            New-Item -Path $($key.Path) -Force | Out-Null
            Write-Host "Creating item property." -ForegroundColor Green
            New-ItemProperty -Path $($key.Path) -Name $($key.Name) -Value $($key.value) -PropertyType DWORD -Force | Out-Null
        }
        else {
            Write-Host "Registry path found." -ForegroundColor Green
            Write-Host "Creating item property." -ForegroundColor Green
            New-ItemProperty -Path $($key.Path) -Name $($key.Name) -Value $($key.value) -PropertyType DWORD -Force | Out-Null
        }
    }
}
catch {
    $errorOccurred = $_.Exception.Message
}
finally {
    if ($errorOccurred) {
        Write-Warning $errorOccurred
        Stop-Transcript
        throw $errorOccurred
    }
    else {
        Write-Host "Script completed successfully.."
        Stop-Transcript -ErrorAction SilentlyContinue
    }
}
#endregion
