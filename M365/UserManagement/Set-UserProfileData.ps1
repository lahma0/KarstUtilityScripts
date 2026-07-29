<#
.SYNOPSIS
Sets Microsoft 365 profile data for a user using Microsoft Graph and Exchange Online.

.DESCRIPTION
This script updates user profile data for new employees. It supports two modes:

1) Interactive mode:
   - If no profile parameters are supplied, the script prompts for UserPrincipalName and then
     prompts field-by-field.
   - If only UserPrincipalName is supplied, the script still prompts field-by-field.

2) Parameter-driven mode:
   - If specific profile parameters are supplied, only those parameters are processed.
   - If UserPrincipalName is not supplied, the script prompts for it.
   - If a supplied profile parameter is null/empty, the script prompts only for that field.

Interactive field prompts show the current value pre-filled so it can be edited in place.
Press Enter to keep the current value unchanged. Press Tab to skip the field unchanged.
For string-collection fields, values are entered as JSON arrays:
["value1", "value2", "value3"]

Custom security attributes in HRPersonalData are read with Get-MgUserSecurityAttribute and
written with Update-MgUserSecurityAttribute after ensuring assignment with
New-MgUserSecurityAttributeAssignment.

ManagerEmailAddress is handled with Set-MgUserManagerByRef.
IsSecondaryAccount and IsHoxhuntDisabled map to Exchange Online extension attributes
(CustomAttribute1/CustomAttribute2) and are stored as strings "True" or "False".

.PARAMETER UserPrincipalName
The user UPN to update. If omitted, the script prompts for it.

.PARAMETER AboutMe
A freeform profile summary.

.PARAMETER Birthday
Birthday in YYYY-MM-DD format.

.PARAMETER BusinessPhones
JSON array of office phone values. Example:
["(512) 555-1234", "(512) 555-1234 ext. 101"]

.PARAMETER City
Primary business city. Maximum length: 128.

.PARAMETER CompanyName
Company name associated with the user.

