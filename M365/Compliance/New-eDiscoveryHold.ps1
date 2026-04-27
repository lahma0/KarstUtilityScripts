<#
.SYNOPSIS
Creates a Microsoft Purview eDiscovery (Standard) case and applies a hold for a specified user. This script would typically be utilized in scenarios such as employee terminations where retaining a user's data is necessary for investigation, administrative, or legal purposes.

.DESCRIPTION
This script creates or reuses a Microsoft Purview eDiscovery (Standard) case, creates or reuses
an associated hold policy, and creates a hold rule that preserves all available content for the
specified user.

It is intended to retain a user's Exchange mailbox content and their related
SharePoint/OneDrive content for investigation, administrative, or legal purposes.

The script:
- Validates the supplied user identifier
- Checks whether ExchangeOnlineManagement is installed and prompts to install it if needed
- Verifies connectivity to the Security & Compliance PowerShell endpoint and connects when needed
- Creates or reuses the eDiscovery case
- Creates or reuses the hold policy
- Creates the hold rule if one does not already exist

.PARAMETER UserId
The email address (UPN) of the user to place on hold.

[Required - User is prompted if not provided]

.PARAMETER CaseName
Display name for the eDiscovery case.

Must be fewer than 64 characters.

If not provided, defaults to: "Term - <UserId>"

[Optional - Defaults based on UserId]

.PARAMETER CaseDescription
Description for the eDiscovery case.

If not provided, defaults to a description stating that the user's data is being retained for
administrative or legal purposes.

[Optional - Defaults based on UserId]

.PARAMETER PolicyName
Display name for the hold policy created within the eDiscovery case.

Must be fewer than 64 characters.

If not provided, defaults to: "Retain <UserId> data"

[Optional - Defaults based on UserId]

.PARAMETER PolicyDescription
Description for the hold policy.

If not provided, defaults to a description stating that all email/OneDrive/SharePoint/Teams data
should be retained for the user.

[Optional - Defaults based on UserId]

.PARAMETER SharePointTenantName
SharePoint tenant host prefix used to construct the user's OneDrive URL.

Example: `tmconcrete` produces `https://tmconcrete-my.sharepoint.com/personal/<sanitized_upn>`.

[Optional - Defaults to tmconcrete]

.EXAMPLE
.\New-eDiscoveryHold.ps1

Runs interactively and prompts for the required UserId.

.EXAMPLE
.\New-eDiscoveryHold.ps1 -UserId "jdoe@contoso.com"

Creates or reuses an eDiscovery case and hold policy for the specified user using default names
and descriptions.

.EXAMPLE
.\New-eDiscoveryHold.ps1 -UserId "jdoe@contoso.com" -CaseName "Term - jdoe@contoso.com - 2026/04/25" -PolicyName "Retain jdoe@contoso.com data - 2026/04/25"

Creates or reuses an eDiscovery case and hold policy using custom case and policy names.

.NOTES
Requires:
- PowerShell 5.1+ or PowerShell 7+
- ExchangeOnlineManagement module
- An account with eDiscovery Manager or higher permissions in Microsoft Purview

The script uses Connect-IPPSSession because eDiscovery (Standard) case and hold management is not
fully covered by Microsoft Graph PowerShell cmdlets.
#>
param (
    [Parameter(Mandatory = $false)]
    [string]$UserId,

    [Parameter(Mandatory = $false)]
    [string]$CaseName,

    [Parameter(Mandatory = $false)]
    [string]$CaseDescription,

    [Parameter(Mandatory = $false)]
    [string]$PolicyName,

    [Parameter(Mandatory = $false)]
    [string]$PolicyDescription,

    [Parameter(Mandatory = $false)]
    [string]$SharePointTenantName = 'tmconcrete'
)

$maxNameLength = 63
if (-not [string]::IsNullOrWhiteSpace($CaseName) -and $CaseName.Trim().Length -gt $maxNameLength) {
    Write-Host "✗ CaseName is too long. It must be fewer than 64 characters. Please reduce the length and try again." -ForegroundColor Red
    exit 1
}

