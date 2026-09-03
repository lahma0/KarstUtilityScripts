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
|-- Utils/
|   |-- BusinessCards/
|   |   `-- templates/
|   |       `-- karst/
|   |           `-- New-BusinessCard.ps1
|   `-- Credentials/
|       `-- Get-PronounceablePassword.ps1
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
        |-- Get-UserProfileData.ps1
        |-- Set-ExtensionAttribute.ps1
        `-- Set-UserProfileData.ps1
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

After passwords are retrieved, the script automatically copies the first returned password to the system clipboard (unless `-NoCopy` is supplied) and displays the machine name associated with that copied password.

By default, the script prompts to confirm whether plaintext password values should be printed to the console output. If you answer `No`, the `Password` field is redacted in the returned results. Use `-SkipPrompt` to bypass this confirmation and print unredacted values.

Detailed stage/timing diagnostics are available via standard PowerShell verbose output (`-Verbose`).

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-DeviceIds` | No | One or more Intune device IDs or device names to query. Accepts a string array. If omitted, the script prompts interactively. |
| `-IncludeHistory` | No | When supplied, also requests password history in addition to the current password. |
| `-NoCopy` | No | When supplied, skips copying the first returned password to the clipboard. |
| `-SkipPrompt` | No | When supplied, skips the plaintext output confirmation prompt and prints password fields unredacted. |

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

# Show detailed stage/timing diagnostics
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop" -Verbose

# Skip copying password to clipboard
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop" -NoCopy

# Skip plaintext-output confirmation prompt and print unredacted passwords
.\Get-IntuneLocalAdminPassword.ps1 -DeviceIds "JohnDoeLaptop" -SkipPrompt
```

### M365 / Email

#### `Invoke-ContentSearchMailPurge.ps1`

Searches all Microsoft 365 user mailboxes for emails matching specified criteria using the Microsoft Purview Content Search feature, then optionally deletes them across the entire organization. Intended for responding to phishing or malicious email incidents where a harmful message must be removed before users can act on it.

