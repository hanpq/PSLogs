function Set-LoggingVariables
{
    <#
    .SYNOPSIS
        Initializes the core PSLogs module variables and data structures

    .DESCRIPTION
        This function sets up all the essential variables and data structures used by the
        PSLogs module. It creates logging levels, level name mappings, default configurations,
        and the main logging hashtable with thread-safe collections for targets and
        enabled targets. This function is called during module initialization and ensures
        idempotent operation by checking if variables are already set up.

    .EXAMPLE
        PS C:\> Set-LoggingVariables

        Initializes all PSLogs module variables if they haven't been set up already

    .NOTES
        This is an internal initialization function called during module import.

        The function creates:
        - Logging level constants (NOTSET=0, DEBUG=10, INFO=20, etc.)
        - LevelNames hashtable for bidirectional level/name mapping
        - ScriptRoot variable pointing to the module directory
        - Defaults hashtable with default level, format, and caller scope
        - Main Logging hashtable with thread-safe concurrent dictionaries

        The function is idempotent - it will return early if variables are already initialized.
        All collections use thread-safe implementations to support the async logging architecture.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Ignored as of now, this is inherited from the original module. This is a internal module cmdlet so the user is not impacted by this.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Does not alter system state')]
    param()
    #Already setup
    if ($Script:Logging -and $Script:LevelNames)
    {
        return
    }

    Write-Verbose -Message 'Setting up vars'

    $Script:NOTSET = 0
    $Script:SQL = 5
    $Script:DEBUG = 10
    $Script:VERBOSE = 14
    $Script:INFO = 20
    $Script:NOTICE = 24
    $Script:SUCCESS = 26
    $Script:WARNING = 30
    $Script:ERROR_ = 40
    $Script:CRITICAL = 50
    $Script:ALERT = 60
    $Script:EMERGENCY = 70

    New-Variable -Name LevelNames           -Scope Script -Option ReadOnly -Value ([hashtable]::Synchronized(@{
                $NOTSET     = 'NOTSET'
                $ERROR_     = 'ERROR'
                $WARNING    = 'WARNING'
                $INFO       = 'INFO'
                $DEBUG      = 'DEBUG'
                $VERBOSE    = 'VERBOSE'
                $NOTICE     = 'NOTICE'
                $SUCCESS    = 'SUCCESS'
                $CRITICAL   = 'CRITICAL'
                $ALERT      = 'ALERT'
                $EMERGENCY  = 'EMERGENCY'
                $SQL        = 'SQL'
                'NOTSET'    = $NOTSET
                'ERROR'     = $ERROR_
                'WARNING'   = $WARNING
                'INFO'      = $INFO
                'DEBUG'     = $DEBUG
                'VERBOSE'   = $VERBOSE
                'NOTICE'    = $NOTICE
                'SUCCESS'   = $SUCCESS
                'CRITICAL'  = $CRITICAL
                'ALERT'     = $ALERT
                'EMERGENCY' = $EMERGENCY
                'SQL'       = $SQL
            }))

    New-Variable -Name ScriptRoot           -Scope Script -Option ReadOnly -Value ([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Module.Path))
    New-Variable -Name Defaults             -Scope Script -Option ReadOnly -Value @{
        Level       = $LevelNames[$LevelNames['NOTSET']]
        LevelNo     = $LevelNames['NOTSET']
        Format      = '[%{timestamp:+%Y-%m-%d %T%Z}] [%{level:-7}] %{message}'
        Timestamp   = '%Y-%m-%d %T%Z'
        CallerScope = 1
    }

    New-Variable -Name Logging              -Scope Script -Option ReadOnly -Value ([hashtable]::Synchronized(@{
                Level          = $Defaults.Level
                LevelNo        = $Defaults.LevelNo
                Format         = $Defaults.Format
                CallerScope    = $Defaults.CallerScope
                CustomTargets  = [String]::Empty
                Targets        = ([System.Collections.Concurrent.ConcurrentDictionary[string, hashtable]]::new([System.StringComparer]::OrdinalIgnoreCase))
                EnabledTargets = ([System.Collections.Concurrent.ConcurrentDictionary[string, hashtable]]::new([System.StringComparer]::OrdinalIgnoreCase))
            }))
}
