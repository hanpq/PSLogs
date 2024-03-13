@{
    Name          = 'Email'
    Description   = 'Send log message to email recipients'
    Configuration = @{
        SMTPServer     = @{Required = $true; Type = [string]; Default = $null }
        From           = @{Required = $true; Type = [string]; Default = $null }
        To             = @{Required = $true; Type = [string]; Default = $null }
        Subject        = @{Required = $false; Type = [string]; Default = '[%{level:-7}] %{message}' }
        Credential     = @{Required = $false; Type = [pscredential]; Default = $null }
        Level          = @{Required = $false; Type = [string]; Default = $Logging.Level }
        Port           = @{Required = $false; Type = [int]; Default = 25 }
        UseSsl         = @{Required = $false; Type = [bool]; Default = $false }
        Format         = @{Required = $false; Type = [string]; Default = $Logging.Format }
        PrintException = @{Required = $false; Type = [bool]; Default = $false }
    }
    Logger        = {
        param(
            [hashtable] $Log,
            [hashtable] $Configuration
        )

        $Body = '<h3>{0}</h3>' -f $Log.Message

        if (![String]::IsNullOrWhiteSpace($Log.ExecInfo))
        {
            $Body += '<pre>'
            $Body += "`n{0}" -f $Log.ExecInfo.Exception.Message
            $Body += "`n{0}" -f (($Log.ExecInfo.ScriptStackTrace -split "`r`n" | ForEach-Object { "`t{0}" -f $_ }) -join "`n")
            $Body += '</pre>'
        }

        $Params = @{
            SmtpServer = $Configuration.SMTPServer
            From       = $Configuration.From
            To         = $Configuration.To.Split(',').Trim()
            Port       = $Configuration.Port
            UseSsl     = $Configuration.UseSsl
            Subject    = Format-Pattern -Pattern $Configuration.Subject -Source $Log
            Body       = $Body
            BodyAsHtml = $true
        }

        if ($Configuration.Credential)
        {
            $Params['Credential'] = $Configuration.Credential
        }

        if ($Log.Body)
        {
            # Previously the json was inserted on a single line. By splitting up the json
            # string into rows and adding <br> we can persist linebreaks in the email
            # message. We also replace spaces with a HTML token for space. This is also
            # stripped in the final email message.
            $Params.Body += "`n`n"
            ($Log.Body | ConvertTo-Json).Split("`n") | ForEach-Object {
                $Params.Body += "$PSItem<br>".Replace(' ', '&nbsp;')
            }
        }

        Send-MailMessage @Params
    }
}