if (-not [string]::IsNullOrWhiteSpace($PolicyName) -and $PolicyName.Trim().Length -gt $maxNameLength) {
    Write-Host "✗ PolicyName is too long. It must be fewer than 64 characters. Please reduce the length and try again." -ForegroundColor Red
    exit 1
}

function Read-YesNoResponse {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [bool]$DefaultValue = $false
    )

    while ($true) {
        $defaultHint = if ($DefaultValue) { "Y" } else { "N" }
        $response = Read-Host "$Prompt (Y/N, default: $defaultHint)"

        if ([string]::IsNullOrWhiteSpace($response)) {
            return $DefaultValue
        }

        switch -Regex ($response.Trim().ToLowerInvariant()) {
            '^(y|yes)$' { return $true }
            '^(n|no)$' { return $false }
            default { Write-Host "Please enter Y or N." -ForegroundColor Yellow }
        }
    }
}

function Test-ValidUserPrincipalName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Length -gt 254) {
        return $false
    }

    return $Value -match '^[A-Za-z0-9][A-Za-z0-9._%+\-]*[A-Za-z0-9]?@([A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]?\.)+[A-Za-z]{2,}$'
}

function Initialize-ExchangeOnlineModule {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "⚠ ExchangeOnlineManagement module is not installed." -ForegroundColor Yellow

        if (Read-YesNoResponse -Prompt "Do you want to install it now?" -DefaultValue $false) {
            try {
                Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            } catch {
                Write-Host "✗ Failed to install ExchangeOnlineManagement. Exiting." -ForegroundColor Red
                throw
            }
        } else {
            Write-Host "✗ Cannot continue without ExchangeOnlineManagement module. Exiting." -ForegroundColor Red
            exit 1
        }
    }

    if (-not (Get-Module ExchangeOnlineManagement)) {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
    }
}

function Test-IPPSSessionConnection {
    try {
        $connections = Get-ConnectionInformation -ErrorAction Stop
        return [bool]($connections | Where-Object { $_.ConnectionUri -like '*compliance.protection.outlook.com*' })
    } catch {
        return $false
    }
}

function Initialize-IPPSSessionConnection {
    if (Test-IPPSSessionConnection) {
        Write-Host "✓ Connected to Security & Compliance PowerShell!" -ForegroundColor Green
        return
    }

    try {
        Connect-IPPSSession -ShowBanner:$false -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "✗ Failed to connect to Security & Compliance PowerShell. Exiting." -ForegroundColor Red
        exit 1
    }

    if (Test-IPPSSessionConnection) {
        Write-Host "✓ Connected to Security & Compliance PowerShell!" -ForegroundColor Green
        return
    }

    Write-Host "✗ Failed to connect to Security & Compliance PowerShell after authentication attempt. Exiting." -ForegroundColor Red
    exit 1
}

function Resolve-UserId {
    param(
        [Parameter(Mandatory = $false)]
        [string]$InputUserId
    )

    $isParameterInput = -not [string]::IsNullOrWhiteSpace($InputUserId)
    $candidate = $InputUserId

    while ($true) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            $candidate = Read-Host "`nEnter the email address (UPN) of the user to place on hold [required]"
        }

        $candidate = $candidate.Trim()

        if (Test-ValidUserPrincipalName -Value $candidate) {
            return $candidate
        }

        if ($isParameterInput) {
            Write-Host "✗ Invalid UserId format for parameter. Expected a valid email address (example@domain.com). Exiting." -ForegroundColor Red
            exit 1
        }

        Write-Host "✗ Invalid UserId format. Please enter a valid email address (example@domain.com)." -ForegroundColor Yellow
        $candidate = $null
    }
}

function Test-NameWithinLimit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [int]$MaxLength,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $true
    }

    $trimmed = $Value.Trim()
    return $trimmed.Length -le $MaxLength
}

