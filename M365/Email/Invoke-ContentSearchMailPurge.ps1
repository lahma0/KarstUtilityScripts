<#
.SYNOPSIS
Searches all Microsoft 365 user mailboxes for a specific email matching given criteria and deletes it.

.DESCRIPTION
This script uses the Security & Compliance Center (Purview) Content Search feature to locate emails 
matching specified criteria across all user mailboxes in the organization, then permanently deletes 
them. This is intended for responding to phishing or malicious email incidents where a harmful 
message must be removed before users can act on it.

The workflow is:
  1. Build a KQL search query from the provided filter parameters.
  2. Create and run a Content Search in the Security & Compliance Center.
  3. Wait for the search to complete and display match statistics.
  4. Prompt for confirmation before proceeding with deletion.
  5. Create and run a Search-and-Purge compliance action to delete matching messages.
  6. Clean up the compliance search and action.

The script validates input format, checks whether the required PowerShell modules are installed,
and prompts you to install them if they are missing. It then verifies whether you are already
connected to the Security & Compliance Center and automatically initiates connection/authentication 
when needed.

.PARAMETER From
Sender email address to search for.

Example: attacker@evil.com

[Optional - but at least one search parameter must be provided]

.PARAMETER To
Recipient email address to search for (matches the To field of the message).

Example: victim@karst.com

[Optional - but at least one search parameter must be provided]

.PARAMETER Subject
Subject line of the email to search for. Supports partial matches.

Example: "Your account has been compromised"

[Optional - but at least one search parameter must be provided]

.PARAMETER MatchTerms
One or more keywords or phrases to search for in the body of the email. Each term is 
combined into the search query with OR logic, so a message matching any of the provided 
terms will be included.

Example: @("click here to verify", "reset your password")

[Optional - but at least one search parameter must be provided]

.PARAMETER StartDate
Only include messages sent on or after this date.

Accepted inputs:
- DateTime value
- Short date string: MM/dd/yyyy (ex: 04/01/2026)
- Short date/time string: MM/dd/yyyy h:mm tt (ex: 04/01/2026 8:00 AM)

[Optional]

.PARAMETER EndDate
Only include messages sent on or before this date.

Accepted inputs:
- DateTime value
- Short date string: MM/dd/yyyy (ex: 04/28/2026)
- Short date/time string: MM/dd/yyyy h:mm tt (ex: 04/28/2026 5:00 PM)

[Optional]

.PARAMETER HasAttachment
When set to $true, only match emails that have attachments. When set to $false, only match 
emails that do not have attachments. When omitted or $null, attachment presence is not 
filtered.

[Optional - Defaults to no filter]

.PARAMETER SearchName
Name to use for the compliance search and purge action created during this operation.

If not provided, a name is auto-generated using the current timestamp.

[Optional - Defaults to auto-generated name]

.PARAMETER PurgeType
Controls how matched messages are deleted. Valid values are:

- SoftDelete: Moves messages to the Recoverable Items folder, where they can be recovered 
  by the user or an administrator within the retention period. [Default]
- HardDelete: Permanently deletes messages. Messages cannot be recovered after a hard 
  delete unless they are on hold or within a retention policy.

In most cases, SoftDelete is preferred as it is recoverable if the search criteria 
accidentally matched legitimate messages.

[Optional - Defaults to SoftDelete]

.PARAMETER SkipConfirmation
When set to $true, skips the interactive confirmation prompt before executing the purge. 
Useful for automated/scripted scenarios.

[Optional - Defaults to $false]

.PARAMETER KeepSearch
When set to $true, does not delete the compliance search and purge action after the 
operation completes. Useful for auditing or review.

[Optional - Defaults to $false (search and purge action are deleted after completion)]

.EXAMPLE
.\Remove-EmailFromAllMailboxes.ps1

Runs interactively and prompts for required values.

.EXAMPLE
.\Remove-EmailFromAllMailboxes.ps1 -From "attacker@evil.com" -Subject "Verify your account"

Removes all emails from the specified sender with the specified subject.

.EXAMPLE
.\Remove-EmailFromAllMailboxes.ps1 -From "attacker@evil.com" -StartDate "04/25/2026" -MatchTerms @("click here", "verify now")

Removes all emails from the specified sender sent on or after the given date that contain 
any of the given terms in the body.

.EXAMPLE
.\Remove-EmailFromAllMailboxes.ps1 -From "attacker@evil.com" -PurgeType HardDelete -SkipConfirmation:$true

Permanently deletes matched emails without prompting for confirmation.

