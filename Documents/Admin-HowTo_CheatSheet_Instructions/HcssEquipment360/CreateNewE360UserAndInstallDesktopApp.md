# HCSS Equipment 360: Create a User and Install the Desktop App

This guide covers creating an HCSS Equipment 360 employee and user account, assigning the user an appropriate role, and setting up the Equipment 360 (E360) Remote Desktop app on a Windows laptop.

---

## ✅ Prerequisites

- Access to the HCSS employee setup page, user administration page, and the local E360 desktop app.
- The user's first and last name, mobile phone number, email address, company/business unit, and job responsibilities.
- A comparable existing E360 account to use as a reference for permissions and roles.
- **For managers who need the desktop E360 app:** request a local domain account from Ian before configuring the laptop. Ian will provide the username (for example, `texmix\jdoe`) and a randomly generated password.
  - Send the domain credentials to Jordan using an approved secure method so they can be saved in the company password manager. Do not send or store the password in this document.
  - Add the manager to the **Cloudflare Equipment360** group in Entra.
- **Technicians do not require the local domain account or Cloudflare Equipment360 group for this setup.**

> **Important:** Assign only the business units and security roles required for the user's job. Use a similar user's account as a reference, and ask before assigning the Administrator role.

---

## 👤 Step 1: Create the Employee Profile

