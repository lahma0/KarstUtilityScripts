<#
.SYNOPSIS
Gets the Windows LAPS password for one or more Intune-managed devices from Microsoft Graph.

.DESCRIPTION
This script retrieves the local administrator password for one or more devices using
Get-LapsAADPassword from Microsoft Graph PowerShell.

If Microsoft Graph PowerShell is not installed, the script can prompt to install it.
If it is installed but not imported, the script imports it automatically. The script
also checks the current Microsoft Graph connection and connects with the required
scopes when needed.

If DeviceIds are not supplied when the script is called, the script prompts for one
or more comma-separated device IDs.

After retrieval, the script copies to the clipboard the first password returned,
which corresponds to the first device name/identifier supplied to the script.

.PARAMETER DeviceIds
One or more Intune device IDs or names to query. This parameter accepts a string array.

.PARAMETER IncludeHistory
When supplied, requests password history in addition to the current password.

.EXAMPLE
.\Get-IntuneLocalAdminPassword.ps1

Prompts for one or more device IDs/names, then retrieves the current LAPS password.

.EXAMPLE
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop"

Retrieves the current LAPS password for a single device.

.EXAMPLE
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop","JaneDoeLaptop"

Retrieves the current LAPS password for multiple devices.

.EXAMPLE
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop" -IncludeHistory

Retrieves the current LAPS password and password history for the specified device.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$DeviceIds,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeHistory
)

$requiredScopes = @(
    "DeviceLocalCredential.Read.All",
    "Device.Read.All"
)

function Test-IsGuid {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $guid = [guid]::Empty
    return [guid]::TryParse($Value, [ref]$guid)
}

function Resolve-DeviceIdentifiers {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Identifiers
    )

    $resolvedDeviceIds = @()

    foreach ($identifier in $Identifiers) {
        $candidate = $identifier.Trim()
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        if (Test-IsGuid -Value $candidate) {
            # LAPS expects Entra device.deviceId, not directory object Id.
            try {
                $matchedByDeviceId = @(Get-MgDevice -Filter "deviceId eq '$candidate'" -Property Id, DeviceId, DisplayName -All -ErrorAction Stop)
            } catch {
                Write-Error "Failed to resolve GUID '$candidate' as a deviceId in Microsoft Graph: $_"
                exit 1
            }

            if ($matchedByDeviceId.Count -eq 1) {
                $resolvedDeviceIds += $matchedByDeviceId[0].DeviceId
                continue
            }

            if ($matchedByDeviceId.Count -gt 1) {
                $matchedIds = ($matchedByDeviceId | ForEach-Object { $_.DeviceId }) -join ", "
                Write-Error "GUID '$candidate' matched multiple devices by deviceId: $matchedIds"
                exit 1
            }

            # If not found by deviceId, treat the GUID as a directory object Id and map to deviceId.
            try {
                $matchedByObjectId = Get-MgDevice -DeviceId $candidate -Property Id, DeviceId, DisplayName -ErrorAction Stop
            } catch {
                $matchedByObjectId = $null
            }

            if ($matchedByObjectId -and -not [string]::IsNullOrWhiteSpace($matchedByObjectId.DeviceId)) {
                $resolvedDeviceIds += $matchedByObjectId.DeviceId
                continue
            }

            Write-Error "GUID '$candidate' was not found as either deviceId or directory object Id in Microsoft Graph."
            exit 1
        }

        $escapedName = $candidate.Replace("'", "''")
        try {
            $matchingDevices = @(Get-MgDevice -Filter "displayName eq '$escapedName'" -Property Id, DeviceId, DisplayName -All -ErrorAction Stop)
        } catch {
            Write-Error "Failed to resolve device name '$candidate' in Microsoft Graph: $_"
            exit 1
        }

        if ($matchingDevices.Count -eq 0) {
            Write-Error "No device found with display name '$candidate'. Provide an exact device name or a device GUID."
            exit 1
        }

        if ($matchingDevices.Count -gt 1) {
            Write-Warning "Multiple devices matched '$candidate'. Retrieving LAPS passwords for all matching devices."
        }

        foreach ($match in $matchingDevices) {
            if ([string]::IsNullOrWhiteSpace($match.DeviceId)) {
                Write-Warning "Skipping matched device '$($match.DisplayName)' (ObjectId: $($match.Id)) because DeviceId is empty."
                continue
            }

            $resolvedDeviceIds += $match.DeviceId
        }
    }

    $resolvedDeviceIds = @($resolvedDeviceIds | Select-Object -Unique)
    if ($resolvedDeviceIds.Count -eq 0) {
        Write-Error "No valid device IDs were resolved from the provided input."
        exit 1
    }

    return $resolvedDeviceIds
}

function Initialize-MicrosoftGraphModule {
    $mgModule = Get-Module -ListAvailable -Name Microsoft.Graph

    if (-not $mgModule) {
        Write-Host "Microsoft Graph PowerShell module is not installed." -ForegroundColor Yellow
        $installResponse = Read-Host "Install Microsoft.Graph now? (Y/N)"

        if ($installResponse -notin @("Y", "y")) {
            Write-Error "Microsoft.Graph is required to continue. Exiting."
            exit 1
        }

        try {
            Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Host "Microsoft.Graph installed successfully." -ForegroundColor Green
        } catch {
            Write-Error "Failed to install Microsoft.Graph: $_"
            exit 1
        }
    }

    if (-not (Get-Module -Name Microsoft.Graph)) {
        try {
            Import-Module Microsoft.Graph -ErrorAction Stop
        } catch {
            Write-Error "Failed to import Microsoft.Graph: $_"
            exit 1
        }
    }
}

