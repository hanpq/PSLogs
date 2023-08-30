# The content of this file will be appended to the end of the psm1 module file. This is useful for custom procesedures after all module functions are loaded.
Set-LoggingVariables

Start-LoggingManager

<#

Stop-LoggingManager must be run to make sure the logging runspace is properly closed. Stop-LoggingManager is a private
function and is not accesible by the user. The following snippet makes sure Stop-LoggingManager is ran when the user run Remove-Module PSLogs.

This also solves an issue in the build process where the lingering runspace would cause the github action powershell task never
exited and froze the workflow.

#>
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = { Stop-LoggingManager }
