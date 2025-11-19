# PSLogs

This project has adopted the following policies [![CodeOfConduct](https://img.shields.io/badge/Code%20Of%20Conduct-gray)](https://github.com/hanpq/PSLogs/blob/main/.github/CODE_OF_CONDUCT.md) [![Contributing](https://img.shields.io/badge/Contributing-gray)](https://github.com/hanpq/PSLogs/blob/main/.github/CONTRIBUTING.md) [![Security](https://img.shields.io/badge/Security-gray)](https://github.com/hanpq/PSLogs/blob/main/.github/SECURITY.md)

## Project status
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/hanpq/PSLogs/build.yml?branch=main&label=build&logo=github)](https://github.com/hanpq/PSLogs/actions/workflows/build.yml) [![Codecov](https://img.shields.io/codecov/c/github/hanpq/PSLogs?logo=codecov&token=qJqWlwMAiD)](https://codecov.io/gh/hanpq/PSLogs) [![Platform](https://img.shields.io/powershellgallery/p/PSLogs?logo=ReasonStudios)](https://img.shields.io/powershellgallery/p/PSLogs) [![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PSLogs?label=downloads)](https://www.powershellgallery.com/packages/PSLogs) [![License](https://img.shields.io/github/license/hanpq/PSLogs)](https://github.com/hanpq/PSLogs/blob/main/LICENSE) [![docs](https://img.shields.io/badge/docs-getps.dev-blueviolet)](https://getps.dev/modules/PSLogs/getstarted) [![changelog](https://img.shields.io/badge/changelog-getps.dev-blueviolet)](https://github.com/hanpq/PSLogs/blob/main/CHANGELOG.md) ![GitHub release (latest SemVer including pre-releases)](https://img.shields.io/github/v/release/hanpq/PSLogs?label=version&sort=semver) ![GitHub release (latest SemVer including pre-releases)](https://img.shields.io/github/v/release/hanpq/PSLogs?include_prereleases&label=prerelease&sort=semver)

## About

PSLogs is a fork of the [Logging][module] module created by [Massimo Bonvicini][github]. Sadly the project is no longer maintained. In the readme in the original repo the author encourages people to reach out to become the owner of the repo so that it can continue to be developed. I've done this but have not gotten any response. Therefor I have forked the project to continue development of the module.

There are a number of logging modules out there, most of them are quite simple and performs the task of logging to console and file very well. What is different with this module (that I really like) is that the logging target is split up into plugins. Of course there is console and file but a number of other targets like elastic search, email, slack, teams, winevent etc. 

I've written a couple of targets myself like SQLite and GELF.

Another reason I really like this logging module is that the logging is disconnected from the script that requests logs to be written. The logging is performed in another thread and therefore the execution of the main script is much less impacted by each logging operation.

## Installation

### PowerShell Gallery

To install from the PowerShell gallery using PowerShellGet run the following command:

```powershell
Install-Module PSLogs -Scope CurrentUser
```

# Usage

## TL;DR

```powershell
Set-LoggingDefaultLevel -Level 'WARNING'
Add-LoggingTarget -Name Console
Add-LoggingTarget -Name File -Configuration @{Path = 'C:\Temp\example_%{+%Y%m%d}.log'}

$Level = 'DEBUG', 'INFO', 'WARNING', 'ERROR'
foreach ($i in 1..100) {
    Write-Log -Level ($Level | Get-Random) -Message 'Message n. {0}' -Arguments $i
    Start-Sleep -Milliseconds (Get-Random -Min 100 -Max 1000)
}

Wait-Logging        # See Note
```

### NOTE

When used in *unattended* scripts (scheduled tasks, spawned process) you need to call `Wait-Logging` to avoid loosing messages. If you run your main script in an interactive shell that stays open at the end of the execution you could avoid using it (keep in mind that if there are messeages in the queue when you close the shell, you'll lose them)

## Configuration

The following section describe how to configure the Logging module.

- Level
- Format
- Targets
- CustomTargets

### Level

There are two aspects of the log level. First the level of each log message and secondly what levels should be logged to the targets. Each target can be configured to a logging level meaning that you might want to log DEBUG and higher to file but only VERBOSE and higher to console. You can also define a default logging level for all targets with `Set-DefaultLoggingLevel`. This default logging level will be used if logging level is omitted in the target configuration.

#### Built-in logging levels

```powershell
* NOTSET    ( 0)
* SQL       ( 5)
* DEBUG     (10)
* VERBOSE   (14)
* INFO      (20)
* NOTICE    (24)
* SUCCESS   (26)
* WARNING   (30)
* ERROR     (40)
* CRITICAL  (50)
* ALERT     (60)
* EMERGENCY (70)
```

#### Configure default logging level

For example:

```powershell
> Get-LoggingDefaultLevel                       # Get the default value
NOTSET                                          # NOTSET level
> Set-LoggingDefaultLevel -Level 'ERROR'        # Set default level to ERROR
> Get-LoggingDefaultLevel                       # Get the current global level
ERROR
```

#### Configure target logging level

```powershell
Add-LoggingTarget -Name Console -Configuration @{
    Level = 'DEBUG'
}
```

### Format

The _Format_ property defines how the message is rendered.

The default value is: `[%{timestamp}] [%{level:-7}] %{message}`

#### Built-in variables

The Log object has a number of attributes that are replaced in the format string to produce the message:

| Format            | Description                                                                                                                                                                                                                                                                                                                                                                         |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `%{timestamp}`    | Time when the log message was created. Defaults to `%Y-%m-%d %T%Z` (_2016-04-20 14:22:45+02_). Take a look at this [Technet article](https://technet.microsoft.com/en-us/library/hh849887.aspx#sectionSection7) about the UFormat parameter, and this [Technet article](<https://msdn.microsoft.com/en-us/library/az4se3k1(v=vs.85).aspx>) for available `[DateTimeFormatInfo]`     |
| `%{timestamputc}` | UTC Time when the log message was created. Defaults to `%Y-%m-%d %T%Z` (_2016-04-20 12:22:45+02_). Take a look at this [Technet article](https://technet.microsoft.com/en-us/library/hh849887.aspx#sectionSection7) about the UFormat parameter, and this [Technet article](<https://msdn.microsoft.com/en-us/library/az4se3k1(v=vs.85).aspx>) for available `[DateTimeFormatInfo]` |
| `%{level}`        | Text logging level for the message (_DEBUG_, _INFO_, _WARNING_, _ERROR_)                                                                                                                                                                                                                                                                                                            |
| `%{levelno}`      | Number logging level for the message (_10_, _20_, _30_, _40_)                                                                                                                                                                                                                                                                                                                       |
| `%{lineno}`       | The line number on wich the write occured                                                                                                                                                                                                                                                                                                                                           |
| `%{pathname}`     | The path of the caller                                                                                                                                                                                                                                                                                                                                                              |
| `%{filename}`     | The file name part of the caller                                                                                                                                                                                                                                                                                                                                                    |
| `%{caller}`       | The caller function name                                                                                                                                                                                                                                                                                                                                                            |
| `%{message}`      | The logged message                                                                                                                                                                                                                                                                                                                                                                  |
| `%{body}`         | The logged body (json format not pretty printed)                                                                                                                                                                                                                                                                                                                                    |
| `%{execinfo}`     | The ErrorRecord catched in a try/catch statement                                                                                                                                                                                                                                                                                                                                    |
| `%{pid}`          | The process id of the currently running powershellprocess ($PID)                                                                                                                                                                                                                                                                                                                    |

After the placeholder name you can pass a padding or a date format string separated by a colon (`:`):

#### Padding

If the padding value is negative, the field will be left aligned and padded with spaces on the right:

```powershell
> Set-LoggingDefaultFormat -Format '[%{level:-7}]'
[DEBUG  ]
[INFO   ]
[WARNING]
[ERROR  ]
```

If the padding value is positive, the field will be right aligned and padded with spaces on the left:

```powershell
> Set-LoggingDefaultFormat -Format '[%{level:7}]'
[  DEBUG]
[   INFO]
[WARNING]
[  ERROR]
```

#### Date format string

The date format string starts with a plus sign (`+`) followed by **UFormat** OR **Format** (`[DateTimeFormatInfo]`) parameters. See [here](https://technet.microsoft.com/en-us/library/hh849887.aspx#sectionSection7) for available **UFormat**s, and [here](<https://msdn.microsoft.com/en-us/library/az4se3k1(v=vs.85).aspx>) for available **Format**s.

```powershell
> Set-LoggingDefaultFormat -Format '%{timestamp}'
2016-04-20 13:31:12+02

> Set-LoggingDefaultFormat -Format '%{timestamp:+%A, %B %d, %Y}'
Wednesday, April 20, 2016

> Set-LoggingDefaultFormat -Format '[%{timestamp:+%T:12}]'   # You could also use padding and date format string at the same time
[   13:31:12]

> Set-LoggingDefaultFormat -Format '[%{timestamp:+yyyy/MM/dd HH:mm:ss.fff}]'
[2016/04/20 13:31:12.431]
```

#### Caller

By default the caller cmdlet is assumed to be the parent function in the executing stack, i.e., the function directly calling the `Write-Log` cmdlet. However, there are instances where a wrapper cmdlet is used on top of `Write-Log` to trigger the logging, thus invalidating the default assumption for the caller.

In these scenarios, it is possible to set the caller scope using `Set-LoggingCallerScope`, which is shown in the example below along with the usage of a wrapper logging cmdlet.

```powershell
# Write-CustomLog is the wrapper logging cmdlet
# If the default caller scope is used, it would print 'Write-CustomLog' everytime
# filename has value only if the code below is executed in a script

Add-LoggingTarget -Name Console -Configuration @{Level = 'DEBUG'; Format = '[%{filename}] [%{caller}] %{message}'}
Set-LoggingCallerScope 2

function Write-CustomLog {
    [CmdletBinding()]
    param(
        $Level,
        $Message
    )

    Write-Log -Level $Level -Message $Message
}

function Invoke-CallerFunctionWithCustomLog {
    1..5 | ForEach-Object {
        # In this example, during execution of Write-Log the numeric scope represents the following:
        # 0 - Write-Log scope
        # 1 - Write-CustomLog scope (which would be default value)
        # 2 - Invoke-CallerFunctionWithCustomLog
        Write-CustomLog -Level (Get-Random 'DEBUG', 'INFO', 'WARNING', 'ERROR') -Message 'Hello, World! (With caller scope at level 2)'
    }
}

Invoke-CallerFunctionWithCustomLog
```

**Note**: A format string starting with a percent symbol (%) will use the `UFormat` parameter of `Get-Date`

## Targets

The _Targets_ property stores the used logging targets, it's where you define where to route your messages.

Keys of the hashtable depends on the target you are configuring. The module ships with 12 targets but you can write your own for specific usage.

When adding a target with `Add-LoggingTarget`, the `-Configuration` parameter accepts a hashtable where additional configuration items can be specified. Each target have its own set of items that can be configured. See the Target specific documentation for further information about the available options.

#### Multiple Targets of Same Type

Starting from version X.X.X, PSLogs supports multiple instances of the same target type using the `UniqueName` parameter. This allows you to configure multiple File targets, Console targets, etc., each with different configurations.

```powershell
# Multiple File targets with different configurations
Add-LoggingTarget -Type File -UniqueName 'ErrorLogs' -Configuration @{
    Level = 'ERROR'
    Path = 'C:\\Logs\\errors.log'
    Tags = @('Error', 'Critical')
}

Add-LoggingTarget -Type File -UniqueName 'DebugLogs' -Configuration @{
    Level = 'DEBUG'
    Path = 'C:\\Logs\\debug.log'
    Tags = @('Debug', 'Development')
}

# Multiple Console targets with different formatting
Add-LoggingTarget -Type Console -UniqueName 'SimpleConsole' -Configuration @{
    Level = 'INFO'
    Format = '%{message}'
    Tags = @('User')
}

Add-LoggingTarget -Type Console -UniqueName 'DetailedConsole' -Configuration @{
    Level = 'DEBUG'
    Format = '[%{timestamp}] [%{level}] [%{caller}] %{message}'
    Tags = @('Developer')
}
```

**Parameters:**
- `-Type`: The target type (File, Console, etc.)
- `-UniqueName`: Unique identifier for this target instance. If omitted, defaults to the Type value
- `-Configuration`: Target-specific configuration including the new `Tags` property

**Note:** For backward compatibility, the `-Name` parameter is still supported as an alias for `-Type`.

#### Tags-based Message Routing

PSLogs now supports tag-based message routing, allowing you to send specific log messages to specific targets based on matching tags.

**Target Configuration:**
Targets can be configured with a `Tags` array in their configuration:

```powershell
Add-LoggingTarget -Type File -UniqueName 'DatabaseLogs' -Configuration @{
    Level = 'DEBUG'
    Path = 'C:\\Logs\\database.log'
    Tags = @('Database', 'Performance')  # This target accepts messages tagged with 'Database' or 'Performance'
}

Add-LoggingTarget -Type File -UniqueName 'WebLogs' -Configuration @{
    Level = 'INFO'
    Path = 'C:\Logs\web.log'
    Tags = @('Web', 'API', 'HTTP')  # This target accepts messages tagged with 'Web', 'API', or 'HTTP'
}
```

**Message Tagging:**
Log messages can be tagged using the `-Tags` parameter in `Write-Log`:

```powershell
# This message will only go to targets that have 'Database' in their tags
Write-Log -Level INFO -Message 'Database connection established' -Tags 'Database'

# This message will go to targets that have 'Web' OR 'Performance' in their tags
Write-Log -Level DEBUG -Message 'API response time: 150ms' -Tags 'Web', 'Performance'

# Multiple tags - message goes to targets matching ANY of these tags
Write-Log -Level ERROR -Message 'Critical system failure' -Tags 'Database', 'Web', 'Critical'
```

**Tag Matching Rules:**
- Tag matching is **case-insensitive** ('database' matches 'Database')
- If a message has multiple tags, it will be sent to targets that match **any** of those tags (OR logic)
- If a target has multiple tags, a message needs to match **any** of the target's tags to be routed there
- Messages without tags default to the 'Default' tag
- Targets without tags default to accepting the 'Default' tag
- **Backward Compatibility:** Existing configurations without tags will continue to work as before

**Example Scenario:**
```powershell
# Set up specialized logging targets
Add-LoggingTarget -Type File -UniqueName 'GeneralLogs' -Configuration @{
    Level = 'INFO'
    Path = 'C:\\Logs\\general.log'
    Tags = @('Default', 'General')  # Accepts default messages and general messages
}

Add-LoggingTarget -Type File -UniqueName 'DatabaseLogs' -Configuration @{
    Level = 'DEBUG'
    Path = 'C:\\Logs\\database.log'
    Tags = @('Database', 'SQL', 'Performance')
}

Add-LoggingTarget -Type File -UniqueName 'ErrorLogs' -Configuration @{
    Level = 'ERROR'
    Path = 'C:\Logs\errors.log'
    Tags = @('Error', 'Database', 'Web')  # Catches errors from multiple sources
}

# Usage
Write-Log 'Application started'  # Goes to GeneralLogs (default tag)
Write-Log -Message 'Query executed in 50ms' -Tags @('Database')  # Goes to DatabaseLogs
Write-Log -Level ERROR -Message 'Connection failed' -Tags @('Database')  # Goes to both DatabaseLogs and ErrorLogs
```

### Console

From version 2.3.3 it supports acquiring lock for issues with git prompt that sometimes gets splitted during output.
The mutex name to acquire is `ConsoleMtx`

#### Configuration options

| Option            | Type      | Mandatory | Default        | Description                                                                                                                     |
| ----------------- | --------- | :-------: | -------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Level             | String    |    No     | Default Level  | Defines the lowest logging level to logged                                                                                      |
| Format            | String    |    No     | Default Format | Defines a custom format for the target                                                                                          |
| PrintException    | Boolean   |    No     | $true          | Prints the stacktrace when an exception object is passed to Write-Log                                                           |
| ColorMapping      | Hashtable |    No     | _See below_    | Overrides the default color mappings                                                                                            |
| OnlyColorizeLevel | Boolean   |    No     | $false         | If set to true, only the level name is colorized instead of the whole log row.                                                  |
| ShortLevel        | Boolean   |    No     | $false         | If true the written level name is trimmed to three chars, ie ERROR -> ERR. This makes the logs more aligned and easier to read. |
| Tags              | String[]  |    No     | @('Default')   | Array of tags for message routing. Messages with matching tags will be sent to this target.                                     |

##### Default color mappings
| Level     | Color    |
| --------- | -------- |
| SQL       | Magenta  |
| DEBUG     | Cyan     |
| INFO      | DarkGray |
| WARNING   | Yellow   |
| ERROR     | Red      |
| NOTICE    | Gray     |
| VERBOSE   | Yellow   |
| SUCCESS   | Green    |
| CRITICAL  | Red      |
| ALERT     | Red      |
| EMERGENCY | Magenta  |

Each color will be verified against `[System.ConsoleColor]`. If it is invalid, an error will appear on the screen along with the original message.

#### Colorize text manually

PSLogs allows you to freely colorize individual parts of the message or variables in the format string. The following two tokens can be used to configure parts of the strings with color.
- `{StartColor:<color>}`
- `{EndColor}`

Note that it will only work with `OnlyColorizeLevel=$true` because if this is `$false` the whole line is colored which overrides this setting. 

You can use it within the message itself:
```powershell
Write-Log -Level VERBOSE -Message 'This is a verbose {StartColor:Magenta}message{EndColor}'
```
![FormatColorMessage](https://raw.githubusercontent.com/hanpq/PSLogs/refs/heads/main/.build/FormatColorMessage.png)

You can also use it within a format string:
```powershell
Add-LoggingTarget -Name Console -Configuration @{
    OnlyColorizeLevel = $true
    Format            = '{StartColor:Green}%{timestamp:+yyyy-MM-dd HH:mm:ss}{EndColor} | %{level:-7} | %{message}'
}
Write-Log -Level VERBOSE -Message 'This is a verbose {StartColor:Magenta}message{EndColor}'
```
![FormatColorMessage](https://raw.githubusercontent.com/hanpq/PSLogs/refs/heads/main/.build/FormatColorFormat.png)


#### Example

```powershell
Add-LoggingTarget -Name Console -Configuration @{
    Level = 'DEBUG'
    Format = '[%{timestamp}] [%{level}] %{message}'
    PrintException = $false
    ColorMapping = @{
        'DEBUG'   = 'Blue'
        'INFO'    = 'Green'
        'WARNING' = 'Yellow'
        'ERROR'   = 'Red'
    }
    OnlyColorizeLevel = $true
    ShortLevel = $true
}
```

#### Format examples
![Logging Formats](https://raw.githubusercontent.com/hanpq/PSLogs/refs/heads/main/.build/LoggingFormats.png)

### File

#### Configuration options

| Option            | Type     | Mandatory | Default        | Description                                                                                                                     |
| ----------------- | -------- | :-------: | -------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Path              | String   |    Yes    | N/A            | Sets the file destination. It supports templating like $Logging.Format                                                          |
| PrintBody         | Boolean  |    No     | $false         | Prints body message too                                                                                                         |
| Append            | Boolean  |    No     | $true          | Append to log file                                                                                                              |
| Encoding          | String   |    No     | ascii          | Sets the log file encoding                                                                                                      |
| Level             | String   |    No     | Default Level  | Defines the lowest logging level to logged                                                                                      |
| Format            | String   |    No     | Default Format | Defines a custom format for the target                                                                                          |
| PrintException    | Boolean  |    No     | $true          | Prints the stacktrace when an exception object is passed to Write-Log                                                           |
| ShortLevel        | Boolean  |    No     | $false         | If true the written level name is trimmed to three chars, ie ERROR -> ERR. This makes the logs more aligned and easier to read. |
| RotateAfterAmount | Int      |    No     | N/A            | Sets the amount of files after which rotation is triggered                                                                      |
| RotateAmount      | Int      |    No     | N/A            | Amount of files to be rotated, when RotateAfterAmount is used                                                                   |
| RotateAfterDate   | DateTime |    No     | N/A            | Rotate after the difference between the current datetime and the datetime of the file(s) are greater then the given timespan    |
| RotateAfterSize   | Int      |    No     | N/A            | Rotate after the file(s) are greater than the given size in BYTES                                                               |
| CompressionPath   | String   |    No     | N/A            | Path of archive (*.zip) to create for the rotated files                                                                         |
| Tags              | String[] |    No     | @('Default')   | Array of tags for message routing. Messages with matching tags will be sent to this target.                                     |

#### Example

```powershell
> Add-LoggingTarget -Name File -Configuration @{
    Path            = 'C:\Temp\%{+%Y%m%d}.log'        
    PrintBody       = $false              
    PrintException  = $false              
    Append          = $true               
    Encoding        = 'ascii'             
    Level           = 'VERBOSE'          
    Format          =  '[%{timestamp}] [%{level}] %{message}'         
    RotateAfterAmount = <NOTSET>          
    RotateAmount      = <NOTSET>          
    RotateAfterDate   = <NOTSET>          
    RotateAfterSize   = <NOTSET>          
    CompressionPath   = <NOTSET>
    Tags            = @('File', 'Application')
}
```

##### Rotation/Removal
_The word `Rotate` has caused some confusion, `Rotate` is more often used to describe when a new log file is generated. In `PSLogs` and formerly the `Logging` module, `Rotate` is more of a `Cleanup` where old log files are removed. Rotation of log file, in other words, generation of new log files is determined by the log file path and variables used for the folder and/or file name. I would love to change this to `Cleanup`/`Remove` instead, but it would be a breaking change._

This module provides the functionality for the file target to remove old log files. To make full use of this functionality, variable data used inside the log path should be encoded, using the previously described format system.

When the file target is initialized, **all files** are retrieved, which **expand** the given log path.
All internally known **placeholders** are therefore substituted with **wildcard** characters.
Based upon this list of files a file is removed, if 
- the difference between it's creation and the current data is greater then the specified **RotateAfterDate**
- it's size in bytes exceeds **RotateAfterSize**
- more than **RotateAfterAmount** files are present and this file belongs to the oldest max(|Files| - RotateAfterAmount, RotateAmount) files.

The default behavior is to remove the log files. It is however possible, to use the **CompressionPath** to define an archive for the rotated log files. **This requires >= NET4.5** The following placeholders are supported
- `%{timestamp}`
- `%{timestamputc}`
If an archive should already be present, the data is added to that archive.

### ElasticSearch

#### Configuration options

| Option        | Type    | Mandatory | Default       | Description                                                                   |
| ------------- | ------- | :-------: | ------------- | ----------------------------------------------------------------------------- |
| Level         | String  |    No     | Default Level | Defines the lowest logging level to logged                                    |
| ServerName    | String  |    Yes    | N/A           | Sets the ES server name                                                       |
| ServerPort    | Int     |    Yes    | N/A           | Sets the ES server port                                                       |
| Index         | String  |    Yes    | N/A           | Sets the ES index name to log to. It supports templating like $Logging.Format |
| Type          | String  |    Yes    | N/A           | Sets the ES type for the message                                              |
| Flatten       | Boolean |    No     | $false        | Transforms the log hashtable in a 1-D hashtable                               |
| Https         | Boolean |    No     | $false        | Uses HTTPS instead of HTTP in elasticsearch URL if $true                      |
| Authorization | String  |    No     |               | Converts creds to base64 and adds it to headers.                              |

#### Example

```powershell
> Add-LoggingTarget -Name ElasticSearch -Configuration @{
    ServerName     = 'localhost'
    ServerPort     = 9200
    Index          = 'logs-%{+%Y.%m.%d}'             
    Type           = 'log'
    Level          = 'WARNING'
    Flatten        = $false            
    Https          = $false            
    Authorization  = 'username:password'
}

$Body = @{source = 'Logging'; host='bastion.constoso.com'; _metadata = @{ip = '10.10.10.10'; server_farm = 'WestEurope'}}
Write-Log -Level 'WARNING' -Message 'Hello, Powershell!' -Body $Body
```

##### Example Flatten=$false

```json
{
  "_index": "powershell-2018-05-10",
  "_type": "doc",
  "_id": "6BfJXWMB8moSvzgSbZgo",
  "_score": 1,
  "_source": {
    "body": {
      "host": "bastion.constoso.com",
      "_metadata": {
        "server_farm": "WestEurope",
        "ip": "10.10.10.10"
      },
      "source": "Logging"
    },
    "levelno": 30,
    "timestamp": "2018-05-14T10:34:31+02",
    "level": "WARNING",
    "message": "Hello, Powershell, No Flatten"
  }
}
```

##### Example Flatten=$true

```json
{
  "_index": "powershell-2018-05-10",
  "_type": "doc",
  "_id": "6RfJXWMB8moSvzgSeJj_",
  "_score": 1,
  "_source": {
    "source": "Logging",
    "server_farm": "WestEurope",
    "ip": "10.10.10.10",
    "levelno": 30,
    "level": "WARNING",
    "host": "bastion.constoso.com",
    "message": "Hello, Powershell, Flatten",
    "timestamp": "2018-05-14T10:34:34+02"
  }
}
```

### Slack

#### Configuration options

| Option  | Type   | Mandatory | Default        | Description                                  |
| ------- | ------ | :-------: | -------------- | -------------------------------------------- |
| Level   | String |    No     | Default Level  | Defines the lowest logging level to logged   |
| Format  | String |    No     | Default Format | Defines a custom format for the target       |
| WebHook | String |    Yes    | N/A            | Sets the Slack Webhook URI                   |
| Channel | String |    No     | N/A            | Overrides the default channel of the Webhook |
| BotName | String |    No     | N/A            | Overrides the default name of the bot        |

#### Example

```powershell
> Add-LoggingTarget -Name Slack -Configuration @{
    WebHook     = 'https://hooks.slack.com/services/xxxx/xxxx/xxxxxxxxxx'      
    Channel     = '#other-channel'
    BotName     = 'PoshLogging' 
    Level       = 'ALERT'   
    Format      = '[%{timestamp}] [%{level}] %{message}'        
}
```

### Email

#### Configuration options

| Option         | Type         | Mandatory | Default        | Description                                      |
| -------------- | ------------ | :-------: | -------------- | ------------------------------------------------ |
| Level          | String       |    No     | Default Level  | Defines the lowest logging level to logged       |
| Format         | String       |    No     | Default Format | Defines a custom format for the target           |
| SMTPServer     | String       |    Yes    | N/A            | SMTP server FQDN                                 |
| From           | String       |    Yes    | N/A            | From address                                     |
| To             | String       |    Yes    | N/A            | A string of recipients                           |
| Subject        | String       |    No     | N/A            | Email subject. Supports formatting and expansion |
| Attachments    | String       |    No     | N/A            | Path to the desired file to attach               |
| Credential     | PSCredential |    No     | N/A            | If your server uses authentication               |
| Port           | Int          |    No     | 25             | Set the SMTP server's port                       |
| UseSsl         | Boolean      |    No     | N/A            | Use encrypted transport to SMTP server           |
| PrintException | Boolean      |    No     | N/A            | Print stacktrace in the body                     |

#### Example

```powershell
> Add-LoggingTarget -Name Email -Configuration @{
    SMTPServer      = 'smtp.contoso.com'                     
    From            = 'PSLogs <pslogs@contoso.com>'
    To              = 'test@contoso.com,robin@hood.eu'
    Subject         = '[%{level:-7}] %{message}'    
    Attachments     = 'C:\Path\To\StateSnapshot.xml'
    Credential      = $cred
    Level           = 'ALERT'                      
    Port            = 587                      
    UseSsl          = $true                    
    PrintException  = $true        
}
```

### Seq

#### Configuration options

| Option     | Type      | Mandatory | Default       | Description                                                          |
| ---------- | --------- | :-------: | ------------- | -------------------------------------------------------------------- |
| Level      | String    |    No     | Default Level | Defines the lowest logging level to logged                           |
| Url        | String    |    Yes    | N/A           | Url to Seq instance                                                  |
| ApiKey     | String    |    No     | N/A           | Api Key to authenticate to Seq                                       |
| Properties | HashTable |    No     | N/A           | Hashtable of user defined properties to be added to each Seq message |

#### Example

```powershell
> Add-LoggingTarget -Name Seq -Configuration @{
    Url         = <NOTSET>
    ApiKey      = <NOTSET>
    Properties  = <NOTSET>
    Level       = <NOTSET>
}
```

### SQLite

#### Configuration options

| Option         | Type      | Mandatory | Default                                                                          | Description                                                      |
| -------------- | --------- | :-------: | -------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| Level          | String    |    No     | Default Level                                                                    | Defines the lowest logging level to logged                       |
| Database       | String    |    Yes    | N/A                                                                              | Set the database file path                                       |
| TableName      | String    |    Yes    | N/A                                                                              | Set the table name the logs should be inserted to.               |
| ColumnMapping  | Hashtable |    No     | Timestamp = 'Timestamp'; Level = 'Level'; Source = 'Caller'; Message = 'Message' | Overrides what built-in values should be inserted into the table |
| MessageFormat  | String    |    No     |                                                                                  | Override the message format                                      |
| PrintException | Boolean   |    No     | $false                                                                           | Append the exception and stackstrace to the message              |

#### Example

```powershell
Add-LoggingTarget -Name SQLite -Configuration @{
    Database      = "$PSScriptRoot\Logs.sqlite"
    TableName     = 'Logs'
    ColumnMapping = @{
        Timestamp = 'Timestamp'
        Severity  = 'Level'
        Source    = 'Caller'
        Message   = 'Message'
    }
    Level         = 'debug'
}

```

#### ColumnMapping for built in variables

Using column mapping the following values can be used out-of-the-box 

- pathname
- pid
- body
- timestamp
- rawmessage
- lineno
- filename
- caller
- level
- timestamputc
- execinfo
- message
- levelno

The key of the ColumnMapping hashtable is the SQL Table column name and the value is one of the above properties.

#### Custom columns

You can also provide custom values for the logging table by providing a hashtable to the Body parameter. Make sure that the table actually has the columns before trying to log them.

```powershell
Write-Log -Level 'WARNING' -Message 'Hello' -Body @{PSEdition = $PSEdition}
```

#### Setup the database

When you have the dependency module PSSQLite installed you can use the following command to initialize a SQLite database for logging. Modify appropriately.

```powershell
$Query = @'
CREATE TABLE "Logs" (
	"Timestamp"	DATETIME NOT NULL,
	"Severity"	TEXT NOT NULL,
	"Source"	TEXT NOT NULL,
	"Message"	TEXT NOT NULL,
	"PSEdition"	TEXT
);
'@
Invoke-SqliteQuery -DataSource C:\Path\To\logs.sqlite -Query $Query
```

### WinEventLog

#### Prerequisites

Before you can log events you need to make sure that the LogName and Source exists. This needs to be done only once (run as an Administrator)

```powershell
> New-EventLog -LogName <NOTSET> -Source <NOTSET>
```

You can now log to the EventLog from your script

#### Configuration options

| Option  | Type   | Mandatory | Default       | Description                                                                                       |
| ------- | ------ | :-------: | ------------- | ------------------------------------------------------------------------------------------------- |
| LogName | String |    Yes    | N/A           | Name of the log to which the events are written                                                   |
| Source  | String |    Yes    | N/A           | Event source, which is typically the name of the application that is writing the event to the log |
| Level   | String |    No     | Default Level | Defines the lowest logging level to logged                                                        |

#### EventID

EventID can be specified as body.

#### Translated Level

Levels will be translated to valid WinEvent log levels

- Greated than 40 = Error
- Between 30 and 39 = Warning
- Less than 30 = Information

#### Example

```powershell
> Add-LoggingTarget -Name WinEventLog -Configuration @{
    LogName = 'Application'
    Source  = 'MyNiceScript'
    Level = 'WARNING'
}

Write-Log -Level 'WARNING' -Message 'Hello, {0}!' -Arguments 'Powershell' -Body @{ EventID = 123 }

```

### Teams

#### Configuration options

| Option  | Type      | Mandatory | Default                       | Description                                      |
| ------- | --------- | :-------: | ----------------------------- | ------------------------------------------------ |
| Level   | String    |    No     | Default Level                 | Defines the lowest logging level to logged       |
| WebHook | String    |    Yes    | N/A                           | Sets the Teams Connector URI                     |
| Details | Boolean   |    No     | $true                         | Prints Log message details like PID, caller etc. |
| Colors  | HashTable |    No     | Defaults shown in the example | Maps log levels to badge colors                  |

#### Example

```powershell
> Add-LoggingTarget -Name Teams -Configuration @{
    WebHook     = 'https://outlook.office.com/webhook/...'
    Details     = $true             
    Level       = 'ALERT'          
    Colors      = @{              
        'DEBUG'     = 'blue'
        'INFO'      = 'brightgreen'
        'WARNING'   = 'orange'
        'ERROR'     = 'red'
        'NOTICE'    = 'gray'
        'VERBOSE'   = 'yellow'
        'SUCCESS'   = 'green'
        'CRITICAL'  = 'red'
        'ALERT'     = 'red'
        'EMERGENCY' = 'magenta'
    }
}

Write-Log -Level 'WARNING' -Message 'Hello, {0}!' -Arguments 'Powershell' -Body @{source = 'Logging'}
```

#### AzureLogAnalytics


Log directly to a Azure Log Analytics Workspace from your script

#### Configuration options

| Option      | Type   | Mandatory | Default                       | Description                                                          |
| ----------- | ------ | :-------: | ----------------------------- | -------------------------------------------------------------------- |
| Level       | String |    No     | Default Level                 | Defines the lowest logging level to logged                           |
| WorkspaceId | String |    Yes    | N/A                           | Id of the Azure Log Analytics Workspace                              |
| SharedKey   | String |    Yes    | $true                         | Primary or Secondary Key to access the Azure Log Analytics Workspace |
| LogType     | String |    No     | Defaults shown in the example | Creates a custom LogType in Log Analytics Workspace                  |

#### Example

```powershell
Add-LoggingTarget -Name AzureLogAnalytics -Configuration @{
    WorkspaceId = '8eda8332-16eb-400b-9f0b-6a21e1c1cf28'       
    SharedKey   = 'w7ZhaGTDtmgxcDJlaMO2YWxza2Rqw7Z1MnlvNDd5MWRsYWpraHNsa2Rhc2Q='    
    LogType     = "Logging"  
    Level       = 'DEBUG'      
}

Write-Log -Level 'WARNING' -Message 'Hello, Powershell!' -Body { Computer = $env:COMPUTERNAME }
```

### Gelf

Graylog logging format, used to send rich log messages to a Graylog server or other log management system using the Gelf protocol.

#### Configuration options

| Option          | Type      | Mandatory | Default        | Description                                                  |
| --------------- | --------- | :-------: | -------------- | ------------------------------------------------------------ |
| Level           | String    |    No     | Default Level  | Defines the lowest logging level to logged                   |
| Server          | String    |    Yes    | N/A            | Defines the servername of the Graylog server                 |
| Port            | Int       |    Yes    | N/A            | Defines the port number of the Gelf Input                    |
| HostName        | String    |    No     | $env:hostname  | Defines the hostname of the server running the script        |
| Format          | String    |    No     | Default Format | Defines a custom format for the target                       |
| Protocol        | String    |    No     | 'TCP'          | Defines if the Gelf input is UDP or TCP                      |
| AdditionalField | Hashtable |    No     | $null          | Optionally pass on additional static values for the log item |

#### Example

```powershell
Add-LoggingTarget -Name Gelf -Configuration @{
    Level = 'DEBUG'
    Server = 'graylog.contoso.com'
    Port = 12202
    Hostname = 'scriptserver.contoso.com'
    Format = '%{message}'
    Protocol = 'UDP'
    AdditionalFields = @{
        Month = (Get-Date).ToString('MMM')
    }
}

Write-Log -Level 'WARNING' -Message 'Hello, Powershell!'
```

### WebexTeams

Post message to Webex

#### Configuration options

| Option   | Type      | Mandatory | Default            | Description                                |
| -------- | --------- | :-------: | ------------------ | ------------------------------------------ |
| Level    | String    |    No     | Default Level      | Defines the lowest logging level to logged |
| Format   | String    |    No     | Default Format     | Defines a custom format for the target     |
| BotToken | String    |    Yes    | N/A                | Defines the bot token                      |
| RoomID   | String    |    Yes    | N/A                | Defines the room id                        |
| Icons    | HashTable |    No     | See defaults below | Override the default icons                 |

#### Default icons

- ERROR   = '🚨'
- WARNING = '⚠️'
- INFO    = 'ℹ️'
- DEBUG   = '🔎'

#### Example

```powershell
Add-LoggingTarget -Name WebexTeams -Configuration @{
    Level = 'DEBUG'
    Format = '%{message}'
    BotToken = ''
    RoomID = ''
    Icons = @{
        ERROR = '🚨'
        WARNING = '⚠️'
        INFO    = 'ℹ️'
        DEBUG   = '🔎'
    }
}

Write-Log -Level 'WARNING' -Message 'Hello, Powershell!'
```

### CustomTargets

If you write a target plugin by your self you can define a path where the module will look for additional target plugins.

Please consider making a pull request to the PSLogs repo so that the target plugin can be included by default in the module.

```powershell
> Set-LoggingCustomTarget -Path 'C:\temp\'
> Get-LoggingAvailableTarget
Name                           Value
----                           -----
Console                        {Configuration, ParamsRequired, Logger}
ElasticSearch                  {Configuration, ParamsRequired, Logger}
File                           {Configuration, ParamsRequired, Logger}
Slack                          {Configuration, ParamsRequired, Logger}
MyCustomTarget                 {Configuration, ParamsRequired, Logger}
```

## Write-Log

The Write-Log function is main tool to actually write/send each log message. One the targets are configured, Write-Log will queue the log message to be written to all configured targets as long as the minimum Level is reached.

Write-Log accepts the following parameters 
- `-Level` parameter to define that logs level. 
- `-Message` parameter defines the actual message to log. 
- `-Arguments` parameter allows you to use format placeholders in the message like, -Message 'Hello, {0}' -Arguments $Username
- `-Body` parameter allows you pass additional info the target. Please see the target specific documentation for more information.
- `-ExceptionInfo` parameter allows you to pass an Exception object to the target. Targets might process these objects differently.
- `-Tags` parameter allows you to specify an array of tags for message routing to specific targets. Defaults to 'Default' if not specified.

#### Tags Parameter Examples

```powershell
# Default behavior (no tags specified - uses 'Default' tag)
Write-Log -Level INFO -Message 'Application started'

# Single tag
Write-Log -Level DEBUG -Message 'Database query executed' -Tags 'Database'

# Multiple tags (message will be routed to targets matching ANY of these tags)
Write-Log -Level WARNING -Message 'Performance issue detected' -Tags 'Performance', 'Web', 'Monitoring'

# Case doesn't matter (these are equivalent)
Write-Log -Message 'Test message' -Tags @('Database')
Write-Log -Message 'Test message' -Tags @('database')
Write-Log -Message 'Test message' -Tags @('DATABASE')
```
- `-Tags` parameter allows you to specify an array of tags for message routing to specific targets. Defaults to 'Default' if not specified.

#### Tags Parameter Examples

```powershell
# Default behavior (no tags specified - uses 'Default' tag)
Write-Log -Level INFO -Message 'Application started'

# Single tag
Write-Log -Level DEBUG -Message 'Database query executed' -Tags @('Database')

# Multiple tags (message will be routed to targets matching ANY of these tags)
Write-Log -Level WARNING -Message 'Performance issue detected' -Tags @('Performance', 'Web', 'Monitoring')

# Case doesn't matter (these are equivalent)
Write-Log -Message 'Test message' -Tags @('Database')
Write-Log -Message 'Test message' -Tags @('database')
Write-Log -Message 'Test message' -Tags @('DATABASE')
```

## Contributing

Please use [issues](https://github.com/hanpq/PSLogs/issues) system or GitHub pull requests to contribute to the project.

For more information, see [CONTRIBUTING](https://github.com/hanpq/PSLogs/blob/main/.github/CONTRIBUTING.md)

## Notes

- The dispatcher thread starts the first time a `Write-Log` command is executed and keeps running in the background to dispatch new messages until the module is removed.
- The runspace code is inspired by the work and research of Boe Prox (@proxb).

## License

This project is licensed under the [MIT License][license]

---

## Included attributions from orginal repo

Special thanks to:

- Boe Prox (@proxb) for his work on [runspaces][runspaces]

[github]: https://github.com/EsOsO
[module]: https://github.com/EsOsO/Logging
[runspaces]: https://learn-powershell.net/tag/runspace/
[license]: https://github.com/EsOsO/Logging/blob/main/docs/LICENSE.md
