<#
.SYNOPSIS
Gets all profile fields managed by Set-UserProfileData.ps1.

.DESCRIPTION
Retrieves standard Microsoft Graph profile properties, HRPersonalData custom security
attributes, the user's manager, and Hoxhunt extension attributes. The default output is a
PowerShell object. Use -AsJson to emit the complete result as JSON.

.PARAMETER UserPrincipalName
The user's UPN or another Microsoft Graph user identifier. If omitted, the script prompts.

.PARAMETER AsJson
Outputs the profile as JSON instead of a formatted PowerShell object.

.EXAMPLE
.\Get-UserProfileData.ps1 -UserPrincipalName "user@contoso.com"

.EXAMPLE
.\Get-UserProfileData.ps1 -UserPrincipalName "user@contoso.com" -AsJson

.NOTES
Required Graph scopes:
- User.Read.All
- Directory.Read.All
- CustomSecAttributeAssignment.Read.All

The Hoxhunt flags are retrieved through Graph OnPremisesExtensionAttributes.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$UserPrincipalName,

    [Parameter()]
    [switch]$AsJson
)

function Initialize-GraphModules {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
        throw "Microsoft.Graph.Users is not installed. Install Microsoft.Graph first."
    }

    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
}

function Connect-GraphIfNeeded {
    $scopes = @(
        "User.Read.All",
        "Directory.Read.All",
        "CustomSecAttributeAssignment.Read.All"
    )

    $context = Get-MgContext -ErrorAction SilentlyContinue
    $needsConnection = $null -eq $context
    if (-not $needsConnection) {
        foreach ($scope in $scopes) {
            if ($scope -notin @($context.Scopes)) {
                $needsConnection = $true
                break
            }
        }
    }

    if ($needsConnection) {
        Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
    }
}

function Get-AdditionalPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) { return $null }

    # Nested open-type values (e.g. an attribute set's own attributes) can deserialize as a
    # plain dictionary instead of an object with an AdditionalProperties member.
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $null
    }

    $properties = $Object.AdditionalProperties
    if ($null -ne $properties) {
        if ($properties -is [System.Collections.IDictionary]) {
            return $properties[$Name]
        }
        return $properties.$Name
    }

    # Fall back to a direct property in case the value deserialized as a plain PSCustomObject.
    if ($Object.PSObject.Properties.Match($Name).Count -gt 0) {
        return $Object.$Name
    }

    return $null
}

function Get-JsonNodeValue {
    param(
        [AllowNull()]
        [object]$Node,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Node) { return $null }

    if ($Node.PSObject.Properties.Match('AdditionalProperties').Count -gt 0 -and $null -ne $Node.AdditionalProperties) {
        $nested = $Node.AdditionalProperties
        if ($nested.PSObject.Properties.Match($Name).Count -gt 0) {
            return $nested.$Name
        }
    }

    if ($Node.PSObject.Properties.Match($Name).Count -gt 0) {
        return $Node.$Name
    }

    return $null
}

function Get-HrPersonalData {
    param([object]$UserObject)

    $result = [ordered]@{
        CompanyMobilePhone       = $null
        EmergencyContactFullName = $null
        EmergencyContactPhone    = $null
        HomeStreetAddress        = $null
        HomeCity                 = $null
        HomeState                = $null
        HomePostalCode           = $null
        PersonalMobilePhone      = $null
    }

    try {
        # Round-trip through JSON so nested open-type data (attribute sets, then attribute
        # values) is normalized to plain PSCustomObjects regardless of how the SDK deserialized it.
        $customSecurityAttributesJson = $UserObject.CustomSecurityAttributes | ConvertTo-Json -Depth 10 -ErrorAction Stop
        $customSecurityAttributes = $customSecurityAttributesJson | ConvertFrom-Json -ErrorAction Stop
        $hrPersonalData = Get-JsonNodeValue -Node $customSecurityAttributes -Name "HRPersonalData"
        if ($null -ne $hrPersonalData) {
            foreach ($name in @($result.Keys)) {
                $result[$name] = Get-JsonNodeValue -Node $hrPersonalData -Name $name
            }
        }
    } catch {
        Write-Warning "Could not retrieve HRPersonalData: $($_.Exception.Message)"
    }

    return $result
}

if ([string]::IsNullOrWhiteSpace($UserPrincipalName)) {
    $UserPrincipalName = Read-Host "Enter UserPrincipalName"
}

