<#
    .SYNOPSIS
        Discovers and initializes all available logging targets

    .DESCRIPTION
        This function scans for and loads all logging target plugins from both the built-in
        targets directory and any custom targets directory. It processes each target's
        configuration schema, validates requirements, and registers them in the module's
        target registry for use with Add-LoggingTarget.

    .EXAMPLE
        PS C:\> Initialize-LoggingTarget

        Loads all available logging targets from the include directory and any custom paths

    .NOTES
        This is an internal function called during module initialization and when the
        consumer runspace starts. It performs the following operations:

        - Scans the built-in targets in the 'include' directory
        - Scans custom targets if a CustomTargets path is configured
        - Loads each target script and extracts its configuration schema
        - Registers targets in the $Script:Logging.Targets hashtable
        - Identifies required vs optional parameters for each target
        - Makes targets available for use with Add-LoggingTarget

        Each target plugin must return a hashtable with:
        - Name: Target identifier
        - Init: Initialization script block (optional)
        - Logger: Main logging script block
        - Description: Target description (optional)
        - Configuration: Parameter schema with types and defaults

        The function is idempotent and can be called multiple times safely.
#>
function Initialize-LoggingTarget
{
    param()

    $targets = @()
    $targets += Get-ChildItem "$ScriptRoot\include" -Filter '*.ps1'

    if ((![String]::IsNullOrWhiteSpace($Script:Logging.CustomTargets)) -and (Test-Path -Path $Script:Logging.CustomTargets -PathType Container))
    {
        $targets += Get-ChildItem -Path $Script:Logging.CustomTargets -Filter '*.ps1'
    }

    foreach ($target in $targets)
    {
        $module = . $target.FullName
        $Script:Logging.Targets[$module.Name] = @{
            Init           = $module.Init
            Logger         = $module.Logger
            Description    = $module.Description
            Defaults       = $module.Configuration
            ParamsRequired = $module.Configuration.GetEnumerator() | Where-Object { $_.Value.Required -eq $true } | Select-Object -ExpandProperty Name | Sort-Object
        }
    }
}
