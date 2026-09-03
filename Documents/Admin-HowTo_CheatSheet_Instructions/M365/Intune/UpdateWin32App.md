# Microsoft Intune - Package/Deploy Superseding Win32 App with IntuneWinAppUtil & WinTuner

Use this procedure to package a new version of a Windows app, upload it to Microsoft Intune with WinTuner, and supersede the prior Intune app.

## 1. Connect to WinTuner

Open PowerShell 7 and connect using an account with the required Intune permissions:

```powershell
Connect-WtWinTuner -Username email@domain.com
```

If the command is not available or fails because the module has not been loaded, run the following command and then retry the connection:

```powershell
Import-Module WinTuner
Connect-WtWinTuner -Username email@domain.com
```

## 2. Prepare the Source Files

Put every installer file and supporting script in one versioned content directory. This includes `install.ps1`, `uninstall.ps1`, `SFTA.ps1`, installers such as `7z2602-x64.msi`, and any files those scripts require.

Example layout:

```text
Win32ContentPrepTool-ProjectFiles/
	7zip-AutoSetFileAssociations/
		logo.png
		26.02/
			install.ps1
			uninstall.ps1
			SFTA.ps1
			7z2602-x64.msi
```

When possible, save the app icon as `logo.png` in the application project root, rather than the version directory. For the example above, its path is `Win32ContentPrepTool-ProjectFiles\7zip-AutoSetFileAssociations\logo.png`.

## 3. Create the .intunewin Package

Run `IntuneWinAppUtil.exe` and specify the version directory as the source, the installation script as the setup file, and an output directory for the completed package.

```powershell
& IntuneWinAppUtil.exe `
		-c "C:\Intune\Win32ContentPrepTool-ProjectFiles\7zip-AutoSetFileAssociations\26.02" `
		-s "install.ps1" `
		-o "C:\Intune\WinTuner\manuallyPackaged\7zip-AutoSetFileAssociations\26.02"
```

Rename the resulting `.intunewin` file to a descriptive application and version name. By default, if the setup script is named `install.ps1`, the packaging tool produces `install.intunewin`:

```text
install.intunewin -> 7z2602-x64-AutoSetFileAssociations.intunewin
```

## 4. Create win32LobApp.json

In the same directory as the renamed `.intunewin` file, create `win32LobApp.json`. Update every value to match the application being packaged. For `detectionRules`, see [MSI Detection Rules](#msi-detection-rules) or [Non-MSI Detection Rules](#non-msi-detection-rules).

Convert `logo.png` to a base64 string at <https://base64.guru/converter/encode/image/png>, then replace the `largeIcon.value` value with that string. Include the app version in `displayName` to make superseded versions easy to identify.

```json
{
	"@odata.type": "#microsoft.graph.win32LobApp",
	"displayName": "7-Zip v26.02 (Auto Set File Associations)",
	"description": "7-Zip is a file archiver with a high compression ratio.",
	"publisher": "Igor Pavlov",
	"developer": "Igor Pavlov",
	"displayVersion": "26.02",
	"appVersion": "26.02",
	"informationUrl": "https://7-zip.org/",
	"fileName": "7z2602-x64-AutoSetFileAssociations.intunewin",
	"setupFilePath": "install.ps1",
	"allowAvailableUninstall": true,
	"applicableArchitectures": "none",
	"allowedArchitectures": "x64",
	"installCommandLine": "%SystemRoot%\\Sysnative\\WindowsPowerShell\\v1.0\\powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1",
	"uninstallCommandLine": "%SystemRoot%\\Sysnative\\WindowsPowerShell\\v1.0\\powershell.exe -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1",
	"installExperience": {
		"deviceRestartBehavior": "basedOnReturnCode",
		"runAsAccount": "system"
	},
	"minimumSupportedOperatingSystem": {
		"v10_2004": true
	},
	"minimumSupportedWindowsRelease": "2004",
	"detectionRules": [
		{
			"@odata.type": "#microsoft.graph.win32LobAppProductCodeDetection",
			"productCode": "{23170F69-40C1-2702-2602-000001000000}",
			"productVersion": "26.02.00.0",
			"productVersionOperator": "greaterThanOrEqual"
		}
	],
	"largeIcon": {
		"type": "image/png",
		"value": "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAAsTAAALEwEAmpwYAAAARUlEQVR4nGNgGAzgP4WY4T+5AMUAfLYQbQAuRWS5AN0AbPI4DUCzAZutuA1AV4jPQPoagMc7xEUjwUAkB8ANoDQpDywAANsEt1e/oiRqAAAAAElFTkSuQmCC"
	},
	"returnCodes": [
		{ "returnCode": 0, "type": "success" },
		{ "returnCode": 1707, "type": "success" },
		{ "returnCode": 3010, "type": "softReboot" },
		{ "returnCode": 1641, "type": "hardReboot" },
		{ "returnCode": 1618, "type": "retry" }
	]
}
```

The install and uninstall commands use `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe` because Intune runs these command lines from a 32-bit command shell. `Sysnative` forces a 64-bit PowerShell session, avoiding file-system redirection issues when installing 64-bit applications.

### MSI Detection Rules

For an MSI installer, use the product-code detection rule in the JSON example. Use the following function to retrieve the MSI product code and product version. It returns an object whose `ProductCode` and `ProductVersion` properties are strings.

```powershell
function Get-MsiProductInfo {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[ValidateScript({ Test-Path $_ -PathType Leaf })]
		[string]$Path
	)

	$installer = New-Object -ComObject WindowsInstaller.Installer
	$database = $installer.GetType().InvokeMember(
		'OpenDatabase', 'InvokeMethod', $null, $installer, @($Path, 0))

	try {
		$getProperty = {
			param([string]$PropertyName)

			$query = "SELECT Value FROM Property WHERE Property = '$PropertyName'"
			$view = $database.GetType().InvokeMember(
				'OpenView', 'InvokeMethod', $null, $database, @($query))
			[void]$view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
			$record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)

			if ($null -eq $record) {
				throw "The MSI does not contain a $PropertyName property."
			}

			[string]$record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1)
		}

		[pscustomobject]@{
			ProductCode = & $getProperty 'ProductCode'
			ProductVersion = & $getProperty 'ProductVersion'
		}
	}
	finally {
		[void][Runtime.InteropServices.Marshal]::ReleaseComObject($database)
		[void][Runtime.InteropServices.Marshal]::ReleaseComObject($installer)
	}
}

