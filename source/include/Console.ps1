@{
    Name          = 'Console'
    Description   = 'Writes messages to console with different colors.'
    Configuration = @{
        Level             = @{Required = $false; Type = [string]; Default = $Logging.Level }
        Format            = @{Required = $false; Type = [string]; Default = $Logging.Format }
        PrintException    = @{Required = $false; Type = [bool]; Default = $true }
        ColorMapping      = @{Required = $false; Type = [hashtable]; Default = @{
                'SQL'       = 'Magenta'
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
        ShortLevel        = @{Required = $false; Type = [bool]; Default = $false }
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

        # System.Drawing is not automatically loaded in PowerShell desktop edition, so we need to load it manually.
        if ($PSVersionTable.PSEdition -eq 'Desktop')
        {
            Add-Type -AssemblyName System.Drawing
        }
    }
    Logger        = {
        param(
            [hashtable] $Log,
            [hashtable] $Configuration
        )

        # Windows Powershell does not know about the "`e`" escape character, so we need to use the [char]0x1b instead to support Windows Powershell.
        $Esc = [char]0x1b

        function Get-RgbFromConsoleColor
        {
            param (
                [Parameter(Mandatory)]
                [System.ConsoleColor]$ConsoleColor
            )

            $colorMap = @{
                Black       = [System.Drawing.Color]::FromArgb(0, 0, 0)
                DarkBlue    = [System.Drawing.Color]::FromArgb(0, 0, 128)
                DarkGreen   = [System.Drawing.Color]::FromArgb(0, 128, 0)
                DarkCyan    = [System.Drawing.Color]::FromArgb(0, 128, 128)
                DarkRed     = [System.Drawing.Color]::FromArgb(128, 0, 0)
                DarkMagenta = [System.Drawing.Color]::FromArgb(128, 0, 128)
                DarkYellow  = [System.Drawing.Color]::FromArgb(128, 128, 0)
                Gray        = [System.Drawing.Color]::FromArgb(192, 192, 192)
                DarkGray    = [System.Drawing.Color]::FromArgb(128, 128, 128)
                Blue        = [System.Drawing.Color]::FromArgb(0, 0, 255)
                Green       = [System.Drawing.Color]::FromArgb(0, 255, 0)
                Cyan        = [System.Drawing.Color]::FromArgb(0, 255, 255)
                Red         = [System.Drawing.Color]::FromArgb(255, 0, 0)
                Magenta     = [System.Drawing.Color]::FromArgb(255, 0, 255)
                Yellow      = [System.Drawing.Color]::FromArgb(255, 255, 0)
                White       = [System.Drawing.Color]::FromArgb(255, 255, 255)
            }

            if ($colorMap.ContainsKey($ConsoleColor.ToString()))
            {
                $color = $colorMap[$ConsoleColor.ToString()]
                return "$($color.R);$($color.G);$($color.B)"
            }
            else
            {
                throw "Unsupported ConsoleColor: $ConsoleColor"
            }
        }

        function FormatColorTokens
        {
            param (
                [string]$InputString
            )
            $matches = [regex]::Matches($InputString, '\{(StartColor.*?|EndColor.*?)\}')

            foreach ($match in $matches)
            {
                $token = $match.Groups[1].Value

                if ($token -like 'StartColor*')
                {
                    $color = $token.split(':')[1]
                    $RGB = Get-RgbFromConsoleColor -ConsoleColor $color
                    $InputString = $InputString -replace $match.value, "$Esc[38;2;$($RGB)m"
                }
                elseif ($token -eq 'EndColor')
                {
                    $InputString = $InputString -replace '\{EndColor\}', "$Esc[0m"
                }
            }

            return $InputString

        }

        try
        {
            $OriginalLogLevel = $Log.Level
            if ($Configuration.ShortLevel)
            {
                $Log.Level = $Log.Level.ToString().Substring(0, 3)
            }
            $logText = Format-Pattern -Pattern $Configuration.Format -Source $Log

            if (![String]::IsNullOrWhiteSpace($Log.ExecInfo) -and $Configuration.PrintException)
            {
                $logText += "`n{0}" -f $Log.ExecInfo.Exception.Message
                $logText += "`n{0}" -f (($Log.ExecInfo.ScriptStackTrace -split "`r`n" | ForEach-Object { "`t{0}" -f $_ }) -join "`n")
            }

            $mtx = New-Object System.Threading.Mutex($false, 'ConsoleMtx')
            [void] $mtx.WaitOne()

            # Colorize tokens is only supported if OnlyColorizeLevel is set to true. Otherwise the whole row is colored and the tokens are not visible.
            if ($Configuration.OnlyColorizeLevel)
            {
                $logtext = FormatColorTokens -InputString $logtext
            }

            # If we have a color mapping for the log level, use it. Otherwise, just write the log text without color.
            if ($Configuration.ColorMapping.ContainsKey($OriginalLogLevel))
            {
                if ($Configuration.OnlyColorizeLevel)
                {
                    $RGB = Get-RgbFromConsoleColor -ConsoleColor $Configuration.ColorMapping[$OriginalLogLevel]
                    $logtext = $logtext.replace($log.level, "$Esc[38;2;$($RGB)m$($log.level)$Esc[0m")
                    $ParentHost.UI.WriteLine($logtext)
                }
                else
                {
                    $ParentHost.UI.WriteLine($Configuration.ColorMapping[$OriginalLogLevel], $ParentHost.UI.RawUI.BackgroundColor, $logText)
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