.NOTES
Requires the ExchangeOnlineManagement module for connection handling.
Requires the ExchangeOnlineManagement module's Security & Compliance cmdlets (Connect-IPPSSession).
The account running this script must have the 'Compliance Search' and 'Search And Purge' roles 
assigned in the Microsoft Purview compliance portal.
#>
param (
    [Parameter(Mandatory = $false)]
    [string]$From,

    [Parameter(Mandatory = $false)]
    [string]$To,

    [Parameter(Mandatory = $false)]
    [string]$Subject,

    [Parameter(Mandatory = $false)]
    [string[]]$MatchTerms,

    [Parameter(Mandatory = $false)]
    [object]$StartDate = $null,

    [Parameter(Mandatory = $false)]
    [object]$EndDate = $null,

    [Parameter(Mandatory = $false)]
    [Nullable[bool]]$HasAttachment = $null,

    [Parameter(Mandatory = $false)]
    [string]$SearchName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("SoftDelete", "HardDelete")]
    [string]$PurgeType = "SoftDelete",

    [Parameter(Mandatory = $false)]
    [bool]$SkipConfirmation = $false,

    [Parameter(Mandatory = $false)]
    [bool]$KeepSearch = $false
)

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

function Initialize-ExchangeOnlineModule {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "⚠ ExchangeOnlineManagement module is not installed." -ForegroundColor Yellow

        if (Read-YesNoResponse -Prompt "Do you want to install it now?" -DefaultValue $false) {
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force
        } else {
            Write-Host "✗ Cannot continue without ExchangeOnlineManagement module. Exiting." -ForegroundColor Red
            exit 1
        }
    }
}

function Test-ComplianceCenterConnection {
    try {
        # New-ComplianceSearch is only available when connected to Security & Compliance
        $null = Get-ComplianceSearch -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Initialize-ComplianceCenterConnection {
    # Ensure module is loaded
    if (-not (Get-Module ExchangeOnlineManagement)) {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
    }

    $connected = Test-ComplianceCenterConnection

    if (-not $connected) {
        try {
            Connect-IPPSSession -ShowBanner:$false -EnableSearchOnlySession
        } catch {
            Write-Host "✗ Failed to connect to Security & Compliance Center. Exiting." -ForegroundColor Red
            exit 1
        }

        if (Test-ComplianceCenterConnection) {
            Write-Host "✓ Connected to Security & Compliance Center!" -ForegroundColor Green
            return
        }

        Write-Host "✗ Failed to connect to Security & Compliance Center after authentication attempt. Exiting." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✓ Connected to Security & Compliance Center!" -ForegroundColor Cyan
    }
}

function Test-ValidEmail([string]$email) {
    if ([string]::IsNullOrEmpty($email) -or $email.Length -gt 254) { return $false }

    if ($email -notmatch '^[A-Za-z0-9][A-Za-z0-9._%+\-]*[A-Za-z0-9]?@([A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]?\.)+[A-Za-z]{2,}$') {
        return $false
    }

    $split = $email.Split('@')
    if ($split.Count -ne 2) { return $false }
    $local = $split[0]
    $domain = $split[1]

    if ($local.Length -lt 1 -or $local.Length -gt 64) { return $false }
    if ($local.StartsWith('.') -or $local.EndsWith('.')) { return $false }
    if ($local.StartsWith('-') -or $local.EndsWith('-')) { return $false }
    if ($local.Contains('..')) { return $false }

    if ($domain.Length -gt 253) { return $false }
    if ($domain.StartsWith('.') -or $domain.EndsWith('.')) { return $false }
    if ($domain.Contains('..')) { return $false }

    $labels = $domain.Split('.')
    foreach ($label in $labels) {
        if ($label.Length -lt 1 -or $label.Length -gt 63) { return $false }
        if ($label.StartsWith('-') -or $label.EndsWith('-')) { return $false }
    }
    return $true
}

function Convert-ToKqlDateString {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [string]$ParameterName
    )

    if ($null -eq $Value) { return $null }
    if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) { return $null }

    [DateTime]$parsed = [DateTime]::MinValue

    if ($Value -is [DateTime]) {
        $parsed = [DateTime]$Value
    } else {
        $candidate = [string]$Value
        [string[]]$acceptedFormats = @(
            "MM/dd/yyyy",
            "M/d/yyyy",
            "MM/dd/yyyy h:mm tt",
            "M/d/yyyy h:mm tt",
            "MM/dd/yyyy hh:mm tt",
            "M/d/yyyy hh:mm tt"
        )

        if (-not [DateTime]::TryParseExact(
                $candidate,
                $acceptedFormats,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AllowWhiteSpaces,
                [ref]$parsed
            )) {
            Write-Host "✗ Invalid ${ParameterName} value. Use DateTime, MM/dd/yyyy, or MM/dd/yyyy h:mm tt (example: 04/28/2026 5:00 PM). Exiting." -ForegroundColor Red
            exit 1
        }
    }

    # KQL date format: yyyy-MM-ddTHH:mm:ss
    return $parsed.ToString("yyyy-MM-ddTHH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Build-KqlQuery {
    param(
        [string]$From,
        [string]$To,
        [string]$Subject,
        [string[]]$MatchTerms,
        [string]$StartDateKql,
        [string]$EndDateKql,
        [Nullable[bool]]$HasAttachment
    )

    $clauses = [System.Collections.Generic.List[string]]::new()

    if (-not [string]::IsNullOrWhiteSpace($From)) {
        $escaped = $From.Replace('"', '\"')
        $clauses.Add("from:`"$escaped`"")
    }

    if (-not [string]::IsNullOrWhiteSpace($To)) {
        $escaped = $To.Replace('"', '\"')
        $clauses.Add("to:`"$escaped`"")
    }

    if (-not [string]::IsNullOrWhiteSpace($Subject)) {
        $escaped = $Subject.Replace('"', '\"')
        $clauses.Add("subject:`"$escaped`"")
    }

    if ($MatchTerms -and $MatchTerms.Count -gt 0) {
        $termClauses = $MatchTerms | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
            $escaped = $_.Trim().Replace('"', '\"')
            "`"$escaped`""
        }
        if ($termClauses) {
            $clauses.Add("body:($($termClauses -join ' OR '))")
        }
    }

    if ($StartDateKql) {
        $clauses.Add("received>=$StartDateKql")
    }

    if ($EndDateKql) {
        $clauses.Add("received<=$EndDateKql")
    }

    if ($null -ne $HasAttachment) {
        $clauses.Add("hasattachment:$($HasAttachment.ToString().ToLowerInvariant())")
    }

    return $clauses -join " AND "
}

function Wait-ForComplianceSearch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName
    )

    Write-Host "`nWaiting for content search to complete..." -ForegroundColor Cyan

    $terminalStatuses = @("Completed", "Failed", "Stopped")
    $dotCount = 0

    while ($true) {
        $search = Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
        $status = $search.Status

        if ($terminalStatuses -contains $status) {
            Write-Host ""  # newline after dots
            return $search
        }

        Write-Host -NoNewline "."
        $dotCount++

        if ($dotCount -ge 60) {
            Write-Host ""
            $dotCount = 0
        }

        Start-Sleep -Seconds 5
    }
}

