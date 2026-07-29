# Reset MFA Methods and Hardware Keys for a User (Microsoft Entra)

Use this quick guide when you need to remove a user's hardware-backed authentication methods (passkeys, FIDO2 security keys, etc.) and force them to register MFA again.

## Prerequisites

- You have an Entra role with permission to manage user authentication methods (for example, Authentication Administrator or Privileged Authentication Administrator).
- You know the target user's account (UPN/email).

## Steps in Microsoft Entra

1. Sign in to the Microsoft Entra admin center:
	- https://entra.microsoft.com
2. Go to **Users** > **All users**.
3. Select the target user.
4. Open **Authentication methods**.
5. Delete all hardware-backed methods, including items such as:
	- Passkey (FIDO2)
	- Security key / FIDO2 key
	- Any other physical key methods listed for the user
6. After hardware methods are removed, click **Require re-register multifactor authentication**.
7. Confirm the prompt.

## Quick Verification

- In **Authentication methods**, confirm hardware key entries are no longer listed.
- Confirm the user is now required to complete MFA registration at next sign-in.

## What to Tell the User

- They will be prompted to set up MFA again on next login.
- Existing passkeys/security keys were removed and must be re-registered if still needed.

## Notes

- This action can affect sign-in immediately.
- If the user is locked out, ensure they have an approved temporary sign-in path (for example, Temporary Access Pass) before removing all methods.