.PARAMETER CompanyMobilePhone
Company-issued mobile phone in format (###) ###-####.
Custom security attribute: HRPersonalData.CompanyMobilePhone.

.PARAMETER Country
Primary business country/region full name. Maximum length: 128.

.PARAMETER Department
Department name. Maximum length: 64.

.PARAMETER DisplayName
Address book display name. Maximum length: 256.

.PARAMETER EmergencyContactFullName
Emergency contact full name.
Custom security attribute: HRPersonalData.EmergencyContactFullName.

.PARAMETER EmergencyContactPhone
Emergency contact phone in format (###) ###-#### or (###) ###-#### ext. ###.
Custom security attribute: HRPersonalData.EmergencyContactPhone.

.PARAMETER EmployeeHireDate
Hire/start date in YYYY-MM-DD format.

.PARAMETER EmployeeLeaveDateTime
Leave date in YYYY-MM-DD format. Leave blank if still employed.

.PARAMETER EmployeeId
Organization employee ID. Maximum length: 16.

.PARAMETER EmployeeType
Worker type (Employee, Contractor, Vendor, etc.).

.PARAMETER FaxNumber
Fax in format (###) ###-#### or (###) ###-#### ext. ###.

.PARAMETER GivenName
First name. Maximum length: 64.

.PARAMETER HomeStreetAddress
Home street address.
Custom security attribute: HRPersonalData.HomeStreetAddress.

.PARAMETER HomeCity
Home city.
Custom security attribute: HRPersonalData.HomeCity.

.PARAMETER HomeState
Home state, 2-letter abbreviation (for example: TX).
Custom security attribute: HRPersonalData.HomeState.

.PARAMETER HomePostalCode
Home postal code.
Custom security attribute: HRPersonalData.HomePostalCode.

.PARAMETER Interests
JSON array of interests.

.PARAMETER IsSecondaryAccount
Stored in Exchange extension attribute 1. Value is normalized to "True" or "False".

.PARAMETER IsHoxhuntDisabled
Stored in Exchange extension attribute 2. Value is normalized to "True" or "False".

.PARAMETER JobTitle
Job title. Maximum length: 128.

.PARAMETER ManagerEmailAddress
Manager UPN/email. Set with Set-MgUserManagerByRef.

.PARAMETER MobilePhone
Primary mobile in format (###) ###-####.

.PARAMETER OfficeLocation
Office location description.

.PARAMETER OtherMails
JSON array of additional email addresses. Up to 250 values, each up to 250 chars.

.PARAMETER PastProjects
JSON array of past projects.

.PARAMETER PersonalMobilePhone
Personal mobile in format (###) ###-####.
Custom security attribute: HRPersonalData.PersonalMobilePhone.

.PARAMETER PostalCode
Business postal code. Maximum length: 40.

.PARAMETER PreferredLanguage
RFC 4646 culture format (for example: en-US, es-ES).

.PARAMETER PreferredName
Preferred/given name used by the person.

.PARAMETER Responsibilities
JSON array of responsibilities.

.PARAMETER Schools
JSON array of schools.

.PARAMETER ShowInAddressList
Boolean. False hides user from address list.

.PARAMETER Skills
JSON array of skills.

.PARAMETER State
Business state/province. Use 2-letter abbreviation. Maximum length: 128.

.PARAMETER StreetAddress
Business street address. Maximum length: 1024.

.PARAMETER Surname
Last name. Maximum length: 64.

.NOTES
Required Graph scopes:
- User.ReadWrite.All
- Directory.ReadWrite.All
- CustomSecAttributeAssignment.ReadWrite.All

ExchangeOnlineManagement is required for extension attributes 1/2 updates.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$UserPrincipalName,

    [Parameter(Mandatory = $false)]
    [string]$AboutMe,

    [Parameter(Mandatory = $false)]
    [string]$Birthday,

    [Parameter(Mandatory = $false)]
    [string]$BusinessPhones,

    [Parameter(Mandatory = $false)]
    [string]$City,

    [Parameter(Mandatory = $false)]
    [string]$CompanyName,

    [Parameter(Mandatory = $false)]
    [string]$CompanyMobilePhone,

    [Parameter(Mandatory = $false)]
    [string]$Country,

    [Parameter(Mandatory = $false)]
    [string]$Department,

    [Parameter(Mandatory = $false)]
    [string]$DisplayName,

    [Parameter(Mandatory = $false)]
    [string]$EmergencyContactFullName,

    [Parameter(Mandatory = $false)]
    [string]$EmergencyContactPhone,

    [Parameter(Mandatory = $false)]
    [string]$EmployeeHireDate,

    [Parameter(Mandatory = $false)]
    [string]$EmployeeLeaveDateTime,

    [Parameter(Mandatory = $false)]
    [string]$EmployeeId,

    [Parameter(Mandatory = $false)]
    [string]$EmployeeType,

    [Parameter(Mandatory = $false)]
    [string]$FaxNumber,

    [Parameter(Mandatory = $false)]
    [string]$GivenName,

    [Parameter(Mandatory = $false)]
    [string]$HomeStreetAddress,

    [Parameter(Mandatory = $false)]
    [string]$HomeCity,

    [Parameter(Mandatory = $false)]
    [string]$HomeState,

    [Parameter(Mandatory = $false)]
    [string]$HomePostalCode,

    [Parameter(Mandatory = $false)]
    [string]$Interests,

    [Parameter(Mandatory = $false)]
    [string]$IsSecondaryAccount,

    [Parameter(Mandatory = $false)]
    [string]$IsHoxhuntDisabled,

    [Parameter(Mandatory = $false)]
    [string]$JobTitle,

    [Parameter(Mandatory = $false)]
    [string]$ManagerEmailAddress,

    [Parameter(Mandatory = $false)]
    [string]$MobilePhone,

    [Parameter(Mandatory = $false)]
    [string]$OfficeLocation,

    [Parameter(Mandatory = $false)]
    [string]$OtherMails,

    [Parameter(Mandatory = $false)]
    [string]$PastProjects,

    [Parameter(Mandatory = $false)]
    [string]$PersonalMobilePhone,

    [Parameter(Mandatory = $false)]
    [string]$PostalCode,

    [Parameter(Mandatory = $false)]
    [string]$PreferredLanguage,

    [Parameter(Mandatory = $false)]
    [string]$PreferredName,

    [Parameter(Mandatory = $false)]
    [string]$Responsibilities,

    [Parameter(Mandatory = $false)]
    [string]$Schools,

    [Parameter(Mandatory = $false)]
    [Nullable[bool]]$ShowInAddressList,

    [Parameter(Mandatory = $false)]
    [string]$Skills,

    [Parameter(Mandatory = $false)]
    [string]$State,

    [Parameter(Mandatory = $false)]
    [string]$StreetAddress,

    [Parameter(Mandatory = $false)]
    [string]$Surname
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

function Initialize-GraphModule {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
        Write-Host "Microsoft.Graph module is not installed." -ForegroundColor Yellow
        if (Read-YesNoResponse -Prompt "Do you want to install Microsoft.Graph now?" -DefaultValue $false) {
            Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
        } else {
            Write-Host "Cannot continue without Microsoft.Graph. Exiting." -ForegroundColor Red
            exit 1
        }
    }
}

function Connect-MgGraphSessionIfNeeded {
    $requiredScopes = @(
        "User.ReadWrite.All",
        "Directory.ReadWrite.All",
        "CustomSecAttributeAssignment.ReadWrite.All"
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

function Initialize-ExchangeOnlineModule {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "ExchangeOnlineManagement module is not installed." -ForegroundColor Yellow
        if (Read-YesNoResponse -Prompt "Install ExchangeOnlineManagement now?" -DefaultValue $false) {
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
        } else {
            Write-Host "Cannot update extension attributes without ExchangeOnlineManagement. Exiting." -ForegroundColor Red
            exit 1
        }
    }

    if (-not (Get-Module ExchangeOnlineManagement)) {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop | Out-Null
    }
}

function Connect-ExchangeOnlineIfNeeded {
    $connected = $false
    try {
        $connected = [bool](Get-ConnectionInformation -ErrorAction Stop)
    } catch {
        $connected = $false
    }

    if (-not $connected) {
        Write-Host "Connecting to Exchange Online (device code auth)..." -ForegroundColor Cyan
        Connect-ExchangeOnline -ShowBanner:$false -Device
    }
}

function Test-ValidEmail {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value.Length -gt 254) { return $false }

    return ($Value -match '^[A-Za-z0-9][A-Za-z0-9._%+\-]*[A-Za-z0-9]?@([A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]?\.)+[A-Za-z]{2,}$')
}

function Convert-StringCollectionLiteralToArray {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Literal,

        [Parameter(Mandatory = $true)]
        [string]$FieldName
    )

    $trimmed = $Literal.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return @()
    }

    try {
        $parsed = $trimmed | ConvertFrom-Json -ErrorAction Stop
        if ($parsed -isnot [array]) {
            throw "Value is not an array."
        }

        $result = @()
        foreach ($item in $parsed) {
            if ($null -eq $item) {
                $result += ""
                continue
            }
            if ($item -isnot [string]) {
                throw "Array contains a non-string value."
            }
            $result += [string]$item
        }

        return $result
    } catch {
        Write-Host "Invalid format for $FieldName. Use JSON array format like [\"value1\", \"value2\"]." -ForegroundColor Red
        throw
    }
}

function Convert-ArrayToStringCollectionLiteral {
    param([object]$Value)

    if ($null -eq $Value) {
        return "[\"\"]"
    }

    $arr = @($Value)
    if ($arr.Count -eq 0) {
        return "[\"\"]"
    }

    $quoted = $arr | ForEach-Object {
        $s = [string]$_
        '"' + ($s.Replace('"', '\"')) + '"'
    }

    return "[$($quoted -join ', ')]"
}

function Read-EditableInput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [string]$InitialText = "",

        [Parameter(Mandatory = $false)]
        [int]$InitialCursorIndex = -1
    )

    if ($null -eq $InitialText) {
        $InitialText = ""
    }

    if ($InitialCursorIndex -lt 0 -or $InitialCursorIndex -gt $InitialText.Length) {
        $InitialCursorIndex = $InitialText.Length
    }

    $chars = [System.Collections.Generic.List[char]]::new()
    foreach ($c in $InitialText.ToCharArray()) {
        $chars.Add($c)
    }

    $cursor = $InitialCursorIndex
    [Console]::Write("$Prompt: ")

    while ($true) {
        $text = -join $chars
        $line = "$Prompt: $text"

        [Console]::Write("`r")
        [Console]::Write($line)

        $pad = [Console]::WindowWidth - $line.Length - 1
        if ($pad -gt 0) {
            [Console]::Write(" " * $pad)
        }

        [Console]::Write("`r$Prompt: ")
        if ($cursor -gt 0) {
            $prefix = -join ($chars.GetRange(0, $cursor))
            [Console]::Write($prefix)
        }

        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            ([ConsoleKey]::Tab) {
                [Console]::WriteLine("")
                return [PSCustomObject]@{
                    Skipped = $true
                    Text    = $InitialText
                }
            }
            ([ConsoleKey]::Enter) {
                [Console]::WriteLine("")
                return [PSCustomObject]@{
                    Skipped = $false
                    Text    = (-join $chars)
                }
            }
            ([ConsoleKey]::LeftArrow) {
                if ($cursor -gt 0) { $cursor-- }
            }
            ([ConsoleKey]::RightArrow) {
                if ($cursor -lt $chars.Count) { $cursor++ }
            }
            ([ConsoleKey]::Home) {
                $cursor = 0
            }
            ([ConsoleKey]::End) {
                $cursor = $chars.Count
            }
            ([ConsoleKey]::Backspace) {
                if ($cursor -gt 0) {
                    $chars.RemoveAt($cursor - 1)
                    $cursor--
                }
            }
            ([ConsoleKey]::Delete) {
                if ($cursor -lt $chars.Count) {
                    $chars.RemoveAt($cursor)
                }
            }
            default {
                if ($key.KeyChar -ge ' ') {
                    $chars.Insert($cursor, $key.KeyChar)
                    $cursor++
                }
            }
        }
    }
}