Get-MsiProductInfo -Path 'C:\Intune\Win32ContentPrepTool-ProjectFiles\7zip-AutoSetFileAssociations\26.02\7z2602-x64.msi'
```

### Non-MSI Detection Rules

Replace the entire `detectionRules` array in the template with one of these options. Choose a detection artifact created only by a successful installation. Detection is evaluated on the client after installation and later during app evaluation; if it does not match, Intune considers the app not installed.

**File version:** Use this when the installer places a stable, versioned executable or DLL on disk. `version` and `versionOperator` can be omitted when only the file's presence matters.

```json
"detectionRules": [
	{
		"@odata.type": "#microsoft.graph.win32LobAppFileSystemDetection",
		"path": "C:\\Program Files\\Vendor\\Application",
		"fileOrFolder": "Application.exe",
		"detectionValue": "1.2.3.4",
		"detectionType": "version",
		"detectionMethod": "exists",
		"operator": "greaterThanOrEqual"
	}
]
```

**Registry value:** Use this for EXE installers that create a reliable registry key or version value. The `keyPath` is relative to the specified hive. Set `detectionType` to `exists` and omit `detectionValue` and `operator` when key presence alone is sufficient.

```json
"detectionRules": [
	{
		"@odata.type": "#microsoft.graph.win32LobAppRegistryDetection",
		"keyPath": "SOFTWARE\\Vendor\\Application",
		"valueName": "Version",
		"detectionValue": "1.2.3",
		"detectionType": "version",
		"operator": "greaterThanOrEqual",
		"rootKey": "HKEY_LOCAL_MACHINE",
		"check32BitOn64System": false
	}
]
```

Use `check32BitOn64System: true` only when a 32-bit application writes to the redirected 32-bit registry view (`HKLM\SOFTWARE\WOW6432Node`).

**Custom PowerShell script:** Use this when installation must be verified through several conditions, such as a file plus a registry value, a service, or application-specific state. Add the script to the content directory. It must write a value to standard output and exit `0` only when the app is detected; any other exit code, or no output, means not detected.

`detect.ps1` example:

```powershell
$installedFile = 'C:\Program Files\Vendor\Application\Application.exe'
$version = (Get-Item $installedFile -ErrorAction SilentlyContinue).VersionInfo.ProductVersion

if ($version -and ([version]$version -ge [version]'1.2.3')) {
		Write-Output "Application version $version detected"
		exit 0
}

exit 1
```

JSON replacement:

```json
"detectionRules": [
	{
		"@odata.type": "#microsoft.graph.win32LobAppPowerShellScriptDetection",
		"scriptContent": "<BASE64-ENCODED-DETECT-PS1-CONTENT>",
		"enforceSignatureCheck": false,
		"runAs32Bit": false
	}
]
```

Base64-encode the script content as UTF-8 without a byte-order mark before placing it in `scriptContent`:

```powershell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-Content .\detect.ps1 -Raw)))
```

## 5. Upload and Supersede the Previous App

Deploy the package from the directory containing both the `.intunewin` file and `win32LobApp.json`.

```powershell
Deploy-WtWin32App `
		-PackageFolder "C:\Intune\WinTuner\manuallyPackaged\7zip-AutoSetFileAssociations\26.02" `
		-GraphId "2bb29419-8f3c-4274-9b23-90deb64c7c8a" `
		-KeepAssignments
```

Set `-GraphId` to the existing app's Microsoft Intune app ID to supersede it. Find the app ID by opening the old app in the Intune admin center and copying the value after `appId/` in the URL. For example, the app ID in the URL below is `eecddfec-8f4b-481d-8ea2-04701eb6bc13`:

```text
https://intune.microsoft.com/#view/Microsoft_Intune_Apps/SettingsMenu/~/2/appId/eecddfec-8f4b-481d-8ea2-04701eb6bc13
```

Use `-KeepAssignments` to copy the old app's assignments to the new superseding app. Omit it only when assignments will be configured separately.

## 6. Mark the Previous App as Deprecated

In the Intune admin center, open the old app and prefix its display name with `[Deprecated]` after the new app has been uploaded and its assignments are confirmed.

```text
[Deprecated] 7-Zip v24.09 (Auto Set File Associations)
```
