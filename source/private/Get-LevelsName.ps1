<#
    .SYNOPSIS
        Gets all available logging level names

    .DESCRIPTION
        This function retrieves all available logging level names from the PSLogs module.
        It returns only the string names of the levels (not the numeric values) in
        alphabetical order.

    .EXAMPLE
        PS C:\> Get-LevelsName
        ALERT
        CRITICAL
        DEBUG
        EMERGENCY
        ERROR
        INFO
        NOTICE
        NOTSET
        SQL
        SUCCESS
        VERBOSE
        WARNING

        Returns all available logging level names in sorted order

    .OUTPUTS
        System.String[]
        Returns an array of string level names

    .NOTES
        This is an internal function used by the PSLogs module to provide a list of
        valid level names for validation and dynamic parameter creation.

        The function filters out numeric keys from the LevelNames hashtable to return
        only the string representations.
#>
function Get-LevelsName
{
    [CmdletBinding()]
    param()

    return $Script:LevelNames.Keys | Where-Object { $_ -isnot [int] } | Sort-Object
}
