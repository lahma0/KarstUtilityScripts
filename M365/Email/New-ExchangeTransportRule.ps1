param (
    [Parameter(Mandatory = $false)]
    [string]$Sender,

    [Parameter(Mandatory = $false)]
    [string]$Reason,

    [Parameter(Mandatory = $false)]
    [string]$Comment
)

function Ensure-ExchangeOnlineModule {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "⚠ ExchangeOnlineManagement module is not installed." -ForegroundColor Yellow
        $install = Read-Host "Do you want to install it now? (Y/N)"
        if ($install -eq 'Y' -or $install -eq 'y') {
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force
        }
        else {
            Write-Host "✗ Cannot continue without ExchangeOnlineManagement module. Exiting." -ForegroundColor Red
            exit 1
        }
    }
}

function Ensure-ExchangeOnlineConnected {
    # Ensure module is loaded
    if (-not (Get-Module ExchangeOnlineManagement)) {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
    }
    # Check if already connected
    $connected = $false
    try {
        $con = Get-ConnectionInformation -ErrorAction Stop
        if ($con) { $connected = $true }
    }
    catch {
        $connected = $false
    }
    # If not connected, prompt to connect
    if (-not $connected) {
        try {
            Connect-ExchangeOnline -ShowBanner:$false
        }
        catch {
            Write-Host "✗ Failed to connect to Exchange Online. Exiting." -ForegroundColor Red
            exit 1
        }
        # Re-check connection after authentication attempt
        try {
            $con = Get-ConnectionInformation -ErrorAction Stop
            if ($con) {
                Write-Host "✓ Connected to Exchange Online!" -ForegroundColor Cyan
                return
            }
        }
        catch {}
        Write-Host "✗ Failed to connect to Exchange Online after authentication attempt. Exiting." -ForegroundColor Red
        exit 1
    }
    else {
        Write-Host "✓ Connected to Exchange Online!" -ForegroundColor Cyan
    }
}