function Wait-ForCompliancePurge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName,

        [Parameter(Mandatory = $true)]
        [string]$ActionName
    )

    Write-Host "`nWaiting for purge action to complete..." -ForegroundColor Cyan

    $terminalStatuses = @("Completed", "Failed", "Stopped")
    $dotCount = 0

    while ($true) {
        $action = Get-ComplianceSearchAction -Identity $ActionName -ErrorAction Stop
        $status = $action.Status

        if ($terminalStatuses -contains $status) {
            Write-Host ""
            return $action
        }

        Write-Host -NoNewline "."
        $dotCount++

        if ($dotCount -ge 60) {
            Write-Host ""
            $dotCount = 0
        }

        Start-Sleep -Seconds 5
    }
}

# ─── Prerequisite: Module check ───────────────────────────────────────────────

Initialize-ExchangeOnlineModule

# ─── Ensure connection to Security & Compliance Center ────────────────────────

Initialize-ComplianceCenterConnection

# ─── Validate email parameters ────────────────────────────────────────────────

if (-not [string]::IsNullOrWhiteSpace($From)) {
    if (-not (Test-ValidEmail $From)) {
        Write-Host "✗ Invalid From email address: '$From'. Exiting." -ForegroundColor Red
        exit 1
    }
}

if (-not [string]::IsNullOrWhiteSpace($To)) {
    if (-not (Test-ValidEmail $To)) {
        Write-Host "✗ Invalid To email address: '$To'. Exiting." -ForegroundColor Red
        exit 1
    }
}

# ─── Ensure at least one search parameter is provided ─────────────────────────

