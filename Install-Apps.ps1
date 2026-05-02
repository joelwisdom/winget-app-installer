param(
    [string]$Profile,
    [switch]$Interactive,
    [switch]$UpdateAll,
    [switch]$DryRun,
    [switch]$Silent,
    [string]$Search,
    [string]$Export,
    [string]$Import,
    [switch]$NoElevate,
    [string]$LogDir
)

# --- Bypass execution policy for this process ---
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# --- Dot-source modules ---
. "$PSScriptRoot\src\Admin.ps1"
. "$PSScriptRoot\src\UI.ps1"
. "$PSScriptRoot\src\Logger.ps1"
. "$PSScriptRoot\src\Config.ps1"
. "$PSScriptRoot\src\Engine.ps1"
. "$PSScriptRoot\src\Interactive.ps1"

# --- Request admin elevation ---
if (-not $NoElevate -and -not (Test-IsAdmin)) {
    Write-Status "Not running as Administrator. Requesting elevation..." -Type Warning
    $elevated = Request-Elevation -BoundParams $PSBoundParameters -ScriptPath $PSCommandPath
    if ($elevated) {
        exit 0
    }
    # If elevation was declined, continue without admin
}

# --- Show banner ---
Write-Banner -IsAdmin (Test-IsAdmin)

# --- Defaults ---
if (-not $LogDir) {
    $LogDir = Join-Path $PSScriptRoot "logs"
}

# --- Preflight checks ---
if (-not (Test-WingetAvailable)) {
    Write-Status "winget is not installed or not in PATH. Please install App Installer from the Microsoft Store." -Type Error
    Wait-ForKeyPress
    exit 1
}

# --- Load catalog ---
$catalog = Read-AppCatalog
$customCatalog = Read-CustomCatalog
if ($customCatalog) {
    $catalog = Merge-Catalogs -MainCatalog $catalog -CustomCatalog $customCatalog
}

if (-not $catalog) {
    Write-Status "Failed to load app catalog." -Type Error
    Wait-ForKeyPress
    exit 1
}

# --- Initialize logging ---
$logPath = New-InstallLog -LogDir $LogDir

# --- Handle search mode ---
if ($Search) {
    Write-Status "Searching winget for '$Search'..." -Type Info
    winget search $Search --accept-source-agreements
    Wait-ForKeyPress
    exit 0
}

# --- Handle export mode ---
if ($Export) {
    Write-Status "Exporting installed apps to profile..." -Type Info
    $allApps = Get-AllCatalogApps -Catalog $catalog
    $installedApps = @()

    foreach ($app in $allApps) {
        Write-Host "  Checking $($app.id)..." -ForegroundColor DarkGray -NoNewline
        if (Test-WingetAppInstalled -Id $app.id) {
            $installedApps += $app.id
            Write-Host " installed" -ForegroundColor Green
        } else {
            Write-Host " not found" -ForegroundColor DarkGray
        }
    }

    $exportProfile = @{
        name        = "Exported Profile"
        description = "Auto-generated from installed apps on $(Get-Date -Format 'yyyy-MM-dd')"
        apps        = $installedApps
        tags        = @()
        preInstall  = $null
        postInstall = $null
    }

    $exportProfile | ConvertTo-Json -Depth 10 | Set-Content -Path $Export
    Write-Status "Exported $($installedApps.Count) apps to $Export" -Type Success
    Wait-ForKeyPress
    exit 0
}

