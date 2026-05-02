function Start-InteractiveInstall {
    param(
        [Parameter(Mandatory)]
        [object]$Catalog,

        [string]$LogPath,

        [switch]$DryRun
    )

    $categories = $Catalog.categories
    $selectionsByCategory = @{}

    Write-Host ""
    Write-Status "Interactive App Installer" -Type Info
    Write-Host "  Select apps from each category. Leave empty to skip."

    # Category selection loop with back navigation
    $catIndex = 0
    while ($catIndex -lt $categories.Count) {
        $category = $categories[$catIndex]
        Write-CategoryHeader -Name $category.name

        # Show previous selection if going back
        if ($selectionsByCategory.ContainsKey($catIndex)) {
            $prev = $selectionsByCategory[$catIndex] -join ", "
            Write-Host "  (previous selection: $prev)" -ForegroundColor DarkGray
        }

        Write-AppList -Apps $category.apps

        $allowBack = $catIndex -gt 0
        $numbers = Read-ValidatedInput -Prompt "  Select" -MaxRange $category.apps.Count -AllowEmpty -AllowSelectAll -AllowBack:$allowBack

        # Handle back
        if ($numbers.Count -eq 1 -and $numbers[0] -eq -1) {
            if ($catIndex -gt 0) {
                $catIndex--
                continue
            }
        }

        $selectionsByCategory[$catIndex] = $numbers
        $catIndex++
    }

    # Build final selection from all categories
    $selectedIds = @()
    for ($i = 0; $i -lt $categories.Count; $i++) {
        if ($selectionsByCategory.ContainsKey($i)) {
            foreach ($num in $selectionsByCategory[$i]) {
                if ($num -gt 0) {
                    $app = $categories[$i].apps[$num - 1]
                    $selectedIds += $app.id
                }
            }
        }
    }

    # Show selection summary
    Write-Host ""
    Write-Host "  Your Selection" -ForegroundColor White -BackgroundColor DarkMagenta
    Write-Host "  ==============" -ForegroundColor DarkMagenta

    if ($selectedIds.Count -eq 0) {
        Write-Status "No apps selected." -Type Warning
        return @()
    }

    foreach ($id in $selectedIds) {
        Write-Host "    - $id" -ForegroundColor White
    }
    Write-Host "  Total: $($selectedIds.Count) app(s)" -ForegroundColor DarkGray
    Write-Host ""

    # Confirmation
    if (-not (Read-Confirmation -Prompt "  Proceed with installation? [Y/n]")) {
        Write-Status "Installation cancelled." -Type Warning
        return @()
    }

    # Install selected apps
    Write-Host ""
    $results = @()
    $totalCount = $selectedIds.Count
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    for ($i = 0; $i -lt $totalCount; $i++) {
        $appId = $selectedIds[$i]
        $isInstalled = Test-WingetAppInstalled -Id $appId
        if ($isInstalled) {
            Write-Status "$appId is already installed. Upgrading..." -Type Info
            $result = Invoke-AppAction -Id $appId -Action Upgrade -DryRun:$DryRun -LogPath $LogPath -CurrentIndex ($i + 1) -TotalCount $totalCount
        } else {
            $result = Invoke-AppAction -Id $appId -Action Install -DryRun:$DryRun -LogPath $LogPath -CurrentIndex ($i + 1) -TotalCount $totalCount
        }
        $results += $result
    }

    $sw.Stop()
    Write-ElapsedTime -Stopwatch $sw

    return $results
}
