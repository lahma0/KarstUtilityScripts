<#
.SYNOPSIS
Creates an Exchange Online transport rule to block email from a specific sender address or domain.

.DESCRIPTION
This script creates a new Exchange transport rule (default mode: Enforce) that deletes messages
from either:
- a specific sender email address, or
- an entire sender domain.

The script validates input format, checks whether ExchangeOnlineManagement is installed,
and prompts you to install it if it is missing. It then verifies whether you are already
connected to Exchange Online and automatically initiates connection/authentication when
needed. The script also checks for an existing rule with the same name and, unless an explicit
priority is provided, assigns the new rule the next available priority.

If an existing rule with the same name is found, the script can optionally remove and recreate it.

.PARAMETER BlockAddress
The sender email address or domain to block.

Examples:
- user@example.com
- example.com

[Required - User is prompted if not provided]

.PARAMETER Reason
A short reason for creating the block rule (ex: phishing, spam, malware). 

Used in the generated rule name.

[Required - User is prompted if not provided]

.PARAMETER Comment
Comment to store on the transport rule for reference/audit context. 

[Optional - User is prompted if not provided but a blank/null value is allowed]

.PARAMETER IncidentReportRecipient
Recipient mailbox for generated incident reports.

If this value or IncidentReportContent is set to null or an empty string, the transport rule will 
not generate an incident report.

[Optional - Defaults to security@karst.com]

.PARAMETER IncidentReportContent
Comma-separated list of incident report fields to include. Valid values are:

- Sender: The sender of the message.
- Recipients: The recipients in the To field of the message. Only the first 10 recipients are 
  displayed in the incident report. If there are more than 10 recipients, the remaining number of 
  recipients are displayed.
- Subject: The Subject field of the message.
- CC: The recipients in the Cc field of the message. Only the first 10 recipients are displayed 
  in the incident report. If there are more than 10 recipients, the remaining number of recipients 
  are displayed.
- BCC: The recipients in the Bcc field of the message. Only the first 10 recipients are displayed 
  in the incident report. If there are more than 10 recipients, the remaining number of recipients 
  are displayed.
- Severity: The audit severity of the rule that was triggered. If the message was processed by 
  more than one rule, the highest severity is displayed.
- RuleDetections: The list of rules that the message triggered.
- FalsePositive: The false positive if the sender marked the message as a false positive for a 
  PolicyTip.
- IdMatch: The sensitive information type that was detected, the exact matched content from the 
  message, and the 150 characters before and after the matched sensitive information.
- AttachOriginalMail: The entire original message as an attachment.

If this value or IncidentReportRecipient is set to null or empty, the transport rule will not 
generate an incident report.

[Optional - Defaults to attaching all fields to the incident report]

.PARAMETER Priority
Priority value for the rule that determines the order of rule processing. Lower numbers are 
processed first.

If not provided, the script automatically finds the highest existing transport rule priority and 
adds 1, ensuring the new rule is processed after all existing rules. This prevents unintentional 
disruption of existing rules.

In most cases, one should not need to specify this parameter. Only use it if there is a specific 
need to set the priority explicitly.

[Optional - Defaults to next available priority (executed after all existing rules)]

.PARAMETER Severity
Sets the severity level of the incident report and the corresponding entry that's written to the 
message tracking logs. Valid values are:

- DoNotAudit: No audit entry is logged.
- Low: The audit entry is assigned low severity.
- Medium: The audit entry is assigned medium severity. [Default]
- High: The audit entry is assigned high severity.

This value does not affect enforcement behavior or message delivery.

[Optional - Defaults to Medium]

.PARAMETER ActivationDate
When the rule starts processing messages. If specified, no actions are taken on messages until the 
specified date/time.

Accepted inputs:
- DateTime value
- Short date string: MM/dd/yyyy (ex: 09/25/2026)
- Short date/time string: MM/dd/yyyy h:mm tt (ex: 09/25/2026 5:00 PM)

[Optional - Defaults to immediate activation if omitted or null/empty]

.PARAMETER ExpiryDate
When the rule stops processing messages. If specified, no actions are taken on messages after the 
specified date/time.

