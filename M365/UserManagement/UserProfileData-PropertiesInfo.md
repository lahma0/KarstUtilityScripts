# UserProfileData Properties Reference

This document is the field-by-field reference for the profile properties read by [Get-UserProfileData.ps1](Get-UserProfileData.ps1) and written by [Set-UserProfileData.ps1](Set-UserProfileData.ps1).

> [!CAUTION]
> **Read-only values:** If a property name below is shown in <span style="color:red">red</span>, that value is considered read-only and should not be changed/edited.

> [!NOTE]
> **Multiple company email addresses:** If an employee has multiple company email addresses, please copy/paste the information across all of their individual entries.

## Field Descriptions

| Property | M365 Property Name | Type | Import to M365? | Special Handling | <div style="width:690px">Description</div> |
|---|---|---|---|---|---|
| AboutMe | `aboutMe` | String | Yes | Requires dedicated PATCH request. | A freeform text entry field for the user to describe themselves. It probably doesn't make sense to fill this out for an employee (unless you know them well and they tell you what information they want here), so you can just leave this blank if you want. |
| <span style="color:red">AccountEnabled</span> | `accountEnabled` | Boolean | No | — | `true` if the account is enabled; otherwise, `false`. |
| Birthday | `birthday` | DateTimeOffset | Yes | Requires dedicated PATCH request. | The birthday of the user. Please use the format: <br>`YYYY-MM-DD` |
| BusinessPhones | `businessPhones` | String collection | Yes | — | If the user has a non-mobile, office (desk) phone number, put that number here. Please use the following format: <br>`(###) ###-####` <br>If the number has an extension, please use the following format instead: <br>`(###) ###-#### ext. ###` |
| City | `city` | String | Yes | — | The city of the user's primary business/office/plant address. Maximum length is 128 characters. |
| CompanyName | `companyName` | String | Yes | — | The name of the company that the user is associated with. Examples: `Johnson City Crushed Stone`, `Bastrop Sand Supply`, `Rawhide Trucking`, `Karst Shared Services, LLC` |
| CompanyMobilePhone | — | String | Yes | Custom security attribute: `HRPersonalData.CompanyMobilePhone`. | If the employee has a company-provided cell phone, put that number here. If not, leave blank. If this field is populated, the field `MobilePhone` should be populated with the same value. Please use the following format: <br>`(###) ###-####` |
| Country | `country` | String | Yes | — | The country or region of the user's primary business/office/plant address. Examples: `United States`, `United Kingdom`, `Canada` <br>Please use the country's full name. Maximum length is 128 characters. No abbreviations or 2/3 letter country codes. |
| <span style="color:red">CreatedDateTime</span> | `createdDateTime` | DateTimeOffset | No | — | The date and time the user was created. |
| <span style="color:red">DeletedDateTime</span> | `deletedDateTime` | DateTimeOffset | No | — | The date and time the user was deleted. |
| Department | `department` | String | Yes | — | The name of the department in which the user works. Examples: `Accounting`, `Marketing`, `Human Resources` <br>Maximum length is 64 characters. |
| DisplayName | `displayName` | String | Yes | — | The name displayed in the address book for the user. This value is usually the combination of the user's first name, middle initial, and family name. If the user has a preferred name or nickname they prefer to be identified as, even in business communications, you can change this field. Otherwise, do not modify it. Maximum length is 256 characters. |
| EmergencyContactFullName | — | String | Yes | Custom security attribute: `HRPersonalData.EmergencyContactFullName`. | If the employee has someone listed as their emergency contact, put that individual's full name here. |
| EmergencyContactPhone | — | String | Yes | Custom security attribute: `HRPersonalData.EmergencyContactPhone`. | If the employee has someone listed as their emergency contact, put that individual's phone number here. Please use the following format: <br>`(###) ###-####` <br>If the number has an extension, please use the following format instead: <br>`(###) ###-#### ext. ###` |
| EmployeeHireDate | `employeeHireDate` | DateTimeOffset | Yes | — | The date and time when the user was hired or will start work in a future hire. Please use the following format: <br>`YYYY-MM-DD` |
| EmployeeLeaveDateTime | `employeeLeaveDateTime` | DateTimeOffset | Yes | — | The date and time when the user left or will leave the organization. If the employee is no longer with the company, PLEASE make sure to fill out this field, even if it is only an estimated date. We may use this to determine if we need to delete the user's account. Leave blank if the employee is still employed by the company. Please use the following format: <br>`YYYY-MM-DD` |
| EmployeeId | `employeeId` | String | Yes | — | The employee identifier assigned to the user by the organization. If we have some type of internal identifier for an employee, put that here. If not, leave blank. The maximum length is 16 characters. |
| EmployeeType | `employeeType` | String | Yes | — | Captures enterprise worker type. Examples: `Employee`, `Contractor`, `Consultant`, `Vendor`. Since nearly all of these users are going to be `Employee`, feel free to re-use this field for some other piece of employee categorization information if you want. If you can't think of any other relevant information, either leave it blank or set it to `Employee`. Just be consistent. |
| FaxNumber | `faxNumber` | String | Yes | — | The fax number of the user. Please use the following format: <br>`(###) ###-####`. If the number has an extension, please use the following format instead: <br>`(###) ###-#### ext. ###` |
| GivenName | `givenName` | String | Yes | — | The given name (first name) of the user. Maximum length is 64 characters. |
| HomeStreetAddress | — | String | Yes | Custom security attribute: `HRPersonalData.HomeStreetAddress`. | The employee's home street address. Please use the following format: <br>`Address1, Address2` (Address2 only if applicable). Example: <br>`555 Fake Rd, Unit 5` |
| HomeCity | — | String | Yes | Custom security attribute: `HRPersonalData.HomeCity`. | The employee's home city. |
| HomeState | — | String | Yes | Custom security attribute: `HRPersonalData.HomeState`. | The employee's home state. Please use the state's 2 letter abbreviation. Example: `TX` |
| HomePostalCode | — | String | Yes | Custom security attribute: `HRPersonalData.HomePostalCode`. | The employee's home postal code. Example: `78641` |
| <span style="color:red">Id</span> | `id` | String | No | — | This value is included for technical reasons. |
| Interests | `interests` | String collection | Yes | Requires dedicated PATCH request. | A list for the user to describe their interests. Not required. Please use the following format: <br>`["Interest 1", "Interest 2", "Interest 3"]` |
| IsSecondaryAccount | — | String | Yes | Stored in `onPremisesExtensionAttributes.ExtensionAttribute1`. | `True` if this is a user's secondary, non-primary account; otherwise, `False` (or leave blank).<br>**Note: This property is currently used to disable Hoxhunt training for users' secondary accounts so they do not receive duplicate training across their multiple accounts. See [On Premises Extension Attributes](#on-premises-extension-attributes) in the [Notes](#notes) section for more info.** |
| IsHoxhuntDisabled | — | String | Yes | Stored in `onPremisesExtensionAttributes.ExtensionAttribute2`. | `True` if Hoxhunt training should be explicitly disabled on this account (such as on test accounts); otherwise, `False` (or leave blank).<br>**Note: If `IsSecondaryAccount` is already set to `True`, this value does not need to be set since setting that value already disables Hoxhunt training. See [On Premises Extension Attributes](#on-premises-extension-attributes) in the [Notes](#notes) section for more info.** |
| JobTitle | `jobTitle` | String | Yes | — | The user's job title. Maximum length is 128 characters. |
| ManagerEmailAddress | — | String | Yes | Set via `Set-MgUserManagerByRef`. | The primary company email address of the employee's manager.<br>**Note: See [Custom Cmdlet](#custom-cmdlet) in the [Notes](#notes) section for more info.** |
| MobilePhone | `mobilePhone` | String | Yes | — | The primary cellular telephone number for the user. If they have a company-provided cell phone, this value should be identical to the value in the field `CompanyMobilePhone`. Otherwise, enter their personal cell phone number. This is the number which will be displayed in the user's profile. Please use the following format: <br>`(###) ###-####` |
| OfficeLocation | `officeLocation` | String | Yes | — | A colloquial description of the office location in the user's place of business. For truck drivers, you may just put `Truck Driver`. For office workers you may put `Suite 38` or `Front Desk`. For remote workers you may put `Home`. For mechanics you may put `Johnson City Crushed Stone: Workshop` or `Mobile Mechanic`. Just put whatever makes most sense to you but make sure it is consistent. For example, do not have `Cedar Park Main Office`, `Cedar Park - Main Office`, and `Main Office - Cedar Park`. Pick one style and use it consistently. |
| OtherMails | `otherMails` | String collection | Yes | — | A list of other email addresses for the user. If the user has multiple company email addresses (multiple instances of the same employee in this list with different `UserPrincipalName` values), do not list those other email addresses in this field. Each company email address should have a separate row, even if they are all used by the same person. This field would typically be used for personal email addresses or free email addresses used for company purposes (@outlook.com, @gmail.com, etc.). Please use the format: <br>`["email1@domain.com", "email2@domain.com", "email3@domain.com"]`. <br>Can store up to 250 values, each with a limit of 250 characters. |
| PastProjects | `pastProjects` | String collection | Yes | Requires dedicated PATCH request. | A list for the user to enumerate their past projects. Not required. Please use the following format: <br>`["Past project 1", "Past project 2", "Past project 3"]` |
| PersonalMobilePhone | — | String | Yes | Custom security attribute: `HRPersonalData.PersonalMobilePhone`. | If the employee has a company-provided cell phone and you put that number in `MobilePhone`, put their personal non-company cell phone number here. If the employee does not have a company-provided cell phone, and you put their personal cell phone number in `MobilePhone`, duplicate that same value here. Please use the following format: <br>`(###) ###-####` |
| PostalCode | `postalCode` | String | Yes | — | The postal code for the user's primary business/office/plant address. Maximum length is 40 characters. Example: `78641` |
| PreferredLanguage | `preferredLanguage` | String | Yes | — | The preferred language for the user. The preferred language format is based on RFC 4646. The name is a combination of an ISO 639 two-letter lowercase culture code associated with the language, and an ISO 3166 two-letter uppercase subculture code associated with the country or region. Examples: `en-US`, `es-ES`. |
| PreferredName | `preferredName` | String | Yes | — | This should be the name the person "goes by" or prefers to be called. For example, someone's first name might be Samuel, but they prefer to be called by their middle name Jordan, so that's what you would put here. Another example would be if someone's name is Thomas but they prefer to be called Tommy. |
| Responsibilities | `responsibilities` | String collection | Yes | Requires dedicated PATCH request. | A list for the user to enumerate their responsibilities. Not required but if it is easy to populate, please do so. For example, for mechanics you might put: <br>`["Fix/repair/maintain trucks", "Fix/repair/maintain heavy equipment", "Fix/repair/maintain plant infrastructure"]` <br>Please use the following format: <br>`["Responsibility 1", "Responsibility 2", "Responsibility 3"]` |
| Schools | `schools` | String collection | Yes | Requires dedicated PATCH request. | A list for the user to enumerate the schools they attended. Not required unless relevant. Please use the following format: <br>`["School name 1", "School name 2", "School name 3"]` |
| ShowInAddressList | `showInAddressList` | Boolean | Yes | — | If the user should not show up in the global address list, change this value to `false`. Otherwise `true`. |
| Skills | `skills` | String collection | Yes | Requires dedicated PATCH request. | A list for the user to enumerate their skills. Not required but if it is relevant, this information could be useful. Please use the following format: <br>`["Skill description 1", "Skill description 2", "Skill description 3"]` |
| State | `state` | String | Yes | — | The state or province of the user's primary business/office/plant address. Maximum length is 128 characters. Please use the state's 2 letter abbreviation. Example: `TX` |
| StreetAddress | `streetAddress` | String | Yes | — | The street address of the user's primary business/office/plant address. Maximum length is 1,024 characters. Please use the following format: <br>`Address1, Address2` (Address2 only if applicable) |
| Surname | `surname` | String | Yes | — | The user's surname (family name or last name). Maximum length is 64 characters. |
| <span style="color:red">UserPrincipalName</span> | `userPrincipalName` | String | No | — | This should be the user's company email address. If there appears to be something wrong with this value, make a note of it in the notes section. |

## Notes

### On Premises Extension Attributes

Entries with a value in the `Special Handling` column, prefixed with `Stored in`, are **Exchange Extension Attributes** and are accessed with Microsoft Graph via the `OnPremisesExtensionAttributes` property, with generic names such as `ExtensionAttribute1` and `ExtensionAttribute2`. Since extension attributes only support string values, we are using the strings `True` and `False` (1st letter capitalized and the rest lowercase) to represent boolean values.

#### Retrieve On Premises Extension Attributes

```powershell
(Get-MgUser -UserId "user@domain.com" -Property "id,displayName,onPremisesExtensionAttributes").OnPremisesExtensionAttributes.ExtensionAttribute1
```

#### Set On Premises Extension Attributes

```powershell
$attributes = @{ onPremisesExtensionAttributes = @{ extensionAttribute1 = "True" } }
Update-MgUser -UserId "user@domain.com" -BodyParameter $attributes
```

### Custom Security Attributes

Entries with a value in the `Special Handling` column, prefixed with `Custom security attribute`, are **Entra Custom Security Attributes** and with Microsoft Graph, values are retrieved via the `customSecurityAttributes` property and are set using the `CustomSecurityAttributes` parameter. To read/write this value, the user must be assigned the `Attribute Assignment Administrator` role and use the scopes `CustomSecAttributeAssignment.ReadWrite.All` and `User.Read.All`. To only read this value, the user must be assigned the `Attribute Assignment Reader` role and use the scopes `CustomSecAttributeAssignment.Read.All` and `User.Read.All`.
| :exclamation:  Global Administrators do not have the `Attribute Assignment Administrator` role by default. |
|------------------------------------------------------------------------------------|

#### Retrieve Custom Security Attributes

```powershell
(Get-MgUser -UserId "user@domain.com" -Property "customSecurityAttributes").CustomSecurityAttributes.AdditionalProperties['HRPersonalData']['PersonalMobilePhone']
```

#### Set Custom Security Attributes

```powershell
$attributes = @{ HRPersonalData = @{ PersonalMobilePhone = '(555) 555-5555' } }
Update-MgUser -UserId "user@domain.com" -CustomSecurityAttributes $attributes
```

### Dedicated Patch Request

Entries with a value in the `Special Handling` column, prefixed with `Requires dedicated PATCH request`, are properties which Microsoft Graph require to be updated in their own PATCH request (cannot be set simultaneously with other properties).

### Custom Cmdlet

Entries with a value in the `Special Handling` column, prefixed with `Set via`, cannot be set like normal properties and instead must be set using the specified Microsoft Graph cmdlet.

#### Retrieve Manager Assigned to User

```powershell
(Get-MgUserManager -UserId "user@domain.com").AdditionalProperties.userPrincipalName
```

#### Assign Manager to User

```powershell
$managerODataId = "https://graph.microsoft.com/v1.0/users/$((Get-MgUser -UserId 'manager@domain.com').Id)"
Set-MgUserManagerByRef -UserId "user@domain.com" -BodyParameter @{ "@odata.id" = $managerODataId }
```

