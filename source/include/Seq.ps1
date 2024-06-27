@{
    Name          = 'Seq'
    Description   = 'Sends log data to the designated Seq server web service'
    Configuration = @{
        Url        = @{Required = $true; Type = [string]; Default = $null }
        ApiKey     = @{Required = $false; Type = [string]; Default = $null }
        Properties = @{Required = $false; Type = [hashtable]; Default = $null }
        Level      = @{Required = $false; Type = [string]; Default = $Logging.Level }
    }
    Logger        = {
        param(
            [hashtable] $Log,
            [hashtable] $Configuration
        )
    
        $allProperties = @{}
        if($null -ne $Configuration.Properties)
        {
            $allProperties += $Configuration.Properties
        }

        # use all properies from log
        $allProperties += $Log
        
        # remove not needed values (dont need to safe data twice)
        $allProperties.Remove("args")
        $allProperties.Remove("message")
        $allProperties.Remove("level")
        $allProperties.Remove("levelno")
        $allProperties.Remove("rawmessage")
        $allProperties.Remove("timestamp")
        $allProperties.Remove("timestamputc")
        $allProperties.Remove("execinfo")

        # default use the already parsed message
        $messageTemplate = $Log.Message

        # check if there are any args given
        if ($Log.args.count -gt 0) {
            # args are given, use the raw message with {...} text
            $messageTemplate = $Log.RawMessage;

            # check if labels are given (same amount of labels are args are necessary)
            $labels_given = ($null -ne $Log.body.labels -and $Log.args.count -eq $Log.body.labels.count)

            foreach($argument in $Log.args) {
                if($labels_given) {
                    # labels are given, add the argument as a value and the label as the named index
                    $allProperties.Add($Log.body.labels[$Log.args.IndexOf($argument)], $argument)
                    # replace the messagetemplated e.g. {0} -> {named}
                    $messageTemplate = $messageTemplate.replace("{$($Log.args.IndexOf($argument))}", "{$($Log.body.labels[$Log.args.IndexOf($argument)])}")
                } else {
                    # no labels are given, add the number as an argument so seq can handle the text correctly
                    $allProperties.Add("$($Log.args.IndexOf($argument))", $argument)
                }
            }

            # remove the labels, they have added to allProperties already
            if($labels_given) {
                $allProperties.body.Remove("labels")
            }

        } else {
            $allProperties += @{ Text = $Log.Message; }
        }

        # if body is empty, remove it
        if($allProperties.body.count -eq 0) {
            $allProperties.Remove("body")
        }

        # exception handling
        $exception = $null
        if ($Log.ExecInfo) {
            $exception = $Log.ExecInfo.ToString()
            $exception += [System.Environment]::NewLine + $Log.ExecInfo.ScriptStackTrace
        }

        # use the 
        $Body = @{
            "Events" = @(
                @{
                    "Timestamp" = $Log.TimestampUtc
                    "Level" = $Log.Level.substring(0,1).toupper()+$Log.Level.substring(1).tolower()
                    "MessageTemplate" = $messageTemplate
                    "Properties" = $allProperties
                    "Exception" = $exception
                }
            )
        }

        if ($Configuration.ApiKey) {
            $Url = '{0}/api/events/raw?apiKey={1}' -f $Configuration.Url, $Configuration.ApiKey
        }
        else {
            $Url = '{0}/api/events/raw' -f $Configuration.Url
        }

        Invoke-RestMethod -Uri $Url -Body ($Body | ConvertTo-Json -Compress -Depth 5) -Method POST -ContentType "application/json" | Out-Null
    }
}
