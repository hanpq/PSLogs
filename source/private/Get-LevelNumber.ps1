<#
    .SYNOPSIS
        Gets the numeric value of a logging level from its name or validates a numeric level

    .DESCRIPTION
        This function converts a logging level name to its numeric value, or validates that
        a numeric level is valid. It accepts both string level names (like 'INFO', 'ERROR')
        and integer level numbers. If the level is invalid, it throws an exception.

    .PARAMETER Level
        The logging level to convert or validate. Can be either a string name (e.g., 'INFO')
        or an integer number (e.g., 20)

    .EXAMPLE
        PS C:\> Get-LevelNumber -Level 'INFO'
        20

        Converts the string level name 'INFO' to its numeric value 20

    .EXAMPLE
        PS C:\> Get-LevelNumber -Level 30
        30

        Validates that numeric level 30 is valid and returns it

    .EXAMPLE
        PS C:\> Get-LevelNumber -Level 'INVALID'

        Throws an exception because 'INVALID' is not a valid level name

    .OUTPUTS
        System.Int32
        Returns the numeric value of the logging level

    .NOTES
        This is an internal function used by the PSLogs module to normalize logging
        levels to their numeric representations for comparison and filtering.

        Valid level names include: NOTSET, SQL, DEBUG, VERBOSE, INFO, NOTICE, SUCCESS,
        WARNING, ERROR, CRITICAL, ALERT, EMERGENCY
#>
function Get-LevelNumber
{
    [CmdletBinding()]
    param(
        $Level
    )
    if ($Level -is [int] -and $Level -in $Script:LevelNames.Keys)
    {
        return $Level
    }
    elseif ([string] $Level -eq $Level -and $Level -in $Script:LevelNames.Keys)
    {
        return $Script:LevelNames[$Level]
    }
    else
    {
        throw ('Level not a valid integer or a valid string: {0}' -f $Level)
    }
}
