<div style="text-align: center;">
<h1>Employee Termination IT Checklist</h1>
</div>

# Manager Inquiries

## :speech_balloon:Do you want to convert the employee’s mailbox to a Shared Mailbox?

### Shared Mailbox Features
- Access employee emails via your Outlook app
- Continue receiving emails sent to the employee’s address
- Send emails from the employee’s address (if authorized)
- Set up automatic replies

**Note:** Employee emails are stored for 10 years and can be accessed if needed, even without a Shared Mailbox.

### If setting up a Shared Mailbox:

:speech_balloon:**Do you want to send an automatic reply to all incoming emails?**

The manager can customize this default template if desired:

> Thank you for contacting **\[Company Name]**. We regret to inform you that **\[Terminated Employee Full Name]** is no longer employed here. Please direct any future correspondence to **\[Manager Full Name]** at **\[Manager Email Address]**.  
>  
> This is an automated reply. For your convenience, this email has been automatically forwarded to **\[Manager Full Name]**.

:speech_balloon:**Would you like this automatic reply to be sent to everyone or only company email addresses?**

If the manager needs help using the Shared Mailbox, they can reach out to [Jordan](mailto:jordan@karst.com) or [Ian](mailto:ian@texmix.com).

## :speech_balloon:Do you need access to the employee’s OneDrive files?

If the manager requests access to the employee's OneDrive files, they will receive an email informing them they have access to the employee's files for a duration of 10 years. Toward the end of this period, they will receive another email advising them to copy the files to their own OneDrive if they need to keep the files.

**Note:** Employee OneDrive files are stored for 10 years and can be accessed if needed, even if the manager declines immediate access to the files.

## :speech_balloon:What accounts, services, or licenses need to be deleted for the user?

