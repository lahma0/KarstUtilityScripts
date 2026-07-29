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

.PARAMETER NoCopy
When supplied, skips copying the first returned password to the clipboard.

.PARAMETER SkipPrompt
When supplied, skips the plaintext output confirmation prompt and prints passwords unredacted.

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

.EXAMPLE
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop" -Verbose

Shows detailed stage/timing output while running the lookup.

.EXAMPLE
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop" -NoCopy

Retrieves LAPS data but does not copy any password to the clipboard.

.EXAMPLE
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop" -SkipPrompt

Skips the plaintext output confirmation prompt and prints unredacted password fields.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$DeviceIds,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeHistory,

    [Parameter(Mandatory = $false)]
    [switch]$NoCopy,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPrompt
)

$requiredScopes = @(
    "DeviceLocalCredential.Read.All",
    "Device.Read.All"
)

$scriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

function Write-Stage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $elapsed = "{0:mm\:ss}" -f $scriptStopwatch.Elapsed
    Write-Verbose "[$elapsed] $Message"
}

function Write-StageDetail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $elapsed = "{0:mm\:ss}" -f $scriptStopwatch.Elapsed
    Write-Verbose "[$elapsed] $Message"
}

function Confirm-PlaintextPasswordOutput {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$SkipPrompt
    )

    if ($SkipPrompt.IsPresent) {
        return $true
    }

    while ($true) {
        $response = Read-Host "Print plaintext password(s) to the console output? (Y/N)"

        if ($response -in @("Y", "y", "Yes", "YES", "yes")) {
            return $true
        }

        if ($response -in @("N", "n", "No", "NO", "no")) {
            return $false
        }

        Write-Host "Please answer Y or N." -ForegroundColor Yellow
    }
}

function Get-RedactedLapsResults {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$LapsResults
    )

    $redactedResults = @()

    foreach ($result in $LapsResults) {
        $props = [ordered]@{}
        foreach ($property in $result.PSObject.Properties) {
            $value = $property.Value

            if ($property.Name -eq "Password" -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
                $value = "[REDACTED]"
            }

            $props[$property.Name] = $value
        }

        $redactedResults += [PSCustomObject]$props
    }

    return $redactedResults
}

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

        Write-StageDetail "Resolving identifier '$candidate'..."

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
                Write-StageDetail "Resolved GUID '$candidate' directly as deviceId '$($matchedByDeviceId[0].DeviceId)'."
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
                Write-StageDetail "Resolved object Id '$candidate' to deviceId '$($matchedByObjectId.DeviceId)'."
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
            Write-StageDetail "Resolved '$candidate' to device '$($match.DisplayName)' with deviceId '$($match.DeviceId)'."
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
    Write-Stage "Checking Microsoft Graph module availability..."

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
        Write-Stage "Connecting to Microsoft Graph..."
        try {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop | Out-Null
            Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
        } catch {
            Write-Error "Failed to connect to Microsoft Graph: $_"
            exit 1
        }
    } else {
        Write-Stage "Microsoft Graph is already connected with required scopes."
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
        [switch]$IncludeHistory,

        [Parameter(Mandatory = $false)]
        [switch]$NoCopy,

        [Parameter(Mandatory = $false)]
        [switch]$SkipPrompt
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
        $deviceStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Stage "Requesting LAPS password for deviceId '$deviceId'..."

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
                Write-StageDetail "LAPS query completed for '$deviceId' in $([int]$deviceStopwatch.Elapsed.TotalSeconds)s."
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

    if ($NoCopy.IsPresent) {
        Write-Verbose "Clipboard copy skipped because -NoCopy was specified."
    } else {
        Copy-FirstLapsPasswordToClipboard -LapsResults $allResults
    }

    $showPlaintext = Confirm-PlaintextPasswordOutput -SkipPrompt:$SkipPrompt
    if (-not $showPlaintext) {
        Write-Host "Password field will be redacted in console output." -ForegroundColor Yellow
        $allResults = Get-RedactedLapsResults -LapsResults $allResults
    }

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

Write-Stage "Starting LAPS password lookup workflow..."
Initialize-MicrosoftGraphModule
Initialize-MgGraphConnection -Scopes $requiredScopes
Write-Stage "Resolving supplied device identifiers in Microsoft Graph..."
$resolvedDeviceIds = Resolve-DeviceIdentifiers -Identifiers $DeviceIds
Write-Stage "Resolved $($resolvedDeviceIds.Count) unique deviceId(s)."
Get-IntuneLocalAdminPassword -ManagedDeviceIds $resolvedDeviceIds -IncludeHistory:$IncludeHistory -NoCopy:$NoCopy -SkipPrompt:$SkipPrompt
Write-Stage "Workflow completed in $([int]$scriptStopwatch.Elapsed.TotalSeconds)s."
