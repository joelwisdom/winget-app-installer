function Import-WingetExport {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$CatalogRoot
    )

    if (-not (Test-Path $Path)) {
        Write-Status "Import file not found: $Path" -Type Error
        return
    }

    $data = Get-Content $Path -Raw | ConvertFrom-Json

    # Extract package IDs from winget export format
    $appIds = @()
    if ($data.Sources) {
        foreach ($source in $data.Sources) {
            foreach ($pkg in $source.Packages) {
                if ($pkg.PackageIdentifier) {
                    $appIds += $pkg.PackageIdentifier
                }
            }
        }
    }

    if ($appIds.Count -eq 0) {
        Write-Status "No packages found in import file." -Type Warning
        return
    }

    Write-Status "Found $($appIds.Count) package(s) in export file." -Type Info
    Write-Host ""

    # Cross-reference with existing catalog
    $catalog = Read-AppCatalog
    $allCatalogApps = @()
    if ($catalog) {
        $allCatalogApps = Get-AllCatalogApps -Catalog $catalog
    }

    $knownIds = @()
    $newIds = @()
    foreach ($id in $appIds) {
        $match = $allCatalogApps | Where-Object { $_.id -eq $id }
        if ($match) {
            $knownIds += $id
        } else {
            $newIds += $id
        }
    }

    Write-Host "  Already in catalog: $($knownIds.Count)" -ForegroundColor Green
    Write-Host "  New (not in catalog): $($newIds.Count)" -ForegroundColor Yellow
    Write-Host ""

    # Offer save options
    Write-Host "  What would you like to do?"
    Write-Host "    1 - Save as a new profile"
    Write-Host "    2 - Add new apps to custom catalog"
    Write-Host "    3 - Both"
    Write-Host "    4 - Cancel"

    $choice = Read-Host "    Choice"

    switch ($choice) {
        "1" { Save-ImportAsProfile -AppIds $appIds -CatalogRoot $CatalogRoot }
        "2" { Save-ImportToCustomCatalog -AppIds $newIds -CatalogRoot $CatalogRoot }
        "3" {
            Save-ImportAsProfile -AppIds $appIds -CatalogRoot $CatalogRoot
            Save-ImportToCustomCatalog -AppIds $newIds -CatalogRoot $CatalogRoot
        }
        default {
            Write-Status "Import cancelled." -Type Info
        }
    }
}

function Save-ImportAsProfile {
    param(
        [Parameter(Mandatory)]
        [string[]]$AppIds,

        [Parameter(Mandatory)]
        [string]$CatalogRoot
    )

    $name = Read-Host "  Profile name"
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = "Imported Profile"
    }

    $safeName = $name -replace '[^\w\-]', '-'
    $profilePath = Join-Path $CatalogRoot "profiles\$safeName.json"

    $profile = @{
        name        = $name
        description = "Imported from winget export on $(Get-Date -Format 'yyyy-MM-dd')"
        apps        = $AppIds
        tags        = @()
        preInstall  = $null
        postInstall = $null
    }

    $profile | ConvertTo-Json -Depth 10 | Set-Content -Path $profilePath
    Write-Status "Profile saved to: $profilePath" -Type Success
}

function Save-ImportToCustomCatalog {
    param(
        [Parameter(Mandatory)]
        [string[]]$AppIds,

        [Parameter(Mandatory)]
        [string]$CatalogRoot
    )

    if ($AppIds.Count -eq 0) {
        Write-Status "No new apps to add to catalog." -Type Info
        return
    }

    $customPath = Join-Path $CatalogRoot "catalog\custom-apps.json"

    if (Test-Path $customPath) {
        $custom = Get-Content $customPath -Raw | ConvertFrom-Json
    } else {
        $custom = @{
            version    = 1
            categories = @()
        }
    }

    # Find or create "Imported" category
    $importCategory = $custom.categories | Where-Object { $_.name -eq "Imported" }

    if (-not $importCategory) {
        $importCategory = @{
            name = "Imported"
            apps = @()
        }
        $custom.categories += $importCategory
    }

    $added = 0
    foreach ($id in $AppIds) {
        $existing = $importCategory.apps | Where-Object { $_.id -eq $id }
        if (-not $existing) {
            $importCategory.apps += @{
                id   = $id
                name = $id.Split(".")[-1]
                tags = @("imported")
            }
            $added++
        }
    }

    $custom | ConvertTo-Json -Depth 10 | Set-Content -Path $customPath
    Write-Status "Added $added app(s) to custom catalog." -Type Success
}
