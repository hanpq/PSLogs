# PSLogs

This project has adopted the following policies [![CodeOfConduct](https://img.shields.io/badge/Code%20Of%20Conduct-gray)](https://github.com/hanpq/PSLogs/blob/main/.github/CODE_OF_CONDUCT.md) [![Contributing](https://img.shields.io/badge/Contributing-gray)](https://github.com/hanpq/PSLogs/blob/main/.github/CONTRIBUTING.md) [![Security](https://img.shields.io/badge/Security-gray)](https://github.com/hanpq/PSLogs/blob/main/.github/SECURITY.md)

## Project status
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/hanpq/PSLogs/build.yml?branch=main&label=build&logo=github)](https://github.com/hanpq/PSLogs/actions/workflows/build.yml) [![Codecov](https://img.shields.io/codecov/c/github/hanpq/PSLogs?logo=codecov&token=qJqWlwMAiD)](https://codecov.io/gh/hanpq/PSLogs) [![Platform](https://img.shields.io/powershellgallery/p/PSLogs?logo=ReasonStudios)](https://img.shields.io/powershellgallery/p/PSLogs) [![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PSLogs?label=downloads)](https://www.powershellgallery.com/packages/PSLogs) [![License](https://img.shields.io/github/license/hanpq/PSLogs)](https://github.com/hanpq/PSLogs/blob/main/LICENSE) [![docs](https://img.shields.io/badge/docs-getps.dev-blueviolet)](https://getps.dev/modules/PSLogs) [![changelog](https://img.shields.io/badge/changelog-getps.dev-blueviolet)](https://github.com/hanpq/PSLogs/blob/main/CHANGELOG.md) ![GitHub release (latest SemVer including pre-releases)](https://img.shields.io/github/v/release/hanpq/PSLogs?label=version&sort=semver) ![GitHub release (latest SemVer including pre-releases)](https://img.shields.io/github/v/release/hanpq/PSLogs?include_prereleases&label=prerelease&sort=semver)

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

## Docs

Please the full documentation on the [docs site][pslogsdocs]

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
[pslogsdocs]: https://getps.dev/modules/PSLogs/
