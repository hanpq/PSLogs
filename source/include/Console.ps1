@{
    Name          = 'Console'
    Description   = 'Writes messages to console with different colors.'
    Configuration = @{
        Level             = @{Required = $false; Type = [string]; Default = $Logging.Level }
        Format            = @{Required = $false; Type = [string]; Default = $Logging.Format }
        PrintException    = @{Required = $false; Type = [bool]; Default = $true }
        ColorMapping      = @{Required = $false; Type = [hashtable]; Default = @{
                'DEBUG'     = 'Cyan'
                'INFO'      = 'DarkGray'
                'WARNING'   = 'Yellow'
                'ERROR'     = 'Red'
                'NOTICE'    = 'Gray'
                'VERBOSE'   = 'Yellow'
                'SUCCESS'   = 'Green'
                'CRITICAL'  = 'Red'
                'ALERT'     = 'Red'
                'EMERGENCY' = 'Magenta'
            }
        }
        OnlyColorizeLevel = @{Required = $false; Type = [bool]; Default = $false }
    }
    Init          = {
        param(
            [hashtable] $Configuration
        )

        foreach ($Level in $Configuration.ColorMapping.Keys)
        {
            $Color = $Configuration.ColorMapping[$Level]

            if ($Color -notin ([System.Enum]::GetNames([System.ConsoleColor])))
            {
                $ParentHost.UI.WriteErrorLine("ERROR: Cannot use custom color '$Color': not a valid [System.ConsoleColor] value")
                continue
            }
        }
    }
    Logger        = {
        param(
            [hashtable] $Log,
            [hashtable] $Configuration
        )

        try
        {
            $ConsoleColors = @{
                Black       = '0;0;0'
                DarkBlue    = '0;0;128'
                DarkGreen   = '0;128;0'
                DarkCyan    = '0;128;128'
                DarkRed     = '128;0;0'
                DarkMagenta = '128;0;128'
                DarkYellow  = '128;128;0'
                Gray        = '192;192;192'
                DarkGray    = '128;128;128'
                Blue        = '0;0;255'
                Green       = '0;255;0'
                Cyan        = '0;255;255'
                Red         = '255;0;0'
                Magenta     = '255;0;255'
                Yellow      = '255;255;0'
                White       = '255;255;255'
            }

            $logText = Format-Pattern -Pattern $Configuration.Format -Source $Log

            if (![String]::IsNullOrWhiteSpace($Log.ExecInfo) -and $Configuration.PrintException)
            {
                $logText += "`n{0}" -f $Log.ExecInfo.Exception.Message
                $logText += "`n{0}" -f (($Log.ExecInfo.ScriptStackTrace -split "`r`n" | ForEach-Object { "`t{0}" -f $_ }) -join "`n")
            }

            $mtx = New-Object System.Threading.Mutex($false, 'ConsoleMtx')
            [void] $mtx.WaitOne()

            if ($Configuration.ColorMapping.ContainsKey($Log.Level))
            {
                if ($Configuration.OnlyColorizeLevel)
                {
                    $logtext = $logtext.replace($log.level, "`e[38;2;$($ConsoleColors.$($Configuration.ColorMapping[$Log.Level]))m$($log.level)`e[0m")
                    $ParentHost.UI.WriteLine($logtext)
                }
                else
                {
                    $ParentHost.UI.WriteLine($Configuration.ColorMapping[$Log.Level], $ParentHost.UI.RawUI.BackgroundColor, $logText)
                }
            }
            else
            {
                $ParentHost.UI.WriteLine($logText)
            }

            [void] $mtx.ReleaseMutex()
            $mtx.Dispose()
        }
        catch
        {
            $ParentHost.UI.WriteErrorLine($_)
        }
    }
}