1. Open the [HCSS Employee Setup page](https://setups.hcssapps.com/employee).
2. Find the largest existing value in the **Code** column. Add 1 to that value to determine the new employee's code.
   - Keep any leading zeroes when entering the code (for example, `0092`).
3. Click **Add Employee**.
4. Enter the employee's **Code**, **First Name**, **Last Name**, **Mobile Phone**, and **Email**.
5. For **Associated Products**, select **Safety**.
6. Under **Business Units**, select the appropriate company.
   - Click **Add** if the employee needs access to multiple companies.
   - Select **AMS** only if the employee needs access to all companies.
7. Click **Add** to save the employee profile.
8. Record the employee code; you will need it when creating the HCSS user account and linking the employee in the E360 desktop app.

---

## 🔐 Step 2: Create the HCSS User Account

1. Open the [HCSS User Administration page](https://hcssapps.com/rs/Users/dddbb5f4-f086-47d9-a6a4-ffa8459f1ae7).
2. Find a user with similar responsibilities and permissions. Use this account as a reference for the new user's access.
3. Click **Add User**.
4. Enter the user's details:
   - **User ID:** `FirstNameLastName` (for example, `JohnSmith`).
   - **First Name**, **Last Name**, **Email**, and **Phone Number**.
   - Select the user's preferred **Contact Method**.
   - Check **Allow Phone Number Login**.
5. Choose the **Subscription Group**:
   - **Technicians** for a mechanic.
   - **All Access Group** for a manager.
   - The purpose of **My Field Users** is currently unclear; confirm before assigning it.
6. Under **Business Unit Access**, click **Select Business Units** and choose the company or companies the user needs.
   - Select **All Business Units** only for a high-level manager or executive who needs access to every company.
7. Select the user's **Home Business Unit**. If only one business unit is assigned, it may be the only available choice.
8. For **Employee Code**, select the code created in Step 1.
9. Click **Save** at the top of the page.

HCSS will send the user an email or SMS with instructions to set up their account, based on the selected **Contact Method**.

---

## 🖥️ Step 3: Add the Employee and User to the E360 Desktop App

1. Open the E360 desktop app on your local machine and sign in if needed.
2. In the top-right corner, click the network-shaped icon (one computer branching to two computers).
3. Select the user's **Home Business Unit**, then click **Yes** in the confirmation dialog.
4. In the top menu, click **Setup** > **Employee**.
5. In the left-hand menu, under **Employee Setup**, click **Employees**.
6. Enter the new employee in the blank row at the top:
   - **Code:** the employee code created in Step 1.
   - **First Name** and **Last Name**.
   - **Types:** choose the appropriate types. Use a similar employee as a reference; generally choose **Mechanic** for mechanics and **Foreman** for managers.
   - **Pay Class:** choose **Mechanic** for a mechanic; choose **None** for others.
7. Click **Save**.
8. In the left-hand menu, expand **Security Setup**, then click **User Accounts**.
9. Click **New** at the top of the page.
10. Link the account and employee:
    - Click the dropdown next to **HCSS App Login** and select the new user's username.
    - Click the dropdown next to **Employee** and select the employee entry, matching the code and name.
11. Click the dropdown next to **Roles** and select the appropriate role or roles. Use a similar employee as a reference. Common role recommendations:
    - **Mechanic:** `Mobile Mechanic`, `E360 Field Mechanic`
    - **Lead mechanic:** `Mobile Mechanic`, `E360 Field Mechanic`, `Lead Mechanic`
    - **Equipment manager or shop coordinator:** `E360 Field Mechanic`, `Equipment Manager`, `Lead Mechanic`, `Mobile Mechanic`
    - **Area manager:** `Area Manager`
    - **General manager:** `General Manager`
    - **Administrator:** `Administrator` — very few people should have this role. If unsure, ask first.
12. Click **Save** in the dialog. If required, click **Save** again at the top of the page.
13. Close the E360 desktop app.

---

## 🌐 Step 4: Install and Connect Cloudflare One (WARP)

Complete this step for a manager who needs the E360 desktop app.

1. Check whether **Cloudflare One** (also called **WARP**) is installed, joined to the team, and up to date.
2. If it is not installed, open an administrator PowerShell terminal and run:

   ```powershell
   winget install Cloudflare.Warp
   ```

3. If Cloudflare One was already installed, verify the team:
   - Open Cloudflare One settings and go to **Profile**.
   - Under **Account Information**, confirm the team is **tex-mix**.
   - If it is not joined to the correct team, continue with the next step.
4. To join the team, open Cloudflare One. Under **Cloudflare One Client**, click **Continue**.
5. At **What is your team name**, enter `tex-mix`.
6. When the browser opens for authentication, click **Azure AD** and authenticate using the user's work account.
   - Do not type the user's email address into the email-address textbox on the authentication page.
   - If the browser asks to open the Cloudflare One client, enable the option to always open links of this type, then click **Open**.
7. Confirm Cloudflare One opens and shows that it is successfully connected.

---

## 🔑 Step 5: Save the Domain Credentials in Windows Credential Manager

Complete this step for a manager who needs the E360 desktop app.

1. Click **Start** and search for **Credential Manager**.
2. Open **Credential Manager**, then click **Windows Credentials**.
3. Click **Add a generic credential**.
4. Enter the following:
   - **Internet or network address:** `TERMSRV/10.147.18.204`
   - **User name:** the domain username Ian provided (for example, `texmix\jdoe`)
   - **Password:** the randomly generated domain password Ian provided
5. Click **OK**.

---

## 📦 Step 6: Install the E360 RDP App and Shortcuts

1. Sign in to the Windows account that will use E360.
2. Open PowerShell as that user. **Do not run this command as administrator.**
3. Confirm `https://bit.ly/e360launcher` is the current, company-approved E360 launcher link before proceeding. This command downloads and executes remote PowerShell code; stop if the link is not recognized or redirects unexpectedly.
4. Run the E360 launcher:

   ```powershell
   irm https://bit.ly/e360launcher | iex
   ```

5. When prompted, choose **Mechanic**, **Manager**, or **Both**, as appropriate.
6. When prompted for shortcut locations, choose **Desktop**, **Start Menu**, or **Both**.
7. Follow any remaining prompts until the installer completes.

---

## ✅ Step 7: Validate the Setup

1. Open each shortcut that was installed and confirm the E360 RDP app connects successfully.
2. If prompted to trust or allow the remote connection file, select the option to always allow or trust it.
3. If prompted to choose which local resources the remote session can access, select at least **Storage** and **Clipboard**.
4. Confirm the user can sign in to E360 and has the expected business unit and role access.
5. Confirm Cloudflare One remains connected for the manager's desktop app access.