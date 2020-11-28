#region Config
$VPNName = ''
$VPNGUID = '' # Grab the GUID from the phonebook file or create your own - note that it needs to be a "hexified" guid.
$currentUser = (Get-CimInstance -ClassName WIn32_Process -Filter 'Name="explorer.exe"' | Invoke-CimMethod -MethodName GetOwner)[0]
$objUser = New-Object System.Security.Principal.NTAccount($currentUser.user)
$strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
$requiredFolder = "C:\Users\$($currentUser.user)\AppData\Local\Packages\Microsoft.AzureVpn_8wekyb3d8bbwe\LocalState"
$rasManKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\RasMan\Config" 
#endregion
#region PBK config
$PBKConfig = @"
# Add your pre-created phonebook configuration here. make sure to replace the Name & GUID with the variables configured above.
"@
#endregion
#region Functions
function Write-Log {
    [cmdletbinding()]
    param (
        [string]$logMessage
    )
    Write-Host "[$(Get-Date -Format 'dd-MM-yyyy_HH:mm:ss')] $logMessage" -ForegroundColor Yellow
}
function Convert-HexToByte {
  [cmdletbinding()]
  param (
    [string]$HexString
  )
  $splitString = ($HexString -replace '(..)','$1,').Trim(',')
  [byte[]]$hexified = $splitString.Split(',') | ForEach-Object { "0x$_"}
  return $hexified
}
function Set-ComputerRegistryValues {
  param (
      [Parameter(Mandatory = $true)]
      [array]$RegistryInstance
  )
  try {
      foreach ($key in $RegistryInstance) {
          $keyPath = $key.Path
          if (!(Test-Path $keyPath)) {
              Write-Host "Registry path : $keyPath not found. Creating now." -ForegroundColor Green
              New-Item -Path $key.Path -Force | Out-Null
              Write-Host "Creating item property: $($key.Name)" -ForegroundColor Green
              New-ItemProperty -Path $keyPath -Name $key.Name -Value $key.Value -Type $key.Type -Force
          }
          else {
              Write-Host "Creating item property: $($key.Name)" -ForegroundColor Green
              New-ItemProperty -Path $keyPath -Name $key.Name -Value $key.Value -Type $key.Type -Force
          }
      }
  }
  catch {
      Throw $_.Exception.Message
  }
}
#endregion
#region deploy VPN
if (!(Test-Path $RequiredFolder -ErrorAction SilentlyContinue)) {
  New-Item $RequiredFolder -ItemType Directory | Out-Null
  $LogLocation = "$RequiredFolder\NewAzureVPNConnectionLog_$(Get-Date -Format 'dd-MM-yyyy_HH_mm_ss').log"
  Start-Transcript -Path $LogLocation -Force -Append
  
  Write-Log "Required folder $RequiredFolder was created on the machine since it wasn't found."
  New-Item "$RequiredFolder\rasphone.pbk" -ItemType File | Out-Null
  
  Write-Log "File rasphone.pbk has been created in $RequiredFolder."
  Set-Content "$RequiredFolder\rasphone.pbk" $PBKConfig
  
  Write-Log "File rasphone.pbk has been populated with configuration details."
  Stop-Transcript | Out-Null
}
else {
  $LogLocation = "$RequiredFolder\NewAzureVPNConnectionLog_$(Get-Date -Format 'dd-MM-yyyy_HH_mm_ss').log"
  Start-Transcript -Path $LogLocation -Force -Append
  
  Write-Log "Folder $RequiredFolder already exists, that means that Azure VPN Client is already installed."
  if (!(Test-Path "$RequiredFolder\rasphone.pbk" -ErrorAction SilentlyContinue)) {
    
    Write-Log "File rasphone.pbk doesn't exist in $RequiredFolder."
    New-Item "$RequiredFolder\rasphone.pbk" -ItemType File | Out-Null
    
    Write-Log "File rasphone.pbk has been created in $RequiredFolder."
    Set-Content "$RequiredFolder\rasphone.pbk" $PBKConfig
    
    Write-Log "File rasphone.pbk has been populated with configuration details."
    Stop-Transcript | Out-Null
  }
  else {
    Write-Log "File rasphone.pbk already exists in $RequiredFolder."
    Rename-Item -Path "$RequiredFolder\rasphone.pbk" -NewName "$RequiredFolder\rasphone.pbk_$(Get-Date -Format 'ddMMyyyy-HHmmss')"    
    
    Write-Log "File rasphone.pbk has been renamed to rasphone.pbk_$(Get-Date -Format 'ddMMyyyy-HHmmss'). This file contains old configuration if it will be required in the future (in case it is, just rename it back to rasphone.pbk)."
    New-Item "$RequiredFolder\rasphone.pbk" -ItemType File | Out-Null
    
    Write-Log "New rasphone.pbk file has been created in $RequiredFolder."
    Set-Content "$RequiredFolder\rasphone.pbk" $PBKConfig
    
    Write-Log "File rasphone.pbk has been populated with configuration details."
    Stop-Transcript | Out-Null
  }
}
#endregion
#region configure always on
[string[]]$autoDisable = (Get-ItemPropertyValue $rasManKeyPath -Name AutoTriggerDisabledProfilesList) | ForEach-Object { if ($_ -ne $VPNName) { $_ }}
$regKeys = @(
  @{
    Path = $rasManKeyPath
    Name = 'AutoTriggerDisabledProfilesList'
    Value = [string[]]$autoDisable
    Type = 'MultiString'
  }
  @{
    Path = $rasManKeyPath
    Name = 'AutoTriggerProfilePhonebookPath'
    Value = "$RequiredFolder\rasphone.pbk"
    Type = 'String'
  }
  @{
    Path = $rasManKeyPath
    Name = 'AutoTriggerProfileEntryName'
    Value = $VPNName
    Type = 'String'
  }
@{
    Path = $rasManKeyPath
    Name = 'UserSID'
    Value = $sid
    Type = 'String'
  }
@{
    Path = $rasManKeyPath
    Name = 'AutoTriggerProfileGUID'
    Value = [Byte[]](Convert-HexToByte -HexString $VPNGUID)
    Type = 'Binary'
  }
)
Set-ComputerRegistryValues $regKeys
#endregion
#region Extra Credit - Dial the VPN. Delete this if you don't need it.
. rasdial $vpnName /PHONEBOOK:$RequiredFolder\rasphone.pbk
#endregion