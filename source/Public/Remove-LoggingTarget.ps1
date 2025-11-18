<#
    .SYNOPSIS
        Remove a logging target
    .DESCRIPTION
        This function removes a previously configured logging target
    .PARAMETER DisplayName
        The DisplayName of the target to remove. If not specified, removes target by Type name
    .PARAMETER Name
        Alias for DisplayName parameter (maintained for backward compatibility)
    .PARAMETER Type
        The type of target to remove (used when DisplayName is not specified)
    .EXAMPLE
        PS C:\> Remove-LoggingTarget -DisplayName 'ErrorsOnly'

        Removes the target with DisplayName 'ErrorsOnly'
    .EXAMPLE
        PS C:\> Remove-LoggingTarget -Name Console

        Removes the Console target (backward compatibility)
    .EXAMPLE
        PS C:\> Remove-LoggingTarget -Type File

        Removes the File target (if only one exists)
    .LINK
        https://logging.readthedocs.io/en/latest/functions/Remove-LoggingTarget.md
    .LINK
        https://logging.readthedocs.io/en/latest/functions/Add-LoggingTarget.md
#>
function Remove-LoggingTarget
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'No system state changed.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Writes help when input is incorrect')]
    [CmdletBinding(DefaultParameterSetName = 'ByDisplayName', HelpUri = 'https://logging.readthedocs.io/en/latest/functions/Remove-LoggingTarget.md')]
    param(
        [Parameter(ParameterSetName = 'ByDisplayName', Position = 0)]
        [Alias('Name')]
        [string] $DisplayName,

        [Parameter(ParameterSetName = 'ByType', Mandatory)]
        [string] $Type
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByType')
    {
        # Remove by Type - find targets with matching Type property
        $targetsToRemove = @()
        foreach ($targetEntry in $Script:Logging.EnabledTargets.GetEnumerator())
        {
            $targetConfig = $targetEntry.Value
            $targetType = if ($targetConfig.ContainsKey('Type'))
            {
                $targetConfig.Type
            }
            else
            {
                $targetEntry.Key  # Fallback for legacy configurations
            }

            if ($targetType -eq $Type)
            {
                $targetsToRemove += $targetEntry.Key
            }
        }

        if ($targetsToRemove.Count -eq 0)
        {
            Write-Warning "No logging targets of type '$Type' found"
            return
        }

        if ($targetsToRemove.Count -gt 1)
        {
            Write-Warning "Multiple targets of type '$Type' found: $($targetsToRemove -join ', '). Use -DisplayName to remove a specific target."
            return
        }

        $DisplayName = $targetsToRemove[0]
    }

    # If no DisplayName provided, list available targets
    if (-not $DisplayName)
    {
        if ($Script:Logging.EnabledTargets.Count -eq 0)
        {
            Write-Warning 'No logging targets are currently configured'
            return
        }

        Write-Host 'Available logging targets:'
        foreach ($targetEntry in $Script:Logging.EnabledTargets.GetEnumerator())
        {
            $targetConfig = $targetEntry.Value
            $targetType = if ($targetConfig.ContainsKey('Type'))
            {
                $targetConfig.Type
            }
            else
            {
                $targetEntry.Key
            }
            Write-Host "  DisplayName: $($targetEntry.Key), Type: $targetType"
        }
        Write-Host 'Use -DisplayName to specify which target to remove'
        return
    }

    # Check if target exists
    if (-not $Script:Logging.EnabledTargets.ContainsKey($DisplayName))
    {
        Write-Warning "Logging target with DisplayName '$DisplayName' not found"
        if ($Script:Logging.EnabledTargets.Count -gt 0)
        {
            Write-Host "Available targets: $($Script:Logging.EnabledTargets.Keys -join ', ')"
        }
        return
    }

    # Get target info for confirmation message
    $targetConfig = $Script:Logging.EnabledTargets[$DisplayName]
    $targetType = if ($targetConfig.ContainsKey('Type'))
    {
        $targetConfig.Type
    }
    else
    {
        $DisplayName
    }

    # Remove the target
    $removed = $Script:Logging.EnabledTargets.TryRemove($DisplayName, [ref]$null)

    if ($removed)
    {
        Write-Verbose "Successfully removed logging target '$DisplayName' (Type: $targetType)"

        # If this was the last target, inform the user
        if ($Script:Logging.EnabledTargets.Count -eq 0)
        {
            Write-Verbose 'No logging targets remain configured. Logging will continue but no output will be generated until targets are added.'
        }
    }
    else
    {
        Write-Warning "Failed to remove logging target '$DisplayName'"
    }
}
