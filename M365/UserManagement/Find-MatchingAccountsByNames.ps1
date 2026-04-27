<#
.SYNOPSIS
Finds potential Microsoft 365 user accounts by matching pasted employee names in the 'LastName, FirstName' format.

.DESCRIPTION
This script prompts for a pasted list of names in "LastName, FirstName" format (one per line),
then searches Microsoft Graph users for likely matches using GivenName, Surname, DisplayName,
Mail, and UserPrincipalName.

If no direct match is found for a name, the script retries with normalized values by removing
common qualifiers/particles and special characters.

By its nature, this script is designed to be forgiving and return potential matches even if the 
name formatting is inconsistent. Many false matches may be returned, especially for common names, 
so results should be reviewed carefully. However, it provides a useful starting point for 
identifying potential user accounts.

For each match, the script returns core account details and attempts to identify whether the
account is a shared mailbox (when Exchange mailbox cmdlets are available).

This script was created so we can copy/paste the list of names from the monthly terminations
spreadsheet Savannah sends out, to quickly find user email accounts that need to be deleted.

.OUTPUTS
Displays match results in the console and exports a timestamped CSV file.
#>

function Connect-MgGraphSessionIfNeeded {
    $requiredScopes = @(
        "User.Read.All",
        "Directory.Read.All"
    )

    $context = Get-MgContext -ErrorAction SilentlyContinue
    $needsConnect = -not $context

    if (-not $needsConnect) {
        $currentScopes = @($context.Scopes)
        foreach ($scope in $requiredScopes) {
            if ($scope -notin $currentScopes) {
                $needsConnect = $true
                break
            }
        }
    }

    if ($needsConnect) {
        Write-Host "Connecting to Microsoft Graph with required scopes..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $requiredScopes -NoWelcome
    }
}

function Convert-ToComparableString {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$InputText,
        [string[]]$QualifierTokens = @()
    )

    $text = $InputText.ToLowerInvariant()
    $text = $text -replace "[^a-z0-9\s]", " "
    $text = $text -replace "\s+", " "
    $text = $text.Trim()

    if (-not $text) {
        return ""
    }

    if ($QualifierTokens.Count -eq 0) {
        return $text
    }

    $tokens = $text -split " "
    $filtered = foreach ($token in $tokens) {
        if ([string]::IsNullOrWhiteSpace($token)) {
            continue
        }

        if ($QualifierTokens -contains $token) {
            continue
        }

        $token
    }

    return ($filtered -join " ").Trim()
}

function Test-NameMatch {
    param(
        [Parameter(Mandatory = $true)]$User,
        [Parameter(Mandatory = $true)][string]$FirstName,
        [Parameter(Mandatory = $true)][string]$LastName,
        [switch]$UseNormalized
    )

    $qualifierTokens = @(
        "jr", "sr", "ii", "iii", "iv", "v", "vi",
        "de", "del", "de la", "dela", "da", "di", "do", "dos", "das", "du",
        "la", "le", "van", "von", "der", "den", "ten", "ter", "st", "saint",
        "bin", "binti", "ibn", "al", "el"
    )

    if ($UseNormalized) {
        $first = Convert-ToComparableString -InputText $FirstName -QualifierTokens $qualifierTokens
        $last = Convert-ToComparableString -InputText $LastName -QualifierTokens $qualifierTokens

        $given = Convert-ToComparableString -InputText ([string]$User.GivenName) -QualifierTokens $qualifierTokens
        $surname = Convert-ToComparableString -InputText ([string]$User.Surname) -QualifierTokens $qualifierTokens
        $display = Convert-ToComparableString -InputText ([string]$User.DisplayName) -QualifierTokens $qualifierTokens
        $mail = Convert-ToComparableString -InputText ([string]$User.Mail) -QualifierTokens $qualifierTokens
        $upn = Convert-ToComparableString -InputText ([string]$User.UserPrincipalName) -QualifierTokens $qualifierTokens
    } else {
        $first = Convert-ToComparableString -InputText $FirstName
        $last = Convert-ToComparableString -InputText $LastName

        $given = Convert-ToComparableString -InputText ([string]$User.GivenName)
        $surname = Convert-ToComparableString -InputText ([string]$User.Surname)
        $display = Convert-ToComparableString -InputText ([string]$User.DisplayName)
        $mail = Convert-ToComparableString -InputText ([string]$User.Mail)
        $upn = Convert-ToComparableString -InputText ([string]$User.UserPrincipalName)
    }

    if (-not $first -and -not $last) {
        return $false
    }

    $displayHasFirstAndLast = $false
    if ($first -and $last) {
        $displayHasFirstAndLast = $display -like "*$first*" -and $display -like "*$last*"
    }

    $givenNameMatch = $first -and $given -like "*$first*"
    $surnameMatch = $last -and $surname -like "*$last*"
    $displayNameMatch = $displayHasFirstAndLast
    $mailMatch = ($first -and $mail -like "*$first*") -or ($last -and $mail -like "*$last*")
    $upnMatch = ($first -and $upn -like "*$first*") -or ($last -and $upn -like "*$last*")

    return ($givenNameMatch -or $surnameMatch -or $displayNameMatch -or $mailMatch -or $upnMatch)
}