The script builds a KQL query from the provided filter parameters, creates and runs a compliance search, displays match results (including a per-mailbox breakdown of affected accounts), and — unless `PurgeType` is set to `None` — executes a compliance purge action to delete the matched messages.

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-From` | No\* | Sender email address or domain to search for. Accepts a full email address (`attacker@evil.com`) or a bare domain name (`evil.com`) to match any sender from that domain. |
| `-To` | No\* | Recipient email address or domain to search for. Accepts a full email address (`victim@karst.com`) or a bare domain name (`karst.com`) to match any recipient at that domain. |
| `-Subject` | No\* | Subject line to search for. Supports partial matches. |
| `-MatchTerms` | No\* | One or more keywords/phrases to search for in the message body. Multiple terms are combined with OR logic. Accepts a string array: `@("term one", "term two")`. |
| `-StartDate` | No\* | Only match messages sent on or after this date. Accepted input: `DateTime`, `MM/dd/yyyy`, or `MM/dd/yyyy h:mm tt`. Dates are treated as local time and automatically converted to UTC before the query is sent to the server. |
| `-EndDate` | No\* | Only match messages sent on or before this date. Accepted input: `DateTime`, `MM/dd/yyyy`, or `MM/dd/yyyy h:mm tt`. Dates are treated as local time and automatically converted to UTC before the query is sent to the server. |
| `-HasAttachment` | No\* | When `$true`, only match messages with attachments. When `$false`, only match messages without attachments. When omitted, attachment presence is not filtered. |
| `-SearchName` | No | Name for the compliance search created in Microsoft Purview. If a search with this name already exists, an interactive menu is presented (see below). Defaults to an auto-generated timestamp-based name. |
| `-PurgeType` | No | How to delete matched messages. `SoftDelete` moves messages to Recoverable Items (recoverable), but note that soft-deleted messages remain findable by subsequent content searches since they still exist in the user's Recoverable Items folder — this is expected behavior. `HardDelete` permanently deletes them and removes them from search results. `None` runs the search only without deleting anything — useful for validating criteria before committing to a purge. Defaults to `SoftDelete`. |
| `-SkipConfirmation` | No | When `$true`, skips the interactive confirmation prompt before purging. Defaults to `$false`. |
| `-KeepSearch` | No | Switch parameter. When specified, retains the compliance search and purge action in Microsoft Purview after the script completes without prompting. When omitted, the script asks whether to delete the search upon completion (default: Y). |

\* At least one search parameter (`From`, `To`, `Subject`, `MatchTerms`, `StartDate`, `EndDate`, or `HasAttachment`) must be provided. If none are supplied via parameters, the script prompts interactively.

**Existing Search Menu**

When `-SearchName` is provided and a compliance search with that name already exists in Microsoft Purview, the script presents an interactive numbered menu:

| Option | Action |
|--------|--------|
| 1 - Overwrite | Deletes the existing search (and purge action if present) and creates a new one using the current parameters. |
| 2 - Show existing search results | Displays the item count, size, and per-mailbox breakdown from the existing search without making any changes. Exits after displaying results. |
| 3 - Re-run the search | Restarts the existing search using its stored KQL query, waits for completion, then continues with the normal purge flow. |
| 4 - Run a purge on existing results | Skips directly to the purge step using the results already in the existing search. If `PurgeType` is `None`, prompts for SoftDelete or HardDelete first. |
| 5 - Delete and exit | Removes the compliance search and any associated purge action from Purview, then exits. If the search or purge action is still in progress, you are prompted to either stop it immediately and delete, wait for it to finish and then delete, or cancel the deletion. |

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

#### `Grant-AccessToOneDrive.ps1`

Grants one or more users access to another user's OneDrive by assigning Site Collection Administrator rights on that OneDrive site.

The script prompts for any required values that are not supplied as parameters and supports passing multiple users in a single parameter array.

It can both grant and revoke OneDrive access for one or more users.

Important: this method grants full read/write administrative access to the target OneDrive site. There is no read-only mode in this script.

The script outputs the target personal-site URL (for example, `https://tmconcrete-my.sharepoint.com/personal/jdoe_karst_com/`).

If the user does not immediately see the target user's files after opening that URL, they should click **My files** in the left navigation.

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-TargetUserId` | No | The target user's UPN/email address whose OneDrive should be shared. If omitted, the script prompts interactively. |
| `-UserIds` | No | One or more UPN/email addresses of users who should receive access. Accepts a string array. If omitted, the script prompts for one or more values separated by commas. |
| `-TenantName` | No | SharePoint tenant prefix used to build the personal site URL. Defaults to `tmconcrete`. |
| `-SiteUrl` | No | Optional full URL for the target OneDrive personal site. If omitted, the script derives the URL from `TargetUserId` and `TenantName`. |
| `-Revoke` | No | Switch parameter. When supplied, removes Site Collection Administrator access for each specified user. |

**Required Module:** `Microsoft.Online.SharePoint.PowerShell`

**Required Permissions:** SharePoint Online admin rights sufficient to manage Site Collection Administrators

**Usage Examples**

```powershell
# Prompt interactively for the target user and the users to grant access to
.\Grant-AccessToOneDrive.ps1

# Grant access to one user for a specific OneDrive site
.\Grant-AccessToOneDrive.ps1 -TargetUserId "jdoe@karst.com" -UserIds "manager@karst.com"

# Grant access to multiple users at once
.\Grant-AccessToOneDrive.ps1 -TargetUserId "jdoe@karst.com" -UserIds "manager@karst.com","manager@texmix.com","manager@sunrise-rm.com"

# Use an explicitly supplied personal site URL
.\Grant-AccessToOneDrive.ps1 -TargetUserId "jdoe@karst.com" -SiteUrl "https://tmconcrete-my.sharepoint.com/personal/jdoe_karst_com/"

# Revoke access for one or more users
.\Grant-AccessToOneDrive.ps1 -TargetUserId "jdoe@karst.com" -UserIds "manager@karst.com","manager@texmix.com" -Revoke
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

#### `Get-UserProfileData.ps1`

