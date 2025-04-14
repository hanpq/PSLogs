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
    }
    Logger        = {
        param(
            [hashtable] $Log,
            [hashtable] $Configuration
        )

        function Get-RgbFromConsoleColor
        {
            param (
                [Parameter(Mandatory)]
                [System.ConsoleColor]$ConsoleColor
            )

            $colorMap = @{
                Black       = [System.Drawing.Color]::FromArgb(0, 0, 0)
                DarkBlue    = [System.Drawing.Color]::FromArgb(0, 0, 139)
                DarkGreen   = [System.Drawing.Color]::FromArgb(0, 100, 0)
                DarkCyan    = [System.Drawing.Color]::FromArgb(0, 139, 139)
                DarkRed     = [System.Drawing.Color]::FromArgb(139, 0, 0)
                DarkMagenta = [System.Drawing.Color]::FromArgb(139, 0, 139)
                DarkYellow  = [System.Drawing.Color]::FromArgb(184, 134, 11)
                Gray        = [System.Drawing.Color]::FromArgb(128, 128, 128)
                DarkGray    = [System.Drawing.Color]::FromArgb(169, 169, 169)
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
                    $InputString = $InputString -replace $match.value, "`e[38;2;$($RGB)m"
                }
                elseif ($token -eq 'EndColor')
                {
                    $InputString = $InputString -replace '\{EndColor\}', "`e[0m"
                }
            }

            return $InputString

        }

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

            if ($Configuration.ColorMapping.ContainsKey($OriginalLogLevel))
            {
                if ($Configuration.OnlyColorizeLevel)
                {
                    $RGB = Get-RgbFromConsoleColor -ConsoleColor $Configuration.ColorMapping[$OriginalLogLevel]
                    $logtext = $logtext.replace($log.level, "`e[38;2;$($($ConsoleColors.$($Configuration.ColorMapping[$OriginalLogLevel]))))m$($log.level)`e[0m")
                    #$logtext = FormatColorTokens -InputString $logtext
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
