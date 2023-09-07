function Set-LoggingVariables
{
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
    $Script:DEBUG = 10
    $Script:VERBOSE = 14
    $Script:INFO = 20
    $Script:NOTICE = 24
    $Script:SUCCESS = 26
    $Script:WARNING = 30
    $Script:ERROR_ = 40
    $Script:CRITIAL = 50
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
                $CRITIAL    = 'CRITICAL'
                $ALERT      = 'ALERT'
                $EMERGENCY  = 'EMERGENCY'
                'NOTSET'    = $NOTSET
                'ERROR'     = $ERROR_
                'WARNING'   = $WARNING
                'INFO'      = $INFO
                'DEBUG'     = $DEBUG
                'VERBOSE'   = $VERBOSE
                'NOTICE'    = $NOTICE
                'SUCCESS'   = $SUCCESS
                'CRITIAL'   = $CRITICAL
                'ALERT'     = $ALERT
                'EMERGENCY' = $EMERGENCY
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
