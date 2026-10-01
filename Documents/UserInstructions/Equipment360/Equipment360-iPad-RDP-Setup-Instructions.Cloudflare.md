# 🧭 Access Equipment 360 on an iPad

Use the instructions below to access the desktop version of Equipment 360 (E360) from an iPad through Remote Desktop (RDP).

> [!NOTE]
> During setup, iPadOS and the apps will ask you to allow permissions. Tap **Allow** or **Accept** and choose the most permissive option. For example, choose **Allow While Using App** instead of **Allow Once**.

---

## 📲 Install the Apps

Download these apps from the App Store if you do not already have them installed:

- [Cloudflare One Agent](https://apps.apple.com/us/app/cloudflare-one-agent/id6443476492)
- [Windows App Mobile](https://apps.apple.com/us/app/windows-app-mobile/id714464092)
- [Microsoft OneDrive](https://apps.apple.com/us/app/microsoft-onedrive/id477537958)

---

## 🔐 Configure Cloudflare One

1. Open the **Cloudflare One** app.
2. Tap **Next**, then tap **Accept**.
3. Enter `tex-mix` (without quotation marks), then tap **Next**.
4. Tap **Continue**.
5. Tap **Azure AD – Azure AD – Tex-Mix Concrete**. If you are not signed in automatically, authenticate with your work email credentials.
6. Tap **Install VPN Profile**, then tap **Allow** when prompted.
7. Tap **Allow Notifications**, then tap **Allow** when prompted.
8. Confirm the **Cloudflare Zero Trust** screen shows the slider enabled and the status **Connected**.

---

## 🖥️ Configure Windows App

1. Open the **Windows** app.
2. Tap the profile icon in the top-left corner, then tap **General**.
3. Set the following options:
	- **Use UDP Where Possible**: Off
	- **Always Import RDP Files**: On
	- **Share Data to Microsoft**: Off
4. Tap the back arrow.
5. Tap **Credentials**, then tap **Add Credentials**.
6. Enter your username (for example, `texmix\jdoe`). If you do not know what it is, enter `texmix\[FirstInitial][LastName]`, all lowercase.
7. Enter your password. If you do not have the password yet, enter a placeholder such as `test` for now.
8. Tap **Save**, then tap the back arrow.
9. Tap **X** to close the profile/settings screen.

---

## 📂 Add the E360 Remote Desktop Connection

1. Open the **OneDrive** app. If the toolbar containing **Home**, **My Files**, **Shared**, and **Favorites** is not visible, tap **My Files** in the top-left corner.
2. Tap **Search Your Files** (in the toolbar at the bottom of the screen) and search for `E360 Manager zt`.
3. Find **E360 Manager zt.rdp**. If file extensions are hidden, it may appear as **E360 Manager zt**.
4. Tap the three-dot menu next to the file on the far right, then tap **Open in Another App**.
5. Find **Windows** in the app list and tap it. Swipe left to see more apps, or tap **More** if Windows is not shown.
6. When the **Enter your Credentials** dialog appears, tap **Cancel**.
7. Under **Saved Devices**, find **E360 Manager zt**. Tap and hold the entry, then tap **Configure** in the menu.
8. Tap **Credentials** and select the credentials you added earlier (for example, `texmix\jdoe`).
9. Scroll to **DEVICE & AUDIO REDIRECTION** and make sure **Clipboard** and **Storage** are enabled.
10. Tap **Save** in the top-right corner of the dialog.

---

## 🚀 Start an E360 Session

Open the **Windows** app and tap **E360 Manager zt** to start the remote session.

> [!IMPORTANT]
> E360 is running on a remote computer; it is not installed locally on the iPad. The session may have additional latency or feel slow depending on your internet connection.

---

## 🖱️ Choose a Control Mode

Windows App has two primary ways to control the remote session:

- **Direct Touch**: Tapping the screen clicks the corresponding location. The mouse pointer is not displayed.
- **Mouse Pointer**: The pointer is visible. Moving your finger moves the pointer, and tapping clicks at its location.

See Microsoft's [Windows App touch, mouse, and pen guidance](https://learn.microsoft.com/en-us/windows-app/input-keyboard-mouse-touch-pen?tabs=ios-ipados) for more information.

**Mouse Pointer** mode is recommended because the small controls in E360 can be difficult to use with Direct Touch. In Mouse Pointer mode, the screen works like a touchpad: move the pointer to a control, then tap to click it.

### Mouse Pointer Gestures

- **Left-click**: Tap with one finger.
- **Right-click**: Tap with two fingers, or tap and hold with one finger.
- **Drag**: Double-tap and hold with one finger, then drag.
- **Scroll**: Tap and hold with two fingers, then drag up or down.
- **Zoom**: Pinch with two fingers to zoom in; spread them apart to zoom out.

### Switch Control Modes

During a remote session, tap the Windows icon in the small toolbar at the top-center of the screen. In the top-left corner, tap the finger icon for **Direct Touch** or the mouse icon for **Mouse Pointer**. The highlighted icon indicates the active mode.
