# Changelog for PSLogs

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.2.1] - 2024-03-13

### Fixed

- When logging to email, body will now preserve formatting of the json object in the final message. Previously the json was concatinated into one single line and no linefeeds/carrage returns were kept. Indentation with space is now also perserved in the mail message.

## [5.2.0] - 2024-02-16

### Fixed

- Improved API call to SEQ so that log arguments are parsed correctly. [PR #3] (Thanks to @in-voker)

## [5.1.0] - 2023-09-11

### Added

- Added configuration parameters to console plugin to only colorize level. This is false by default.

### Fixed

- Typos in comment based help fixed.
- Fixed typo on critical logging level defintion.

## [5.0.3] - 2023-09-07

### Fixed

- Debug changelog update on release....

## [5.0.2] - 2023-09-07

### Added

- New logging levels added; notice, verbose, success, critical, alert and emergency.

### Changed

- Default coloring/icons has been updated to accomodate differentiation for the new logging levels.

## [5.0.1] - 2023-09-05

### Fixed

- Fixed an issue where the logging manager was not always disposed when the module was removed.

### Changed

- Project forked from RootITUp/Logging to hanpq/PSLogs

## [4.8.5] - 2022-03-23

## [4.8.3] - 2021-10-06

## [4.8.2] - 2021-03-15

## [4.8.1] - 2021-02-18

## [4.8.0] - 2021-02-11

## [4.7.1] - 2021-02-11

### Added

- Teams target now support additional body types for adaptive cards (@jangins101)

### Fixed

- Refactored Teams target (@jangins101)
- Removed formatting timestamp on log event creation, this caused lost of milliseconds later on

## [4.5.0] - 2020-10-22

### Added

- Teams target now support additional body types for adaptive cards (@jangins101)

### Fixed

- Refactored Teams target (@jangins101)
- Removed formatting timestamp on log event creation, this caused lost of milliseconds later on

## [4.4.0] - 2020-06-17

### Fixed

- NotifyBeginApplication/NotifyEndApplication calls not needed (#99)
- Fix startup race condition (#100) (@Tadas)
- Fixed an issue in AzureLogAnalytics target (#102) (@Glober777)
- Resolve relative Path in File target (#103) (@Tadas)
- Target name is case insensitive (#106) (@Tadas)

## [4.3.2] - 2020-05-28

### Security

- Fix url when ApiKey is used (#96) (@gahujipo)

## [4.3.1] - 2020-05-28

### Added

- Added target for Azure Log Analytics Workspace (thx to @manualbashing)
- Added target for Webex Teams (thx to @itshorty)

### Fixed

- Fixed module autoload (thx to @Tadas)
- Module don't hang shell exit (thx to @Tadas) #82

## [4.2.13] - 2020-02-25

## [4.2.12] - 2019-11-08

## [4.2.11] - 2019-09-23

### Fixed

- Closed issue #66 where messages are lost on Powershell ISE

### Changed

- Decreased `Wait-Logging` timeout from 5 minutes to 30 seconds

## [4.2.7] - 2019-09-19

## [4.2.6] - 2019-09-13

### Fixed 

- In this release we worked out an issue about setting default level or formatting was not honored by the already configured targets (#67) and one about level ignored when dispatching messages to targets (#68) Thanks to: @ZamElek

## [4.2.3] - 2019-08-27

## [4.2.2] - 2019-08-05

### Fixed

- In this minor release we fixed an annoying issue about how the module loads the available targets. Now the loading routine is run inside the runspace to isolate the scope where the targets scriptblock is created.
- Major code update to address issue #63
- `Set-LoggingDefaultLevel` sets default level on cofigured targets too (#61, #58)

### Changed

- Removed validation on parameter Arguments

## [4.1.1] - 2019-05-20

### Added

- Added timestamputc to log message properties #48
- Added Icons configuration to Slack target to map Log Levels to emoji #53

### Fixed

- Removed self loading in runspace
- Moved Use-LogMessage to private functions
- Added timeout to Wait-Logging to avoid hangs

## [4.0.3] - 2019-04-15

### Fixed

- Removed catalog generation until I get more grasp on the process

## [3.0.0] - 2019-04-15

### Added

- This major release shouldn't break anything. It should improve logging performance to a new level thanks to the amazing work of @tosoikea.
- Advanced Logging Manager (thx to @tosoikea)
- Module catalog generation on build

### Fixed

- Filename token (thx to @lookcloser)
  
### Changed

- Code cleanup

## [2.10.0] - 2019-04-04

### Added

- Added support for target default config
- Added support for target initialization scriptblock
- Added DynamicParam generation function

### Changed

- Synchronized variables are now Constant instead of ReadOnly (thx to @tosoikea)

## [2.9.1] - 2019-03-15

### Added

- Added Windows EventLog target (thx to @tadas)
- Powershellgallery publishing on build

### Fixed

- Fixed Write-Log -Arguments detection

## [2.6.0] - 2018-10-24

### Fixed

- Copyright string in mkdocs.yml
- Build version for CD

## [2.4.13] - 2018-10-22

### Added

- Caller function in message template

## [2.4.12] - 2018-09-21

### Added

- Seq target (thx @TheSemicolon)
- $ExceptionInfo paramter to Write-Log to add Error tracing

## [2.4.11] - 2018-08-17

### Fixed

- Fixed custom targets for locations outside module folder (#20 thx to @jeremymcgee73)

## [2.4.10] - 2018-05-14

### Fixed

- Fixed ElasticSearch target
- Added some more documentation
- Minor tweaking

## [2.4.9] - 2018-04-10

### Added

- Implement OverrideColorMapping for Console target
- Implement format [DateTimeFormatInfo] usage and tests

## [2.4.8] - 2018-02-27

### Fixed

- Fixed email configuration address parsing

## [2.4.7] - 2017-11-06

### Fixed

- Fixed slack logging target

## [2.4.6] - 2017-09-12

### Fixed

- Set runspace ApartmentState to MTA
- Set min runspaces equals to 1
- Set max runspaces equals to NUMBER_OF_PROCESSORS + 1

## [2.4.5] - 2017-04-19

### Fixed

- Fixed timestamp based on system locale

## [2.4.4] - 2017-03-13

### Fixed

- Fixed module autoloading timing

## [2.4.3] - 2017-01-10

### Fixed

- Fixed build script to release on powershelgallery only on main branch

## [2.4.2] - 2017-01-10

### Fixed

- Fixed minor issues in internal functions
- Added new Pester tests

## [2.4.1] - 2016-12-29

### Fixed

- Fixed deployment issues
- Moved to AppVeyor CI

## [2.4.0] - 2016-12-28

### Fixed

- Moved to psake build tool
- Moved to platyps doc generation tool
- Major folder structure change
