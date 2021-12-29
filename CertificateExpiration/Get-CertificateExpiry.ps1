#region config
$config = @{
    tenantId     = "powers-hell.com"
    appId        = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    clientSecret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    dayThreshold = 7
}
#endregion

#region functions
function Get-AuthHeader {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$TenantId,
        [parameter(Mandatory = $true)]
        [string]$ApplicationId,
        [parameter(Mandatory = $true)]
        [string]$ClientSecret
    )
    $requestBody = @{
        resource      = 'https://graph.microsoft.com'
        client_id     = $ApplicationId
        client_secret = $clientSecret
        grant_type    = "client_credentials"
        scope         = "openid"
    }

    $authParams = @{
        Method = 'Post'
        Uri = "https://login.microsoftonline.com/$TenantId/oauth2/token"
        Body = $requestBody
    }
    $auth = Invoke-RestMethod @authParams
    $authorizationHeader = @{
        Authorization = "Bearer $($auth.access_token)"
    }
    return $authorizationHeader
}

function Get-TrustedCertificatesFromIntune {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [hashtable]$AuthHeader
    )

    try {
        #region Query Graph
        $baseUri = 'https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations'
        $graphParams = @{
            Method      = 'Get'
            Uri         = $baseUri
            Headers     = $AuthHeader
            ContentType = 'Application/Json'
        }
        $result = Invoke-RestMethod @graphParams
        $resultValue = $result.value.Count -gt 0 ? $result.value : $null
        #endregion
        #region Format the results
        $foundCertificates = $resultValue | Where-Object { $_.'@odata.type' -like "#microsoft.graph.*TrustedRootCertificate" }
        if ($foundCertificates.Count -gt 0) {
            Write-Verbose "$($foundCertificates.Count) Trusted certificates found"
            return $foundCertificates
        }
        #endregion
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}

function Get-CertificateDataFromTrustedCertificatePolicy {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $True, ValueFromPipeline)]
        [PSCustomObject]$TrustedRootCertificate
    )
    try {
        $decryptedTRC = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($TrustedRootCertificate.trustedRootCertificate))
        if ($decryptedTRC -match "-----BEGIN CERTIFICATE-----") {
            #region base64 encoded certificate detected
            Write-Verbose "Base64 encoded certificate detected.."
            $formattedCertContent = ($decryptedTRC -replace "-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----", "").Trim()
            $decryptedCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]([System.Convert]::FromBase64String($formattedCertContent))
            return $decryptedCertificate
            #endregion
        }
        else {
            #region der encoded certificate detected
            Write-Verbose "Der encoded certificate detected.."
            [byte[]]$decryptedDerTRC = [System.Convert]::FromBase64String($TrustedRootCertificate.trustedRootCertificate)
            $decryptedCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]($decryptedDerTRC)
            return $decryptedCertificate
            #endregion
        }
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}
#endregion

#region auth
$authHeader = Get-AuthHeader -TenantId $config.tenantId -ApplicationId $config.appId -ClientSecret $config.clientSecret
#endregion

#region grab certificate profiles
$certificateProfiles = Get-TrustedCertificatesFromIntune -AuthHeader $authHeader
#endregion

#region grab certicate metadata and send alerts if certificate expires within set threshold
Write-Host ([system.environment]::NewLine)
$Expiringcertificates = foreach ($cert in $certificateProfiles) {
    $certData = Get-CertificateDataFromTrustedCertificatePolicy -TrustedRootCertificate $cert
    $daysRemaining = [math]::Round((($certData.NotAfter) - ($dn)).TotalDays)
    if ($daysRemaining -lt $config.dayThreshold) {
        Write-Host "$($cert.displayName) expires in $daysRemaining days ⚠️⚠️⚠️"
        $certData
    }
}
Write-Host ([system.environment]::NewLine)
#endregion