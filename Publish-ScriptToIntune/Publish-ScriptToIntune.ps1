#requires -module msal.ps
function Publish-ScriptToIntune {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$ScriptFilePath,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [string]$Description,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("System", "User")]
        [string]$RunAsAccount = "System",

        [Parameter(Mandatory = $false)]
        [boolean]$EnforceSignatureCheck,

        [Parameter(Mandatory = $false)]
        [boolean]$RunAs32Bit

    )
    try {
        $script:tick = [char]0x221a
        $errorMsg = $null
        #region authenticate to Graph
        if ($PSVersionTable.PSEdition -ne "Core") {
            $auth = Get-MsalToken -ClientId "d1ddf0e4-d672-4dae-b554-9d5bdfd93547" -RedirectUri "urn:ietf:wg:oauth:2.0:oob" -Interactive
        }
        else {
            $auth = Get-MsalToken -ClientId "d1ddf0e4-d672-4dae-b554-9d5bdfd93547" -DeviceCode
        }
        if (!($auth)) {
            throw "Authentication failed."
        }
        $script:authToken = @{
            Authorization = $auth.CreateAuthorizationHeader()
        }
        #endregion
        #region encode the script content to base64
        $scriptContent = Get-Content "$ScriptFilePath" -Raw
        $encodedScriptContent = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$scriptContent"))
        #endregion
        #region build the request body
        $postBody = [PSCustomObject]@{
            displayName           = $DisplayName
            description           = $Description
            enforceSignatureCheck = $EnforceSignatureCheck
            fileName              = $ScriptFilePath.Name
            runAs32Bit            = $RunAs32Bit
            runAsAccount          = $RunAsAccount
            scriptContent         = $encodedScriptContent
        } | ConvertTo-Json -Depth 10
        #endregion
        Write-Host "`nPosting script content to Intune: " -NoNewline -ForegroundColor Cyan
        #region post the request
        $postParams = @{
            Method      = "Post"
            Uri         = "https://graph.microsoft.com/Beta/deviceManagement/deviceManagementScripts"
            Headers     = $script:authToken
            Body        = $postBody
            ContentType = "Application/Json"
        }
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
            Write-Host "`n"
        }
        $res = Invoke-RestMethod @postParams
        #endregion
    }
    catch {
        $errorMsg = $_.Exception.Message
    }
    finally {
        if ($auth) {
            if ($errorMsg) {
                Write-Host "X`n" -ForegroundColor Red
                Write-Warning $errorMsg
            }
            else {
                if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
                    $res
                }
                Write-Host "$script:tick Script published to Intune with ID $($res.id)" -ForegroundColor Green
            }
        }
    }
}