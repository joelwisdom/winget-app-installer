# winget-app-installer bootstrap script
# Usage: irm https://raw.githubusercontent.com/joelwisdom/winget-app-installer/master/Install.ps1 | iex

param(
    [string]$InstallDir,
    [switch]$NoRun
)

# Bypass execution policy for this process so the user never has to do it manually
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

$ErrorActionPreference = "Stop"
$repo = "joelwisdom/winget-app-installer"
$branch = "master"

# Default install location
if (-not $InstallDir) {
    $InstallDir = Join-Path $env:LOCALAPPDATA "winget-app-installer"
}

Write-Host ""
Write-Host "[*] winget-app-installer bootstrap" -ForegroundColor Cyan
Write-Host "    Installing to: $InstallDir" -ForegroundColor DarkGray
Write-Host ""

# Download zip from GitHub
$zipUrl = "https://github.com/$repo/archive/refs/heads/$branch.zip"
$zipPath = Join-Path $env:TEMP "winget-app-installer.zip"
$extractPath = Join-Path $env:TEMP "winget-app-installer-extract"

Write-Host "[*] Downloading from GitHub..." -ForegroundColor Cyan
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
} catch {
    Write-Host "[-] Download failed: $_" -ForegroundColor Red
    exit 1
}

# Extract
Write-Host "[*] Extracting..." -ForegroundColor Cyan
if (Test-Path $extractPath) {
    Remove-Item $extractPath -Recurse -Force
}
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

# The zip extracts to a subfolder named repo-branch
$sourcePath = Join-Path $extractPath "winget-app-installer-$branch"

# Copy to install directory
if (Test-Path $InstallDir) {
    Write-Host "[!] Existing installation found. Updating..." -ForegroundColor Yellow
    # Preserve custom catalog and user profiles
    $customCatalog = Join-Path $InstallDir "catalog\custom-apps.json"
    $hasCustomCatalog = Test-Path $customCatalog
    $userProfiles = @()
    $profilesDir = Join-Path $InstallDir "profiles"
    if (Test-Path $profilesDir) {
        $userProfiles = Get-ChildItem $profilesDir -Filter "*.json" |
            Where-Object { $_.Name -notin @("developer.json", "general.json", "example-custom.json") }
    }

    Remove-Item $InstallDir -Recurse -Force
    Copy-Item -Path $sourcePath -Destination $InstallDir -Recurse -Force

    # Restore user files
    if ($hasCustomCatalog) {
        Copy-Item $customCatalog (Join-Path $InstallDir "catalog\custom-apps.json")
    }
    foreach ($p in $userProfiles) {
        Copy-Item $p.FullName (Join-Path $InstallDir "profiles\$($p.Name)")
    }
} else {
    Copy-Item -Path $sourcePath -Destination $InstallDir -Recurse -Force
}

# Cleanup temp files
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "[+] Installed to $InstallDir" -ForegroundColor Green
Write-Host ""
Write-Host "    Usage:" -ForegroundColor White
Write-Host "      Interactive:  & '$InstallDir\Run-Installer.cmd'" -ForegroundColor DarkGray
Write-Host "      Profile:      & '$InstallDir\Run-Installer.cmd' -Profile profiles/developer.json" -ForegroundColor DarkGray
Write-Host "      Dry-run:      & '$InstallDir\Run-Installer.cmd' -Profile profiles/developer.json -DryRun" -ForegroundColor DarkGray
Write-Host "      Update all:   & '$InstallDir\Run-Installer.cmd' -UpdateAll" -ForegroundColor DarkGray
Write-Host ""

# Run interactive mode unless told not to
if (-not $NoRun) {
    $run = Read-Host "Launch interactive installer now? [Y/n]"
    if ($run -ne "n" -and $run -ne "N") {
        $cmdPath = Join-Path $InstallDir "Run-Installer.cmd"
        cmd /c "`"$cmdPath`""
    }
}
