<#
    .SYNOPSIS
        Stops the asynchronous logging consumer runspace and cleans up resources

    .DESCRIPTION
        This function gracefully shuts down the background consumer runspace by marking
        the message queue as completed, waiting for the consumer to finish processing
        remaining messages, and then disposing of all resources including the runspace,
        queue, and event handlers. It ensures proper cleanup to prevent resource leaks.

    .EXAMPLE
        PS C:\> Stop-LoggingManager

        Stops the logging manager and cleans up all resources

    .NOTES
        This is an internal function that is automatically called when:
        - The PSLogs module is being unloaded
        - PowerShell is exiting
        - Manual cleanup is requested

        The function performs the following cleanup steps:
        1. Marks the message queue as complete (no new messages accepted)
        2. Waits for the consumer runspace to finish processing remaining messages
        3. Disposes the PowerShell runspace and associated resources
        4. Unregisters event handlers and module removal callbacks
        5. Removes script-scoped variables

        After this function completes, a new Start-LoggingManager call would be
        required to resume logging operations.
#>
function Stop-LoggingManager
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Does not alter system state')]
    param ()

    $Script:LoggingEventQueue.CompleteAdding()
    $Script:LoggingEventQueue.Dispose()

    [void] $Script:LoggingRunspace.Powershell.EndInvoke($Script:LoggingRunspace.Handle)
    [void] $Script:LoggingRunspace.Powershell.Dispose()

    $ExecutionContext.SessionState.Module.OnRemove = $null
    Get-EventSubscriber | Where-Object { $_.Action.Id -eq $Script:LoggingRunspace.EngineEventJob.Id } | Unregister-Event

    Remove-Variable -Scope Script -Force -Name LoggingEventQueue
    Remove-Variable -Scope Script -Force -Name LoggingRunspace
    Remove-Variable -Scope Script -Force -Name TargetsInitSync
}