Accepted inputs:
- DateTime value
- Short date string: MM/dd/yyyy (ex: 09/25/2026)
- Short date/time string: MM/dd/yyyy h:mm tt (ex: 09/25/2026 5:00 PM)

[Optional - Defaults to no expiry date if omitted or null/empty]

.PARAMETER Mode
How the rule operates and what actions are taken. Valid values are:

- Enforce: All rule actions are executed and affect message delivery (emails are blocked as 
  expected). [Default]
- Audit: Logs actions that would have been taken; actions which affect message delivery are not 
  executed. Incident Reports are still generated.
- AuditAndNotify: Logs actions that would have been taken; actions which affect message delivery 
  are not executed. Incident Reports and Notifications are still generated.

Since this is set to Enforce by default, there is no need to change this parameter unless you want 
to create an audit-only rule for testing or monitoring purposes. In almost all cases, this should 
be left as Enforce.

[Optional - Defaults to Enforce]

.PARAMETER ReturnToSender
When true, the sender receives a non-delivery report (NDR) indicating their message was blocked. 
When false, messages are silently dropped without notifying the sender.

In most cases, this should be left at its default value since notifying the sender that their 
message was blocked can give them an opportunity to change tactics and attempt to bypass the rule. 
Only set this to true if you have a specific reason to notify senders that their messages are being 
blocked.

[Optional - Defaults to false]

.PARAMETER StopRuleProcessing
Stops processing of subsequent rules when this rule matches.

Do not change this from its default value of false unless you have a specific reason to prevent 
subsequent rules from processing messages that match this rule. In most cases, you will want to 
allow subsequent rules to also process matching messages.

[Optional - Defaults to false]

.PARAMETER DeferOnRuleFailure
When true, if there is an error during rule processing, the message is deferred and retried later 
instead of being processed with the default error handling behavior (which is to ignore the error 
and continue processing the message).

Only change this if you have a specific reason and understand the processing implications.

[Optional - Defaults to false]

.PARAMETER MatchSenderIn
Where to look for sender addresses in conditions and exceptions that match senders (such as From or 
SenderDomainIs conditions). Valid values are:

- Header: Only check the message header for sender addresses. Rules created in the Exchange admin 
  center use this option by default.
- Envelope: Only check 'MAIL FROM' value which is stored in the Return-Path field in SMTP 
  envelopes. This is the address used during the SMTP transaction and is less likely to be spoofed 
  than header sender fields, which can be easily forged by attackers. However, not all email 
  systems properly populate the Return-Path field, so using this option may result in some 
  legitimate messages not being processed by the rule.
- HeaderOrEnvelope: Check both the message header and the SMTP envelope for sender addresses. This 
  is the safest option to ensure that the rule applies to all messages from the specified sender, 
  regardless of whether the sender address is in the header or envelope. [Default]

[Optional - Defaults to HeaderOrEnvelope]

.EXAMPLE
.\New-ExchangeBlockRule.ps1

Runs interactively and prompts for all values.

.EXAMPLE
.\New-ExchangeBlockRule.ps1 -BlockAddress "spammer@evil.com" -Reason "spam"

Creates a rule that blocks a specific sender address.

.EXAMPLE
.\New-ExchangeBlockRule.ps1 -BlockAddress "evil.com" -Reason "phishing" -Comment "Multiple users are receiving phishing emails from multiple email addresses using this domain."

Creates a rule that blocks all senders from the specified domain.

