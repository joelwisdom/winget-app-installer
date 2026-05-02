# winget-app-installer

A PowerShell-based tool for automating Windows app installation using [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/). Designed for enterprise laptop provisioning and power-user machine setup.

## Features

- **Interactive mode** — guided category-based app selection with input validation
- **Profile mode** — unattended installs from JSON configuration files (idempotent)
- **Update-all** — upgrade every installed catalog app in one command
- **Dry-run** — preview what would happen without calling winget
- **Export** — generate a profile from currently installed apps
- **Search** — search the winget catalog directly
- **Logging** — timestamped log files with install reports
- **Extensible catalog** — external JSON app catalog with custom overlay support
- **Pre/post hooks** — run scripts before or after profile installs

## Requirements

- Windows 10/11
- PowerShell 5.1+
- [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (ships with Windows 11; install via Microsoft Store on Windows 10)

## Install

**One-liner (recommended):**

```powershell
irm https://raw.githubusercontent.com/joelwisdom/winget-app-installer/master/Install.ps1 | iex
```

This downloads the tool to `%LOCALAPPDATA%\winget-app-installer` and optionally launches the interactive installer. To install without running:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/joelwisdom/winget-app-installer/master/Install.ps1))) -NoRun
```

To install to a custom directory:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/joelwisdom/winget-app-installer/master/Install.ps1))) -InstallDir "C:\Tools\winget-installer"
```

**Alternative:** Clone the repo and run directly.

## Quick Start

**Double-click:** Run `Run-Installer.cmd` to launch interactive mode.

**PowerShell:**

```powershell
# Interactive mode (default)
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1

# Install from a profile
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -Profile profiles/developer.json

# Dry-run a profile (see what would install)
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -Profile profiles/developer.json -DryRun

# Upgrade all installed catalog apps
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -UpdateAll

# Search winget for an app
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -Search "visual studio"

# Export installed apps to a profile
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -Export my-setup.json

# Silent profile install (no prompts, for automation)
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -Profile profiles/developer.json -Silent
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Profile <path>` | Run a profile JSON for unattended install |
| `-Interactive` | Launch guided category-based selection (default) |
| `-UpdateAll` | Upgrade all installed apps found in the catalog |
| `-DryRun` | Show what would happen without executing |
| `-Silent` | Suppress prompts (requires `-Profile`) |
| `-Search <term>` | Search the winget catalog |
| `-Export <path>` | Export installed catalog apps to a profile JSON |
| `-LogDir <path>` | Custom log directory (default: `./logs`) |

## Profiles

Profiles are JSON files that define a set of apps to install. See `profiles/` for examples.

```json
{
  "name": "Developer Workstation",
  "description": "Core development tools",
  "apps": [
    "Git.Git",
    "Microsoft.VisualStudioCode",
    "OpenJS.Nodejs"
  ],
  "tags": ["dev-core"],
  "preInstall": null,
  "postInstall": null
}
```

- **apps** — explicit list of winget package IDs to install
- **tags** — install any app in the catalog matching these tags (merged with `apps`)
- **preInstall / postInstall** — optional paths to PowerShell scripts to run before/after

### Included Profiles

| Profile | Description |
|---------|-------------|
| `developer.json` | Git, VS Code, Node.js, Terminal, AWS CLI, etc. |
| `general.json` | Chrome, Discord, Spotify, 7-Zip, Zoom |
| `example-custom.json` | Template to copy and customize |

## App Catalog

The app catalog lives in `catalog/apps.json`. Each app has an `id` (winget package ID), `name`, and `tags`.

To add your own apps without modifying the main catalog, create `catalog/custom-apps.json` with the same format — it will be merged automatically.

## Project Structure

```
Install.ps1             # Bootstrap script (irm | iex)
Install-Apps.ps1        # Entry point
Run-Installer.cmd       # Batch launcher (double-click)
catalog/
  apps.json             # Master app catalog (31 apps, 7 categories)
profiles/
  developer.json        # Dev workstation profile
  general.json          # General user profile
  example-custom.json   # Template for custom profiles
src/
  UI.ps1                # Console output and input validation
  Logger.ps1            # File logging and install reports
  Config.ps1            # Catalog and profile loading
  Engine.ps1            # Core winget install/upgrade logic
  Interactive.ps1       # Interactive menu mode
logs/                   # Created at runtime (gitignored)
```

## Legacy Scripts

The original `AppInstaller.ps1` and `GetMyApps.ps1` are preserved for reference but are superseded by `Install-Apps.ps1`.
