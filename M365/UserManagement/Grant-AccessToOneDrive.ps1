<#
.SYNOPSIS
Grants one or more users access to another user's OneDrive.

.DESCRIPTION
This script grants access to a target user's OneDrive by assigning Site Collection Administrator
rights on the target OneDrive site.

It supports interactive prompts for missing required parameters, accepts multiple users in a
single parameter array, and can optionally revoke previously granted access.

Important: This method always grants full read/write administrative access to the target OneDrive.
There is no read-only mode in this script.

The script outputs the target personal-site URL and reminds you that if the user does not
immediately see the target user's files after opening the URL, they should click My files
in the left navigation.

.PARAMETER TargetUserId
The target user's UPN/email address whose OneDrive should be shared. If omitted, the script prompts.

.PARAMETER UserIds
One or more UPN/email addresses of users who should receive access. Accepts a string array.
If omitted, the script prompts for one or more values separated by commas.

.PARAMETER TenantName
The SharePoint Online tenant prefix used to build the personal site URL. Defaults to tmconcrete.

.PARAMETER SiteUrl
Optional full URL for the target OneDrive personal site. If omitted, the script derives the URL from
TargetUserId and TenantName.

.PARAMETER Revoke
When supplied, removes Site Collection Administrator access for each specified user.

.EXAMPLE
.\Grant-AccessToOneDrive.ps1 -TargetUserId "jdoe@karst.com" -UserIds "manager@karst.com","manager@texmix.com"

Grants access to the OneDrive for jdoe@karst.com for users manager@karst.com and manager@texmix.com.

.EXAMPLE
.\Grant-AccessToOneDrive.ps1 -TargetUserId "jdoe@karst.com" -UserIds "manager@karst.com","manager@texmix.com","manager@sunrise-rm.com"

Grants access to the OneDrive for jdoe@karst.com for three users.

.EXAMPLE
.\Grant-AccessToOneDrive.ps1 -TargetUserId "jdoe@karst.com" -SiteUrl "https://tmconcrete-my.sharepoint.com/personal/jdoe_karst_com/"

Uses an explicitly supplied OneDrive site URL instead of deriving it automatically.

.EXAMPLE
.\Grant-AccessToOneDrive.ps1 -TargetUserId "jdoe@karst.com" -UserIds "manager@karst.com","manager@texmix.com" -Revoke

Revokes Site Collection Administrator access for users manager@karst.com and manager@texmix.com on jdoe@karst.com OneDrive.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetUserId,

    [Parameter(Mandatory = $false)]
    [string[]]$UserIds,

    [Parameter(Mandatory = $false)]
    [string]$TenantName = "tmconcrete",

    [Parameter(Mandatory = $false)]
    [string]$SiteUrl,

    [Parameter(Mandatory = $false)]
    [switch]$Revoke
)

$requiredSharePointModule = "Microsoft.Online.SharePoint.PowerShell"
$scriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

function Write-Stage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $elapsed = "{0:mm\:ss}" -f $scriptStopwatch.Elapsed
    Write-Host "[${elapsed}] ${Message}"
}

function Write-StageEmphasis {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ConsoleColor]$Color = [ConsoleColor]::Cyan
    )

    $elapsed = "{0:mm\:ss}" -f $scriptStopwatch.Elapsed
    Write-Host "[${elapsed}] ${Message}" -ForegroundColor $Color
}

function Prompt-ForValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PromptText
    )

    $value = Read-Host $PromptText
    while ([string]::IsNullOrWhiteSpace($value)) {
        $value = Read-Host $PromptText
    }

    return $value.Trim()
}

function Resolve-UserList {
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$InputUsers,

        [Parameter(Mandatory = $true)]
        [string]$PromptText
    )

    if ($InputUsers -and $InputUsers.Count -gt 0) {
        $resolved = @()
        foreach ($user in $InputUsers) {
            if ([string]::IsNullOrWhiteSpace($user)) {
                continue
            }

            foreach ($part in ($user -split ",")) {
                $candidate = $part.Trim()
                if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                    $resolved += $candidate
                }
            }
        }

        return @($resolved | Select-Object -Unique)
    }

    $input = Prompt-ForValue -PromptText $PromptText
    $parts = @($input -split "," | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($parts.Count -eq 0) {
        throw "At least one user UPN/email address is required."
    }

    return @($parts | Select-Object -Unique)
}

