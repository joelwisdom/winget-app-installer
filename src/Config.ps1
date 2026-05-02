function Read-AppCatalog {
    param(
        [string]$Path
    )

    if (-not $Path) {
        $Path = Join-Path $PSScriptRoot "..\catalog\apps.json"
    }

    if (-not (Test-Path $Path)) {
        Write-Status "Catalog not found: $Path" -Type Error
        return $null
    }

    $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
    return $json
}

function Read-CustomCatalog {
    param(
        [string]$Path
    )

    if (-not $Path) {
        $Path = Join-Path $PSScriptRoot "..\catalog\custom-apps.json"
    }

    if (-not (Test-Path $Path)) {
        return $null
    }

    $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
    return $json
}

function Merge-Catalogs {
    param(
        [Parameter(Mandatory)]
        [object]$MainCatalog,

        [object]$CustomCatalog
    )

    if (-not $CustomCatalog) {
        return $MainCatalog
    }

    foreach ($customCat in $CustomCatalog.categories) {
        $existing = $MainCatalog.categories | Where-Object { $_.name -eq $customCat.name }
        if ($existing) {
            # Merge apps into existing category, skip duplicates
            foreach ($app in $customCat.apps) {
                $isDuplicate = $existing.apps | Where-Object { $_.id -eq $app.id }
                if (-not $isDuplicate) {
                    $existing.apps += $app
                }
            }
        } else {
            $MainCatalog.categories += $customCat
        }
    }

    return $MainCatalog
}

function Get-AllCatalogApps {
    param(
        [Parameter(Mandatory)]
        [object]$Catalog
    )

    $allApps = @()
    foreach ($category in $Catalog.categories) {
        foreach ($app in $category.apps) {
            $allApps += $app
        }
    }
    return $allApps
}

function Read-InstallProfile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Catalog
    )

    if (-not (Test-Path $Path)) {
        Write-Status "Profile not found: $Path" -Type Error
        return $null
    }

    $profile = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $allApps = Get-AllCatalogApps -Catalog $Catalog
    $resolvedIds = @()

    # Add explicitly listed apps
    if ($profile.apps) {
        foreach ($appId in $profile.apps) {
            $found = $allApps | Where-Object { $_.id -eq $appId }
            if (-not $found) {
                Write-Status "Warning: '$appId' from profile not found in catalog (will attempt install anyway)" -Type Warning
            }
            if ($appId -notin $resolvedIds) {
                $resolvedIds += $appId
            }
        }
    }

    # Add apps matching profile tags
    if ($profile.tags) {
        foreach ($app in $allApps) {
            foreach ($tag in $profile.tags) {
                if ($app.tags -contains $tag -and $app.id -notin $resolvedIds) {
                    $resolvedIds += $app.id
                }
            }
        }
    }

    return @{
        Name        = $profile.name
        Description = $profile.description
        Apps        = $resolvedIds
        PreInstall  = $profile.preInstall
        PostInstall = $profile.postInstall
    }
}
