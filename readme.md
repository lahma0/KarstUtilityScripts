# Karst Utility Scripts

A curated collection of practical PowerShell utilities for internal IT operations.

This repository is primarily focused on Microsoft 365, Azure, and Entra administration, with scripts that support areas such as:

- user lifecycle management (onboarding/offboarding)
- email and transport policy administration
- identity and directory attributes
- operational support workflows and repeatable admin tasks

## Purpose

The goal of this repo is to provide maintainable, reusable scripts that reduce manual effort and improve consistency across administrative tasks.

The directory structure is organized by function where possible. Some scripts may logically fit multiple areas, so organization may evolve over time as the library grows.

## Repository Structure

```text
KarstUtilityScripts/
|-- readme.md
`-- M365/
    |-- Compliance/
    |   `-- New-eDiscoveryHold.ps1
    |-- Devices/
    |   `-- Get-IntuneLocalAdminPassword.ps1
    |-- Email/
    |   |-- Invoke-ContentSearchMailPurge.ps1
    |   `-- New-ExchangeBlockRule.ps1
    `-- UserManagement/
        |-- Find-MatchingAccountsByNames.ps1
        |-- Get-ExtensionAttribute.ps1
        `-- Set-ExtensionAttribute.ps1
```

## Current Script Catalog

### M365 / Compliance

#### `New-eDiscoveryHold.ps1`

Creates or reuses a Microsoft Purview eDiscovery (Standard) case, creates or reuses a hold policy inside that case, and creates a hold rule that preserves all available content for a specified user. This is intended for situations such as terminations, internal investigations, or legal preservation workflows where user data must be retained.

The script verifies that the ExchangeOnlineManagement module is installed, connects to the Security & Compliance PowerShell endpoint using `Connect-IPPSSession`, validates the supplied user UPN, derives sensible default names/descriptions, and constructs the user's OneDrive location from the user's UPN and the configured SharePoint tenant host.

By default, the script uses `tmconcrete` as the SharePoint tenant host prefix, producing OneDrive URLs in the format `https://tmconcrete-my.sharepoint.com/personal/<sanitized_upn>`.

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-UserId` | No | The user's email address/UPN to place on hold. If omitted, the script prompts interactively. |
| `-CaseName` | No | Display name for the eDiscovery case. Must be fewer than 64 characters. Defaults to `Term - <UserId>`. |
| `-CaseDescription` | No | Description for the eDiscovery case. Defaults to a standard retention/legal-purpose description based on the user. |
| `-PolicyName` | No | Display name for the hold policy. Must be fewer than 64 characters. Defaults to `Retain <UserId> data`. |
| `-PolicyDescription` | No | Description for the hold policy. Defaults to a standard description noting email/OneDrive/SharePoint/Teams preservation for the user. |
| `-SharePointTenantName` | No | SharePoint tenant host prefix used to build the personal site URL. Defaults to `tmconcrete`. Example: `tmconcrete` produces `https://tmconcrete-my.sharepoint.com/personal/<user_upn>`. |

Note: Purview enforces strict name-length limits for case, policy, and rule names. This script validates these names and stops with a clear error if any generated or supplied value is 64 characters or longer.

**Required Module:** `ExchangeOnlineManagement`

**Required Permissions:** `eDiscovery Manager` or higher in Microsoft Purview

**Usage Examples**

```powershell
# Run interactively and enter the user UPN when prompted
.\New-eDiscoveryHold.ps1

# Create or reuse a case/hold using default names and descriptions
.\New-eDiscoveryHold.ps1 -UserId "jdoe@contoso.com"

# Create or reuse a case/hold with custom case and policy names
.\New-eDiscoveryHold.ps1 -UserId "jdoe@contoso.com" -CaseName "Term - jdoe@contoso.com - 2026/04/25" -PolicyName "Preserve jdoe@contoso.com data"

# Specify a different SharePoint tenant host prefix if needed
.\New-eDiscoveryHold.ps1 -UserId "jdoe@contoso.com" -SharePointTenantName "tmconcrete"
```

### M365 / Devices

#### `Get-IntuneLocalAdminPassword.ps1`

Gets the Windows LAPS password for one or more Intune-managed devices from Microsoft Graph by calling `Get-LapsAADPassword`. The script can prompt to install the Microsoft Graph PowerShell module if it is missing, imports it automatically when already installed, and connects to Microsoft Graph with the required scopes when needed.

If `DeviceIds` are not supplied when the script is run, it prompts for one or more comma-separated device IDs or device names.

