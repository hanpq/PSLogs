# Pipeline migration kit

This folder makes it possible to move other PowerShell modules from the legacy Sampler pipeline to the PSLogs build and release pipeline, and to update them later.

PSLogs is the single source of truth. The kit does not contain copies of the pipeline files; `Export-PipelineKit.ps1` collects the current, tested files when you need them.

| File | Purpose |
| --- | --- |
| [MAINTAINER-SETUP.md](MAINTAINER-SETUP.md) | Start here. How to run a migration, and the GitHub settings and secrets you must configure yourself. |
| [AI-MIGRATION.md](AI-MIGRATION.md) | Step-by-step instructions for the AI agent working in the target repository. |
| [kit-files.psd1](kit-files.psd1) | Which PSLogs files are copied unchanged (`Copy`) and which must be adapted per module (`Adapt`). |
| [Export-PipelineKit.ps1](Export-PipelineKit.ps1) | Builds `output/pipeline-migration-kit/` with the documents, the files and a `KIT-VERSION.txt`. |

## Keeping the kit current

When you change the pipeline in PSLogs:

- Add new pipeline files to `kit-files.psd1`, and remove deleted ones. The export fails if a listed file is not tracked by Git.
- If the change affects how a module must be adapted, update `AI-MIGRATION.md`. If it needs a new secret or setting, update `MAINTAINER-SETUP.md`.
- Commit before exporting, so `KIT-VERSION.txt` points to a real commit.