function Test-MaxLength {
    param(
        [string]$Value,
        [int]$MaxLength,
        [string]$FieldName
    )

    if ($null -ne $Value -and $Value.Length -gt $MaxLength) {
        Write-Host "$FieldName exceeds maximum length of $MaxLength characters." -ForegroundColor Red
        return $false
    }

    return $true
}

function Test-DateOnlyLiteral {
    param(
        [string]$Value,
        [string]$FieldName
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $true
    }

    [DateTime]$parsed = [DateTime]::MinValue
    if (-not [DateTime]::TryParseExact(
            $Value.Trim(),
            "yyyy-MM-dd",
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$parsed
        )) {
        Write-Host "$FieldName must use format YYYY-MM-DD." -ForegroundColor Red
        return $false
    }

    return $true
}

function Test-PhoneWithOptionalExtension {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    return ($Value -match '^\(\d{3}\) \d{3}-\d{4}( ext\. \d+)?$')
}

function Test-PhoneNoExtension {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    return ($Value -match '^\(\d{3}\) \d{3}-\d{4}$')
}

function Normalize-BoolString {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $trimmed = $Value.Trim()
    if ($trimmed -match '^(?i:true)$') { return "True" }
    if ($trimmed -match '^(?i:false)$') { return "False" }

    Write-Host "Value must be True or False." -ForegroundColor Red
    throw "Invalid boolean string"
}