After passwords are retrieved, the script automatically copies the first returned password to the system clipboard and displays the machine name associated with that copied password.

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-DeviceIds` | No | One or more Intune device IDs or device names to query. Accepts a string array. If omitted, the script prompts interactively. |
| `-IncludeHistory` | No | When supplied, also requests password history in addition to the current password. |

**Required Graph Scopes:** `DeviceLocalCredential.Read.All`, `Device.Read.All`

**Usage Examples**

```powershell
# Run interactively and enter one or more device IDs/names when prompted
.\Get-IntuneLocalAdminPassword.ps1

# Get the current local admin password for one device
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop"

# Get passwords for multiple devices
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop","JaneDoeLaptop"

# Include password history in the results
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop" -IncludeHistory
```

### M365 / Email

#### `Invoke-ContentSearchMailPurge.ps1`

Searches all Microsoft 365 user mailboxes for emails matching specified criteria using the Microsoft Purview Content Search feature, then optionally deletes them across the entire organization. Intended for responding to phishing or malicious email incidents where a harmful message must be removed before users can act on it.

The script builds a KQL query from the provided filter parameters, creates and runs a compliance search, displays match results (including a per-mailbox breakdown of affected accounts), and — unless `PurgeType` is set to `None` — executes a compliance purge action to delete the matched messages.

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-From` | No\* | Sender email address to search for. |
| `-To` | No\* | Recipient email address to search for. |
| `-Subject` | No\* | Subject line to search for. Supports partial matches. |
| `-MatchTerms` | No\* | One or more keywords/phrases to search for in the message body. Multiple terms are combined with OR logic. Accepts a string array: `@("term one", "term two")`. |
| `-StartDate` | No\* | Only match messages sent on or after this date. Accepted input: `DateTime`, `MM/dd/yyyy`, or `MM/dd/yyyy h:mm tt`. |
| `-EndDate` | No\* | Only match messages sent on or before this date. Accepted input: `DateTime`, `MM/dd/yyyy`, or `MM/dd/yyyy h:mm tt`. |
| `-HasAttachment` | No\* | When `$true`, only match messages with attachments. When `$false`, only match messages without attachments. When omitted, attachment presence is not filtered. |
| `-SearchName` | No | Name for the compliance search created in Microsoft Purview. If a search with this name already exists, an interactive menu is presented (see below). Defaults to an auto-generated timestamp-based name. |
| `-PurgeType` | No | How to delete matched messages. `SoftDelete` moves messages to Recoverable Items (recoverable). `HardDelete` permanently deletes them. `None` runs the search only without deleting anything — useful for validating criteria before committing to a purge. Defaults to `SoftDelete`. |
| `-SkipConfirmation` | No | When `$true`, skips the interactive confirmation prompt before purging. Defaults to `$false`. |
| `-KeepSearch` | No | When `$true`, retains the compliance search and purge action in Microsoft Purview after the script completes. Defaults to `$false`. |

\* At least one search parameter (`From`, `To`, `Subject`, `MatchTerms`, `StartDate`, `EndDate`, or `HasAttachment`) must be provided. If none are supplied via parameters, the script prompts interactively.

**Existing Search Menu**

When `-SearchName` is provided and a compliance search with that name already exists in Microsoft Purview, the script presents an interactive numbered menu:

| Option | Action |
|--------|--------|
| 1 - Overwrite | Deletes the existing search (and purge action if present) and creates a new one using the current parameters. |
| 2 - Show existing search results | Displays the item count, size, and per-mailbox breakdown from the existing search without making any changes. Exits after displaying results. |
| 3 - Re-run the search | Restarts the existing search using its stored KQL query, waits for completion, then continues with the normal purge flow. |
| 4 - Run a purge on existing results | Skips directly to the purge step using the results already in the existing search. If `PurgeType` is `None`, prompts for SoftDelete or HardDelete first. |
| 5 - Delete and exit | Removes the compliance search and any associated purge action from Purview, then exits. |

**Required Module:** `ExchangeOnlineManagement` (v3.9.0 or higher)

**Required Permissions:** `Compliance Search` and `Search And Purge` roles in Microsoft Purview

**Usage Examples**

```powershell
# Run interactively — script will prompt for all search criteria
.\Invoke-ContentSearchMailPurge.ps1

# Search-only (no purge) — review which mailboxes are affected before deleting
.\Invoke-ContentSearchMailPurge.ps1 -From "attacker@evil.com" -Subject "Verify your account" -PurgeType None

# Search and soft-delete matching messages (default purge type)
.\Invoke-ContentSearchMailPurge.ps1 -From "attacker@evil.com" -Subject "Verify your account"

# Search with date range and body keyword matching
.\Invoke-ContentSearchMailPurge.ps1 -From "attacker@evil.com" -StartDate "04/25/2026" -MatchTerms @("click here", "verify now")

# Hard-delete without confirmation prompt (use with caution)
.\Invoke-ContentSearchMailPurge.ps1 -From "attacker@evil.com" -PurgeType HardDelete -SkipConfirmation:$true

# Named search — re-run or purge later using the existing-search menu
.\Invoke-ContentSearchMailPurge.ps1 -From "attacker@evil.com" -Subject "Verify your account" -SearchName "Phish-Apr29-EvilCom" -PurgeType None
```