Retrieves all profile fields managed by `Set-UserProfileData.ps1` for one Microsoft 365 user. The output includes standard Microsoft Graph profile properties, `HRPersonalData` custom security attributes, the assigned manager, and the Hoxhunt extension attributes.

The default output is a PowerShell object. Collection fields such as `BusinessPhones`, `Interests`, `OtherMails`, `PastProjects`, `Responsibilities`, `Schools`, and `Skills` are returned as arrays. Use `-AsJson` when a JSON representation is needed for export or reuse with other tooling.

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-UserPrincipalName` | No | User UPN or another Microsoft Graph user identifier. If omitted, the script prompts. |
| `-AsJson` | No | Emits the complete profile as JSON instead of a formatted PowerShell object. |

**Required Modules**

- `Microsoft.Graph`
- `ExchangeOnlineManagement`

**Required Graph Scopes**

- `User.Read.All`
- `Directory.Read.All`
- `CustomSecAttributeAssignment.Read.All`

**Usage Examples**

```powershell
# Prompt for the user's UPN and display all profile fields
.\Get-UserProfileData.ps1

# Retrieve profile data for a specific user
.\Get-UserProfileData.ps1 -UserPrincipalName "jdoe@contoso.com"

# Retrieve profile data as JSON
.\Get-UserProfileData.ps1 -UserPrincipalName "jdoe@contoso.com" -AsJson
```

#### `Set-UserProfileData.ps1`

Sets new employee profile data by updating standard Microsoft Graph user properties, manager assignment, Entra custom security attributes, and string-based extension attributes used for Hoxhunt behavior flags.

The script supports both interactive and parameter-driven workflows:

- If run without profile parameters, it prompts for `UserPrincipalName` and then prompts all fields.
- If run with only `UserPrincipalName`, it still prompts all fields.
- If run with specific profile parameters, only those parameters are processed.
- If a supplied parameter is missing a value, only that field is prompted.
- Prompted fields are editable with the current value prefilled.
- Press `Enter` to keep current value, `Backspace` to clear value, and `Tab` to skip unchanged.

**Special handling**

- Manager assignment uses `Set-MgUserManagerByRef`.
- Custom security attributes use:
  - `Get-MgUserSecurityAttribute`
  - `New-MgUserSecurityAttributeAssignment`
  - `Update-MgUserSecurityAttribute`
- `IsSecondaryAccount` and `IsHoxhuntDisabled` are normalized to `True`/`False` and stored in extension attributes (`CustomAttribute1`/`CustomAttribute2`).

**Common parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-UserPrincipalName` | No | Target user UPN. Prompted if omitted. |
| `-ManagerEmailAddress` | No | Manager UPN/email. Assigns or clears manager reference. |
| `-IsSecondaryAccount` | No | Stored as normalized `True`/`False` string in extension attribute 1. |
| `-IsHoxhuntDisabled` | No | Stored as normalized `True`/`False` string in extension attribute 2. |

Additional supported parameters map directly to the profile schema in the script help, including identity, contact, address, organization, and string-collection fields such as `BusinessPhones`, `OtherMails`, `Responsibilities`, `Skills`, etc.

**Required Modules**

- `Microsoft.Graph`

**Required Graph Scopes**

- `User.ReadWrite.All`
- `Directory.ReadWrite.All`
- `CustomSecAttributeAssignment.ReadWrite.All`
- `User-Phone.ReadWrite.All`
- `User-Mail.ReadWrite.All`
- `User-LifeCycleInfo.ReadWrite.All`

**Usage Examples**

```powershell
# Fully interactive (prompt UPN, then prompt all fields)
.\Set-UserProfileData.ps1

# Prompt all fields for an existing user
.\Set-UserProfileData.ps1 -UserPrincipalName "jdoe@contoso.com"

# Update only provided fields (no extra prompts)
.\Set-UserProfileData.ps1 -UserPrincipalName "jdoe@contoso.com" -DisplayName "John Q. Doe" -Department "Accounting"

# Update manager and Hoxhunt flags
.\Set-UserProfileData.ps1 -UserPrincipalName "jdoe@contoso.com" -ManagerEmailAddress "mgr@contoso.com" -IsSecondaryAccount "True" -IsHoxhuntDisabled "False"

# Update string collections using JSON array format
.\Set-UserProfileData.ps1 -UserPrincipalName "jdoe@contoso.com" -Responsibilities '["Approve invoices", "Manage monthly close"]'
```