function IsValidEmail([string]$email) {
    # General length check
    if ([string]::IsNullOrEmpty($email) -or $email.Length -gt 254) { return $false }

    # Basic regex (local allows common special chars, then @, then valid domain with subdomains and TLD)
    if ($email -notmatch '^[A-Za-z0-9][A-Za-z0-9._%+\-]*[A-Za-z0-9]?@([A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]?\.)+[A-Za-z]{2,}$') { return $false }

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

function IsValidDomain([string]$domain) {
    if ([string]::IsNullOrEmpty($domain) -or $domain.Length -gt 253) { return $false }
    # Must not start/end with '.' or '-'
    if ($domain.StartsWith('.') -or $domain.EndsWith('.')) { return $false }
    if ($domain.StartsWith('-') -or $domain.EndsWith('-')) { return $false }
    if ($domain.Contains('..')) { return $false }

    # General pattern: Labels and TLD
    if ($domain -notmatch '^([A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]?\.)+[A-Za-z]{2,}$') { return $false }

    $labels = $domain.Split('.')
    foreach ($label in $labels) {
        if ($label.Length -lt 1 -or $label.Length -gt 63) { return $false }
        if ($label.StartsWith('-') -or $label.EndsWith('-')) { return $false }
    }
    return $true
}

# Prerequisite: Module check
Ensure-ExchangeOnlineModule

# Ensure connection to Exchange Online
Ensure-ExchangeOnlineConnected

# Interactive or parameter input with format validation
if (-not $Sender) {
    do {
        $Sender = Read-Host "`nEnter sender email address or domain to block [required]"
        if ($Sender -match '@') {
            if (-not (IsValidEmail $Sender)) {
                Write-Host "✗ Invalid email format. Please enter a valid email address (example@domain.com)." -ForegroundColor Yellow
                $Sender = $null
            }
        }
        else {
            if (-not (IsValidDomain $Sender)) {
                Write-Host "✗ Invalid domain format. Please enter a valid domain (example.com)." -ForegroundColor Yellow
                $Sender = $null
            }
        }
    } while (-not $Sender)
}
else {
    # Parameter provided: Format check
    if ($Sender -match '@') {
        if (-not (IsValidEmail $Sender)) {
            Write-Host "✗ Invalid email format for parameter. Expected valid email address (example@domain.com). Exiting." -ForegroundColor Red
            exit 1
        }
    }
    else {
        if (-not (IsValidDomain $Sender)) {
            Write-Host "✗ Invalid domain format for parameter. Expected valid domain (example.com). Exiting." -ForegroundColor Red
            exit 1
        }
    }
}

if (-not $Reason) {
    do {
        $Reason = Read-Host "`nEnter the reason for blocking (e.g. 'phishing', 'spam', 'malware', etc.) [required]"
    } while ([string]::IsNullOrWhiteSpace($Reason))
}

if (-not $Comment) {
    $Comment = Read-Host "`nEnter a comment for this rule [optional]"
}

# Determine whether input is an email or domain
if ($Sender -match "@") {
    $isDomain = $false
    $ruleName = "Block $Sender ($Reason)"
    $conditionParam = @{From = $Sender }
}
else {
    $isDomain = $true
    $cleanDomain = $Sender.TrimStart("@").ToLower()
    $ruleName = "Block *.$cleanDomain ($Reason)"
    $conditionParam = @{SenderDomainIs = $cleanDomain }
}


# Check if rule already exists
$existingRule = Get-TransportRule -Identity $ruleName -ErrorAction SilentlyContinue
if ($existingRule) {
    Write-Host "`n✗ A rule with the name '${ruleName}' already exists!" -ForegroundColor Red
    $overwrite = Read-Host "Do you want to remove the existing rule and create a new one? (Y/N)"
    if ($overwrite -eq 'Y' -or $overwrite -eq 'y') {
        Remove-TransportRule -Identity $ruleName -Confirm:$false
        Write-Host "🛈 Existing rule removed" -ForegroundColor Cyan
    }
    else {
        Write-Host "✗ Operation cancelled due to existing rule with identical name." -ForegroundColor Red
        exit
    }
}

# Find the highest priority and set new rule priority
Write-Host "`nCalculating rule priority..." -ForegroundColor Cyan
$rules = Get-TransportRule
if ($rules) {
    $currentMaxPriority = ($rules | Measure-Object -Property Priority -Maximum).Maximum
    $newPriority = $currentMaxPriority + 1
    Write-Host "🛈 Highest existing priority: ${currentMaxPriority} | New rule priority: ${newPriority}" -ForegroundColor Cyan
}
else {
    $newPriority = 0
    Write-Host "🛈 No existing rules found. Using priority: ${newPriority}" -ForegroundColor Cyan
}

$incidentContent = "Sender,Recipients,Subject,Cc,Bcc,Severity,RuleDetections,FalsePositive,AttachOriginalMail"

# Prepare parameters for the new rule
$transportRuleParams = @{
    Name                   = $ruleName
    Priority               = $newPriority
    Enabled                = $true
    Mode                   = "Enforce"
    SetAuditSeverity       = "Medium"
    StopRuleProcessing     = $false
    GenerateIncidentReport = "security@karst.com"
    IncidentReportContent  = $incidentContent
    DeleteMessage          = $true
    SenderAddressLocation  = "HeaderOrEnvelope"
}

if ($isDomain) {
    $transportRuleParams.SenderDomainIs = $cleanDomain
}
else {
    $transportRuleParams.From = $Sender
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

    if ($isDomain) {
        Write-Host "  Blocks: All emails from *.$senderDomain domain" -ForegroundColor White
    }
    else {
        Write-Host "  Blocks: Email from $senderEmail" -ForegroundColor White
    }

    Write-Host "  Action: Delete message without notification" -ForegroundColor White
    Write-Host "  Incident Report: Sent to security@karst.com" -ForegroundColor White
    Write-Host "  Status: Enabled" -ForegroundColor White

    if (![string]::IsNullOrWhiteSpace($Comment)) {
        Write-Host "  Comment: $Comment" -ForegroundColor White
    }
}
catch {
    Write-Host "`n✗✗✗ ERROR ✗✗✗" -ForegroundColor Red
    Write-Host "✗ Failed to create transport rule!" -ForegroundColor Red
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