#### `New-ExchangeBlockRule.ps1`

Creates new Exchange transport rules for mail flow/security scenarios. Specifically, the script allows the user to quickly block incoming emails from specific email addresses or domains. If not supplied as parameters, the script will prompt interactively for any required values.

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-BlockAddress` | No | The sender email address or domain to block (e.g. `spammer@evil.com` or `evil.com`). |
| `-Reason` | No | A brief description of why the rule is being created. Used to name the rule. |
| `-Comment` | No | A longer explanatory comment attached to the transport rule for audit/reference purposes. |
| `-ActivationDate` | No | Rule start date/time. Accepted input: `DateTime`, `MM/dd/yyyy`, or `MM/dd/yyyy h:mm tt` (for example `09/25/2026 5:00 PM`). If provided, the rule does not process messages until this date/time. |
| `-ExpiryDate` | No | Rule end date/time. Accepted input: `DateTime`, `MM/dd/yyyy`, or `MM/dd/yyyy h:mm tt` (for example `09/25/2026 5:00 PM`). If provided, the rule stops taking action after this date/time. |
| `-IncidentReportRecipient` | No | Recipient mailbox for incident reports. Defaults to `security@karst.com`. If this value is null or empty, the rule will not generate an incident report. |

**Advanced Params**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Priority` | No | Explicit rule priority. If omitted, the script automatically finds the highest existing priority and uses `+1`. In most cases, do not set this manually. |
| `-Severity` | No | Audit/logging severity metadata for the rule. Defaults to `Medium`. Valid values: `DoNotAudit`, `Low`, `Medium`, `High`. This does not affect enforcement behavior. |
| `-Mode` | No | Defaults to `Enforce`. Valid values: `Enforce`, `Audit`, `AuditAndNotify`. Use `Audit`/`AuditAndNotify` when testing rule behavior before affecting delivery. |
| `-IncidentReportContent` | No | Comma-separated list of fields to include in incident reports. Defaults to `Sender,Recipients,Subject,Cc,Bcc,Severity,RuleDetections,FalsePositive,AttachOriginalMail`. If this value is null or empty, the rule will not generate an incident report. If either `IncidentReportRecipient` or `IncidentReportContent` is null/empty, incident report parameters are not sent. |
| `-ReturnToSender` | No | Boolean, default `False`. If `False`, blocked messages are silently dropped. If `True`, senders get an NDR. In almost all cases this should remain `False` so malicious actors are not tipped off. |
| `-StopRuleProcessing` | No | Boolean, default `False`. If `True`, no later transport rules are evaluated after this rule matches. Usually should remain `False`. |
| `-DeferOnRuleFailure` | No | Boolean, default `False`. If `True`, `RuleErrorAction` is set to `Defer` so messages are retried when processing fails. Otherwise default ignore behavior is used (parameter omitted). Only change this if you specifically need deferred retries. |
| `-MatchSenderIn` | No | Defaults to `HeaderOrEnvelope`. Valid values: `HeaderOrEnvelope`, `Header`, `Envelope`. Controls where sender matching is evaluated. Most cases should use the default. |

**Usage Examples**

```powershell
# Fully interactive — script will prompt for all values
.\New-ExchangeBlockRule.ps1

# Most common way to block an email address
.\New-ExchangeBlockRule.ps1 -BlockAddress "spammer@evil.com" -Reason "spam" -Comment "jdoe@karst.com is receiving a ton of spam emails from this address. The emails do not include an 'Unsubscribe' link."

# Most common way to block an entire domain
.\New-ExchangeBlockRule.ps1 -BlockAddress "evil.com" -Reason "phishing" -Comment "Multiple users are receiving phishing emails from a variety of email addresses using this domain."

# Use explicit dates and audit mode for staged rollout/testing
.\New-ExchangeBlockRule.ps1 -BlockAddress "evil.com" -Reason "phishing" -Mode "Audit" -ActivationDate "09/25/2026" -ExpiryDate "10/01/2026 5:00 PM"

# Customize incident report settings
.\New-ExchangeBlockRule.ps1 -BlockAddress "evil.com" -Reason "phishing" -IncidentReportRecipient "admin@karst.com" -IncidentReportContent "Sender,Subject,Severity"

# Disable incident reports by setting one or both report params to empty/null
.\New-ExchangeBlockRule.ps1 -BlockAddress "evil.com" -Reason "phishing" -IncidentReportRecipient ""
```

### M365 / UserManagement

#### `Find-MatchingAccountsByNames.ps1`

