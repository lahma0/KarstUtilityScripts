# 🧭 Migrate Local Domain-Joined Windows Profile to Entra ID (Intune)

This guide documents a streamlined process for migrating older domain-joined Windows 10 endpoints to Windows 11 and moving user sign-in from local Active Directory to Microsoft Entra ID (Intune).

The process keeps the user's existing Windows profile, including:

- Installed applications
- User settings
- Local files
- App data

This avoids rebuilding a user profile from scratch.

---

## ✅ Prerequisites

- Device is upgraded to Windows 11.
- You have local administrator access on the device being migrated.
- You can run PowerShell on a separate admin workstation.
- User UPN (work email) is known.
- Script file [Save-AzureADUser.ps1](Save-AzureADUser.ps1) is available.

---

## 🛠️ Migration Steps

1. Upgrade the target machine to Windows 11.

2. Sign in to the target machine using a local administrator account.

3. Create a Windows restore point on the target machine before continuing.

4. Download ForensiT User Profile Wizard on the target machine:
  - https://www.forensit.com/Downloads/Profwiz.msi

5. Run the MSI.
  - You would expect an MSI to install an application, but this one only extracts 'Profwiz.exe' to the same directory as the MSI.

6. On your admin workstation (not the target machine), run [Save-AzureADUser.ps1](Save-AzureADUser.ps1).
  - The script generates 'ForensiTAzureID.xml' in the same directory.

7. Copy 'ForensiTAzureID.xml' to the target machine into the same folder as 'Profwiz.exe'.

8. Run 'Profwiz.exe' as Administrator, then click Next.

9. In Profiles stored on this computer, select the user's current domain profile, then click Next.

10. In Enter the domain, or select the local computer name:
  - Enter 'tmconcrete.onmicrosoft.com'
  - Check the Azure AD checkbox
  - Click Next

11. In Enter the account name:
  - Enter the user's UPN (work email address)
  - Optionally check 'Set as default logon' (will cause the user's account to be the default selected account on the logon screen after startup)
  - Click Next

12. Wait for migration to complete.
  - When Migration Complete appears, save the log if needed.
  - Click Next.

13. Click Finish and reboot the machine.

---

## 🔎 Post-Migration Validation

- User can sign in using Entra ID credentials (work email).
- User profile data is intact (desktop files, documents, app settings).
- Required business applications still launch correctly.
- Device appears in Intune and applies expected policies.

---

## ⚠️ Notes

- Run this during a maintenance window whenever possible.
- Keep a backup of critical user data before migration.
- If something fails, retain the Profwiz migration log for troubleshooting.