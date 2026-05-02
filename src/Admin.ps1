function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Elevation {
    param(
        [Parameter(Mandatory)]
        [hashtable]$BoundParams,

        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    # Rebuild argument list from bound parameters
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"")

    foreach ($key in $BoundParams.Keys) {
        $value = $BoundParams[$key]
        if ($value -is [switch] -or $value -is [bool]) {
            if ($value) {
                $argList += "-$key"
            }
        } else {
            $argList += "-$key"
            $argList += "`"$value`""
        }
    }

    try {
        Start-Process powershell -Verb RunAs -ArgumentList ($argList -join " ")
    } catch {
        Write-Status "UAC was declined. Continuing without admin — some installs may prompt individually." -Type Warning
        return $false
    }

    return $true
}