function Validate-AndConvertFieldValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FieldName,

        [Parameter(Mandatory = $true)]
        [string]$FieldType,

        [Parameter(Mandatory = $false)]
        [object]$InputValue
    )

    $value = $InputValue
    if ($FieldType -eq "Boolean") {
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
            return $null
        }

        if ($value -is [bool]) {
            return [bool]$value
        }

        $t = [string]$value
        if ($t -match '^(?i:true)$') { return $true }
        if ($t -match '^(?i:false)$') { return $false }

        Write-Host "$FieldName must be True or False." -ForegroundColor Red
        throw "Invalid boolean value"
    }

    if ($FieldType -eq "String collection") {
        $items = @()

        if ($value -is [array]) {
            $items = @($value | ForEach-Object { [string]$_ })
        } else {
            $items = Convert-StringCollectionLiteralToArray -Literal ([string]$value) -FieldName $FieldName
        }

        if ($FieldName -eq "BusinessPhones") {
            foreach ($phone in $items) {
                if (-not (Test-PhoneWithOptionalExtension -Value $phone)) {
                    Write-Host "BusinessPhones values must use format (###) ###-#### or (###) ###-#### ext. ###." -ForegroundColor Red
                    throw "Invalid business phone"
                }
            }
        }

        return $items
    }

    $s = if ($null -eq $value) { "" } else { [string]$value }

    switch ($FieldName) {
        "Birthday" {
            if (-not (Test-DateOnlyLiteral -Value $s -FieldName $FieldName)) { throw "Invalid date" }
        }
        "EmployeeHireDate" {
            if (-not (Test-DateOnlyLiteral -Value $s -FieldName $FieldName)) { throw "Invalid date" }
        }
        "EmployeeLeaveDateTime" {
            if (-not (Test-DateOnlyLiteral -Value $s -FieldName $FieldName)) { throw "Invalid date" }
        }
        "BusinessPhones" {
            # handled in collection branch
        }
        "City" { if (-not (Test-MaxLength -Value $s -MaxLength 128 -FieldName $FieldName)) { throw "Invalid length" } }
        "Country" { if (-not (Test-MaxLength -Value $s -MaxLength 128 -FieldName $FieldName)) { throw "Invalid length" } }
        "Department" { if (-not (Test-MaxLength -Value $s -MaxLength 64 -FieldName $FieldName)) { throw "Invalid length" } }
        "DisplayName" { if (-not (Test-MaxLength -Value $s -MaxLength 256 -FieldName $FieldName)) { throw "Invalid length" } }
        "EmployeeId" { if (-not (Test-MaxLength -Value $s -MaxLength 16 -FieldName $FieldName)) { throw "Invalid length" } }
        "GivenName" { if (-not (Test-MaxLength -Value $s -MaxLength 64 -FieldName $FieldName)) { throw "Invalid length" } }
        "JobTitle" { if (-not (Test-MaxLength -Value $s -MaxLength 128 -FieldName $FieldName)) { throw "Invalid length" } }
        "PostalCode" { if (-not (Test-MaxLength -Value $s -MaxLength 40 -FieldName $FieldName)) { throw "Invalid length" } }
        "State" {
            if (-not (Test-MaxLength -Value $s -MaxLength 128 -FieldName $FieldName)) { throw "Invalid length" }
            if (-not [string]::IsNullOrWhiteSpace($s) -and $s -notmatch '^[A-Za-z]{2}$') {
                Write-Host "State must be a 2-letter abbreviation (example: TX)." -ForegroundColor Red
                throw "Invalid state"
            }
            $s = $s.ToUpperInvariant()
        }
        "StreetAddress" { if (-not (Test-MaxLength -Value $s -MaxLength 1024 -FieldName $FieldName)) { throw "Invalid length" } }
        "Surname" { if (-not (Test-MaxLength -Value $s -MaxLength 64 -FieldName $FieldName)) { throw "Invalid length" } }
        "HomeState" {
            if (-not [string]::IsNullOrWhiteSpace($s) -and $s -notmatch '^[A-Za-z]{2}$') {
                Write-Host "HomeState must be a 2-letter abbreviation (example: TX)." -ForegroundColor Red
                throw "Invalid HomeState"
            }
            $s = $s.ToUpperInvariant()
        }
        "ManagerEmailAddress" {
            if (-not [string]::IsNullOrWhiteSpace($s) -and -not (Test-ValidEmail -Value $s)) {
                Write-Host "ManagerEmailAddress must be a valid email address." -ForegroundColor Red
                throw "Invalid manager email"
            }
        }
        "PreferredLanguage" {
            if (-not [string]::IsNullOrWhiteSpace($s) -and $s -notmatch '^[a-z]{2}-[A-Z]{2}$') {
                Write-Host "PreferredLanguage must use RFC 4646 format (example: en-US)." -ForegroundColor Red
                throw "Invalid language"
            }
        }
        "CompanyMobilePhone" {
            if (-not (Test-PhoneNoExtension -Value $s)) {
                Write-Host "CompanyMobilePhone must use format (###) ###-####." -ForegroundColor Red
                throw "Invalid phone"
            }
        }
        "MobilePhone" {
            if (-not (Test-PhoneNoExtension -Value $s)) {
                Write-Host "MobilePhone must use format (###) ###-####." -ForegroundColor Red
                throw "Invalid phone"
            }
        }
        "PersonalMobilePhone" {
            if (-not (Test-PhoneNoExtension -Value $s)) {
                Write-Host "PersonalMobilePhone must use format (###) ###-####." -ForegroundColor Red
                throw "Invalid phone"
            }
        }
        "FaxNumber" {
            if (-not (Test-PhoneWithOptionalExtension -Value $s)) {
                Write-Host "FaxNumber must use format (###) ###-#### or (###) ###-#### ext. ###." -ForegroundColor Red
                throw "Invalid fax"
            }
        }
        "EmergencyContactPhone" {
            if (-not (Test-PhoneWithOptionalExtension -Value $s)) {
                Write-Host "EmergencyContactPhone must use format (###) ###-#### or (###) ###-#### ext. ###." -ForegroundColor Red
                throw "Invalid emergency phone"
            }
        }
        "IsSecondaryAccount" {
            $s = Normalize-BoolString -Value $s
        }
        "IsHoxhuntDisabled" {
            $s = Normalize-BoolString -Value $s
        }
    }

    return $s
}

