# 📷 Adding Ubiquiti IP Cameras to Fast-Weigh

This guide explains how to configure a Ubiquiti IP camera (managed by UniFi Protect) for use with Fast-Weigh, and how to assign it to a lane in the local Fast-Weigh instance's server settings. It also covers stitching two cameras together (e.g. a front-facing plate camera and a top-down bed camera) into a single stacked image.

Reference: [Fast-Weigh IP Camera documentation](https://help.tacinsight.com/fast-weigh-knowledge-base/references/hardware/ip-cameras)

---

## ✅ Prerequisites

- Access to the UniFi Network console (to set a fixed IP address).
- Access to the UniFi Protect console (to retrieve the camera's Recovery Code).
- Access to the local Fast-Weigh instance's server settings.
- The camera is already adopted in UniFi Protect and online.

---

## 🌐 Step 1: Set a Fixed IP Address in UniFi Network

1. Open the **UniFi Network** console.
2. Navigate to **Clients** and locate the camera (search by name or MAC address).
3. Select the camera, then open the **Settings** tab (gear icon) for that client.
4. Under **IP Settings**, check the **Fixed IP Address** checkbox.
5. By default, the **IP Address** field is populated with the camera's current IP. Leave the value as-is and click **Apply Changes**.
   - Note down this IP address; you will need it in later steps.

---

## 🔑 Step 2: Retrieve the Camera's Recovery Code in UniFi Protect

1. Open the **UniFi Protect** console.
2. Navigate to **Devices** and select the camera.
3. Open the camera's **Settings** panel.
4. Locate the **Recovery Code** (sometimes listed under device/advanced settings).
   - This code is used as the local admin password when logging into the camera's own web administration page.

---

## 🖥️ Step 3: Log Into the Camera's Web Administration Page

1. Open a web browser and navigate to `https://<camera-ip-address>` using the fixed IP address set in Step 1.
2. The browser will show an SSL/certificate warning because the camera uses a self-signed certificate.
   - Click **Advanced** (or equivalent), then **Proceed to `<camera-ip-address>` (unsafe)** to bypass the warning.
3. Log in using:
   - **Username:** `ubnt`
   - **Password:** the Recovery Code retrieved in Step 2.

---

## 📸 Step 4: Enable Anonymous Snapshots

1. In the camera's web administration page, navigate to the camera's **Settings**.
2. Locate the **Anonymous Snapshots** (or **Anonymous Capture**) option.
3. Enable this setting and save/apply the change.
   - This allows Fast-Weigh to pull snapshot images from the camera without authenticating.

---

## 🧾 Step 5: Add the Camera in Fast-Weigh Server Settings

1. In the local Fast-Weigh instance, open **Server Settings**.
2. Navigate to the **Manage Devices** section.
3. Click **Add Device** and select **IP Camera** (just **Camera** in some versions) in the **Device Type** dropdown to create a new camera entry.
4. For the image capture URL, use the camera's fixed IP address in the Ubiquiti snapshot format:

   ```http
   http://x.x.x.x/snap.jpeg
   ```

   Replace `x.x.x.x` with the camera's fixed IP address from Step 1.
5. Give the camera a descriptive name (e.g. `Scale 1 - Front`) and save.

   Note: You can leave the other settings at their default values.

---

## 🛣️ Step 6: Assign the Camera to a Lane

1. In **Server Settings**, navigate to the **Manage Lanes** section.
2. Select the **Camera** dropdown for the desired lane.
3. Select the name of the camera you just created in the previous step.

---

## 🖇️ Combining Two Cameras Into One Stacked Image

If a lane uses two cameras — for example, a front-facing camera to capture the truck and its license plate, and a top-down camera mounted above to capture the material in the bed — Fast-Weigh can stitch both snapshots into a single top-and-bottom image.

1. Follow Steps 1–4 above for **both** cameras so each has a fixed IP address and Anonymous Snapshots enabled.
2. In **Server Settings > Cameras**, create a single camera entry using both snapshot URLs, comma-separated, with the `fwpos` parameter indicating position:

   ```http
   http://x.x.x.x/snap.jpeg?fwpos=1, http://x.x.x.x/snap.jpeg?fwpos=3
   ```

   - The **first** URL (`fwpos=1`) is the **top** image — typically the front-facing camera capturing the truck and license plate.
   - The **second** URL (`fwpos=3`) is the **bottom** image — typically the top-down camera capturing the bed/materials.
   - Replace each `x.x.x.x` with the respective camera's fixed IP address.
3. Save the camera entry, then assign it to the appropriate lane as described in Step 6.

> **Note:** See the [Fast-Weigh IP Camera documentation](https://help.tacinsight.com/fast-weigh-knowledge-base/references/hardware/ip-cameras) for additional multi-image layouts (side-by-side, quadrants, etc.) using the same `fwpos` parameter.

> **Note:** Newer versions of Fast-Weigh include a button with a pencil icon next to the **Snapshot URL** field. This opens a GUI for selecting a multi-camera layout (side-by-side, top-and-bottom, quadrants, etc.) instead of manually editing the snapshot URL with `fwpos` parameters.

---

## 🔎 Validation

- Snapshot URL(s) load a current image when opened directly in a browser.
- The camera (or combined camera) appears correctly in the assigned lane's ticket capture.
- For combined images, confirm the top image is the front/plate view and the bottom image is the bed/material view.
- To test the added camera, click the camera icon in the **Test** column, next to the camera name (under **Manage Devices**). This will pull a snapshot from the assigned cameras showing you how they will look and confirms that they are functioning correctly.
