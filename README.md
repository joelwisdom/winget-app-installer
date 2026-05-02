# winget-app-installer

A PowerShell-based tool for automating Windows app installation using [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/). Designed for enterprise laptop provisioning and power-user machine setup.

## Features

- **Admin self-elevation** — prompts for UAC once at startup so individual installs don't each require elevation
- **Interactive mode** — guided category-based app selection with select-all, back navigation, and tag display
- **Profile mode** — unattended installs from JSON configuration files (idempotent)
- **Interactive search** — search the winget catalog, then install or add results to your catalog
- **Import** — import apps from `winget export` to create profiles or extend your catalog
- **Update-all** — upgrade every installed catalog app in one command
- **Dry-run** — preview what would happen without calling winget
- **Export** — generate a profile from currently installed apps
- **Progress tracking** — [X/Y] counter and elapsed time during installs
- **Logging** — timestamped log files with install reports
- **Extensible catalog** — 62 apps across 9 categories, with custom overlay support
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
# Interactive mode (default) — auto-elevates to admin
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1

# Install from a profile
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -Profile profiles/developer.json

# Dry-run a profile (see what would install)
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -Profile profiles/developer.json -DryRun

# Upgrade all installed catalog apps
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -UpdateAll

# Search winget interactively (install or add to catalog)
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -Search "visual studio"

# Import from another machine's winget export
winget export -o my-apps.json   # on source machine
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -Import my-apps.json

# Export installed apps to a profile
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -Export my-setup.json

# Silent profile install (no prompts, for automation)
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -Profile profiles/developer.json -Silent

# Skip admin elevation
powershell -ExecutionPolicy Bypass -File .\Install-Apps.ps1 -NoElevate
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Profile <path>` | Run a profile JSON for unattended install |
| `-Interactive` | Launch guided category-based selection (default) |
| `-UpdateAll` | Upgrade all installed apps found in the catalog |
| `-DryRun` | Show what would happen without executing |
| `-Silent` | Suppress prompts (requires `-Profile`) |
| `-Search <term>` | Search winget interactively — install or add to catalog |
| `-Import <path>` | Import apps from a `winget export` JSON file |
| `-Export <path>` | Export installed catalog apps to a profile JSON |
| `-NoElevate` | Skip the admin elevation prompt at startup |
| `-LogDir <path>` | Custom log directory (default: `./logs`) |

## Interactive Mode

When selecting apps from categories:
- Enter numbers separated by spaces (e.g. `1 3 4`)
- Enter `a` to select all apps in a category
- Enter `b` to go back to the previous category
- Leave empty to skip a category

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

The app catalog lives in `catalog/apps.json` with 62 apps across 9 categories:

| Category | Apps |
|----------|------|
| Browsers | Chrome, Firefox, LibreWolf, Brave, Edge, Arc |
| Communication | Discord, WhatsApp, Thunderbird, Slack, Teams, Zoom, Telegram, Element |
| Development | Git, GitHub CLI, VS Code, JetBrains IDEs, Node.js, Python, Docker, Postman, cloud CLIs, terminals |
| Media | Spotify, VLC, OBS Studio, GIMP, Audacity, HandBrake, qBittorrent |
| Gaming | Steam, Epic Games, GOG Galaxy |
| Security | Bitwarden, KeePassXC, NordVPN, Proton VPN, Malwarebytes |
| Productivity | Notion, Obsidian, LibreOffice, Adobe Reader, Notepad++ |
| Networking | VMware, Wireshark, PuTTY, WinSCP, Nmap |
| Utility | 7-Zip, WinRAR, PowerToys, Everything, WinDirStat, Sysinternals, HWiNFO |

To add your own apps without modifying the main catalog, create `catalog/custom-apps.json` with the same format — it will be merged automatically.

## Project Structure

```
Install.ps1             # Bootstrap script (irm | iex)
Install-Apps.ps1        # Entry point
Run-Installer.cmd       # Batch launcher (double-click)
catalog/
  apps.json             # Master app catalog (62 apps, 9 categories)
profiles/
  developer.json        # Dev workstation profile
  general.json          # General user profile
  example-custom.json   # Template for custom profiles
src/
  Admin.ps1             # Admin detection and UAC elevation
  UI.ps1                # Console output, banner, and input validation
  Logger.ps1            # File logging and install reports
  Config.ps1            # Catalog and profile loading
  Engine.ps1            # Core winget install/upgrade logic with progress
  Interactive.ps1       # Interactive menu with back navigation
  Search.ps1            # Winget search parsing and interactive selection
  Import.ps1            # Winget export import and profile generation
logs/                   # Created at runtime (gitignored)
```
