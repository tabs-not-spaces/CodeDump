function Get-TenantIdFromDomain {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FQDN
    )
    try {
        $uri = "https://login.microsoftonline.com/$($FQDN)/.well-known/openid-configuration"
        $rest = Invoke-RestMethod -Method Get -UseBasicParsing -Uri $uri
        if ($rest.authorization_endpoint) {
            $result = $(($rest.authorization_endpoint | Select-String '\w{8}-\w{4}-\w{4}-\w{4}-\w{12}').Matches.Value)
            if ([guid]::Parse($result)) {
                return $result.ToString()
            }
            else {
                throw "Tenant ID not found."
            }
        }
        else {
            throw "Tenant ID not found."
        }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}