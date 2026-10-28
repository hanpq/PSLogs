@{
    Name          = 'Ntfy'
    Description   = 'Publishes formatted messages to an ntfy topic.'
    Configuration = @{
        Topic            = @{Required = $true; Type = [string]; Default = $null }
        Url              = @{Required = $false; Type = [string]; Default = $null }
        Token            = @{Required = $false; Type = [string]; Default = $null }
        Title            = @{Required = $false; Type = [string]; Default = $null }
        Priority         = @{Required = $false; Type = [int]; Default = 3 }
        NotificationTags = @{Required = $false; Type = [string[]]; Default = @() }
        Level            = @{Required = $false; Type = [string]; Default = $Logging.Level }
        Format           = @{Required = $false; Type = [string]; Default = $Logging.Format }
    }
    Init          = {
        param(
            [hashtable] $Configuration
        )

        if ($Configuration.Topic -cnotmatch '\A[A-Za-z0-9_-]+\z')
        {
            throw 'Ntfy Topic must contain only letters, numbers, underscores, and hyphens.'
        }

        $ServerUri = $null
        if (-not [uri]::TryCreate($Configuration.Url, [System.UriKind]::Absolute, [ref] $ServerUri) -or
            $ServerUri.Scheme -notin @('http', 'https') -or
            $ServerUri.Query -or $ServerUri.Fragment -or $ServerUri.UserInfo)
        {
            throw 'Ntfy Url must be an absolute HTTP or HTTPS server URL without credentials, a query, or a fragment.'
        }

        if ($Configuration.Priority -lt 1 -or $Configuration.Priority -gt 5)
        {
            throw 'Ntfy Priority must be between 1 (minimum) and 5 (maximum).'
        }
    }
    Logger        = {
        param(
            [hashtable] $Log,
            [hashtable] $Configuration
        )

        $Payload = @{
            topic    = $Configuration.Topic
            message  = Format-Pattern -Pattern $Configuration.Format -Source $Log
            priority = $Configuration.Priority
        }

        if (-not [string]::IsNullOrWhiteSpace($Configuration.Title))
        {
            $Payload.title = Format-Pattern -Pattern $Configuration.Title -Source $Log
        }

        if ($Configuration.NotificationTags.Count -gt 0)
        {
            $Payload.tags = @($Configuration.NotificationTags)
        }

        $Headers = @{}
        if (-not [string]::IsNullOrWhiteSpace($Configuration.Token))
        {
            $Headers.Authorization = 'Bearer {0}' -f $Configuration.Token
        }

        $Json = $Payload | ConvertTo-Json -Compress
        $Request = @{
            Uri         = $Configuration.Url.TrimEnd('/') + '/'
            Method      = 'POST'
            ContentType = 'application/json; charset=utf-8'
            Headers     = $Headers
            Body        = [System.Text.Encoding]::UTF8.GetBytes($Json)
            ErrorAction = 'Stop'
        }

        Invoke-RestMethod @Request | Out-Null
    }
}
