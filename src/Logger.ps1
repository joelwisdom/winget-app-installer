function New-InstallLog {
    param(
        [Parameter(Mandatory)]
        [string]$LogDir
    )

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $logPath = Join-Path $LogDir "install-$timestamp.log"
    New-Item -ItemType File -Path $logPath -Force | Out-Null

    Write-Log -Path $logPath -Message "Log started" -Level INFO
    return $logPath
}

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $Path -Value $line
}

function Write-InstallReport {
    param(
        [Parameter(Mandatory)]
        [array]$Results,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $succeeded = @($Results | Where-Object { $_.Success })
    $failed = @($Results | Where-Object { -not $_.Success })
    $skipped = @($Results | Where-Object { $_.Action -eq "Skipped" })

    Write-Log -Path $LogPath -Message "--- INSTALL REPORT ---" -Level INFO
    Write-Log -Path $LogPath -Message "Total: $($Results.Count)" -Level INFO
    Write-Log -Path $LogPath -Message "Succeeded: $($succeeded.Count)" -Level INFO
    Write-Log -Path $LogPath -Message "Failed: $($failed.Count)" -Level INFO
    Write-Log -Path $LogPath -Message "Skipped: $($skipped.Count)" -Level INFO

    if ($failed.Count -gt 0) {
        Write-Log -Path $LogPath -Message "Failed applications:" -Level ERROR
        foreach ($f in $failed) {
            Write-Log -Path $LogPath -Message "  $($f.Id) - exit code $($f.ExitCode)" -Level ERROR
        }
    }

    if ($succeeded.Count -gt 0) {
        Write-Log -Path $LogPath -Message "Succeeded applications:" -Level INFO
        foreach ($s in $succeeded) {
            Write-Log -Path $LogPath -Message "  $($s.Id) ($($s.Duration)s)" -Level INFO
        }
    }

    Write-Log -Path $LogPath -Message "--- END REPORT ---" -Level INFO
}