function Resolve-PersonalSiteUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetUser,

        [Parameter(Mandatory = $true)]
        [string]$Tenant,

        [Parameter(Mandatory = $false)]
        [string]$ExplicitSiteUrl
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitSiteUrl)) {
        return "$($ExplicitSiteUrl.Trim().TrimEnd('/'))/"
    }

    if ($TargetUser -notmatch "@") {
        throw "TargetUserId must be a UPN/email address when deriving the personal site URL."
    }

    $localPart = ($TargetUser.Split("@"))[0]
    $domainPart = ($TargetUser.Split("@"))[1]

    $sanitizedLocal = ($localPart -replace "[^a-zA-Z0-9]", "_")
    $sanitizedDomain = ($domainPart -replace "[^a-zA-Z0-9]", "_")

    return "https://${Tenant}-my.sharepoint.com/personal/${sanitizedLocal}_${sanitizedDomain}/"
}

function Initialize-SharePointModule {
    Write-Stage "Checking SharePoint Online module availability..."

    if (-not (Get-Module -ListAvailable -Name $requiredSharePointModule)) {
        Write-Host "SharePoint module is not installed: $($requiredSharePointModule)" -ForegroundColor Yellow
        $installResponse = Read-Host "Install required SharePoint module now? (Y/N)"
        if ($installResponse -notin @("Y", "y")) {
            throw "${requiredSharePointModule} is required to continue."
        }

        try {
            Install-Module -Name $requiredSharePointModule -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Host "SharePoint module installed successfully." -ForegroundColor Green
        } catch {
            throw "Failed to install SharePoint module: ${_}"
        }
    }

    if (-not (Get-Module -Name $requiredSharePointModule)) {
        try {
            Import-Module $requiredSharePointModule -ErrorAction Stop
        } catch {
            throw "Failed to import SharePoint module: ${_}"
        }
    }
}

function Connect-SharePointOnline {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Tenant
    )

    $adminUrl = "https://${Tenant}-admin.sharepoint.com"
    Write-Stage "Connecting to SharePoint admin: ${adminUrl}"

    try {
        Connect-SPOService -Url $adminUrl -ErrorAction Stop | Out-Null
        Write-Host "Connected to SharePoint Online." -ForegroundColor Green
    } catch {
        throw "Failed to connect to SharePoint Online: ${_}"
    }
}

function Set-OneDriveSiteCollectionAdminAccess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteUrl,

        [Parameter(Mandatory = $true)]
        [string]$UserUpn,

        [Parameter(Mandatory = $false)]
        [switch]$Revoke
    )

    if ($Revoke.IsPresent) {
        Write-Stage "Revoking Site Collection Administrator access for ${UserUpn} on ${SiteUrl}..."
    } else {
        Write-Stage "Granting Site Collection Administrator access for ${UserUpn} on ${SiteUrl}..."
    }

    try {
        Set-SPOUser -Site $SiteUrl -LoginName $UserUpn -IsSiteCollectionAdmin (-not $Revoke.IsPresent) -ErrorAction Stop | Out-Null

        if ($Revoke.IsPresent) {
            Write-Host "Revoked Site Collection Administrator access for ${UserUpn}." -ForegroundColor Green
        } else {
            Write-Host "Granted Site Collection Administrator access for ${UserUpn}." -ForegroundColor Green
        }
    } catch {
        throw "Failed to update Site Collection Administrator access for '${UserUpn}' on '${SiteUrl}': ${_}"
    }
}

if ([string]::IsNullOrWhiteSpace($TargetUserId)) {
    $TargetUserId = Prompt-ForValue -PromptText "Enter the target user's UPN/email address whose OneDrive should be shared"
}

$TargetUserId = $TargetUserId.Trim()
if ([string]::IsNullOrWhiteSpace($TargetUserId)) {
    throw "TargetUserId is required."
}

$resolvedUserIds = Resolve-UserList -InputUsers $UserIds -PromptText "Enter one or more UPN/email addresses to process (comma-separated)"
$resolvedSiteUrl = Resolve-PersonalSiteUrl -TargetUser $TargetUserId -Tenant $TenantName -ExplicitSiteUrl $SiteUrl

$workflowAction = if ($Revoke.IsPresent) { "revoke" } else { "grant" }
Write-Stage "Preparing to ${workflowAction} access for $($resolvedUserIds.Count) user(s) for '${TargetUserId}'"
Initialize-SharePointModule
Connect-SharePointOnline -Tenant $TenantName

Write-Stage "Using OneDrive site URL ${resolvedSiteUrl}"
if (-not $Revoke.IsPresent) {
    Write-StageEmphasis -Message "Share this URL with the user: ${resolvedSiteUrl}" -Color Yellow
    Write-StageEmphasis -Message "If the user does not immediately see the target user's files, have them click 'My files' in the left navigation." -Color Yellow
}

foreach ($userUpn in $resolvedUserIds) {
    Set-OneDriveSiteCollectionAdminAccess -SiteUrl $resolvedSiteUrl -UserUpn $userUpn -Revoke:$Revoke
}

Write-Stage "Completed OneDrive access workflow in $([int]$scriptStopwatch.Elapsed.TotalSeconds)s."