### Utils / BusinessCards

#### `New-BusinessCard.ps1`

Generates a business card SVG file by populating a template with contact information. The script discovers available SVG templates, collects field values from parameters or interactive prompts, and writes a fully substituted SVG to a specified output path.

All field values are automatically converted to uppercase in the output, with the exception of QR code content which is preserved as-is. Phone numbers are assembled from separate type, number, and extension inputs and formatted as `C: 737.376.6888` or `O: 254.489.0469 EXT 5027`. QR code content is extracted from a separate QR SVG file by capturing everything between the first `<g>` and last `</g>` elements.

**Supported Template Placeholders**

`<!--#Email#-->`, `<!--#Phone1#-->`, `<!--#Phone2#-->`, `<!--#Addr1#-->`, `<!--#City1#-->`, `<!--#State1#-->`, `<!--#Zip1#-->`, `<!--#Addr2#-->`, `<!--#City2#-->`, `<!--#State2#-->`, `<!--#Zip2#-->`, `<!--#JobTitle#-->`, `<!--#Region#-->`, `<!--#QR#-->`

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Template` | No | Path to the SVG template file. If omitted, the script searches the templates folder and presents a numbered selection menu. |
| `-Email` | No\* | Email address. Converted to uppercase. |
| `-Phone1Type` | No\* | Type of the first phone number. Valid values: `Cell`, `Office`. |
| `-Phone1Number` | No\* | First phone number. Must be exactly 10 digits (no formatting). |
| `-Phone1Extension` | No | Extension for the first phone number (1-6 digits). Only prompted if `Phone1` is in the template and both `-Phone1Type` and `-Phone1Number` were not both pre-supplied as parameters. Leave blank for no extension. |
| `-Phone2Type` | No\* | Type of the second phone number. Valid values: `Cell`, `Office`. Only used if `<!--#Phone2#-->` is in the template. |
| `-Phone2Number` | No\* | Second phone number. Must be exactly 10 digits (no formatting). Only used if `<!--#Phone2#-->` is in the template. |
| `-Phone2Extension` | No | Extension for the second phone number (1-6 digits). Only prompted if `Phone2` is in the template and both `-Phone2Type` and `-Phone2Number` were not both pre-supplied as parameters. |
| `-Addr1` | No\* | First address line. Converted to uppercase. |
| `-City1` | No\* | City for the first address. Converted to uppercase. |
| `-State1` | No\* | State for the first address. Converted to uppercase. |
| `-Zip1` | No\* | ZIP code for the first address. Converted to uppercase. |
| `-Addr2` | No\* | Second address line. Converted to uppercase. |
| `-City2` | No\* | City for the second address. Converted to uppercase. |
| `-State2` | No\* | State for the second address. Converted to uppercase. |
| `-Zip2` | No\* | ZIP code for the second address. Converted to uppercase. |
| `-JobTitle` | No\* | Job title. Converted to uppercase. |
| `-Region` | No\* | Region or territory. Converted to uppercase. |
| `-QR` | No\* | Raw SVG content for the QR code (the inner `<g>...</g>` elements). Preserved as-is. If omitted, `-QrSvgPath` is used instead. |
| `-QrSvgPath` | No\* | Path to a QR code SVG file. The script extracts content between the first `<g>` and last `</g>` elements. Ignored if `-QR` is supplied. |
| `-FirstName` | No | First name of the card recipient. Used to auto-generate the suggested output file name. Only prompted when `-OutputSvgPath` is not supplied. |
| `-LastName` | No | Last name of the card recipient. Used to auto-generate the suggested output file name. Only prompted when `-OutputSvgPath` is not supplied. |
| `-OutputSvgPath` | No | Path where the populated SVG should be saved. Missing parent directories are created automatically. If the file already exists, the script prompts before overwriting. If omitted, a path is suggested in the format `.<br>\output\[TemplateName].[FirstName].[LastName].svg`, where any occurrence of `-Template` or `Template` in the template filename is removed. |
| `-OverwriteWithoutPrompting` | No | Switch. When specified, overwrites an existing output file without prompting. |