$hasAnyFilter = (
    (-not [string]::IsNullOrWhiteSpace($From)) -or
    (-not [string]::IsNullOrWhiteSpace($To)) -or
    (-not [string]::IsNullOrWhiteSpace($Subject)) -or
    ($MatchTerms -and ($MatchTerms | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) -or
    ($null -ne $StartDate) -or
    ($null -ne $EndDate) -or
    ($null -ne $HasAttachment)
)

while (-not $hasAnyFilter) {
    Write-Host "`n⚠ At least one search parameter (From, To, Subject, MatchTerms, StartDate, EndDate, or HasAttachment) must be provided." -ForegroundColor Yellow
    Write-Host "Please enter search criteria below. Leave a field blank to skip it.`n" -ForegroundColor Yellow

    $inputFrom = Read-Host "From (sender email address)"
    if (-not [string]::IsNullOrWhiteSpace($inputFrom)) {
        if (-not (Test-ValidEmail $inputFrom.Trim())) {
            Write-Host "✗ Invalid From email address. Skipping." -ForegroundColor Yellow
        } else {
            $From = $inputFrom.Trim()
        }
    }

    $inputTo = Read-Host "To (recipient email address)"
    if (-not [string]::IsNullOrWhiteSpace($inputTo)) {
        if (-not (Test-ValidEmail $inputTo.Trim())) {
            Write-Host "✗ Invalid To email address. Skipping." -ForegroundColor Yellow
        } else {
            $To = $inputTo.Trim()
        }
    }

    $inputSubject = Read-Host "Subject (partial match supported)"
    if (-not [string]::IsNullOrWhiteSpace($inputSubject)) {
        $Subject = $inputSubject.Trim()
    }

    $inputTerms = Read-Host "Body search terms (comma-separated)"
    if (-not [string]::IsNullOrWhiteSpace($inputTerms)) {
        $MatchTerms = $inputTerms.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    $inputStart = Read-Host "Start date (MM/dd/yyyy or MM/dd/yyyy h:mm tt, leave blank to skip)"
    if (-not [string]::IsNullOrWhiteSpace($inputStart)) {
        $StartDate = $inputStart.Trim()
    }

    $inputEnd = Read-Host "End date (MM/dd/yyyy or MM/dd/yyyy h:mm tt, leave blank to skip)"
    if (-not [string]::IsNullOrWhiteSpace($inputEnd)) {
        $EndDate = $inputEnd.Trim()
    }

    $hasAnyFilter = (
        (-not [string]::IsNullOrWhiteSpace($From)) -or
        (-not [string]::IsNullOrWhiteSpace($To)) -or
        (-not [string]::IsNullOrWhiteSpace($Subject)) -or
        ($MatchTerms -and ($MatchTerms | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) -or
        ($null -ne $StartDate) -or
        ($null -ne $EndDate) -or
        ($null -ne $HasAttachment)
    )
}

# ─── Parse dates ──────────────────────────────────────────────────────────────

$startDateKql = Convert-ToKqlDateString -Value $StartDate -ParameterName "StartDate"
$endDateKql = Convert-ToKqlDateString -Value $EndDate   -ParameterName "EndDate"

# ─── Build KQL query ──────────────────────────────────────────────────────────

$kqlQuery = Build-KqlQuery `
    -From $From `
    -To $To `
    -Subject $Subject `
    -MatchTerms $MatchTerms `
    -StartDateKql $startDateKql `
    -EndDateKql $endDateKql `
    -HasAttachment $HasAttachment

Write-Host "`n🛈 KQL Query: $kqlQuery" -ForegroundColor Cyan

# ─── Generate search name ─────────────────────────────────────────────────────

if ([string]::IsNullOrWhiteSpace($SearchName)) {
    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $SearchName = "PhishingRemoval-$timestamp"
}

$purgeActionName = "${SearchName}_Purge"

# ─── Check for existing search with same name ─────────────────────────────────

$existingSearch = Get-ComplianceSearch -Identity $SearchName -ErrorAction SilentlyContinue
if ($existingSearch) {
    Write-Host "`n✗ A compliance search with the name '${SearchName}' already exists!" -ForegroundColor Red
    if (Read-YesNoResponse -Prompt "Do you want to remove the existing search and recreate it?" -DefaultValue $false) {
        # Remove purge action if it exists
        $existingAction = Get-ComplianceSearchAction -Identity $purgeActionName -ErrorAction SilentlyContinue
        if ($existingAction) {
            Remove-ComplianceSearchAction -Identity $purgeActionName -Confirm:$false
            Write-Host "🛈 Existing purge action removed." -ForegroundColor Cyan
        }
        Remove-ComplianceSearch -Identity $SearchName -Confirm:$false
        Write-Host "🛈 Existing compliance search removed." -ForegroundColor Cyan
    } else {
        Write-Host "✗ Operation cancelled due to existing compliance search with identical name." -ForegroundColor Red
        exit
    }
}

# ─── Create and run compliance search ────────────────────────────────────────

Write-Host "`nCreating compliance search '$SearchName'..." -ForegroundColor Cyan

New-ComplianceSearch `
    -Name $SearchName `
    -ExchangeLocation All `
    -ContentMatchQuery $kqlQuery `
    -ErrorAction Stop | Out-Null

Start-ComplianceSearch -Identity $SearchName -ErrorAction Stop

$completedSearch = Wait-ForComplianceSearch -SearchName $SearchName

if ($completedSearch.Status -ne "Completed") {
    Write-Host "✗ Compliance search ended with status: $($completedSearch.Status). Exiting." -ForegroundColor Red
    exit 1
}

$itemCount = $completedSearch.Items
$itemSizeMB = [math]::Round($completedSearch.Size / 1MB, 2)

Write-Host "`n✓ Compliance search completed." -ForegroundColor Green
Write-Host "`nSearch Results:" -ForegroundColor Cyan
Write-Host "  Search Name : $SearchName" -ForegroundColor White
Write-Host "  KQL Query   : $kqlQuery" -ForegroundColor White
Write-Host "  Items Found : $itemCount" -ForegroundColor White
Write-Host "  Total Size  : $itemSizeMB MB" -ForegroundColor White

if ($itemCount -eq 0) {
    Write-Host "`n🛈 No matching messages found. Nothing to delete." -ForegroundColor Cyan

    if (-not $KeepSearch) {
        Remove-ComplianceSearch -Identity $SearchName -Confirm:$false
        Write-Host "🛈 Compliance search removed." -ForegroundColor Cyan
    }

    exit 0
}

# ─── Confirmation prompt ──────────────────────────────────────────────────────

if (-not $SkipConfirmation) {
    Write-Host ""
    Write-Host "⚠ WARNING: You are about to $($PurgeType.ToUpper()) DELETE $itemCount message(s) across all mailboxes." -ForegroundColor Yellow
    if ($PurgeType -eq "HardDelete") {
        Write-Host "⚠ HardDelete is PERMANENT and CANNOT be undone!" -ForegroundColor Red
    }

    $confirmed = Read-YesNoResponse -Prompt "Are you sure you want to proceed with the deletion?" -DefaultValue $false
    if (-not $confirmed) {
        Write-Host "✗ Operation cancelled by user." -ForegroundColor Red

        if (-not $KeepSearch) {
            Remove-ComplianceSearch -Identity $SearchName -Confirm:$false
            Write-Host "🛈 Compliance search removed." -ForegroundColor Cyan
        }

        exit
    }
}

# ─── Execute purge ────────────────────────────────────────────────────────────

Write-Host "`nExecuting $PurgeType purge..." -ForegroundColor Cyan

New-ComplianceSearchAction `
    -SearchName $SearchName `
    -Purge `
    -PurgeType $PurgeType `
    -Confirm:$false `
    -ErrorAction Stop | Out-Null

$completedAction = Wait-ForCompliancePurge -SearchName $SearchName -ActionName $purgeActionName

if ($completedAction.Status -ne "Completed") {
    Write-Host "✗ Purge action ended with status: $($completedAction.Status). Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "`n✓✓✓ SUCCESS ✓✓✓" -ForegroundColor Green
Write-Host "Purge action completed successfully!" -ForegroundColor Green
Write-Host "`nPurge Details:" -ForegroundColor Cyan
Write-Host "  Search Name : $SearchName" -ForegroundColor White
Write-Host "  KQL Query   : $kqlQuery" -ForegroundColor White
Write-Host "  Items Purged: $itemCount" -ForegroundColor White
Write-Host "  Purge Type  : $PurgeType" -ForegroundColor White

if ($PurgeType -eq "SoftDelete") {
    Write-Host "  Note        : Messages moved to Recoverable Items (can be recovered within retention period)" -ForegroundColor White
} else {
    Write-Host "  Note        : Messages permanently deleted and CANNOT be recovered" -ForegroundColor White
}

# ─── Cleanup ──────────────────────────────────────────────────────────────────

if (-not $KeepSearch) {
    try {
        Remove-ComplianceSearchAction -Identity $purgeActionName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-ComplianceSearch -Identity $SearchName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "`n🛈 Compliance search and purge action removed." -ForegroundColor Cyan
    } catch {
        Write-Host "`n⚠ Could not remove compliance search/action: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n🛈 Compliance search and purge action retained (KeepSearch = true)." -ForegroundColor Cyan
}
