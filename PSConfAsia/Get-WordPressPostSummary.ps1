function Get-WordPressPostSummary {
    [CmdletBinding()]
    param (
        [string[]]$url
    )
    try {
        $result = @()
        foreach ($blog in $url) {
            $hostName = $blog -replace '(^http:\/\/)|(\/$)', ''
            try {
                $iwr = Invoke-WebRequest -Method Get -UseBasicParsing `
                    -Uri "http://$($hostName)/wp-json/wp/v2/posts"
                
            }
            catch {
                $iwr = Invoke-WebRequest -Method Get -UseBasicParsing `
                    -Uri "http://$($hostName)/?rest_route=/wp/v2/posts"
            }
            if ($iwr.StatusCode -eq 200) {
                $jsonContent = $iwr.Content | ConvertFrom-Json
                foreach ($post in $jsonContent) {
                    $result += [PSCustomObject]@{
                        Date    = get-date $($post.date)
                        Link    = [System.Web.HttpUtility]::HtmlDecode($post.link)
                        Title   = [System.Web.HttpUtility]::HtmlDecode($post.title.rendered)
                        Excerpt = [System.Web.HttpUtility]::HtmlDecode($post.excerpt.rendered) `
                            -replace '\<\/?.*?\>', ""
                    }
                }
            }
        }
        if ($result) {
            return $result | Sort-Object -Property Date -Descending
        }
        else {
            Throw $iwr.StatusCode
        }
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}
Get-WordPressPostSummary -url "blog.vigilant.it", "powers-hell.com", "steven.hosking.com.au"
