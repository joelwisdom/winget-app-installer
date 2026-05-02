function Invoke-WingetSearch {
    param(
        [Parameter(Mandatory)]
        [string]$Query
    )

    $output = winget search $Query --accept-source-agreements 2>&1 | Out-String
    $lines = $output -split "`n" | ForEach-Object { $_.TrimEnd() }

    # Find the separator line (all dashes/spaces) to locate column positions
    $separatorIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*-{3,}') {
            $separatorIndex = $i
            break
        }
    }

    if ($separatorIndex -lt 1) {
        return @()
    }

    $headerLine = $lines[$separatorIndex - 1]
    $separatorLine = $lines[$separatorIndex]

    # Parse column positions from the header
    $nameStart = 0
    $idStart = $headerLine.IndexOf("Id")
    $versionStart = $headerLine.IndexOf("Version")
    $sourceStart = $headerLine.IndexOf("Source")

    if ($idStart -lt 0 -or $versionStart -lt 0) {
        return @()
    }

    $results = @()
    for ($i = $separatorIndex + 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.Length -lt $versionStart) { continue }

        $name = $line.Substring($nameStart, [Math]::Min($idStart, $line.Length) - $nameStart).Trim()
        $id = ""
        $version = ""
        $source = ""

        if ($line.Length -gt $idStart) {
            $idEnd = [Math]::Min($versionStart, $line.Length)
            $id = $line.Substring($idStart, $idEnd - $idStart).Trim()
        }
        if ($line.Length -gt $versionStart) {
            if ($sourceStart -gt 0 -and $line.Length -gt $sourceStart) {
                $version = $line.Substring($versionStart, $sourceStart - $versionStart).Trim()
                $source = $line.Substring($sourceStart).Trim()
            } else {
                $version = $line.Substring($versionStart).Trim()
            }
        }

        if ($id) {
            $results += [PSCustomObject]@{
                Name    = $name
                Id      = $id
                Version = $version
                Source  = $source
            }
        }
    }

    return $results
}

function Start-InteractiveSearch {
    param(
        [string]$InitialQuery,

        [Parameter(Mandatory)]
        [string]$CatalogRoot
    )

    $query = $InitialQuery

    while ($true) {
        if (-not $query) {
            $query = Read-Host "`n  Search winget (or 'q' to quit)"
            if ($query -eq "q" -or $query -eq "Q" -or [string]::IsNullOrWhiteSpace($query)) {
                return
            }
        }

        Write-Status "Searching winget for '$query'..." -Type Info
        $results = Invoke-WingetSearch -Query $query

        if ($results.Count -eq 0) {
            Write-Status "No results found." -Type Warning
            $query = $null
            continue
        }

        # Display results as numbered list
        Write-Host ""
        Write-Host "  Search Results ($($results.Count) found)" -ForegroundColor White -BackgroundColor DarkCyan
        Write-Host "  $("=" * 40)" -ForegroundColor DarkCyan

        $displayCount = [Math]::Min($results.Count, 20)
        for ($i = 0; $i -lt $displayCount; $i++) {
            $r = $results[$i]
            Write-Host "    " -NoNewline
            Write-Host "$($i + 1)".PadLeft(2) -ForegroundColor Yellow -NoNewline
            Write-Host " - $($r.Name)" -ForegroundColor White -NoNewline
            Write-Host " ($($r.Id))" -ForegroundColor DarkGray -NoNewline
            Write-Host " v$($r.Version)" -ForegroundColor DarkGray
        }

        if ($results.Count -gt 20) {
            Write-Host "    ... and $($results.Count - 20) more (refine your search)" -ForegroundColor DarkGray
        }

        Write-Host ""
        $numbers = Read-ValidatedInput -Prompt "  Select apps to act on" -MaxRange $displayCount -AllowEmpty -AllowSelectAll

        if ($numbers.Count -eq 0) {
            $query = $null
            continue
        }

        # For each selected app, offer actions
        foreach ($num in $numbers) {
            $selected = $results[$num - 1]
            Write-Host ""
            Write-Host "  Selected: $($selected.Name) ($($selected.Id))" -ForegroundColor Cyan
            Write-Host "    1 - Install now"
            Write-Host "    2 - Add to custom catalog"
            Write-Host "    3 - Skip"

            $action = Read-Host "    Action"

            switch ($action) {
                "1" {
                    Write-Status "Installing $($selected.Id)..." -Type Info
                    $result = Install-WingetApp -Id $selected.Id
                    if ($result.Success) {
                        Write-Status "$($selected.Id) installed successfully." -Type Success
                    } else {
                        Write-Status "$($selected.Id) installation failed (exit code $($result.ExitCode))." -Type Error
                    }
                }
                "2" {
                    $app = @{
                        id   = $selected.Id
                        name = $selected.Name
                        tags = @("user-added")
                    }
                    Save-ToCustomCatalog -App $app -CatalogRoot $CatalogRoot
                    Write-Status "Added $($selected.Id) to custom catalog." -Type Success
                }
                default {
                    Write-Status "Skipped $($selected.Id)." -Type Info
                }
            }
        }

        $query = $null
    }
}

function Save-ToCustomCatalog {
    param(
        [Parameter(Mandatory)]
        [hashtable]$App,

        [Parameter(Mandatory)]
        [string]$CatalogRoot
    )

    $customPath = Join-Path $CatalogRoot "catalog\custom-apps.json"

    if (Test-Path $customPath) {
        $custom = Get-Content $customPath -Raw | ConvertFrom-Json
    } else {
        $custom = @{
            version    = 1
            categories = @()
        }
    }

    # Find or create "User Added" category
    $userCategory = $custom.categories | Where-Object { $_.name -eq "User Added" }

    if (-not $userCategory) {
        $userCategory = @{
            name = "User Added"
            apps = @()
        }
        $custom.categories += $userCategory
    }

    # Check for duplicates
    $existing = $userCategory.apps | Where-Object { $_.id -eq $App.id }
    if ($existing) {
        return
    }

    $userCategory.apps += $App
    $custom | ConvertTo-Json -Depth 10 | Set-Content -Path $customPath
}

function Save-ToProfile {
    param(
        [Parameter(Mandatory)]
        [string]$AppId,

        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    if (-not (Test-Path $ProfilePath)) {
        Write-Status "Profile not found: $ProfilePath" -Type Error
        return
    }

    $profile = Get-Content $ProfilePath -Raw | ConvertFrom-Json

    if ($profile.apps -contains $AppId) {
        Write-Status "$AppId already in profile." -Type Info
        return
    }

    $profile.apps += $AppId
    $profile | ConvertTo-Json -Depth 10 | Set-Content -Path $ProfilePath
    Write-Status "Added $AppId to profile." -Type Success
}