\* Prompted only if the corresponding placeholder is found in the selected template.

**Phone Extension Prompting Rules**

- If both `-Phone1Type` **and** `-Phone1Number` are supplied as parameters, `-Phone1Extension` is assumed absent and the user is **not** prompted for it.
- If only one of `-Phone1Type` or `-Phone1Number` is supplied as a parameter (or neither), the user **is** prompted for the extension and informed they can leave it blank if none exists.
- The same rules apply to the Phone 2 parameters.

**Usage Examples**

```powershell
# Fully interactive — select a template from the menu, then provide all values when prompted
.\New-BusinessCard.ps1

# Provide a template and some values; prompts only for the remaining placeholders
.\New-BusinessCard.ps1 -Template ".\karst\Karst-BusinessCard-Template.svg" -Email "jdoe@karst.com" -JobTitle "Project Manager" -Phone1Type Office -Phone1Number "2544890469"

# Use an existing QR SVG file and write to a specific output path
.\New-BusinessCard.ps1 -Template ".\karst\Karst-BusinessCard-Template.svg" -Email "jdoe@karst.com" -QrSvgPath ".\qr\jdoe-qr.svg" -OutputSvgPath ".\output\Karst-BusinessCard.John.Doe.svg" -OverwriteWithoutPrompting

# Provide both phone entries as parameters (extension is not prompted for either)
.\New-BusinessCard.ps1 -Phone1Type Cell -Phone1Number "7373766888" -Phone2Type Office -Phone2Number "2544890469" -Phone2Extension "5027"
```

### Utils / Credentials

#### `Get-PronounceablePassword.ps1`

Generates one or more pronounceable passwords with configurable total length, minimum digit/special-character counts, case style for the pronounceable portion, and ordered grouping of password elements.

Password content is always grouped by element type and never interleaved. The three groups are:

- Letters
- Digits
- SpecialChars

For example, grouped output may look like `bazFOO348!@`, but never like `baz3FOO4!8@`.

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Length` | No | Total password length. Minimum `12`. Default `14`. |
| `-MinNumOfDigits` | No | Minimum number of digit characters. Range `1` to `3`. Default `1`. |
| `-MinNumOfSpecialChars` | No | Minimum number of special characters. Range `1` to `3`. Default `1`. |
| `-Case` | No | Case mode for the pronounceable letter segment. Valid values: `lowerUPPER`, `UPPERlower`, `CamelCase`, `lowerOnly`, `UPPEROnly`, `Random`. Default `Random` (randomly picks from `lowerUPPER`, `UPPERlower`, `CamelCase`). |
| `-Order` | No | Group order mode. Valid values: `LettersDigitsSpecialChars`, `LettersSpecialCharsDigits`, `DigitsLettersSpecialChars`, `DigitsSpecialCharsLetters`, `SpecialCharsLettersDigits`, `SpecialCharsDigitsLetters`, `Random`. Default `Random`. |
| `-Count` | No | Number of passwords to generate. Minimum `1`. Default `1`. |

**Usage Examples**

```powershell
# Generate one password with default settings
.\Get-PronounceablePassword.ps1

# Generate one 16-character password with explicit case/order
.\Get-PronounceablePassword.ps1 -Length 16 -MinNumOfDigits 3 -MinNumOfSpecialChars 2 -Case CamelCase -Order DigitsLettersSpecialChars

# Generate five passwords
.\Get-PronounceablePassword.ps1 -Count 5

# Generate three passwords with fixed lowercase letters and fixed order
.\Get-PronounceablePassword.ps1 -Count 3 -Case lowerOnly -Order LettersDigitsSpecialChars
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