function Resolve-ShortHoldRuleName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyName,

        [Parameter(Mandatory = $true)]
        [string]$UserId
    )

    $seed = "$PolicyName|$UserId"
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($seed)
        $hashBytes = $sha1.ComputeHash($bytes)
        $hash = ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').Substring(0, 10)
        return "HoldRule-$hash"
    } finally {
        $sha1.Dispose()
    }
}

function Resolve-HoldConfiguration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedUserId,

        [Parameter(Mandatory = $false)]
        [string]$InputCaseName,

        [Parameter(Mandatory = $false)]
        [string]$InputCaseDescription,

        [Parameter(Mandatory = $false)]
        [string]$InputPolicyName,

        [Parameter(Mandatory = $false)]
        [string]$InputPolicyDescription
    )

    $resolvedCaseName = $InputCaseName
    $resolvedCaseDescription = $InputCaseDescription
    $resolvedPolicyName = $InputPolicyName
    $resolvedPolicyDescription = $InputPolicyDescription

    if ([string]::IsNullOrWhiteSpace($resolvedCaseName)) {
        $resolvedCaseName = "Term - $ResolvedUserId"
    }

    if ([string]::IsNullOrWhiteSpace($resolvedCaseDescription)) {
        $resolvedCaseDescription = "The employee with the email address '$ResolvedUserId' was terminated. This case retains all of that user's data in case it is later needed for administrative or legal purposes."
    }

    if ([string]::IsNullOrWhiteSpace($resolvedPolicyName)) {
        $resolvedPolicyName = "Retain $ResolvedUserId data"
    }

    if ([string]::IsNullOrWhiteSpace($resolvedPolicyDescription)) {
        $resolvedPolicyDescription = "This policy specifies that all email, OneDrive, SharePoint, and Teams data should be preserved for the user '$ResolvedUserId'."
    }

    if (-not (Test-NameWithinLimit -Value $resolvedCaseName -MaxLength 63 -Label "CaseName")) {
        Write-Host "✗ Resolved CaseName is too long. It must be fewer than 64 characters. Provide a shorter -CaseName value and try again." -ForegroundColor Red
        exit 1
    }

    if (-not (Test-NameWithinLimit -Value $resolvedPolicyName -MaxLength 63 -Label "PolicyName")) {
        Write-Host "✗ Resolved PolicyName is too long. It must be fewer than 64 characters. Provide a shorter -PolicyName value and try again." -ForegroundColor Red
        exit 1
    }

    $resolvedCaseName = $resolvedCaseName.Trim()
    $resolvedPolicyName = $resolvedPolicyName.Trim()

    return [PSCustomObject]@{
        CaseName          = $resolvedCaseName
        CaseDescription   = $resolvedCaseDescription
        PolicyName        = $resolvedPolicyName
        PolicyDescription = $resolvedPolicyDescription
    }
}

function Resolve-OneDriveUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedUserId,

        [Parameter(Mandatory = $false)]
        [string]$InputSharePointTenantName
    )

    $tenantName = $InputSharePointTenantName.Trim().ToLowerInvariant()
    $sanitizedUpn = ($ResolvedUserId.Trim().ToLowerInvariant() -replace '@', '_') -replace '\.', '_'
    return "https://$tenantName-my.sharepoint.com/personal/$sanitizedUpn"
}

# Prerequisite: Module check
Initialize-ExchangeOnlineModule

# Ensure connection to Security & Compliance PowerShell
Initialize-IPPSSessionConnection

$UserId = Resolve-UserId -InputUserId $UserId
$resolvedDefaults = Resolve-HoldConfiguration -ResolvedUserId $UserId -InputCaseName $CaseName -InputCaseDescription $CaseDescription -InputPolicyName $PolicyName -InputPolicyDescription $PolicyDescription
$CaseName = $resolvedDefaults.CaseName
$CaseDescription = $resolvedDefaults.CaseDescription
$PolicyName = $resolvedDefaults.PolicyName
$PolicyDescription = $resolvedDefaults.PolicyDescription
$oneDriveUrl = Resolve-OneDriveUrl -ResolvedUserId $UserId -InputSharePointTenantName $SharePointTenantName