.NOTES
Requires ExchangeOnlineManagement module and permissions to manage Exchange transport rules.
#>
param (
    [Parameter(Mandatory = $false)]
    [string]$BlockAddress,

    [Parameter(Mandatory = $false)]
    [string]$Reason,

    [Parameter(Mandatory = $false)]
    [string]$Comment,

    [Parameter(Mandatory = $false)]
    [string]$IncidentReportRecipient = "security@karst.com",

    [Parameter(Mandatory = $false)]
    [string]$IncidentReportContent = "Sender,Recipients,Subject,Cc,Bcc,Severity,RuleDetections,FalsePositive,AttachOriginalMail",

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, [int]::MaxValue)]
    [Nullable[int]]$Priority,

    [Parameter(Mandatory = $false)]
    [ValidateSet("DoNotAudit", "Low", "Medium", "High")]
    [string]$Severity = "Medium",

    [Parameter(Mandatory = $false)]
    [object]$ActivationDate = $null,

    [Parameter(Mandatory = $false)]
    [object]$ExpiryDate = $null,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Enforce", "Audit", "AuditAndNotify")]
    [string]$Mode = "Enforce",

    [Parameter(Mandatory = $false)]
    [bool]$ReturnToSender = $false,

    [Parameter(Mandatory = $false)]
    [bool]$StopRuleProcessing = $false,

    [Parameter(Mandatory = $false)]
    [bool]$DeferOnRuleFailure = $false,

    [Parameter(Mandatory = $false)]
    [ValidateSet("HeaderOrEnvelope", "Header", "Envelope")]
    [string]$MatchSenderIn = "HeaderOrEnvelope"
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

function Test-ExchangeOnlineConnection {
    try {
        $con = Get-ConnectionInformation -ErrorAction Stop
        return [bool]$con
    } catch {
        return $false
    }
}

function Initialize-ExchangeOnlineConnection {
    # Ensure module is loaded
    if (-not (Get-Module ExchangeOnlineManagement)) {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
    }

    $connected = Test-ExchangeOnlineConnection

    # If not connected, prompt to connect
    if (-not $connected) {
        try {
            Connect-ExchangeOnline -ShowBanner:$false
        } catch {
            Write-Host "✗ Failed to connect to Exchange Online. Exiting." -ForegroundColor Red
            exit 1
        }

        # Re-check connection after authentication attempt
        if (Test-ExchangeOnlineConnection) {
            Write-Host "✓ Connected to Exchange Online!" -ForegroundColor Green
            return
        }

        Write-Host "✗ Failed to connect to Exchange Online after authentication attempt. Exiting." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✓ Connected to Exchange Online!" -ForegroundColor Cyan
    }
}

function Test-ValidEmail([string]$email) {
    # General length check
    if ([string]::IsNullOrEmpty($email) -or $email.Length -gt 254) { return $false }

    # Basic regex (local allows common special chars, then @, then valid domain with subdomains and TLD)
    if ($email -notmatch '^[A-Za-z0-9][A-Za-z0-9._%+\-]*[A-Za-z0-9]?@([A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]?\.)+[A-Za-z]{2,}$') {
        return $false
    }

    $split = $email.Split('@')
    if ($split.Count -ne 2) { return $false }
    $local = $split[0]
    $domain = $split[1]

    # Local checks
    if ($local.Length -lt 1 -or $local.Length -gt 64) { return $false }
    if ($local.StartsWith('.') -or $local.EndsWith('.')) { return $false }
    if ($local.StartsWith('-') -or $local.EndsWith('-')) { return $false }
    if ($local.Contains('..')) { return $false }

    # Domain checks
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

function Test-ValidDomain([string]$domain) {
    if ([string]::IsNullOrEmpty($domain) -or $domain.Length -gt 253) { return $false }

    # Must not start/end with '.' or '-'
    if ($domain.StartsWith('.') -or $domain.EndsWith('.')) { return $false }
    if ($domain.StartsWith('-') -or $domain.EndsWith('-')) { return $false }
    if ($domain.Contains('..')) { return $false }

    # General pattern: Labels and TLD
    if ($domain -notmatch '^([A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]?\.)+[A-Za-z]{2,}$') {
        return $false
    }

    $labels = $domain.Split('.')
    foreach ($label in $labels) {
        if ($label.Length -lt 1 -or $label.Length -gt 63) { return $false }
        if ($label.StartsWith('-') -or $label.EndsWith('-')) { return $false }
    }
    return $true
}

function Convert-ToTransportRuleDateString {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [string]$ParameterName
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    [DateTime]$parsed = [DateTime]::MinValue
    $includesTime = $false

    if ($Value -is [DateTime]) {
        $parsed = [DateTime]$Value
        $includesTime = $parsed.TimeOfDay.TotalSeconds -ne 0
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
            Write-Host "✗ Invalid ${ParameterName} value. Use DateTime, MM/dd/yyyy, or MM/dd/yyyy h:mm tt (example: 09/25/2026 5:00 PM). Exiting." -ForegroundColor Red
            exit 1
        }

        $includesTime = $candidate -match '(?i)\b\d{1,2}:\d{2}\s*(AM|PM)\b'
    }

    if ($includesTime) {
        return $parsed.ToString("MM/dd/yyyy h:mm tt", [System.Globalization.CultureInfo]::InvariantCulture)
    }

    return $parsed.ToString("MM/dd/yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Resolve-BlockTarget {
    param(
        [Parameter(Mandatory = $false)]
        [string]$InputAddress
    )

    $isParameterInput = -not [string]::IsNullOrWhiteSpace($InputAddress)
    $candidate = $InputAddress

    while ($true) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            $candidate = Read-Host "`nEnter sender email address or domain to block [required]"
        }

        $candidate = $candidate.Trim()

        if ($candidate -match '@') {
            if (Test-ValidEmail $candidate) {
                return [PSCustomObject]@{
                    BlockAddress = $candidate
                    IsDomain     = $false
                    CleanDomain  = $null
                }
            }

            if ($isParameterInput) {
                Write-Host "✗ Invalid email format for parameter. Expected valid email address (example@domain.com). Exiting." -ForegroundColor Red
                exit 1
            }

            Write-Host "✗ Invalid email format. Please enter a valid email address (example@domain.com)." -ForegroundColor Yellow
            $candidate = $null
            continue
        }

        if (Test-ValidDomain $candidate) {
            return [PSCustomObject]@{
                BlockAddress = $candidate
                IsDomain     = $true
                CleanDomain  = $candidate.TrimStart("@").ToLowerInvariant()
            }
        }

        if ($isParameterInput) {
            Write-Host "✗ Invalid domain format for parameter. Expected valid domain (example.com). Exiting." -ForegroundColor Red
            exit 1
        }

        Write-Host "✗ Invalid domain format. Please enter a valid domain (example.com)." -ForegroundColor Yellow
        $candidate = $null
    }
}