function Initialize-MgGraphConnection {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Scopes
    )

    $needsConnect = $true
    $context = Get-MgContext -ErrorAction SilentlyContinue

    if ($context) {
        $currentScopes = @($context.Scopes)
        $missingScopes = $Scopes | Where-Object { $_ -notin $currentScopes }
        $needsConnect = ($missingScopes.Count -gt 0)
    }

    if ($needsConnect) {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
        try {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop | Out-Null
            Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
        } catch {
            Write-Error "Failed to connect to Microsoft Graph: $_"
            exit 1
        }
    } else {
        Write-Host "Microsoft Graph is already connected with required scopes." -ForegroundColor Green
    }
}

function Copy-FirstLapsPasswordToClipboard {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$LapsResults
    )

    $firstPassword = $null
    $firstMachineName = $null

    foreach ($result in $LapsResults) {
        $machineName = @($result.DeviceName, $result.DisplayName, $result.DeviceId, $result.Id | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
        $machineName = @($machineName)[0]

        if ($result.PSObject.Properties.Name -contains "Credentials" -and $result.Credentials) {
            foreach ($credential in @($result.Credentials)) {
                if ($credential.PSObject.Properties.Name -contains "Password" -and -not [string]::IsNullOrWhiteSpace($credential.Password)) {
                    $firstPassword = $credential.Password
                    $firstMachineName = $machineName
                    break
                }

                if ($credential.PSObject.Properties.Name -contains "passwordBase64" -and -not [string]::IsNullOrWhiteSpace($credential.passwordBase64)) {
                    try {
                        $firstPassword = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($credential.passwordBase64))
                    } catch {
                        $firstPassword = $credential.passwordBase64
                    }

                    $firstMachineName = $machineName
                    break
                }
            }
        }

        if (-not $firstPassword -and $result.PSObject.Properties.Name -contains "Password" -and -not [string]::IsNullOrWhiteSpace($result.Password)) {
            $firstPassword = $result.Password
            $firstMachineName = $machineName
        }

        if ($firstPassword) {
            break
        }
    }

    if (-not $firstPassword) {
        Write-Warning "No password value was found in the returned LAPS data, so nothing was copied to the clipboard."
        return
    }

    try {
        Set-Clipboard -Value $firstPassword
    } catch {
        Write-Warning "Password was retrieved but could not be copied to clipboard: $_"
        return
    }

    if ([string]::IsNullOrWhiteSpace($firstMachineName)) {
        $firstMachineName = "UnknownDevice"
    }

    Write-Host "Copied the first returned password to clipboard for machine '$firstMachineName'." -ForegroundColor Cyan
}

function Get-IntuneLocalAdminPassword {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ManagedDeviceIds,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeHistory
    )

    $lapsCommand = Get-Command -Name Get-LapsAADPassword -ErrorAction SilentlyContinue
    if (-not $lapsCommand) {
        Write-Error "Get-LapsAADPassword was not found after importing Microsoft.Graph. Ensure your Graph module version supports this cmdlet."
        exit 1
    }

    if (-not $lapsCommand.Parameters.ContainsKey("DeviceIds")) {
        Write-Error "Get-LapsAADPassword does not expose a DeviceIds parameter in this environment."
        exit 1
    }

    if ($IncludeHistory.IsPresent -and -not $lapsCommand.Parameters.ContainsKey("IncludeHistory")) {
        Write-Error "Get-LapsAADPassword does not expose an IncludeHistory parameter in this environment."
        exit 1
    }

    $allResults = @()

    foreach ($deviceId in $ManagedDeviceIds) {
        $splat = @{
            DeviceIds = @($deviceId)
        }

        if ($IncludeHistory.IsPresent) {
            $splat["IncludeHistory"] = $true
        }

        if ($lapsCommand.Parameters.ContainsKey("IncludePasswords")) {
            $splat["IncludePasswords"] = $true
        }

        if ($lapsCommand.Parameters.ContainsKey("AsPlainText")) {
            $splat["AsPlainText"] = $true
        }

        try {
            $deviceResult = Get-LapsAADPassword @splat -ErrorAction Stop
            if ($deviceResult) {
                $allResults += $deviceResult
            }
        } catch {
            Write-Error "Failed to retrieve local admin password for device '$deviceId': $_"
            exit 1
        }
    }

    if (-not $allResults -or $allResults.Count -eq 0) {
        Write-Warning "No LAPS password data was returned for the supplied DeviceIds/Names."
        return
    }

    Copy-FirstLapsPasswordToClipboard -LapsResults $allResults
    Write-Host "LAPS password lookup successful for $($ManagedDeviceIds.Count) device(s)." -ForegroundColor Green
    $allResults
}

if (-not $DeviceIds -or $DeviceIds.Count -eq 0) {
    $deviceIdInput = Read-Host "Enter one or more Intune DeviceIds/Names (comma-separated)"
    $DeviceIds = @($deviceIdInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

if (-not $DeviceIds -or $DeviceIds.Count -eq 0) {
    Write-Error "At least one DeviceId/Name is required. Exiting."
    exit 1
}

Initialize-MicrosoftGraphModule
Initialize-MgGraphConnection -Scopes $requiredScopes
$resolvedDeviceIds = Resolve-DeviceIdentifiers -Identifiers $DeviceIds
Get-IntuneLocalAdminPassword -ManagedDeviceIds $resolvedDeviceIds -IncludeHistory:$IncludeHistory
