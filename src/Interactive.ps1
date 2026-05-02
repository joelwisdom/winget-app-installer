function Start-InteractiveInstall {
    param(
        [Parameter(Mandatory)]
        [object]$Catalog,

        [string]$LogPath,

        [switch]$DryRun
    )

    $selectedIds = @()

    Write-Host ""
    Write-Status "Interactive App Installer" -Type Info
    Write-Host "  Select apps from each category. Enter numbers separated by spaces."
    Write-Host "  Leave empty to skip a category."

    foreach ($category in $Catalog.categories) {
        Write-CategoryHeader -Name $category.name
        Write-AppList -Apps $category.apps

        $numbers = Read-ValidatedInput -Prompt "  Select (e.g. 1 3 4)" -MaxRange $category.apps.Count -AllowEmpty

        foreach ($num in $numbers) {
            $app = $category.apps[$num - 1]
            $selectedIds += $app.id
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
    Write-Host ""

    # Confirmation
    if (-not (Read-Confirmation -Prompt "  Proceed with installation? [Y/n]")) {
        Write-Status "Installation cancelled." -Type Warning
        return @()
    }

    # Install selected apps
    Write-Host ""
    $results = @()

    foreach ($appId in $selectedIds) {
        $isInstalled = Test-WingetAppInstalled -Id $appId
        if ($isInstalled) {
            Write-Status "$appId is already installed. Upgrading..." -Type Info
            $result = Invoke-AppAction -Id $appId -Action Upgrade -DryRun:$DryRun -LogPath $LogPath
        } else {
            $result = Invoke-AppAction -Id $appId -Action Install -DryRun:$DryRun -LogPath $LogPath
        }
        $results += $result
    }

    return $results
}
