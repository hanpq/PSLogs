
Import-Module 'D:\Repos\PSLogs\output\PSLogs' -Force

function Log
{
    param (
        [switch]$FormatColor = $false
    )
    $Level = @(
        'ERROR',
        'WARNING',
        'INFO',
        'DEBUG',
        'VERBOSE',
        'NOTICE',
        'SUCCESS',
        'CRITICAL',
        'ALERT',
        'EMERGENCY',
        'SQL'
    )
    foreach ($i in 1..3)
    {
        if ($FormatColor)
        {
            Write-Log -Level ($Level | Get-Random) -Message "Message {StartColor:Yellow}$i{EndColor}"
        }
        else
        {
            Write-Log -Level ($Level | Get-Random) -Message "Message $i"
        }
    }
}

Write-Host "Default format ('[%{timestamp:+%Y-%m-%d %T%Z}] [%{level:-7}] %{message}')"
Add-LoggingTarget -Name Console -Configuration @{
    ShortLevel        = $false
    OnlyColorizeLevel = $false
    Format            = '[%{timestamp:+%Y-%m-%d %T%Z}] [%{level:-7}] %{message}'
}
Log
Wait-Logging

Write-Host "`nDelimited with | ('%{timestamp:+yyyy-MM-dd HH:mm:ss:fff} | %{level} | %{message}')"
Add-LoggingTarget -Name Console -Configuration @{
    ShortLevel        = $false
    OnlyColorizeLevel = $false
    Format            = '%{timestamp:+yyyy-MM-dd HH:mm:ss:fff} | %{level} | %{message}'
}
Log
Wait-Logging

Write-Host "`nDelimited with | and static level length ('%{timestamp:+yyyy-MM-dd HH:mm:ss:fff} | %{level:-7} | %{message}')"
Add-LoggingTarget -Name Console -Configuration @{
    ShortLevel        = $false
    OnlyColorizeLevel = $false
    Format            = '%{timestamp:+yyyy-MM-dd HH:mm:ss:fff} | %{level:-7} | %{message}'
}
Log
Wait-Logging


Write-Host "`nDelimited with | short level ('%{timestamp:+yyyy-MM-dd HH:mm:ss:fff} | %{level} | %{message}')"
Add-LoggingTarget -Name Console -Configuration @{
    ShortLevel        = $true
    OnlyColorizeLevel = $false
    Format            = '%{timestamp:+yyyy-MM-dd HH:mm:ss:fff} | %{level} | %{message}'
}
Log
Wait-Logging

Write-Host "`nDelimited with | and static level length and colorize level ('%{timestamp:+yyyy-MM-dd HH:mm:ss} | %{level:-7} | %{message}')"
Add-LoggingTarget -Name Console -Configuration @{
    ShortLevel        = $false
    OnlyColorizeLevel = $true
    Format            = '%{timestamp:+yyyy-MM-dd HH:mm:ss} | %{level:-7} | %{message}'
}
Log -FormatColor
Wait-Logging

Write-Host "`nDelimited with | and static level length and colorize level ('%{timestamp:+yyyy-MM-dd HH:mm:ss} | %{level:-7} | %{message}')"
Add-LoggingTarget -Name Console -Configuration @{
    ShortLevel        = $false
    OnlyColorizeLevel = $true
    Format            = '{StartColor:Blue}%{timestamp:+yyyy-MM-dd HH:mm:ss}{EndColor} | %{level:-7} | %{message}'
}
Log -FormatColor
Wait-Logging


Remove-Module PSLogs
