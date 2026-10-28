BeforeAll {
    $ProjectPath = (Resolve-Path "$PSScriptRoot\..\..").Path
    . "$ProjectPath\source\Private\Format-Pattern.ps1"
    $Logging = @{ Level = 'DEBUG'; Format = '[%{level}] %{message}' }
    $Target = . "$ProjectPath\source\include\Ntfy.ps1"
}

Describe -Tags Targets, TargetNtfy 'Ntfy target' {
    BeforeEach {
        $Configuration = @{}
        foreach ($Key in $Target.Configuration.Keys)
        {
            $Configuration[$Key] = $Target.Configuration[$Key].Default
        }
        $Configuration.Url = 'https://ntfy.example.test'
        $Configuration.Topic = 'pslogs-test'
        $Log = @{ Level = 'INFO'; Message = 'Hello, ntfy!' }
        # Unit tests never invoke the real HTTP cmdlet, including tests using the default URL.
        Mock Invoke-RestMethod { @{ id = 'test-notification' } }
    }

    It 'requires only a topic and uses module level and format defaults' {
        $Target.Name | Should -Be 'Ntfy'
        @($Target.Configuration.Keys | Where-Object { $Target.Configuration[$_].Required }) |
            Should -Be @('Topic')
        $Configuration.Priority | Should -Be 3
        $Configuration.Level | Should -Be $Logging.Level
        $Configuration.Format | Should -Be $Logging.Format
        { & $Target.Init $Configuration } | Should -Not -Throw
    }

    It 'posts a formatted JSON message to the server root without pipeline output' {
        $Result = & $Target.Logger $Log $Configuration

        $Result | Should -BeNullOrEmpty
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Payload = [System.Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
            $Uri -eq 'https://ntfy.example.test/' -and $Method -eq 'POST' -and
            $ContentType -eq 'application/json; charset=utf-8' -and $ErrorAction -eq 'Stop' -and
            $Payload.topic -eq 'pslogs-test' -and $Payload.message -eq '[INFO] Hello, ntfy!' -and
            $Payload.priority -eq 3 -and @($Payload.PSObject.Properties).Count -eq 3 -and
            $Headers.Count -eq 0
        }
    }

    It 'supports a self-hosted server, token, formatted title, priority and notification tags' {
        $Configuration.Url = 'https://ntfy.example.test/notifications/'
        $Configuration.Token = 'test-token'
        $Configuration.Title = 'PSLogs: %{level}'
        $Configuration.Priority = 5
        $Configuration.NotificationTags = [string[]] @('warning', 'computer')
        $Configuration.Tags = @('routing-only')
        $Configuration.Format = '%{message}'

        & $Target.Init $Configuration
        & $Target.Logger $Log $Configuration

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Payload = [System.Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
            $Uri -eq 'https://ntfy.example.test/notifications/' -and
            $Headers.Authorization -eq 'Bearer test-token' -and
            $Payload.title -eq 'PSLogs: INFO' -and $Payload.priority -eq 5 -and
            $Payload.message -eq 'Hello, ntfy!' -and
            ($Payload.tags -join ',') -eq 'warning,computer'
        }
    }

    It 'preserves Unicode, newlines and JSON special characters' {
        $Log.Message = "Hello, $([char]0x4e16)$([char]0x754c)!`n`"quoted`" \path"
        $Configuration.Title = "Title $([char]0x00e5)"
        & $Target.Logger $Log $Configuration

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Body -is [byte[]] -and
            ([System.Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json).message -eq "[INFO] $($Log.Message)" -and
            ([System.Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json).title -eq $Configuration.Title
        }
    }

    It 'serializes a single notification tag as an array' {
        $Configuration.NotificationTags = [string[]] @('warning')
        & $Target.Logger $Log $Configuration

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Payload = [System.Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
            $Payload.tags -is [array] -and $Payload.tags.Count -eq 1 -and $Payload.tags[0] -eq 'warning'
        }
    }

    It 'accepts priority <Priority>' -ForEach @(
        @{ Priority = 1 }
        @{ Priority = 5 }
    ) {
        $Configuration.Priority = $Priority
        { & $Target.Init $Configuration } | Should -Not -Throw
    }

    It 'rejects priority <Priority>' -ForEach @(
        @{ Priority = 0 }
        @{ Priority = 6 }
    ) {
        $Configuration.Priority = $Priority
        { & $Target.Init $Configuration } | Should -Throw '*Priority must be between*'
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'rejects invalid topic "<Topic>"' -ForEach @(
        @{ Topic = '' }
        @{ Topic = ' ' }
        @{ Topic = 'topic/path' }
        @{ Topic = 'topic?query' }
        @{ Topic = "topic`nheader" }
        @{ Topic = "topic`n" }
    ) {
        $Configuration.Topic = $Topic
        { & $Target.Init $Configuration } | Should -Throw '*Topic must contain only*'
    }

    It 'rejects invalid server URL "<Url>"' -ForEach @(
        @{ Url = '' }
        @{ Url = 'not-a-url' }
        @{ Url = 'ftp://example.test' }
        @{ Url = 'https://example.test/?query=1' }
        @{ Url = 'https://example.test/#fragment' }
        @{ Url = 'https://user:password@example.test' }
    ) {
        $Configuration.Url = $Url
        { & $Target.Init $Configuration } | Should -Throw '*Url must be an absolute*'
    }

    It 'propagates publishing failures to the logging manager' {
        Mock Invoke-RestMethod { throw 'ntfy publishing failed' }
        { & $Target.Logger $Log $Configuration } | Should -Throw '*ntfy publishing failed*'
    }
}