function Initialize-SharedMailboxLookupState {
    $moduleInstalled = Get-Module -ListAvailable -Name ExchangeOnlineManagement -ErrorAction SilentlyContinue
    if (-not $moduleInstalled) {
        Write-Host "The ExchangeOnlineManagement module is not installed." -ForegroundColor DarkYellow
        $installChoice = Read-Host "Install ExchangeOnlineManagement now? (Y/N)"

        if ($installChoice -notmatch "^(y|yes)$") {
            return [PSCustomObject]@{
                Available   = $false
                CommandName = $null
                Reason      = "ExchangeOnlineManagement module not installed"
            }
        }

        try {
            Write-Host "Installing ExchangeOnlineManagement module for current user..." -ForegroundColor Cyan
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        } catch {
            return [PSCustomObject]@{
                Available   = $false
                CommandName = $null
                Reason      = "Failed to install ExchangeOnlineManagement: $($_.Exception.Message)"
            }
        }
    }

    try {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop | Out-Null
    } catch {
        return [PSCustomObject]@{
            Available   = $false
            CommandName = $null
            Reason      = "Failed to import ExchangeOnlineManagement: $($_.Exception.Message)"
        }
    }

    $exoMailboxCmd = Get-Command -Name Get-EXOMailbox -ErrorAction SilentlyContinue
    if (-not $exoMailboxCmd) {
        return [PSCustomObject]@{
            Available   = $false
            CommandName = $null
            Reason      = "Get-EXOMailbox cmdlet not available after loading ExchangeOnlineManagement"
        }
    }

    $needsConnect = $true
    try {
        Get-EXOMailbox -ResultSize 1 -ErrorAction Stop | Out-Null
        $needsConnect = $false
    } catch {
        # Any failure here is treated as "not currently connected" and triggers auth flow.
        $needsConnect = $true
    }

    if ($needsConnect) {
        $connectCommand = Get-Command -Name Connect-ExchangeOnline -ErrorAction SilentlyContinue
        if (-not $connectCommand) {
            return [PSCustomObject]@{
                Available   = $false
                CommandName = $null
                Reason      = "Connect-ExchangeOnline cmdlet unavailable after importing module"
            }
        }

        try {
            Write-Host "Connecting to Exchange Online (default auth)..." -ForegroundColor Cyan
            Connect-ExchangeOnline -ShowBanner:$false
            Get-EXOMailbox -ResultSize 1 -ErrorAction Stop | Out-Null
        } catch {
            return [PSCustomObject]@{
                Available   = $false
                CommandName = $null
                Reason      = "Failed default Connect-ExchangeOnline authentication in this session: $($_.Exception.Message)"
            }
        }
    }

    return [PSCustomObject]@{
        Available   = $true
        CommandName = "Get-EXOMailbox"
        Reason      = "Connected to Exchange Online"
    }
}

function Get-SharedMailboxInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity,
        [Parameter(Mandatory = $true)]
        $LookupState,
        [Parameter(Mandatory = $true)]
        [hashtable]$Cache
    )

    if ([string]::IsNullOrWhiteSpace($Identity)) {
        return [PSCustomObject]@{
            IsSharedMailbox     = $false
            SharedMailboxStatus = "Skipped: No identity"
        }
    }

    if ($Cache.ContainsKey($Identity)) {
        return $Cache[$Identity]
    }

    if (-not $LookupState.Available) {
        $reasonSuffix = if ($LookupState.PSObject.Properties.Name -contains "Reason" -and -not [string]::IsNullOrWhiteSpace([string]$LookupState.Reason)) {
            ": $($LookupState.Reason)"
        } else {
            ""
        }

        $result = [PSCustomObject]@{
            IsSharedMailbox     = $false
            SharedMailboxStatus = "Unknown: Exchange mailbox lookup unavailable$reasonSuffix"
        }
        $Cache[$Identity] = $result
        return $result
    }

    try {
        if ($LookupState.CommandName -eq "Get-EXOMailbox") {
            $mailbox = Get-EXOMailbox -Identity $Identity -ErrorAction Stop
            $isShared = [string]$mailbox.RecipientTypeDetails -eq "SharedMailbox"
            $result = [PSCustomObject]@{
                IsSharedMailbox     = $isShared
                SharedMailboxStatus = "Checked via Get-EXOMailbox"
            }
            $Cache[$Identity] = $result
            return $result
        }

        $legacyMailbox = Get-Mailbox -Identity $Identity -ErrorAction Stop
        $legacyIsShared = [string]$legacyMailbox.RecipientTypeDetails -eq "SharedMailbox"
        $legacyResult = [PSCustomObject]@{
            IsSharedMailbox     = $legacyIsShared
            SharedMailboxStatus = "Checked via Get-Mailbox"
        }
        $Cache[$Identity] = $legacyResult
        return $legacyResult
    } catch {
        $result = [PSCustomObject]@{
            IsSharedMailbox     = $false
            SharedMailboxStatus = "Unknown: $($_.Exception.Message)"
        }
        $Cache[$Identity] = $result
        return $result
    }
}