try {
    Write-Host "`nCreating or locating eDiscovery case..." -ForegroundColor Cyan
    $existingCase = Get-ComplianceCase -Identity $CaseName -ErrorAction SilentlyContinue

    if ($existingCase) {
        Write-Host "🛈 A case named '$CaseName' already exists. Using the existing case." -ForegroundColor Cyan
    } else {
        New-ComplianceCase -Name $CaseName -Description $CaseDescription -CaseType eDiscovery -ErrorAction Stop | Out-Null
        Write-Host "✓ eDiscovery case created successfully!" -ForegroundColor Green
    }

    Write-Host "`nCreating or locating hold policy..." -ForegroundColor Cyan
    $policyParams = @{
        Name             = $PolicyName
        Case             = $CaseName
        Comment          = $PolicyDescription
        ExchangeLocation = @($UserId)
        Enabled          = $true
        ErrorAction      = 'Stop'
    }

    if ($oneDriveUrl) {
        $policyParams.SharePointLocation = @($oneDriveUrl)
    }

    $existingPolicy = Get-CaseHoldPolicy -Case $CaseName -Identity $PolicyName -ErrorAction SilentlyContinue
    if ($existingPolicy) {
        Write-Host "🛈 A hold policy named '$PolicyName' already exists in case '$CaseName'. Using the existing policy." -ForegroundColor Cyan
    } else {
        Write-Host "🛈 Name lengths => CaseName: $($CaseName.Length), PolicyName: $($PolicyName.Length)" -ForegroundColor DarkGray
        Write-Host "🛈 SharePointLocation => $($policyParams.SharePointLocation -join ', ')" -ForegroundColor DarkGray
        New-CaseHoldPolicy @policyParams | Out-Null
        Write-Host "✓ Hold policy created successfully!" -ForegroundColor Green
    }

    Write-Host "`nCreating hold rule..." -ForegroundColor Cyan
    $ruleName = Resolve-ShortHoldRuleName -PolicyName $PolicyName -UserId $UserId
    if (-not (Test-NameWithinLimit -Value $ruleName -MaxLength 63 -Label "RuleName")) {
        Write-Host "✗ Generated rule name is too long. It must be fewer than 64 characters. Provide shorter input values and try again." -ForegroundColor Red
        exit 1
    }
    Write-Host "🛈 Name lengths => RuleName: $($ruleName.Length) ('$ruleName')" -ForegroundColor DarkGray
    $existingRule = Get-CaseHoldRule -Policy $PolicyName -ErrorAction SilentlyContinue

    if ($existingRule) {
        Write-Host "🛈 A hold rule already exists for policy '$PolicyName'. Skipping rule creation." -ForegroundColor Cyan
    } else {
        New-CaseHoldRule -Name $ruleName -Policy $PolicyName -Disabled:$false -ErrorAction Stop | Out-Null
        Write-Host "✓ Hold rule created successfully!" -ForegroundColor Green
    }

    Write-Host "`n✓✓✓ SUCCESS ✓✓✓" -ForegroundColor Green
    Write-Host "eDiscovery hold configured successfully!" -ForegroundColor Green
    Write-Host "`nHold Details:" -ForegroundColor Cyan
    Write-Host "  User: $UserId" -ForegroundColor White
    Write-Host "  Case: $CaseName" -ForegroundColor White
    Write-Host "  Policy: $PolicyName" -ForegroundColor White
    Write-Host "  Exchange Location: $UserId" -ForegroundColor White

    Write-Host "  OneDrive Location: $oneDriveUrl" -ForegroundColor White

    Write-Host "  Hold Rule: $ruleName" -ForegroundColor White
    Write-Host "  Status: Enabled" -ForegroundColor White
    Write-Host "`n🛈 It can take up to 60 minutes for the hold to fully take effect." -ForegroundColor Cyan
} catch {
    Write-Host "`n✗✗✗ ERROR ✗✗✗" -ForegroundColor Red
    Write-Host "✗ Failed to configure eDiscovery hold!" -ForegroundColor Red
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}