<#
    .SYNOPSIS
        Enable a logging target
    .DESCRIPTION
        This function configure and enable a logging target
    .PARAMETER Type
        The type of the target to enable and configure
    .PARAMETER Name
        Alias for Type parameter (maintained for backward compatibility)
    .PARAMETER DisplayName
        Unique identifier for this target instance. If not specified, defaults to the Type value
    .PARAMETER Configuration
        An hashtable containing the configurations for the target
    .EXAMPLE
        PS C:\> Add-LoggingTarget -Name Console -Configuration @{Level = 'DEBUG'}
    .EXAMPLE
        PS C:\> Add-LoggingTarget -Type File -DisplayName 'ErrorsOnly' -Configuration @{Level = 'ERROR'; Path = 'C:\Temp\errors.log'}
    .EXAMPLE
        PS C:\> Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = 'C:\Temp\script.log'}
    .LINK
        https://logging.readthedocs.io/en/latest/functions/Add-LoggingTarget.md
    .LINK
        https://logging.readthedocs.io/en/latest/functions/Write-Log.md
    .LINK
        https://logging.readthedocs.io/en/latest/AvailableTargets.md
    .LINK
        https://github.com/EsOsO/Logging/blob/master/Logging/public/Add-LoggingTarget.ps1
#>
function Add-LoggingTarget
{
    [CmdletBinding(HelpUri = 'https://logging.readthedocs.io/en/latest/functions/Add-LoggingTarget.md')]
    param(
        [Parameter(Position = 2)]
        [hashtable] $Configuration = @{}
    )

    dynamicparam
    {
        # Create Type parameter with Name as alias for backward compatibility
        $dictionary = New-LoggingDynamicParam -Name 'Type' -Target -Alias @('Name')

        # Add DisplayName parameter
        $displayNameAttribute = New-Object System.Management.Automation.ParameterAttribute
        $displayNameAttribute.Mandatory = $false
        $displayNameCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $displayNameCollection.Add($displayNameAttribute)
        $displayNameParam = New-Object System.Management.Automation.RuntimeDefinedParameter('DisplayName', [string], $displayNameCollection)
        $dictionary.Add('DisplayName', $displayNameParam)

        return $dictionary
    }

    end
    {
        # Determine target type (Type parameter or Name alias)
        $targetType = $PSBoundParameters.Type

        # Determine display name (use DisplayName if provided, otherwise use target type)
        $displayName = if ($PSBoundParameters.DisplayName)
        {
            $PSBoundParameters.DisplayName
        }
        else
        {
            $targetType
        }

        # Allow replacing existing targets with same DisplayName for backward compatibility
        if ($Script:Logging.EnabledTargets.ContainsKey($displayName))
        {
            Write-Verbose "Replacing existing logging target with DisplayName '$displayName'"
        }

        # Validate that the target type exists
        if (-not $Script:Logging.Targets.ContainsKey($targetType))
        {
            throw "Logging target type '$targetType' is not available. Available targets: $($Script:Logging.Targets.Keys -join ', ')"
        }

        # Create target configuration with type and display name metadata
        $targetConfig = Merge-DefaultConfig -Target $targetType -Configuration $Configuration
        $targetConfig.Type = $targetType
        $targetConfig.DisplayName = $displayName

        $Script:Logging.EnabledTargets[$displayName] = $targetConfig

        # Special case hack - resolve target file path if it's a relative path
        # This can't be done in the Init scriptblock of the logging target because that scriptblock gets created in the
        # log consumer runspace and doesn't inherit the current SessionState. That means that the scriptblock doesn't know the
        # current working directory at the time when `Add-LoggingTarget` is being called and can't accurately resolve the relative path.
        if ($targetType -eq 'File')
        {
            $Script:Logging.EnabledTargets[$displayName].Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Configuration.Path)
        }

        if ($Script:Logging.Targets[$targetType].Init -is [scriptblock])
        {
            & $Script:Logging.Targets[$targetType].Init $Script:Logging.EnabledTargets[$displayName]
        }
    }
}