# Prerequisite: Module check
Initialize-ExchangeOnlineModule

# Ensure connection to Exchange Online
Initialize-ExchangeOnlineConnection

$resolvedTarget = Resolve-BlockTarget -InputAddress $BlockAddress
$BlockAddress = $resolvedTarget.BlockAddress
$isDomain = $resolvedTarget.IsDomain
$cleanDomain = $resolvedTarget.CleanDomain

if (-not $Reason) {
    do {
        $Reason = Read-Host "`nEnter the reason for blocking (e.g. 'phishing', 'spam', 'malware', etc.) [required]"
    } while ([string]::IsNullOrWhiteSpace($Reason))
}

if (-not $Comment) {
    $Comment = Read-Host "`nEnter a comment for this rule [optional]"
}

# Determine whether input is an email or domain
if (-not $isDomain) {
    $ruleName = "Block $BlockAddress ($Reason)"
} else {
    $ruleName = "Block *.$cleanDomain ($Reason)"
}


# Check if rule already exists
$existingRule = Get-TransportRule -Identity $ruleName -ErrorAction SilentlyContinue
if ($existingRule) {
    Write-Host "`n✗ A rule with the name '${ruleName}' already exists!" -ForegroundColor Red
    $overwrite = Read-Host "Do you want to remove the existing rule and create a new one? (Y/N)"
    if ($overwrite -eq 'Y' -or $overwrite -eq 'y') {
        Remove-TransportRule -Identity $ruleName -Confirm:$false
        Write-Host "🛈 Existing rule removed" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Operation cancelled due to existing rule with identical name." -ForegroundColor Red
        exit
    }
}

# Find the highest priority and set new rule priority
if ($null -ne $Priority) {
    $newPriority = $Priority
    Write-Host "`nUsing specified rule priority: ${newPriority}" -ForegroundColor Cyan
} else {
    Write-Host "`nCalculating rule priority..." -ForegroundColor Cyan
    $rules = Get-TransportRule
    if ($rules) {
        $currentMaxPriority = ($rules | Measure-Object -Property Priority -Maximum).Maximum
        $newPriority = $currentMaxPriority + 1
        Write-Host "🛈 Highest existing priority: ${currentMaxPriority} | New rule priority: ${newPriority}" -ForegroundColor Cyan
    } else {
        $newPriority = 0
        Write-Host "🛈 No existing rules found. Using priority: ${newPriority}" -ForegroundColor Cyan
    }
}

