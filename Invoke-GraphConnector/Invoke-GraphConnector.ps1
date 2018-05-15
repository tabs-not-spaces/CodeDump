# POST method: $req
$requestBody = Get-Content $req -Raw | ConvertFrom-Json
$tenant = $requestBody.tenant

# GET method: each querystring parameter is its own variable
if ($req_query_tenant) {
    $tenant = $req_query_tenant 
}
if ($req_query_query) {
    $query = $req_query_query
}
if ($req_query_ver) {
    $ver = $req_query_ver
}
else {
    $ver = 'v1.0'
}
if ($req_query_space) {
    $space = $req_query_space
}
else {
    $space = "AAD"
}
$fp = $EXECUTION_CONTEXT_FUNCTIONDIRECTORY
$config = Get-Content "$fp/appConfig.json" -Raw | ConvertFrom-Json
$account = $config.accounts | Where-Object {$_.strTd -eq "$tenant"}
$GLOBAL:adal = "$fp/Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
$GLOBAL:adalforms = "$fp/Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"


<#
.Synopsis
   simple script to retrieve Graph API Access Token and create the correctly formed header object.
.EXAMPLE
    .\Get-AuthHeader -un "ben@tenantdomain.onmicrosoft.com" -pw 'password'
.EXAMPLE
   .\Get-AuthHeader -un "ben@tenantdomain.onmicrosoft.com" -pw 'password'
.INPUTS
   $un    - email address of account to be used to authenticate to tenant domain / graph API
   $pw    - password of account. if more than simple characters, try and wrap in single quotes.
#>
function Get-AuthHeader {
    param (
        [Parameter(Mandatory = $true)]
        $un,
        [Parameter(Mandatory = $true)]
        $pw,
        [parameter(mandatory = $true)] [ValidateSet('Intune', 'AAD')]
        $space
    )
    
    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $un
    $tenantDomain = $userUpn.Host
    switch ($space) {
        "Intune" {
            $cId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
            break;
        }
        "AAD" {
            $cId = "1950a258-227b-4e31-a9cf-717495945fc2"
            break;
        }
    }
    
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authString = "https://login.microsoftonline.com/$tenantDomain" 

    $pw = $pw | ConvertTo-SecureString -AsPlainText -Force
    $cred = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserPasswordCredential -ArgumentList $userUpn, $pw
    $authContext = new-object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authString
    try {
        $authResult = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContextIntegratedAuthExtensions]::AcquireTokenAsync($authContext, $resourceAppIdURI, $cId, $cred).Result
        if ($authResult.AccessToken) {
    
            # Creating header for Authorization token
    
            $authHeader = @{
                'Content-Type'  = 'application/json'
                'Authorization' = "Bearer " + $authResult.AccessToken
                'ExpiresOn'     = $authResult.ExpiresOn
            }
    
            return $authHeader
        }
        else {
            throw;
        }
    }
    Catch {
        return $false
    }
}
<#
.Synopsis
   simple script to form Graph API URLs and deliver the results as a JSON Payload.
.EXAMPLE
    .\Get-JsonFromGraph -strUn "ben@tenantdomain.onmicrosoft.com" -strPw 'password' -strQuery "Users" -ver 1.0
.EXAMPLE
   .\Get-JsonFromGraph -strUn "ben@tenantdomain.onmicrosoft.com" -strPw 'password' -strQuery "ManagedDevices" -ver beta
.INPUTS
   $strUn    - email address of account to be used to authenticate to tenant domain / graph API
   $strPw    - password of account. if more than simple characters, wrap in single quotes.
   $strQuery - the query you want to send to Graph. Please see GraphAPI documentation for further into
   $ver      - what version of Graph to run the query against. (v1.0 / beta)
#>
Function Get-JsonFromGraph {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $strUn,
        [Parameter(Mandatory = $true)]
        $strPw,
        [Parameter(Mandatory = $true)]
        $strQuery,
        [parameter(mandatory = $true)] [ValidateSet('v1.0', 'beta')]
        $ver,
        [Parameter(Mandatory = $false)]
        $space

    )
    #proxy pass-thru
    $webClient = new-object System.Net.WebClient
    $webClient.Headers.Add(“user-agent”, “PowerShell Script”)
    $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

    try { 
        switch ($space) {
            "Intune" {
                $header = Get-AuthHeader -un $strUn -pw $strPw -space Intune
                break;
            }
            "AAD" {
                $header = Get-AuthHeader -un $strUn -pw $strPw -space AAD
                break;
            }
        }
        if ($header) {
            #create the URL
            $url = "https://graph.microsoft.com/$ver/$strQuery"
        
            #Invoke the Restful call and display content.
            Write-Verbose $url
            $query = Invoke-RestMethod -Method Get -Headers $header -Uri $url -ErrorAction STOP
            if ($query) {
                if ($query.value) {
                    #multiple results returned. handle it
                    $query = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/$ver/$strQuery" -Headers $header
                    $result = @()
                    while ($query.'@odata.nextLink') {
                        Write-Verbose "$($query.value.Count) objects returned from Graph"
                        $result += $query.value
                        Write-Verbose "$($result.count) objects in result array"
                        $query = Invoke-RestMethod -Method Get -Uri $query.'@odata.nextLink' -Headers $header
                    }
                    $result += $query.value
                    Write-Verbose "$($query.value.Count) objects returned from Graph"
                    Write-Verbose "$($result.count) objects in result array"
                    return $result
                }
                else {
                    #single result returned. handle it.
                    $query = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/$ver/$strQuery" -Headers $header
                    return $query
                }
            }
            else {
                $error = @{
                    errNumber = 404
                    errMsg    = "No results found. Either there literally is nothing there or your query was malformed."
                }
            }
            throw;
        }
        else {
            $error = @{
                errNumber = 401
                errMsg    = "Authentication Failed during attempt to create Auth header."
            }
            throw;
        }
    }
    catch {
        return $error
    }
}
$objReq = Get-JsonFromGraph -strUn $account.strUn -strPw $account.strPw -strQuery $query -ver $ver -space $space
$objReq | ConvertTo-Json | out-file -encoding ascii -FilePath $res