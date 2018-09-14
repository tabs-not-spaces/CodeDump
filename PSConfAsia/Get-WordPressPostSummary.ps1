function Get-WordPressPostSummary {
    [CmdletBinding()]
    param (
        [string[]]$url
    )
    try {
        $result = @()
        foreach ($blog in $url) {
            $hostName = $blog -replace '(^http:\/\/)|(\/$)', ''
            $iwr = Invoke-WebRequest -Method Get -UseBasicParsing `
                -Uri "http://$($hostName)/wp-json/wp/v2/posts"
            if ($iwr.StatusCode -eq 200) {
                $jsonContent = $iwr.Content | ConvertFrom-Json
                foreach ($post in $jsonContent) {
                    $result += [PSCustomObject]@{
                        Date    = get-date $($post.date)
                        Title   = [System.Web.HttpUtility]::HtmlDecode($post.title.rendered)
                        Excerpt = [System.Web.HttpUtility]::HtmlDecode($post.excerpt.rendered) `
                            -replace '<\/?p>', ""
                    }
                }
            }
        }
            if ($result) {
                return $result
            }
        else {
            Throw $iwr.StatusCode
        }
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}
Get-WordPressPostSummary -url "powers-hell.com", "blog.vigilant.it"