# --- Handle profile mode ---
if ($Profile) {
    $profilePath = $Profile
    if (-not [System.IO.Path]::IsPathRooted($profilePath)) {
        $profilePath = Join-Path $PSScriptRoot $Profile
    }

    $profileData = Read-InstallProfile -Path $profilePath -Catalog $catalog
    if (-not $profileData) {
        Wait-ForKeyPress
        exit 1
    }

    Write-Status "Profile: $($profileData.Name)" -Type Info
    Write-Status "$($profileData.Description)" -Type Info
    Write-Status "Apps to process: $($profileData.Apps.Count)" -Type Info
    Write-Log -Path $logPath -Message "Running profile: $($profileData.Name)" -Level INFO

    if ($DryRun) {
        Write-Status "DRY RUN - no changes will be made" -Type Warning
    }

    # Run pre-install hook
    if ($profileData.PreInstall -and -not $DryRun) {
        $hookPath = $profileData.PreInstall
        if (-not [System.IO.Path]::IsPathRooted($hookPath)) {
            $hookPath = Join-Path $PSScriptRoot $hookPath
        }
        if (Test-Path $hookPath) {
            Write-Status "Running pre-install hook: $hookPath" -Type Info
            Write-Log -Path $logPath -Message "Running pre-install: $hookPath" -Level INFO
            try {
                . $hookPath
            } catch {
                Write-Status "Pre-install hook failed: $_" -Type Error
                Write-Log -Path $logPath -Message "Pre-install hook failed: $_" -Level ERROR
            }
        } else {
            Write-Status "Pre-install hook not found: $hookPath" -Type Warning
        }
    }

    # Process apps
    $results = @()
    $totalApps = $profileData.Apps.Count
    $profileSw = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $totalApps; $i++) {
        $appId = $profileData.Apps[$i]
        $isInstalled = Test-WingetAppInstalled -Id $appId
        if ($isInstalled) {
            if ($UpdateAll) {
                $result = Invoke-AppAction -Id $appId -Action Upgrade -DryRun:$DryRun -LogPath $logPath -CurrentIndex ($i + 1) -TotalCount $totalApps
            } else {
                Write-Status "[$($i + 1)/$totalApps] $appId already installed. Skipping." -Type Info
                Write-Log -Path $logPath -Message "Skipped $appId (already installed)" -Level INFO
                $result = @{ Id = $appId; Action = "Skipped"; Success = $true; ExitCode = 0; Duration = 0 }
            }
        } else {
            $result = Invoke-AppAction -Id $appId -Action Install -DryRun:$DryRun -LogPath $logPath -CurrentIndex ($i + 1) -TotalCount $totalApps
        }
        $results += $result
    }
    $profileSw.Stop()
    Write-ElapsedTime -Stopwatch $profileSw

    # Run post-install hook
    if ($profileData.PostInstall -and -not $DryRun) {
        $hookPath = $profileData.PostInstall
        if (-not [System.IO.Path]::IsPathRooted($hookPath)) {
            $hookPath = Join-Path $PSScriptRoot $hookPath
        }
        if (Test-Path $hookPath) {
            Write-Status "Running post-install hook: $hookPath" -Type Info
            Write-Log -Path $logPath -Message "Running post-install: $hookPath" -Level INFO
            try {
                . $hookPath
            } catch {
                Write-Status "Post-install hook failed: $_" -Type Error
                Write-Log -Path $logPath -Message "Post-install hook failed: $_" -Level ERROR
            }
        } else {
            Write-Status "Post-install hook not found: $hookPath" -Type Warning
        }
    }

    Write-InstallReport -Results $results -LogPath $logPath
    Write-ResultsSummary -Results $results
    Write-Status "Log saved to: $logPath" -Type Info

    if (-not $Silent) {
        Wait-ForKeyPress
    }

    $failed = @($results | Where-Object { -not $_.Success -and $_.Action -ne "Skipped" })
    exit $(if ($failed.Count -gt 0) { 1 } else { 0 })
}

# --- Handle update-all mode (no profile) ---
if ($UpdateAll) {
    Write-Status "Checking all catalog apps for updates..." -Type Info
    Write-Log -Path $logPath -Message "Running update-all mode" -Level INFO

    if ($DryRun) {
        Write-Status "DRY RUN - no changes will be made" -Type Warning
    }

    $allApps = Get-AllCatalogApps -Catalog $catalog
    $results = @()
    $toUpgrade = @()

    # First pass: discover which apps are installed
    foreach ($app in $allApps) {
        Write-Host "  Checking $($app.id)..." -ForegroundColor DarkGray -NoNewline
        if (Test-WingetAppInstalled -Id $app.id) {
            Write-Host " found" -ForegroundColor Cyan
            $toUpgrade += $app
        } else {
            Write-Host " not installed" -ForegroundColor DarkGray
        }
    }

    # Second pass: upgrade with progress
    if ($toUpgrade.Count -gt 0) {
        Write-Status "Upgrading $($toUpgrade.Count) installed app(s)..." -Type Info
        $updateSw = [System.Diagnostics.Stopwatch]::StartNew()
        for ($i = 0; $i -lt $toUpgrade.Count; $i++) {
            $result = Invoke-AppAction -Id $toUpgrade[$i].id -Action Upgrade -DryRun:$DryRun -LogPath $logPath -CurrentIndex ($i + 1) -TotalCount $toUpgrade.Count
            $results += $result
        }
        $updateSw.Stop()
        Write-ElapsedTime -Stopwatch $updateSw
    }

    if ($results.Count -eq 0) {
        Write-Status "No catalog apps are currently installed." -Type Info
    } else {
        Write-InstallReport -Results $results -LogPath $logPath
        Write-ResultsSummary -Results $results
    }

    Write-Status "Log saved to: $logPath" -Type Info
    Wait-ForKeyPress
    exit 0
}

# --- Default: Interactive mode ---
if ($DryRun) {
    Write-Status "DRY RUN - no changes will be made" -Type Warning
}

$results = Start-InteractiveInstall -Catalog $catalog -LogPath $logPath -DryRun:$DryRun

if ($results.Count -gt 0) {
    Write-InstallReport -Results $results -LogPath $logPath
    Write-ResultsSummary -Results $results
    Write-Status "Log saved to: $logPath" -Type Info
}

Wait-ForKeyPress

$failed = @($results | Where-Object { -not $_.Success -and $_.Action -ne "Skipped" })
exit $(if ($failed.Count -gt 0) { 1 } else { 0 })