function Set-CustomSecurityAttributes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [hashtable]$Attributes
    )

    if ($Attributes.Count -eq 0) { return }

    New-MgUserSecurityAttributeAssignment -UserId $UserId -AttributeSet "HRPersonalData" -ErrorAction SilentlyContinue | Out-Null

    $body = @{
        "HRPersonalData" = $Attributes
    }

    Update-MgUserSecurityAttribute -UserId $UserId -BodyParameter $body -ErrorAction Stop | Out-Null
}

$fields = @(
    [PSCustomObject]@{ Name = "AboutMe"; Type = "String"; GraphProperty = "aboutMe"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "Birthday"; Type = "DateTimeOffset"; GraphProperty = "birthday"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "BusinessPhones"; Type = "String collection"; GraphProperty = "businessPhones"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "City"; Type = "String"; GraphProperty = "city"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "CompanyName"; Type = "String"; GraphProperty = "companyName"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "CompanyMobilePhone"; Type = "String"; GraphProperty = $null; CustomSecurityAttribute = "CompanyMobilePhone"; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "Country"; Type = "String"; GraphProperty = "country"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "Department"; Type = "String"; GraphProperty = "department"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "DisplayName"; Type = "String"; GraphProperty = "displayName"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "EmergencyContactFullName"; Type = "String"; GraphProperty = $null; CustomSecurityAttribute = "EmergencyContactFullName"; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "EmergencyContactPhone"; Type = "String"; GraphProperty = $null; CustomSecurityAttribute = "EmergencyContactPhone"; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "EmployeeHireDate"; Type = "DateTimeOffset"; GraphProperty = "employeeHireDate"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "EmployeeLeaveDateTime"; Type = "DateTimeOffset"; GraphProperty = "employeeLeaveDateTime"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "EmployeeId"; Type = "String"; GraphProperty = "employeeId"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "EmployeeType"; Type = "String"; GraphProperty = "employeeType"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "FaxNumber"; Type = "String"; GraphProperty = "faxNumber"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "GivenName"; Type = "String"; GraphProperty = "givenName"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "HomeStreetAddress"; Type = "String"; GraphProperty = $null; CustomSecurityAttribute = "HomeStreetAddress"; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "HomeCity"; Type = "String"; GraphProperty = $null; CustomSecurityAttribute = "HomeCity"; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "HomeState"; Type = "String"; GraphProperty = $null; CustomSecurityAttribute = "HomeState"; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "HomePostalCode"; Type = "String"; GraphProperty = $null; CustomSecurityAttribute = "HomePostalCode"; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "Interests"; Type = "String collection"; GraphProperty = "interests"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "IsSecondaryAccount"; Type = "String"; GraphProperty = $null; CustomSecurityAttribute = $null; ExtensionAttribute = "CustomAttribute1" },
    [PSCustomObject]@{ Name = "IsHoxhuntDisabled"; Type = "String"; GraphProperty = $null; CustomSecurityAttribute = $null; ExtensionAttribute = "CustomAttribute2" },
    [PSCustomObject]@{ Name = "JobTitle"; Type = "String"; GraphProperty = "jobTitle"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "ManagerEmailAddress"; Type = "String"; GraphProperty = $null; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "MobilePhone"; Type = "String"; GraphProperty = "mobilePhone"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "OfficeLocation"; Type = "String"; GraphProperty = "officeLocation"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "OtherMails"; Type = "String collection"; GraphProperty = "otherMails"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "PastProjects"; Type = "String collection"; GraphProperty = "pastProjects"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "PersonalMobilePhone"; Type = "String"; GraphProperty = $null; CustomSecurityAttribute = "PersonalMobilePhone"; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "PostalCode"; Type = "String"; GraphProperty = "postalCode"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "PreferredLanguage"; Type = "String"; GraphProperty = "preferredLanguage"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "PreferredName"; Type = "String"; GraphProperty = "preferredName"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "Responsibilities"; Type = "String collection"; GraphProperty = "responsibilities"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "Schools"; Type = "String collection"; GraphProperty = "schools"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "ShowInAddressList"; Type = "Boolean"; GraphProperty = "showInAddressList"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "Skills"; Type = "String collection"; GraphProperty = "skills"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "State"; Type = "String"; GraphProperty = "state"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "StreetAddress"; Type = "String"; GraphProperty = "streetAddress"; CustomSecurityAttribute = $null; ExtensionAttribute = $null },
    [PSCustomObject]@{ Name = "Surname"; Type = "String"; GraphProperty = "surname"; CustomSecurityAttribute = $null; ExtensionAttribute = $null }
)