if ([string]::IsNullOrWhiteSpace($UserPrincipalName)) {
    throw "UserPrincipalName is required."
}

Initialize-GraphModules
Connect-GraphIfNeeded

$graphProperties = @(
    "id", "userPrincipalName", "aboutMe", "birthday", "businessPhones", "city", "companyName", "country",
    "department", "displayName", "employeeHireDate", "employeeLeaveDateTime", "employeeId", "employeeType",
    "faxNumber", "givenName", "interests", "jobTitle", "mobilePhone", "officeLocation", "otherMails",
    "pastProjects", "postalCode", "preferredLanguage", "preferredName", "responsibilities", "schools",
    "showInAddressList", "skills", "state", "streetAddress", "surname", "onPremisesExtensionAttributes",
    "customSecurityAttributes"
)

$user = Get-MgUser -UserId $UserPrincipalName -Property ($graphProperties -join ",") -ErrorAction Stop
$hrPersonalData = Get-HrPersonalData -UserObject $user

$managerEmailAddress = $null
try {
    $manager = Get-MgUserManager -UserId $user.Id -ErrorAction Stop
    $managerEmailAddress = Get-AdditionalPropertyValue -Object $manager -Name "userPrincipalName"
} catch {
    Write-Verbose "No manager assigned or manager could not be retrieved: $($_.Exception.Message)"
}

$profile = [ordered]@{
    UserPrincipalName        = $user.UserPrincipalName
    Id                       = $user.Id
    AboutMe                  = $user.AboutMe
    Birthday                 = if ($null -eq $user.Birthday) { $null } else { ([DateTimeOffset]$user.Birthday).ToString("yyyy-MM-dd") }
    BusinessPhones           = @($user.BusinessPhones)
    City                     = $user.City
    CompanyName              = $user.CompanyName
    CompanyMobilePhone       = $hrPersonalData.CompanyMobilePhone
    Country                  = $user.Country
    Department               = $user.Department
    DisplayName              = $user.DisplayName
    EmergencyContactFullName = $hrPersonalData.EmergencyContactFullName
    EmergencyContactPhone    = $hrPersonalData.EmergencyContactPhone
    EmployeeHireDate         = if ($null -eq $user.EmployeeHireDate) { $null } else { ([DateTimeOffset]$user.EmployeeHireDate).ToString("yyyy-MM-dd") }
    EmployeeLeaveDateTime    = if ($null -eq $user.EmployeeLeaveDateTime) { $null } else { ([DateTimeOffset]$user.EmployeeLeaveDateTime).ToString("yyyy-MM-dd") }
    EmployeeId               = $user.EmployeeId
    EmployeeType             = $user.EmployeeType
    FaxNumber                = $user.FaxNumber
    GivenName                = $user.GivenName
    HomeStreetAddress        = $hrPersonalData.HomeStreetAddress
    HomeCity                 = $hrPersonalData.HomeCity
    HomeState                = $hrPersonalData.HomeState
    HomePostalCode           = $hrPersonalData.HomePostalCode
    Interests                = @($user.Interests)
    IsSecondaryAccount       = [string]$user.OnPremisesExtensionAttributes.extensionAttribute1
    IsHoxhuntDisabled        = [string]$user.OnPremisesExtensionAttributes.extensionAttribute2
    JobTitle                 = $user.JobTitle
    ManagerEmailAddress      = $managerEmailAddress
    MobilePhone              = $user.MobilePhone
    OfficeLocation           = $user.OfficeLocation
    OtherMails               = @($user.OtherMails)
    PastProjects             = @($user.PastProjects)
    PersonalMobilePhone      = $hrPersonalData.PersonalMobilePhone
    PostalCode               = $user.PostalCode
    PreferredLanguage        = $user.PreferredLanguage
    PreferredName            = $user.PreferredName
    Responsibilities         = @($user.Responsibilities)
    Schools                  = @($user.Schools)
    ShowInAddressList        = $user.ShowInAddressList
    Skills                   = @($user.Skills)
    State                    = $user.State
    StreetAddress            = $user.StreetAddress
    Surname                  = $user.Surname
}

$output = [PSCustomObject]$profile
if ($AsJson) {
    $output | ConvertTo-Json -Depth 6
} else {
    $output
}
