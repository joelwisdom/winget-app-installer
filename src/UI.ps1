function Write-Banner {
    param(
        [bool]$IsAdmin = $false
    )

    $adminText = if ($IsAdmin) { "Administrator" } else { "Standard User" }
    $adminColor = if ($IsAdmin) { "Green" } else { "Yellow" }

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   " -ForegroundColor Cyan -NoNewline
    Write-Host "winget App Installer" -ForegroundColor White -NoNewline
    Write-Host "              ║" -ForegroundColor Cyan
    Write-Host "  ║   Running as: " -ForegroundColor Cyan -NoNewline
    Write-Host "$($adminText.PadRight(23))" -ForegroundColor $adminColor -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-ElapsedTime {
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Stopwatch]$Stopwatch
    )

    $elapsed = $Stopwatch.Elapsed
    if ($elapsed.TotalMinutes -ge 1) {
        $timeStr = "{0}m {1}s" -f [math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
    } else {
        $timeStr = "{0}s" -f [math]::Round($elapsed.TotalSeconds, 1)
    }
    Write-Host "  Total time: $timeStr" -ForegroundColor DarkGray
}

function Write-Status {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )

    $colors = @{
        Info    = "Cyan"
        Success = "Green"
        Warning = "Yellow"
        Error   = "Red"
    }

    $prefixes = @{
        Info    = "[*]"
        Success = "[+]"
        Warning = "[!]"
        Error   = "[-]"
    }

    Write-Host "$($prefixes[$Type]) $Message" -ForegroundColor $colors[$Type]
}

function Write-CategoryHeader {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    Write-Host ""
    Write-Host "  $Name" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "  $('=' * ($Name.Length))" -ForegroundColor DarkBlue
}

function Write-AppList {
    param(
        [Parameter(Mandatory)]
        [array]$Apps
    )

    for ($i = 0; $i -lt $Apps.Count; $i++) {
        $num = $i + 1
        Write-Host "    " -NoNewline
        Write-Host "$num" -ForegroundColor Yellow -NoNewline
        Write-Host " - $($Apps[$i].name)" -ForegroundColor White -NoNewline
        Write-Host " ($($Apps[$i].id))" -ForegroundColor DarkGray
    }
}

function Write-InstallResult {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Result
    )

    if ($Result.Success) {
        Write-Status "$($Result.Action): $($Result.Id) ($($Result.Duration)s)" -Type Success
    } else {
        Write-Status "$($Result.Action) failed: $($Result.Id) (exit code $($Result.ExitCode))" -Type Error
    }
}

function Write-ResultsSummary {
    param(
        [Parameter(Mandatory)]
        [array]$Results
    )

    $succeeded = @($Results | Where-Object { $_.Success })
    $failed = @($Results | Where-Object { -not $_.Success })

    Write-Host ""
    Write-Host "  Summary" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "  =======" -ForegroundColor DarkBlue
    Write-Status "Total: $($Results.Count)  |  Succeeded: $($succeeded.Count)  |  Failed: $($failed.Count)" -Type Info

    if ($failed.Count -gt 0) {
        Write-Host ""
        Write-Status "Failed applications:" -Type Error
        foreach ($f in $failed) {
            Write-Host "    - $($f.Id) (exit code $($f.ExitCode))" -ForegroundColor Red
        }
    }
}

function Read-ValidatedInput {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [int]$MaxRange,

        [switch]$AllowEmpty
    )

    while ($true) {
        $input = Read-Host $Prompt

        # Allow empty input to skip
        if ([string]::IsNullOrWhiteSpace($input)) {
            if ($AllowEmpty) {
                return @()
            }
            Write-Status "Input cannot be empty. Please try again." -Type Warning
            continue
        }

        $parts = $input.Trim() -split '\s+'
        $valid = $true
        $numbers = @()

        foreach ($part in $parts) {
            $num = 0
            if (-not [int]::TryParse($part, [ref]$num)) {
                Write-Status "'$part' is not a valid number." -Type Warning
                $valid = $false
                break
            }
            if ($num -lt 1 -or $num -gt $MaxRange) {
                Write-Status "$num is out of range (1-$MaxRange)." -Type Warning
                $valid = $false
                break
            }
            $numbers += $num
        }

        if ($valid) {
            return $numbers
        }
    }
}

function Read-Confirmation {
    param(
        [string]$Prompt = "Proceed? [Y/n]"
    )

    $response = Read-Host $Prompt
    return ($response -ne "n" -and $response -ne "N")
}

function Wait-ForKeyPress {
    if ($Host.Name -eq "ConsoleHost") {
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor DarkGray
        $Host.UI.RawUI.FlushInputBuffer()
        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
    }
}
