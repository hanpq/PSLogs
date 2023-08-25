# The content of this file will be prepended to the top of the psm1 module file. This is useful for custom module setup is needed on import.
$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$PSModule = $ExecutionContext.SessionState.Module
$PSModuleRoot = $PSModule.ModuleBase