$profileParameterNames = @($fields.Name)
$boundProfileParameters = @($PSBoundParameters.Keys | Where-Object { $_ -in $profileParameterNames })
$promptAllFields = ($boundProfileParameters.Count -eq 0)

if ([string]::IsNullOrWhiteSpace($UserPrincipalName)) {
    $UserPrincipalName = Read-Host "Enter employee UserPrincipalName"
}

if (-not (Test-ValidEmail -Value $UserPrincipalName)) {
    Write-Host "Invalid UserPrincipalName. Exiting." -ForegroundColor Red
    exit 1
}

Initialize-GraphModule
Connect-MgGraphSessionIfNeeded

# Pull current Graph values.
$graphProperties = @(
    "id", "userPrincipalName", "aboutMe", "birthday", "businessPhones", "city", "companyName", "country", "department",
    "displayName", "employeeHireDate", "employeeLeaveDateTime", "employeeId", "employeeType", "faxNumber", "givenName",
    "interests", "jobTitle", "mobilePhone", "officeLocation", "otherMails", "pastProjects", "postalCode", "preferredLanguage",
    "preferredName", "responsibilities", "schools", "showInAddressList", "skills", "state", "streetAddress", "surname"
)

$currentUser = Get-MgUser -UserId $UserPrincipalName -Property ($graphProperties -join ",") -ErrorAction Stop

# Pull current custom security attributes.
$currentCustom = @{}
try {
    $securityAttrs = Get-MgUserSecurityAttribute -UserId $UserPrincipalName -AttributeSet "HRPersonalData" -ErrorAction SilentlyContinue
    if ($null -ne $securityAttrs -and $null -ne $securityAttrs.AdditionalProperties) {
        foreach ($name in @("CompanyMobilePhone", "EmergencyContactFullName", "EmergencyContactPhone", "HomeStreetAddress", "HomeCity", "HomeState", "HomePostalCode", "PersonalMobilePhone")) {
            if ($securityAttrs.AdditionalProperties.ContainsKey($name)) {
                $currentCustom[$name] = [string]$securityAttrs.AdditionalProperties[$name]
            }
        }
    }
} catch {
    # Non-fatal for read path.
}