$sharedMailboxLookupState = Initialize-SharedMailboxLookupState
$sharedMailboxCache = @{}

if ($sharedMailboxLookupState.Available) {
    Write-Host "Exchange mailbox lookup available via $($sharedMailboxLookupState.CommandName). Shared mailbox detection enabled." -ForegroundColor Cyan
} else {
    Write-Host "Exchange mailbox lookup unavailable ($($sharedMailboxLookupState.Reason)). Shared mailbox status will be marked as Unknown." -ForegroundColor DarkYellow
}

Connect-MgGraphSessionIfNeeded

Write-Host "Paste names in 'LastName, FirstName' format. Press Enter on an empty line when done:" -ForegroundColor Cyan

$inputLines = @()
while ($true) {
    $line = Read-Host
    if ([string]::IsNullOrWhiteSpace($line)) {
        break
    }

    $inputLines += $line.Trim()
}

if ($inputLines.Count -eq 0) {
    Write-Host "No names were provided. Exiting." -ForegroundColor Yellow
    return
}

$employeesToSearch = @()
foreach ($line in $inputLines) {
    if ($line -notmatch "^\s*(.+?)\s*,\s*(.+?)\s*$") {
        Write-Host "Skipping invalid format: '$line'" -ForegroundColor Yellow
        continue
    }

    $employeesToSearch += [PSCustomObject]@{
        ProvidedName = $line
        LastName     = $Matches[1].Trim()
        FirstName    = $Matches[2].Trim()
    }
}

if ($employeesToSearch.Count -eq 0) {
    Write-Host "No valid names found after parsing input. Exiting." -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "Loading users from Microsoft Graph..." -ForegroundColor Cyan

$allUsers = Get-MgUser -All -Property Id, DisplayName, GivenName, Surname, Mail, UserPrincipalName, CreatedDateTime, Department, JobTitle, AccountEnabled
$matchedUsers = @()

Write-Host "Searching for matching user accounts..." -ForegroundColor Cyan
Write-Host ""

foreach ($employee in $employeesToSearch) {
    $firstName = $employee.FirstName
    $lastName = $employee.LastName

    Write-Host "Searching for: $($employee.ProvidedName)" -ForegroundColor Yellow

    $allMatches = $allUsers | Where-Object {
        Test-NameMatch -User $_ -FirstName $firstName -LastName $lastName
    }

    if (-not $allMatches) {
        Write-Host "  No direct matches. Trying normalized fallback..." -ForegroundColor DarkYellow
        $allMatches = $allUsers | Where-Object {
            Test-NameMatch -User $_ -FirstName $firstName -LastName $lastName -UseNormalized
        }
    }

    $allMatches = $allMatches | Sort-Object Id -Unique

    foreach ($user in $allMatches) {
        $identityForMailboxCheck = if (-not [string]::IsNullOrWhiteSpace([string]$user.UserPrincipalName)) {
            [string]$user.UserPrincipalName
        } elseif (-not [string]::IsNullOrWhiteSpace([string]$user.Mail)) {
            [string]$user.Mail
        } else {
            [string]$user.Id
        }

        $sharedMailboxInfo = Get-SharedMailboxInfo -Identity $identityForMailboxCheck -LookupState $sharedMailboxLookupState -Cache $sharedMailboxCache

        $matchedUsers += [PSCustomObject]@{
            ProvidedName        = $employee.ProvidedName
            DisplayName         = $user.DisplayName
            UserPrincipalName   = $user.UserPrincipalName
            Mail                = $user.Mail
            Surname             = $user.Surname
            GivenName           = $user.GivenName
            CreatedDateTime     = $user.CreatedDateTime
            Department          = $user.Department
            JobTitle            = $user.JobTitle
            AccountEnabled      = $user.AccountEnabled
            IsSharedMailbox     = $sharedMailboxInfo.IsSharedMailbox
            SharedMailboxStatus = $sharedMailboxInfo.SharedMailboxStatus
            Id                  = $user.Id
        }

        Write-Host "  MATCH: $($user.DisplayName) ($($user.UserPrincipalName)) | SharedMailbox=$($sharedMailboxInfo.IsSharedMailbox)" -ForegroundColor Green
    }

    if (($allMatches | Measure-Object).Count -eq 0) {
        Write-Host "  No matches found" -ForegroundColor Gray
    }

    Write-Host ""
}

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "SUMMARY OF MATCHED ACCOUNTS" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

if ($matchedUsers.Count -gt 0) {
    $matchedUsers | Format-Table ProvidedName, DisplayName, UserPrincipalName, Mail, Surname, GivenName, CreatedDateTime, Department, JobTitle, AccountEnabled, IsSharedMailbox, SharedMailboxStatus -AutoSize
} else {
    Write-Host "No accounts matched the provided names." -ForegroundColor Yellow
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$exportPath = "UserMatches_ByPastedNames_$timestamp.csv"
$matchedUsers | Export-Csv -Path $exportPath -NoTypeInformation
Write-Host "Results exported to: $exportPath" -ForegroundColor Green
