# NumPad for Kiosks — Deployment Guide

Turn any iPad into a locked-down numeric data-entry station using NumPad's custom keyboard,
Guided Access (or Single App Mode), and — for fleets — MDM.

This guide is for IT admins, deployment engineers, and store/warehouse ops teams rolling out
iPads as kiosks (inventory counts, price checks, PIN entry, order lookups, POS add-ons, etc.)
where a big, fast, tappable numpad beats the full iOS keyboard.

- **App:** NumPad — `com.morevoltage.NumPad`
- **Keyboard extension:** `com.morevoltage.NumPad.Keyboard`
- **Shared app group:** `group.morevoltage.numpad.container`

---

## Before you begin: the one rule that trips up every kiosk deployment

> **Enable and configure the keyboard *before* you lock the device.**

Once an iPad is locked into Single App Mode (SAM), Autonomous Single App Mode (ASAM), or Guided
Access, **Settings is unreachable**. There is no way to open Settings → General → Keyboard, no way
to grant Full Access, and no way to switch keyboards from inside the locked session. If you skip a
step below and lock the device first, the only fix is unlocking it, finishing setup, and locking it
again.

Do all keyboard setup first. Lock the device last.

---

## Step-by-step provisioning

### 1. Install NumPad and enable the keyboard

1. Install the NumPad app from the App Store (or push it via Apps and Books / Apple Business
   Manager for managed devices — see [Managed deployment](#managed-app-deployment-abm) below).
2. Open **Settings → General → Keyboard → Keyboards → Add New Keyboard…** and add **NumPad**.
3. Confirm it appears in the keyboard list. If it doesn't appear here, nothing downstream will
   work — see [Troubleshooting](#troubleshooting).

This step **must** happen while the device is unlocked and Settings is reachable. There is no
MDM payload that pre-enables a third-party keyboard for the user — Apple does not expose one, so
this is always a manual, on-device step (once, at provisioning time, per device).

### 2. Grant Full Access (only if you want clipboard history)

Full Access is **optional** and only gates three things in NumPad: **clipboard history**,
**haptics**, and **key-click sound**. The core numpad, packs, themes, and Tax/Tip overlay all work
identically with Full Access **off**.

- If your kiosk workflow never needs to paste previously-copied values back in, or you'd rather
  not grant a third-party keyboard access to the clipboard, **skip this** and leave Full Access
  off. This is the more conservative, more easily-approved-by-security choice for shared kiosk
  hardware.
- If you do want clipboard history: in the same **Keyboards** list, tap **NumPad** and toggle
  **Allow Full Access**.

Like keyboard enablement, this toggle lives in Settings and is unreachable once the device is
locked — decide and set it now.

### 3. Configure NumPad

Open the NumPad app and set up the kiosk's keyboard behavior:

- **Pack** (Home → Packs): pick the key layout for the job — Math, Finance, Symbols, Programmer,
  or the plain numpad.
- **Theme** (Home → Theme): choose a high-contrast theme that reads well under kiosk lighting.
- **Keyboard Height** (Home → Keyboard Height): pick **Small**, **Default**, or **Tall**. An
  upcoming NumPad release adds iPad-specific height presets, including an extra-tall **Pro Kiosk**
  preset sized for wall-mounted iPads and larger touch targets — worth revisiting this setting
  after you update.
- **Custom Keyboard** (Pro): if your workflow benefits from fixed shortcut keys around the numpad
  (Enter, Tab, arrows, decimal, a specific symbol), build a layout under Home → Custom Keyboard so
  every operator gets the same keys in the same place.

Test data entry in your actual kiosk app now, before locking, so you can adjust pack/theme/height
while you can still reach Settings and the NumPad app.

### 4. Confirm your kiosk app doesn't block third-party keyboards

Third-party keyboard extensions are **not** blocked by Guided Access, Single App Mode, Autonomous
Single App Mode, or MDM "assessment mode" — Apple confirmed this explicitly (WWDC17 session 716,
"Extending Your App with Custom Keyboards"). If NumPad isn't showing up inside your locked kiosk
app, the lock mode itself is not the cause.

The one thing that *can* block it is your own app's code: an app can opt out of third-party
keyboards by implementing

```swift
func application(_ application: UIApplication,
                  shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool
```

and returning `false` for `.keyboard`. If you built the kiosk app in-house (or commissioned it),
have your developer confirm this method either doesn't exist or returns `true` for `.keyboard`.
If you're deploying a third-party off-the-shelf kiosk/POS app, ask the vendor directly — there is
no way to detect or override this from outside the app.

### 5. Lock the device

With the keyboard enabled, Full Access set, and NumPad configured, now lock the iPad into your
chosen mode:

- **Guided Access** (Settings → Accessibility → Guided Access, then triple-click the side/home
  button in your kiosk app): good for single-device, staff-supervised kiosks. **Double-check the
  Software Keyboards toggle** in the Guided Access options screen before starting the session — see
  the warning below.
- **Single App Mode (SAM)** or **Autonomous Single App Mode (ASAM)**: MDM-driven, no supervision
  needed for ASAM once configured; use this for unattended, always-on kiosks managed at fleet
  scale.

> **Guided Access "Software Keyboards" trap:** Guided Access has its own **Software Keyboards**
> toggle (in the options sheet you get to via the ⓘ / circle button when starting a session). If
> this is turned **off**, it hides *every* on-screen keyboard — NumPad included — regardless of
> whether it's enabled in Settings. This is unrelated to the third-party-keyboard question above;
> it's a blanket "no on-screen keyboard at all" switch, typically used with an attached hardware
> keyboard or scanner. Make sure it's **on** if operators need to type.

---

## Managed / MDM notes

### There is no MDM payload for keyboard enablement

Apple does not provide a Configuration Profile payload that pre-enables a specific third-party
keyboard or pre-grants Full Access. Every device needs the manual Settings step in
[Step 1](#1-install-numpad-and-enable-the-keyboard) and [Step 2](#2-grant-full-access-only-if-you-want-clipboard-history)
done once, by a human, before it's locked or handed to a store. Bake this into your provisioning
checklist / imaging process (e.g., as a step in Apple Configurator or your enrollment "welcome"
flow) rather than assuming a profile will do it for you.

### Managed Open In can block NumPad inside managed apps — deploy it as a managed app

Some MDM solutions use **Managed Open In** restrictions to control which keyboards, and which
apps' data, can flow into a managed app. If your kiosk app is deployed as a *managed* app but
NumPad is installed as an *unmanaged* (personal) app, Managed Open In can block NumPad from being
used as the keyboard inside it.

**Fix:** deploy NumPad itself as a managed app via **Apple Business Manager** (Apps and Books,
device-assignment or VPP licensing) alongside your kiosk app. Once both apps are managed under the
same MDM, Managed Open In treats NumPad as trusted and the restriction no longer applies.

### Intune App Protection

Microsoft Intune App Protection Policies can force corporate accounts to use only Apple's built-in
keyboard inside protected apps, regardless of what's enabled in Settings. If your kiosk app (or
the account it signs in with) is wrapped in an Intune App Protection Policy, check the policy's
keyboard restriction setting — this is an Intune-side allow/deny, not something NumPad or the
device's Settings can override. Coordinate with your Intune admin to exempt the kiosk app/account
or the policy will keep switching operators back to the system keyboard.

### Hardware keyboards suppress the on-screen keyboard

If the kiosk has a paired Bluetooth accessory that identifies itself as a hardware keyboard —
this includes many **Bluetooth barcode/QR scanners**, which present as keyboards by design — iOS
will not show any on-screen keyboard, NumPad included, while it's connected. If a kiosk needs both
scanner input and NumPad's on-screen numpad, budget for toggling Bluetooth off when manual number
entry is needed, or use a scanner in a non-HID (app-integrated) mode instead.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| NumPad doesn't appear in the keyboard switcher at all | Never added in Settings → General → Keyboard → Keyboards, or added *after* the device was locked | Unlock the device, add NumPad in Settings, then re-lock |
| NumPad appears everywhere *except* inside the kiosk app | Kiosk app blocks third-party keyboards via `shouldAllowExtensionPointIdentifier` | Ask the app's developer/vendor to allow `.keyboard`, or choose a different kiosk app |
| NumPad worked before, stopped working after enrolling in MDM / moving to a managed kiosk app | Managed Open In blocking an unmanaged NumPad inside a managed app | Deploy NumPad as a managed app via Apple Business Manager |
| Corporate-account users get the system keyboard no matter what | Intune App Protection Policy forcing built-in keyboards | Check/adjust the policy's keyboard restriction with your Intune admin |
| No on-screen keyboard shows up at all, in any app | Guided Access **Software Keyboards** toggle is off, or a paired accessory (e.g., a Bluetooth scanner) is presenting as a hardware keyboard | Turn Software Keyboards back on in the Guided Access options sheet; disconnect/reconfigure the hardware accessory if a software keyboard is also needed |
| Full Access-only features (clipboard history, haptics, sound) aren't working | Full Access not granted, or granted after locking | Unlock, enable **Allow Full Access** for NumPad in Settings, re-lock |
| Settings isn't reachable to fix any of the above | Device is already in SAM/ASAM/Guided Access | Exit the lock mode (per your MDM's or Guided Access's exit procedure) before making changes |

---

## FAQ

**Does Guided Access or Single App Mode block third-party keyboards like NumPad?**
No. Apple confirmed at WWDC17 (session 716) that Guided Access, SAM, ASAM, and assessment mode do
not block custom keyboard extensions. If NumPad isn't available in a locked session, the cause is
almost always the kiosk app itself opting out, an MDM policy (Managed Open In, Intune App
Protection), or a connected hardware keyboard/scanner — not the lock mode.

**Can we use MDM to automatically enable NumPad and skip the manual Settings step?**
No. There is no Apple MDM payload for pre-enabling a third-party keyboard or pre-granting Full
Access. It's a one-time manual step per device, done before locking.

**Do we need to grant Full Access?**
Only if you want clipboard history, haptics, or the key-click sound. The numpad, all packs,
themes, and the Tax/Tip overlay work fully without Full Access.

**Will this work on shared/kiosk iPads without an Apple ID?**
Yes — enabling a keyboard and NumPad's own settings don't require an Apple ID or iCloud. If NumPad
is deployed as a managed app (see [Managed deployment](#managed-app-deployment-abm)), it can be
installed and licensed device-based through Apple Business Manager with no App Store sign-in
required on the device.

**We use a Bluetooth barcode scanner on the kiosk — will NumPad still show up?**
Not while the scanner is connected as a Bluetooth HID keyboard — iOS suppresses all on-screen
keyboards while a hardware keyboard is attached. This is standard iOS behavior, not specific to
NumPad.

**Our kiosk app is managed through MDM but NumPad still gets blocked — why?**
Most commonly, Managed Open In is restricting an *unmanaged* NumPad inside a *managed* kiosk app.
Deploy NumPad as a managed app through Apple Business Manager so both apps are on the same side of
that boundary.

**What's the extra-tall height preset for?**
An upcoming release adds an iPad-focused **Pro Kiosk** height preset — a taller keyboard with
bigger keys, aimed at wall-mounted kiosks and stands where operators tap from a slight distance or
with gloves. It layers on top of the existing Small/Default/Tall presets and the same portrait/
landscape clamping.

---

## App Store description (kiosk pitch)

> **Turn any iPad into a fast, focused numeric data-entry station.** NumPad replaces the sprawling
> system keyboard with a big, tappable numpad purpose-built for counts, prices, codes, and
> lookups — perfect for retail, warehouse, healthcare, and field-service kiosks locked down with
> Guided Access or MDM. Choose from Math, Finance, Symbols, and Programmer key packs, 17 themes for
> at-a-glance legibility, and adjustable keyboard heights (including an extra-tall Pro Kiosk preset
> for wall-mounted setups) so every station is sized right for the job. No clipboard access
> required unless you want it — NumPad works fully with Full Access left off, and deploys cleanly
> as a managed app via Apple Business Manager for fleets of any size.