Searches for M365 user accounts which match a list of user-provided names in the format `LastName, FirstName` (each entry separated by a newline) to speed up account lookups. This was specifically created to copy/paste the list of names from Savannah's monthly terminations spreadsheet, allowing one to easily find matching user accounts/emails that need to be disabled/deleted.

The script queries Microsoft Graph and attempts to match against `GivenName`, `Surname`, `DisplayName`, `Mail`, and `UserPrincipalName`. If no direct match is found, it retries with normalized values (removing common qualifiers, particles, and special characters). Results are displayed in the console and exported to a timestamped CSV file.

**Parameters**

This script takes no parameters. It will interactively prompt you to paste the list of names when run.

**Required Graph Scopes:** `User.Read.All`, `Directory.Read.All`

**Usage Examples**

```powershell
# Run the script, then paste names when prompted (one per line: "LastName, FirstName")
.\Find-MatchingAccountsByNames.ps1
```

#### `Get-ExtensionAttribute.ps1`

Retrieves extension attribute values for one or more user objects. Specifically designed to look up the values of `ExtensionAttribute1` (`IsSecondaryAccount`) and `ExtensionAttribute2` (`IsHoxhuntDisabled`). These attributes are used for Hoxhunt SCIM to determine whether specific users should or should not be enrolled in training.

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-UserId` | Yes | One or more user identifiers — UPN (e.g. `user@domain.com`) or Object ID. Accepts an array and pipeline input. |
| `-AttributeNum` | Yes | The extension attribute number to retrieve. Must be an integer between `1` and `15`. |

**Required Graph Scopes:** `User.ReadWrite.All`

**Usage Examples**

```powershell
# Get ExtensionAttribute1 for a single user
.\Get-ExtensionAttribute.ps1 -UserId "user@domain.com" -AttributeNum 1

# Get ExtensionAttribute1 for multiple users
.\Get-ExtensionAttribute.ps1 -UserId "user1@domain.com","user2@domain.com" -AttributeNum 1

# Pipe in a list of users from a text file
Get-Content users.txt | .\Get-ExtensionAttribute.ps1 -AttributeNum 2
```

#### `Set-ExtensionAttribute.ps1`

Updates extension attribute values for one or more user objects. Specifically designed to set the values of `ExtensionAttribute1` (`IsSecondaryAccount`) and `ExtensionAttribute2` (`IsHoxhuntDisabled`). These attributes are used for Hoxhunt SCIM to determine whether specific users should or should not be enrolled in training.

These are string properties treated as booleans — values should be set to either `True` or `False` (first letter capitalized).

> **ExtensionAttribute1 — IsSecondaryAccount:** Indicates the email account is *not* the user's primary email account and therefore should not be enrolled in Hoxhunt training. Users can still report emails using the Hoxhunt button.
>
> **ExtensionAttribute2 — IsHoxhuntDisabled:** Fully disables Hoxhunt enrollment for the account. Typically used for test accounts, admin accounts, or other accounts that should never receive training. Only use this when `ExtensionAttribute1` does not apply.

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-UserId` | Yes | One or more user identifiers — UPN (e.g. `user@domain.com`) or Object ID. Accepts an array and pipeline input. |
| `-AttributeNum` | Yes | The extension attribute number to set. Must be an integer between `1` and `15`. |
| `-Value` | Yes | The value to assign to the attribute (e.g. `True` or `False`). |

**Required Graph Scopes:** `User.ReadWrite.All`

**Usage Examples**

```powershell
# Mark a single account as a secondary account (exclude from Hoxhunt training)
.\Set-ExtensionAttribute.ps1 -UserId "user@domain.com" -AttributeNum 1 -Value "True"

# Disable Hoxhunt entirely for an admin account
.\Set-ExtensionAttribute.ps1 -UserId "admin@domain.com" -AttributeNum 2 -Value "True"

# Bulk-update multiple users at once
.\Set-ExtensionAttribute.ps1 -UserId "user1@domain.com","user2@domain.com" -AttributeNum 1 -Value "True"

# Re-enable a user for Hoxhunt training
.\Set-ExtensionAttribute.ps1 -UserId "user@domain.com" -AttributeNum 1 -Value "False"
```

## Usage Notes

- Run scripts with an account that has the required role/permissions.
- Review each script before execution in production environments.
- Test changes in a non-production environment when possible.
- Document any environment-specific assumptions directly in script comments.

## Conventions

- Scripts are grouped by service area and operational purpose.
- Names follow an action-oriented pattern where practical (for example: `Get-*`, `Set-*`, `Find-*`, `New-*`).
- Documentation in this README will continue to expand as additional scripts are added.

## Roadmap

Planned areas for continued growth include:

- onboarding and offboarding automation
- Intune and endpoint management tooling
- identity governance and reporting helpers
- enhanced script-level documentation and examples