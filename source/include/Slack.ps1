@{
    Name          = 'Slack'
    Configuration = @{
        WebHook = @{Required = $true; Type = [string]; Default = $null }
        BotName = @{Required = $false; Type = [string]; Default = $null }
        Channel = @{Required = $false; Type = [string]; Default = $null }
        Icons   = @{Required = $false; Type = [hashtable]; Default = @{
                'ERROR'     = ':fire:'
                'WARNING'   = ':warning:'
                'INFO'      = ':exclamation:'
                'DEBUG'     = ':eyes:'
                'NOTICE'    = ':speech_balloon:'
                'VERBOSE'   = ':mag:'
                'SUCCESS'   = ':white_check_mark:'
                'CRITICAL'  = ':bangbang:'
                'ALERT'     = ':x:'
                'EMERGENCY' = ':red_circle:'
            }
        }
        Level   = @{Required = $false; Type = [string]; Default = $Logging.Level }
        Format  = @{Required = $false; Type = [string]; Default = $Logging.Format }
    }
    Logger        = {
        param(
            [hashtable] $Log,
            [hashtable] $Configuration
        )

        $Text = @{
            text = Format-Pattern -Pattern $Configuration.Format -Source $Log
        }

        if ($Configuration.BotName)
        {
            $Text['username'] = $Configuration.BotName
        }

        if ($Configuration.Channel)
        {
            $Text['channel'] = $Configuration.Channel
        }

        $Text['icon_emoji'] = $Configuration.Icons[$Log.LevelNo]

        $payload = 'payload={0}' -f ($Text | ConvertTo-Json -Compress)

        Invoke-RestMethod -Method POST -Uri $Configuration.WebHook -Body $payload | Out-Null
    }
}
