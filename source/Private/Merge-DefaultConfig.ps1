<#
    .SYNOPSIS
        Merges user configuration with default target configuration values

    .DESCRIPTION
        This function combines user-provided configuration parameters with the default
        configuration for a specific logging target. It validates that required parameters
        are provided, checks parameter types, and fills in default values for missing
        optional parameters.

    .PARAMETER Target
        The name of the logging target to merge configuration for (e.g., 'File', 'Console')

    .PARAMETER Configuration
        A hashtable containing user-provided configuration parameters for the target

    .EXAMPLE
        PS C:\> $config = @{ Path = 'C:\logs\app.log'; Level = 'INFO' }
        PS C:\> Merge-DefaultConfig -Target 'File' -Configuration $config

        Merges the user configuration with File target defaults, filling in missing
        values like Format, Encoding, etc.

    .EXAMPLE
        PS C:\> $config = @{ Level = 'DEBUG' }
        PS C:\> Merge-DefaultConfig -Target 'Console' -Configuration $config

        Merges the user configuration with Console target defaults

    .OUTPUTS
        System.Collections.Hashtable
        Returns a complete configuration hashtable with all required and optional
        parameters filled in

    .NOTES
        This is an internal function used by Add-LoggingTarget to ensure that all
        target configurations have the necessary parameters with appropriate default
        values and correct types.

        The function will throw exceptions if:
        - Required parameters are missing
        - Parameter types don't match the expected types for the target
#>
function Merge-DefaultConfig
{
    param(
        [string] $Target,
        [hashtable] $Configuration
    )

    $DefaultConfiguration = $Script:Logging.Targets[$Target].Defaults
    $ParamsRequired = $Script:Logging.Targets[$Target].ParamsRequired

    $result = @{}

    foreach ($Param in $DefaultConfiguration.Keys)
    {
        if ($Param -in $ParamsRequired -and $Param -notin $Configuration.Keys)
        {
            throw ('Configuration {0} is required for target {1}; please provide one of type {2}' -f $Param, $Target, $DefaultConfiguration[$Param].Type)
        }

        if ($Configuration.ContainsKey($Param))
        {
            if ($Configuration[$Param] -is $DefaultConfiguration[$Param].Type)
            {
                $result[$Param] = $Configuration[$Param]
            }
            else
            {
                throw ('Configuration {0} has to be of type {1} for target {2}' -f $Param, $DefaultConfiguration[$Param].Type, $Target)
            }
        }
        else
        {
            $result[$Param] = $DefaultConfiguration[$Param].Default
        }
    }

    return $result
}
