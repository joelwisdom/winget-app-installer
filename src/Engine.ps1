function Test-WingetAvailable {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-WingetAppInstalled {
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    $output = winget list --id $Id --exact --accept-source-agreements 2>&1
    return ($LASTEXITCODE -eq 0)
}

function Install-WingetApp {
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [switch]$DryRun
    )

    if ($DryRun) {
        return @{
            Id       = $Id
            Action   = "Install"
            Success  = $true
            ExitCode = 0
            Duration = 0
            DryRun   = $true
        }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    winget install -e -h --id $Id --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    $sw.Stop()

    return @{
        Id       = $Id
        Action   = "Install"
        Success  = ($LASTEXITCODE -eq 0)
        ExitCode = $LASTEXITCODE
        Duration = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        DryRun   = $false
    }
}

function Update-WingetApp {
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [switch]$DryRun
    )

    if ($DryRun) {
        return @{
            Id       = $Id
            Action   = "Upgrade"
            Success  = $true
            ExitCode = 0
            Duration = 0
            DryRun   = $true
        }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    winget upgrade -e -h --id $Id --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    $sw.Stop()

    return @{
        Id       = $Id
        Action   = "Upgrade"
        Success  = ($LASTEXITCODE -eq 0)
        ExitCode = $LASTEXITCODE
        Duration = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        DryRun   = $false
    }
}

function Invoke-AppAction {
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        [ValidateSet("Install", "Upgrade")]
        [string]$Action,

        [switch]$DryRun,

        [string]$LogPath,

        [int]$CurrentIndex = 0,

        [int]$TotalCount = 0
    )

    $dryLabel = if ($DryRun) { "[DRY RUN] " } else { "" }
    $progressLabel = if ($TotalCount -gt 0) { "[$CurrentIndex/$TotalCount] " } else { "" }

    if ($Action -eq "Install") {
        if ($LogPath) { Write-Log -Path $LogPath -Message "${dryLabel}Installing $Id" -Level INFO }
        Write-Status "${progressLabel}${dryLabel}Installing $Id..." -Type Info
        $result = Install-WingetApp -Id $Id -DryRun:$DryRun
    } else {
        if ($LogPath) { Write-Log -Path $LogPath -Message "${dryLabel}Upgrading $Id" -Level INFO }
        Write-Status "${progressLabel}${dryLabel}Upgrading $Id..." -Type Info
        $result = Update-WingetApp -Id $Id -DryRun:$DryRun
    }

    if ($LogPath) {
        $level = if ($result.Success) { "INFO" } else { "ERROR" }
        Write-Log -Path $LogPath -Message "${dryLabel}$($result.Action) $Id - exit code $($result.ExitCode) ($($result.Duration)s)" -Level $level
    }

    Write-InstallResult -Result $result
    return $result
}