# Pull current manager.
$currentManagerEmail = ""
try {
    $managerObj = Get-MgUserManager -UserId $UserPrincipalName -ErrorAction Stop
    if ($null -ne $managerObj -and $null -ne $managerObj.AdditionalProperties -and $managerObj.AdditionalProperties.ContainsKey("userPrincipalName")) {
        $currentManagerEmail = [string]$managerObj.AdditionalProperties["userPrincipalName"]
    }
} catch {
    $currentManagerEmail = ""
}

# Pull current extension attributes only if needed.
$needsExtensionAttributeFlow = $promptAllFields -or ($boundProfileParameters -contains "IsSecondaryAccount") -or ($boundProfileParameters -contains "IsHoxhuntDisabled")
$currentCustomAttribute1 = ""
$currentCustomAttribute2 = ""

if ($needsExtensionAttributeFlow) {
    Initialize-ExchangeOnlineModule
    Connect-ExchangeOnlineIfNeeded

    try {
        $exoUser = Get-User -Identity $UserPrincipalName -ErrorAction Stop
        $currentCustomAttribute1 = [string]$exoUser.CustomAttribute1
        $currentCustomAttribute2 = [string]$exoUser.CustomAttribute2
    } catch {
        Write-Host "Could not read current extension attributes for $UserPrincipalName: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$graphUpdates = @{}
$customSecurityUpdates = @{}
$extensionUpdates = @{}
$changedFields = @()

foreach ($field in $fields) {
    $fieldName = $field.Name
    $wasBound = $PSBoundParameters.ContainsKey($fieldName)

    if (-not $promptAllFields -and -not $wasBound) {
        continue
    }

    $providedValue = Get-Variable -Name $fieldName -ValueOnly
    $needsPromptForMissingValue = $false

    if ($promptAllFields) {
        $needsPromptForMissingValue = $true
    } else {
        if ($wasBound) {
            if ($null -eq $providedValue) {
                $needsPromptForMissingValue = $true
            } elseif (($field.Type -eq "String" -or $field.Type -eq "DateTimeOffset" -or $field.Type -eq "String collection") -and [string]::IsNullOrWhiteSpace([string]$providedValue)) {
                $needsPromptForMissingValue = $true
            }
        }
    }

    $currentValue = $null
    if ($field.GraphProperty) {
        $currentValue = $currentUser.$($field.GraphProperty)
    } elseif ($field.CustomSecurityAttribute) {
        $currentValue = if ($currentCustom.ContainsKey($field.CustomSecurityAttribute)) { [string]$currentCustom[$field.CustomSecurityAttribute] } else { "" }
    } elseif ($field.ExtensionAttribute -eq "CustomAttribute1") {
        $currentValue = $currentCustomAttribute1
    } elseif ($field.ExtensionAttribute -eq "CustomAttribute2") {
        $currentValue = $currentCustomAttribute2
    }

    if ($fieldName -eq "ManagerEmailAddress") {
        $currentValue = $currentManagerEmail
    }

    $finalValue = $null
    $changed = $false

    if ($needsPromptForMissingValue) {
        $initialDisplay = ""
        $initialCursor = -1

        if ($field.Type -eq "String collection") {
            $initialDisplay = Convert-ArrayToStringCollectionLiteral -Value $currentValue
            if ($initialDisplay -eq "[\"\"]") {
                $initialCursor = 2
            }
        } elseif ($field.Type -eq "Boolean") {
            if ($null -eq $currentValue) {
                $initialDisplay = ""
            } else {
                $initialDisplay = ([bool]$currentValue).ToString()
            }
        } else {
            $initialDisplay = if ($null -eq $currentValue) { "" } else { [string]$currentValue }
        }

        while ($true) {
            try {
                $promptResult = Read-EditableInput -Prompt $fieldName -InitialText $initialDisplay -InitialCursorIndex $initialCursor

                if ($promptResult.Skipped) {
                    $changed = $false
                    break
                }

                $raw = $promptResult.Text
                if ($raw -eq $initialDisplay) {
                    $changed = $false
                    break
                }

                $finalValue = Validate-AndConvertFieldValue -FieldName $fieldName -FieldType $field.Type -InputValue $raw
                $changed = $true
                break
            } catch {
                Write-Host "Please re-enter $fieldName." -ForegroundColor Yellow
            }
        }
    } else {
        try {
            $finalValue = Validate-AndConvertFieldValue -FieldName $fieldName -FieldType $field.Type -InputValue $providedValue
            $changed = $true
        } catch {
            Write-Host "Provided value for $fieldName is invalid. Exiting." -ForegroundColor Red
            exit 1
        }
    }

    if (-not $changed) {
        continue
    }

    if ($fieldName -eq "ManagerEmailAddress") {
        $changedFields += $fieldName
        if ([string]::IsNullOrWhiteSpace([string]$finalValue)) {
            Remove-MgUserManagerByRef -UserId $UserPrincipalName -ErrorAction SilentlyContinue
        } else {
            $managerUser = Get-MgUser -UserId ([string]$finalValue) -Property Id -ErrorAction Stop
            $managerODataId = "https://graph.microsoft.com/v1.0/users/$($managerUser.Id)"
            Set-MgUserManagerByRef -UserId $UserPrincipalName -BodyParameter @{ "@odata.id" = $managerODataId } -ErrorAction Stop
        }

        continue
    }

    if ($field.CustomSecurityAttribute) {
        $customSecurityUpdates[$field.CustomSecurityAttribute] = if ([string]::IsNullOrWhiteSpace([string]$finalValue)) { $null } else { [string]$finalValue }
        $changedFields += $fieldName
        continue
    }

    if ($field.ExtensionAttribute) {
        if ($field.ExtensionAttribute -eq "CustomAttribute1") {
            $extensionUpdates["CustomAttribute1"] = if ([string]::IsNullOrWhiteSpace([string]$finalValue)) { $null } else { [string]$finalValue }
        } elseif ($field.ExtensionAttribute -eq "CustomAttribute2") {
            $extensionUpdates["CustomAttribute2"] = if ([string]::IsNullOrWhiteSpace([string]$finalValue)) { $null } else { [string]$finalValue }
        }

        $changedFields += $fieldName
        continue
    }

    # Graph standard fields
    if ($field.GraphProperty) {
        if ($field.Type -eq "String collection") {
            if ($fieldName -eq "OtherMails") {
                foreach ($mail in @($finalValue)) {
                    if (-not [string]::IsNullOrWhiteSpace($mail)) {
                        if ($mail.Length -gt 250) {
                            Write-Host "OtherMails value '$mail' exceeds 250 characters. Exiting." -ForegroundColor Red
                            exit 1
                        }
                        if (-not (Test-ValidEmail -Value $mail)) {
                            Write-Host "OtherMails value '$mail' is not a valid email format. Exiting." -ForegroundColor Red
                            exit 1
                        }
                    }
                }

                if (@($finalValue).Count -gt 250) {
                    Write-Host "OtherMails supports up to 250 values. Exiting." -ForegroundColor Red
                    exit 1
                }
            }

            $graphUpdates[$field.GraphProperty] = @($finalValue)
        } elseif ($field.Type -eq "Boolean") {
            if ($null -eq $finalValue) {
                $graphUpdates[$field.GraphProperty] = $null
            } else {
                $graphUpdates[$field.GraphProperty] = [bool]$finalValue
            }
        } else {
            $graphUpdates[$field.GraphProperty] = if ([string]::IsNullOrWhiteSpace([string]$finalValue)) { $null } else { [string]$finalValue }
        }

        $changedFields += $fieldName
    }
}

if ($changedFields.Count -eq 0) {
    Write-Host "No changes were made." -ForegroundColor Yellow
    exit 0
}

# Submit Graph profile updates.
if ($graphUpdates.Count -gt 0) {
    Update-MgUser -UserId $UserPrincipalName -BodyParameter $graphUpdates -ErrorAction Stop | Out-Null
}

# Submit custom security attribute updates.
if ($customSecurityUpdates.Count -gt 0) {
    Set-CustomSecurityAttributes -UserId $UserPrincipalName -Attributes $customSecurityUpdates
}

# Submit Exchange extension attribute updates.
if ($extensionUpdates.Count -gt 0) {
    if (-not $needsExtensionAttributeFlow) {
        Initialize-ExchangeOnlineModule
        Connect-ExchangeOnlineIfNeeded
    }

    $setUserParams = @{ Identity = $UserPrincipalName }
    if ($extensionUpdates.ContainsKey("CustomAttribute1")) { $setUserParams["CustomAttribute1"] = $extensionUpdates["CustomAttribute1"] }
    if ($extensionUpdates.ContainsKey("CustomAttribute2")) { $setUserParams["CustomAttribute2"] = $extensionUpdates["CustomAttribute2"] }

    Set-User @setUserParams -ErrorAction Stop | Out-Null
}

Write-Host "" 
Write-Host "SUCCESS" -ForegroundColor Green
Write-Host "Updated user: $UserPrincipalName" -ForegroundColor Green
Write-Host "Changed fields:" -ForegroundColor Cyan
foreach ($name in ($changedFields | Sort-Object -Unique)) {
    Write-Host "  - $name" -ForegroundColor White
}