Describe -Tags Targets, TargetNtfy 'Ntfy module integration' {
    BeforeAll {
        Remove-Module PSLogs -Force -ErrorAction SilentlyContinue
        $Manifest = Get-ChildItem "$ProjectPath\output\PSLogs" -Recurse -Filter PSLogs.psd1 |
            Select-Object -First 1
        Import-Module $Manifest.FullName -Force -ErrorAction Stop
    }

    AfterAll {
        Remove-Module PSLogs -Force -ErrorAction SilentlyContinue
    }

    AfterEach {
        if ((Get-LoggingTarget).ContainsKey('Ntfy'))
        {
            Remove-LoggingTarget -UniqueName Ntfy
        }
    }

    It 'is discovered and requires Topic' {
        $Targets = Get-LoggingAvailableTarget
        $Targets.Ntfy | Should -Not -BeNullOrEmpty
        $Targets.Ntfy.ParamsRequired | Should -Be @('Topic')
        { Add-LoggingTarget -Type Ntfy } | Should -Throw '*Topic is required*'
    }

    It 'merges defaults and keeps routing tags separate from notification tags' {
        Add-LoggingTarget -Type Ntfy -Configuration @{
            Url = 'http://127.0.0.1:1/'
            Topic = 'pslogs-test'
            NotificationTags = [string[]] @('warning')
            Tags = @('Operations')
        }
        $Enabled = (Get-LoggingTarget).Ntfy
        $Enabled.Url | Should -Be 'http://127.0.0.1:1/'
        $Enabled.Priority | Should -Be 3
        $Enabled.NotificationTags | Should -Be @('warning')
        $Enabled.Tags | Should -Be @('operations')
        $Enabled.Type | Should -Be 'Ntfy'
    }

    It 'publishes a UTF-8 notification from the consumer runspace to a local HTTP server' {
        $PortProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $PortProbe.Start()
        $Port = $PortProbe.LocalEndpoint.Port
        $PortProbe.Stop()
        $Url = "http://127.0.0.1:$Port/"
        $Listener = [System.Net.HttpListener]::new()
        $Listener.Prefixes.Add($Url)

        try
        {
            $Listener.Start()
            $PendingRequest = $Listener.BeginGetContext($null, $null)
            Add-LoggingTarget -Type Ntfy -Configuration @{
                Url = $Url
                Topic = 'local-test'
                Token = 'local-test-token'
                Format = '%{message}'
                Level = 'WARNING'
                Tags = @('Operations')
                NotificationTags = [string[]] @('warning')
            }
            $Message = "Notification $([char]0x4e16)$([char]0x754c)"
            Write-Log -Level INFO -Message 'Below threshold' -Tags Operations
            Write-Log -Level WARNING -Message 'Wrong route' -Tags Other
            Write-Log -Level WARNING -Message $Message -Tags Operations

            $PendingRequest.AsyncWaitHandle.WaitOne(10000) | Should -BeTrue
            $Context = $Listener.EndGetContext($PendingRequest)
            $Reader = [System.IO.StreamReader]::new($Context.Request.InputStream, [System.Text.Encoding]::UTF8)
            try
            {
                $Payload = $Reader.ReadToEnd() | ConvertFrom-Json
            }
            finally
            {
                $Reader.Dispose()
                $Context.Response.StatusCode = 200
                $Context.Response.Close()
            }

            $Context.Request.HttpMethod | Should -Be 'POST'
            $Context.Request.RawUrl | Should -Be '/'
            $Context.Request.ContentType | Should -Be 'application/json; charset=utf-8'
            $Context.Request.Headers['Authorization'] | Should -Be 'Bearer local-test-token'
            $Payload.topic | Should -Be 'local-test'
            $Payload.message | Should -Be $Message
            $Payload.tags | Should -Be @('warning')
            Wait-Logging
        }
        finally
        {
            $Listener.Close()
        }
    }
}
