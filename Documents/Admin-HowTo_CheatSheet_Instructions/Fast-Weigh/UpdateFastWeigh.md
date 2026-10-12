# 🔄 Updating Fast-Weigh

This guide explains how to download and install a Fast-Weigh update, including the required full uninstall and reinstall when moving from v5.0 to v5.1 or higher.

---

## ✅ Before You Begin

- Confirm the site's existing Fast-Weigh version and the version you intend to install. There are specific actions that must be performed when updating between specific versions, so please review those provisions prior to upgrading.
- Schedule the update during a maintenance window.
- For each site you plan to update, contact Fast-Weigh support and ask them to update that site's maximum version code.
  - The site-specific installer download link is limited to the version Fast-Weigh support has marked as eligible for that location.
  - Normal portal admins cannot change this version code.
- While installers are not site-specific (since you must input the sync config API key during set up), it probably is not a great idea to update a site with an installer downloaded for another site without having support update that site's version code on the back-end first.

---

## 📥 Download the Installer

1. Open the [Fast-Weigh portal](https://portal.fast-weigh.com).
2. Navigate to **Admin Panel > [Sync Configs](https://portal.fast-weigh.com/SyncConfig#)** .
3. Under the **Win** column, click **Download**.
   - The installer offered is based on the maximum version code configured for that site.

> **Important:** Fast-Weigh updates can have version-specific requirements. Check with Fast-Weigh support if you are unsure whether an in-place update is supported or whether additional steps are required.

---

## ⚠️ Updating from v5.0 to v5.1 or Higher

When moving from v5.0 to v5.1 or higher, completely uninstall and reinstall Fast-Weigh. Do not perform this as a standard in-place update.

### Before Uninstalling

1. Download the updated installer from **Admin Panel > Sync Configs** in the [Fast-Weigh portal](https://portal.fast-weigh.com/SyncConfig#)
2. In the local Fast-Weigh instance, open **Server Settings** and:
   - Run a **Full Sync**
   - Select **Save Config > To Portal**
3. Manually record the following values which are not saved/restored with the config:
   - **Next Ticket Number**
   - **Ticket Printer**/**Cash Printer** assignments for each lane

### Uninstall and Reinstall

1. Run `uninstall.exe` from the Fast-Weigh **Program Files** directory
2. After the uninstall completes, delete the Fast-Weigh **Program Files** directory (should contain a single file which is safe to delete)
3. In the portal, go to **Admin Panel > Sync Configs** and copy the Sync Config API key for the site you are updating
4. Run the updated installer, paste the API key when prompted, and continue the installation
5. Hard refresh the browser on the local Fast-Weigh instance
6. Log in and set a new PIN (previous local PIN assigment was deleted)

### Restore and Validate Configuration

In the local Fast-Weigh instance, open **Server Settings** and perform the following:
1. Click **Full Sync** and wait for it to finish
2. Click **Refresh Reports**
3. Click **Load Config > From Portal**
4. Set **Next Ticket Number** to the value recorded before uninstalling
5. For each lane, restore the **Ticket Printer** and **Cash Printer** assignments recorded before uninstalling
6. Confirm the lanes and reports are working as expected

---

## 📝 Notes

- Other version transitions may have their own special requirements. Confirm the correct procedure with Fast-Weigh support before updating.
- Proceed with caution if using a more up-to-date site's installer without having support first update the site's max version property.