For a list of examples, see the [Services](#services) section below.

## :speech_balloon: What company equipment did the employee have and has it been recovered?

For a list of examples, see the [Company Equipment](#company-equipment) section below.

# Device Recovery and Service Disconnection

## Company Equipment

Ensure company equipment has been recovered by coordinating with the manager.
- Laptops
- Phones
- Tablets
- Hotspots
- DiagnosticLink

## Mosyle Device Management

If the employee has a company iPhone or iPad that uses Verizon Wireless service.
- Remote wipe the device if it is not immediately recovered
- Unassign the device from the terminated employee
- Rename the device to indicate it is ready to be reassigned (ex: *iPadAir13M2-Unassigned01*)

## Cellular Service

If the employee has a company phone, tablet, or hotspot.
- Unassign/rename the device within the mobile provider's portal to indicate it is ready to be reassigned
- Disconnect service for cellular devices unless the number/service is going to be immediately reused

## Services

Remove employee user accounts/access/licenses on all relevant services.
- [HCSS Equipment 360](https://www.hcss.com)
- [Stonemont](https://www.stonemont.com)
- [Adobe](https://www.adobe.com/acrobat/business/for-admins.html)
- [Samsara](https://www.samsara.com)
- [Reolink](https://reolink.com)
- [Plan Source](https://plansource.com)
- [NetSuite](https://www.netsuite.com/portal/home.shtml)
- [Truckast](https://www.truckast.com)
- [Sales Insight - Sales Quote Tool](https://tmc.readymixinsight.com)
- [ISQFT](https://app.isqft.com)
- [Building Connected](https://app.buildingconnected.com)
- [Virtual Builders Exchange](https://www.virtualbx.com)
- [PlanHub](https://planhub.com)
- [AlertMedia](https://www.alertmedia.com)
- [TeamViewer](https://www.teamviewer.com)
- [ConcreteGo](https://www.concretego.com)
- [Dropbox](https://www.dropbox.com)
- [Fast-Weigh/TacInsight](https://www.fastweigh.com)
- [Verifi](https://www.verifi.com) (Contact [Account Rep](mailto:steve.d.smith@gcpat.com))
- [Staples Business](https://www.staplesadvantage.com)
- [Tableau](https://www.tableau.com) (Talk to [Ian](mailto:ian@texmix.com)/[Taylor](mailto:taylor@texmix.com))
- [Workeasy](https://www.workeasysoftware.com)
- *[there are likely many more services we should note here; please edit the list as needed]*

# Microsoft 365 Tasks

## Block sign-in and reset password

Block the user from signing into their account and reset their password.

### Using web GUI

It may take up to 60 minutes to log the user out of all sessions when using this method.

- Navigate to https://admin.microsoft.com/Adminportal/Home#/users
- Select a user
- Click **Block sign-in**
- Click **Reset password**

### Using PowerShell

The user will be logged out of all sessions immediately when using this method.

```powershell
Connect-MgGraph -NoWelcome -Scopes "User.ReadWrite.All"
$user = "user@domain.com"
Revoke-MgUserSignInSession -UserId $user

# Generate Random Password
$pass = -join(48..57+65..90+97..122|ForEach-Object{[char]$_}|Get-Random -C 14)
Update-MgUser -UserId $user -PasswordProfile @{Password = $pass; ForceChangePasswordNextSignIn = $true}
Write-Host "Password for user ${user} has been reset to ${pass}"
```

## Wipe devices

Remote wipe Intune-managed devices if local/non-OneDrive data does not need to be recovered.

*   Navigate to [Microsoft Intune Admin Center](https://intune.microsoft.com/%23view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/overview)
*   Select the user's device and then click **Wipe**

## Reassign group roles

Reassign SharePoint group roles to someone else if the user is the owner/manager of any SharePoint groups.  
[Microsoft 365 Admin Center](https://admin.microsoft.com/Adminportal/Home%23/users)

## Generate OneDrive sharing report

Generate a OneDrive sharing report for the user to verify that they are not hosting files or folders currently accessed by other employees. In certain cases, a user may share a directory that serves as a common repository for multiple staff members. If such a user is removed, those employees could lose access to important files. Please follow the instructions below to create a CSV file listing all files and folders shared by the departing employee:

- Navigate to [Microsoft 365 Admin Center](https://admin.microsoft.com/Adminportal/Home%23/users)
- Select the relevant user
- Navigate to the **OneDrive** tab
- Click **Create link to files** under **Get access to files**
- Click the generated link
- Click the settings cog in the top right-hand corner of the page
- Click "OneDrive settings"
- Click "More Settings"
- Click "Run sharing report" under "Manage Access"
- Choose a folder to save the report to and click the "Save" button
- Click the back button in your web browser until you get back to the user's files
- Navigate to the folder you saved the report to
- Refresh the page intermittently until the report appears
    *   It may take minutes or hours to generate the report depending on the size of the OneDrive. You should receive an email when the report is finished generating.

Review the report to identify potentially significant shared files or directories that may be serving as repositories for multiple users. Consult with employees regarding access to these files and directories and confirm whether continued access is required. If only a single user needs access, consider transferring the files to their OneDrive; if the files are shared among a group, evaluate the option of migrating them to SharePoint to facilitate collaborative use.

## Retain data

**Note:** Setting a litigation hold on the user's mailbox prevents completion of the "Delete user" workflow which is used to convert the user's mailbox to a Shared Mailbox and remove all licenses from the account. An #ediscoveryhold should be implemented instead. This will retain the user's mailbox/OneDrive data using Microsoft Purview.

**(No longer recommended)**  
**Set a litigation hold on the user’s mailbox** for 3650 days (10 years) to ensure retention for discovery purposes, regardless of account deletion actions. Messages are held from the date they were received or created, not from when the hold was set. This process complements the retention policy in Microsoft Purview and preserves data for potential legal proceedings.

### Using PowerShell

```powershell
# Ensure the ExchangeOnlineManagement PowerShell module is installed
Install-Module -Name ExchangeOnlineManagement -Force

# Authenticate with Exchange online
Connect-ExchangeOnline

# Set the litigation hold
Set-Mailbox "user@domain.com" -LitigationHoldEnabled $true -LitigationHoldDuration 3650
```

### Using web GUI

*   **Navigate to** <https://admin.microsoft.com/Adminportal/Home%23/users>
*   **Select the relevant user**
*   **Navigate to the "Mail" tab**
*   **Click "Manage litigation hold"** under "More actions"
*   **Check the "Turn on litigation hold" checkbox**
*   **Set the "Hold duration (days)" value to "3650"** (10 years)
*   **Click the "Save changes" button**

<a name="eDiscoveryHold"></a>**(Recommended)**  
**Set an eDiscovery hold policy on the user’s OneDrive and mailbox.** This step may not be strictly necessary since the user’s OneDrive can be recovered for 10 years from the data of deletion (this was changed from the default of 30 days to 10 years using the PowerShell command `Set-SPOTenant -OrphanedPersonalSitesRetentionPeriod 3650`), but due to *Litigation Holds* no longer being recommended, **this step should be performed for all terminated employees**.

Note: This will also implement an eDiscovery hold on the user’s mailbox, OneDrive, and Teams messages. Performing this process makes it easy to search a user's account for specific content which could be especially useful for enforcement or legal proceedings.

### Using PowerShell

Use the **<https://github.com/lahma0/KarstUtilityScripts/blob/main/M365/Compliance/New-eDiscoveryHold.ps1>** script located in the **<https://github.com/lahma0/KarstUtilityScripts/tree/main>** repo to quickly create an eDiscovery hold for the user:

`KarstUtilityScripts > M365 > Compliance > New-eDiscoveryHold.ps1`

### Using web GUI

*   **Navigate to** <https://purview.microsoft.com/ediscovery/casespage> and **click the "Create case" button**
*   **Enter a name** in the format of "Termination - Retain data for <mailto:user@domain.com>"
*   **Enter a brief description** describing why the data needs to be retained
*   **Click the "Create" button**
*   **Navigate to the "Hold policies" tab** and **click the "New policy" button**
*   **Enter a name** such as "Retain OneDrive data"
*   **Enter a brief description**
*   **Click "Add sources"**
*   **Search for the user**, **click the checkbox next to their name**, and **click the "Manage" button** (leave everything else default: Scope items by "All sources in the tenant", Show for "All people and groups", Locations to include "Mailboxes and sites")
*   **Ensure "Mailboxes" and "Sites" are checked** next to the username and then **click the "Save" button**
*   **Click "Apply hold"** without adding any additional conditions in the "Condition builder"

## Account deletion/conversion

The account deletion process involves a series of guided steps within the Microsoft 365 Admin Center. These steps apply whether the account is being deleted or converted into a Shared Mailbox. Follow the appropriate steps based upon the manager's instructions.

*   **Navigate to** <https://admin.microsoft.com/Adminportal/Home%23/users>
*   **Choose the user and click "Delete user"**
*   **Select the "Make their email aliases available immediately" checkbox**
*   **Select the "Give another user access to this user's OneDrive files for 30 days after the user is deleted" checkbox** if the manager requests access to an employee's OneDrive files. Select the manager's account in the textbox that appears. Please note that although this option indicates a 30-day access period, the default value has been updated to 3,650 days (10 years).
*   **Select the "Give another user access to this user's email" checkbox** if the manager requests the mailbox to be converted to a Shared Mailbox
    *   After checking the item, **click the new link that appears: "Required: Give email access to another user"**

    *   **Select the manager's account and click the "Next" button**

    *   **Select "Create a new display name" and enter a display name** in the following format:
        $$
        Manager Full Name] for \[Terminated Employee Full Name] (Retired)
        $$

    *   **Click the "Next" button**

    *   If the manager wanted an automatic reply configured, **check the "Send automatic replies" checkbox and enter the customized message** supplied by the manager. If the manager did not provide a customized reply, but did want an automatic reply sent, customize the message according to this template:

        > Thank you for contacting \[Company Name]. We regret to inform you that \[Terminated Employee Full Name] is no longer employed here. Please direct any future correspondence to \[Manager Full Name] at \[Manager Email Address].
        >
        > This is an automated reply. For your convenience, this email has been automatically forwarded to \[Manager Full Name].

    *   **Select the "Email from people inside and outside your organization" option** unless the manager specified that automatic responses should only be sent to people within the organization

    *   **Click the "Next" button**

    *   If the employee has email aliases, you'll be asked whether to delete any of them. Only remove aliases if the manager requests it. **Click the "Next" button**

    *   Review the options and **click the "Transfer ownership" button**

    *   If someone has delegate access to the employee's mailbox, they'll be listed under the "Remove delegate access from their mailbox" checkbox. Confirm with the user and manager before removing access and then check the box. **Click the "Assign and convert" button**

    *   Review the final details and **click the "Close" button**

If you delegated access to the user's OneDrive, the manager should get an email with the employee's OneDrive link, but this can take a long time or may not happen at all. It's probably best to just send the link yourself:  
<https://tmconcrete-my.sharepoint.com/personal/email_domain_tld/>  
(e.g., <https://tmconcrete-my.sharepoint.com/personal/jordan_karst_com/>)

## Schedule a follow-up

After converting a user's mailbox to a Shared Mailbox, check with the manager in 6 months about continued access. If needed, check again in another 6 months; if not, #\_delete\_a\_shared.

# Additional Information

## <a name="_Delete_a_Shared"></a>Delete a Shared Mailbox and stop automatic replies

*   Navigate to <https://admin.microsoft.com/Adminportal/Home?#/SharedMailbox>
*   Click the checkbox next to the name of the Shared Mailbox
*   Click the "Delete shared mailbox" button

## Restore a deleted user's OneDrive

This process can be used to recover a deleted user's entire OneDrive. Recovery can be performed within a specified number of days after account deletion, with this parameter being defined within the SharePoint Admin Center:  
<https://tmconcrete-admin.sharepoint.com/_layouts/15/online/AdminHome.aspx?modern=true#/settings>

By default, the recovery period is set to 30 days, but it was modified to 3650 days (10 years) in June of 2025.

This procedure operates independently from the retention policies established within Microsoft Purview. The retention policies in Microsoft Purview serve as a final measure to retain data for a specified duration. Purview retention policies only preserve files, excluding any directory information. In contrast, the retention policy configured in the SharePoint Admin Center retains both directory and file information comprehensively.

Follow these steps to recover a deleted user's OneDrive using the PowerShell SharePoint Online Management Shell:

*   Check if the SharePoint Online Management Shell is already installed:

```powershell
Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ListAvailable | Select Name,Version
```

*   If it is not installed yet, open PowerShell as admin and install it:

```powershell
Install-Module -Name Microsoft.Online.SharePoint.PowerShell
```

*   Finally, run this script, noting the comments which describe which values need to be modified:

```powershell
# Import the SharePoint Online Management Shell module (if using Powershell 7, you must include the '-UseWindowsPowerShell' switch at the end of the command)
Import-Module Microsoft.Online.SharePoint.PowerShell

# Authenticate to the SharePoint service
Connect-SPOService -Url "https://tmconcrete-admin.sharepoint.com"

# Retrieve the deleted OneDrive: change 'user_domain_com' to match whichever user you're trying to retrieve. i.e. 'jordan_karst_com'
Get-SPODeletedSite -Identity "https://tmconcrete.sharepoint.com/user_domain_com"

# Alternatively, you can get a list of all retained/deleted OneDrive sites and their URLs with this command
# Get-SPODeletedSite -IncludeOnlyPersonalSite | FT url

# If the deleted site exists, restore it
Restore-SPODeletedSite -Identity "https://tmconcrete.sharepoint.com/user_domain_com"

# Assign an administrator to the OneDrive to access the needed data
Set-SPOUser -Site "https://tmconcrete.sharepoint.com/user_domain_com" -LoginName "admin@domain.com" -IsSiteCollectionAdmin $True
```

## Recover a deleted user's mailbox

A deleted user's mailbox will be retained for the period specified in the Exchange retention policy in Microsoft Purview (currently 10 years). To recover a deleted user's entire mailbox, navigate to Microsoft Purview's Inactive Mailboxes page, select a user, and click "Export."  
<https://purview.microsoft.com/datalifecyclemanagement/inactivemailbox>

## Set the default retention period for a deleted user’s OneDrive

By default, a deleted user’s OneDrive is retained for 30 days before being sent to the recycling bin (at which point it will be deleted after 93 days). We have already modified this value to 3650 days (10 years). To modify this value, use the following PowerShell script:

```powershell
# Ensure the ExchangeOnlineManagement PowerShell module is installed
Install-Module -Name ExchangeOnlineManagement -Force

# Authenticate with Exchange online
Connect-ExchangeOnline

# Set the orphaned site retention period (this example sets it to 3650 days)
Set-SPOTenant -OrphanedPersonalSitesRetentionPeriod 3650
```