$activationDateString = Convert-ToTransportRuleDateString -Value $ActivationDate -ParameterName "ActivationDate"
$expiryDateString = Convert-ToTransportRuleDateString -Value $ExpiryDate -ParameterName "ExpiryDate"
$hasIncidentReport = -not [string]::IsNullOrWhiteSpace($IncidentReportRecipient) -and -not [string]::IsNullOrWhiteSpace($IncidentReportContent)

# Prepare parameters for the new rule
$transportRuleParams = @{
    Name                  = $ruleName
    Priority              = $newPriority
    Enabled               = $true
    Mode                  = $Mode
    SetAuditSeverity      = $Severity
    StopRuleProcessing    = $StopRuleProcessing
    DeleteMessage         = -not $ReturnToSender
    SenderAddressLocation = $MatchSenderIn
}

if ($hasIncidentReport) {
    $transportRuleParams.GenerateIncidentReport = $IncidentReportRecipient
    $transportRuleParams.IncidentReportContent = $IncidentReportContent
}

if ($activationDateString) {
    $transportRuleParams.ActivationDate = $activationDateString
}

if ($expiryDateString) {
    $transportRuleParams.ExpiryDate = $expiryDateString
}

if ($DeferOnRuleFailure) {
    $transportRuleParams.RuleErrorAction = "Defer"
}

if ($isDomain) {
    $transportRuleParams.SenderDomainIs = $cleanDomain
} else {
    $transportRuleParams.From = $BlockAddress
}

if (-not [string]::IsNullOrWhiteSpace($Comment)) {
    $transportRuleParams.Comment = $Comment
}

try {
    # Create the transport rule
    Write-Host "`nCreating transport rule..." -ForegroundColor Cyan

    New-TransportRule @transportRuleParams
    Write-Host "`n✓✓✓ SUCCESS ✓✓✓" -ForegroundColor Green
    Write-Host "Transport rule created successfully!" -ForegroundColor Green
    Write-Host "`nRule Details:" -ForegroundColor Cyan
    Write-Host "  Name: $ruleName" -ForegroundColor White
    Write-Host "  Priority: $newPriority" -ForegroundColor White
    Write-Host "  Mode: $Mode" -ForegroundColor White
    Write-Host "  Severity: $Severity" -ForegroundColor White
    Write-Host "  Sender Match Location: $MatchSenderIn" -ForegroundColor White

    if ($isDomain) {
        Write-Host "  Blocks: All emails from *.$cleanDomain domain" -ForegroundColor White
    } else {
        Write-Host "  Blocks: Email from $BlockAddress" -ForegroundColor White
    }

    if ($ReturnToSender) {
        Write-Host "  Action: Block message and return NDR to sender" -ForegroundColor White
    } else {
        Write-Host "  Action: Delete message and block it without notifying sender" -ForegroundColor White
    }

    if ($hasIncidentReport) {
        Write-Host "  Incident Reports: Send to $IncidentReportRecipient" -ForegroundColor White
    } else {
        Write-Host "  Incident Reports: Disabled" -ForegroundColor White
    }

    if ($activationDateString) {
        Write-Host "  Activation Date: $activationDateString" -ForegroundColor White
    }

    if ($expiryDateString) {
        Write-Host "  Expiry Date: $expiryDateString" -ForegroundColor White
    }

    if ($DeferOnRuleFailure) {
        Write-Host "  Rule Error Action: Defer" -ForegroundColor White
    }

    Write-Host "  Stop Rule Processing: $StopRuleProcessing" -ForegroundColor White
    Write-Host "  Status: Enabled" -ForegroundColor White

    if (![string]::IsNullOrWhiteSpace($Comment)) {
        Write-Host "  Comment: $Comment" -ForegroundColor White
    }
} catch {
    Write-Host "`n✗✗✗ ERROR ✗✗✗" -ForegroundColor Red
    Write-Host "✗ Failed to create transport rule!" -ForegroundColor Red
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
