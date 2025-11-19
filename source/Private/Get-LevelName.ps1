<#
    .SYNOPSIS
        Gets the name of a logging level from its numeric value

    .DESCRIPTION
        This function retrieves the string name of a logging level based on its numeric value.
        If the level number is not found in the defined levels, it returns a generic 'Level X' format.

    .PARAMETER Level
        The numeric value of the logging level to get the name for

    .EXAMPLE
        PS C:\> Get-LevelName -Level 20
        INFO

        Gets the name for logging level 20, which returns 'INFO'

    .EXAMPLE
        PS C:\> Get-LevelName -Level 999
        Level 999

        Gets the name for an undefined logging level, which returns 'Level 999'

    .OUTPUTS
        System.String
        Returns the string name of the logging level

    .NOTES
        This is an internal function used by the PSLogs module to convert numeric
        logging levels to their string representations.
#>
function Get-LevelName
{
    [CmdletBinding()]
    param(
        [int] $Level
    )

    $l = $Script:LevelNames[$Level]
    if ($l)
    {
        return $l
    }
    else
    {
        return ('Level {0}' -f $Level)
    }
}
