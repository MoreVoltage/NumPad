# NumPad 2.0 — Screenshot Storyboard

10 shots, each captured as an **iPhone 6.9" pair** (iPhone 16 Pro Max class simulator) and an
**iPad 13" pair** (iPad Pro 13" class simulator) — 20 raw captures total, later composited with
device frames/captions by the existing `marketing/generate_app_store_screenshots.py` pipeline.

All debug routes below require a **DEBUG-configuration build** running in Simulator —
`xcrun simctl openurl <device> "numpad://debug/..."` — per `NumPad/Libraries/DebugDeepLinkRoute.swift`.
They compile to nothing in Release (the whole file is `#if DEBUG`). For shots that need Full
Access or a live keyboard session, the Simulator must have the keyboard enabled once by hand
first (Settings > Keyboards) — the debug routes don't grant that, they only set state/navigate.

---

### 1. "Math that computes itself"
**Screen:** Keyboard extension, Math pack active, Live Math Preview chip floating above an
in-progress expression ("84.50×1.18") in a text field.
**Reach:** `numpad://debug/typing` (raises the minimal text-field host) → select the field to
bring up the keyboard → type the expression. Live Math Preview is on by default
(`UserPrefs.liveMathPreview = true`), no entitlement needed.
**Why first:** this is the above-the-fold hero of the description — compute-as-you-type is the
single new capability most worth leading with.

### 2. "Six packs, one keypad"
**Screen:** Packs picker (`PacksViewController`) showing all 6 selectable packs (Finance,
Symbols & Science, Programmer, Date & Time, Units & Conversion, Cooking & Baking) with lock
chips on unowned ones.
**Reach:** Home → "Packs" row → `PacksViewController` pushes directly. No debug route needed
(it's a normal in-app navigation one tap deep); optionally `numpad://debug/entitle?pro=0` first
to guarantee lock chips are visible for the screenshot.

### 3. "Convert as you type"
**Screen:** Keyboard extension, Units & Conversion (or Cooking & Baking) pack active, the "="
key long-pressed to show `ConversionView` mid-conversion (e.g. "12 in → 30.48 cm").
**Reach:** `numpad://debug/entitle?pro=1` (entitles the conversion overlay) →
`numpad://debug/typing` → switch to the Units pack via the pack picker → long-press "=".

### 4. "Build your own keyboard"
**Screen:** Custom Keyboard editor (`CustomKeyboardEditorView`), Configure tab, drag-and-drop
Key Library palette open with a chip mid-drag into Column 1, live preview visible above.
**Reach:** `numpad://debug/entitle?pro=1` → `numpad://debug/editor` (pushes the editor
directly).

### 5. "Left- or right-handed"
**Screen:** Custom Keyboard editor, Settings tab, handedness segmented control set to "Left",
with the live preview showing columns mirrored to the left side.
**Reach:** `numpad://debug/entitle?pro=1` → `numpad://debug/editor` → tap the Settings segment
→ toggle handedness.

### 6. "Liquid Glass, on iOS 26"
**Screen:** Keyboard extension rendered with the "Glass" theme's real Liquid Glass material
(iOS 26 simulator only — falls back to a translucent gray on earlier OS versions, so this shot
requires an iOS 26 runtime).
**Reach:** Home → Theme → select "Glass" (or "Glass Dark" for the dark-appearance pairing) →
`numpad://debug/typing` to raise the keyboard against real content.

### 7. "Just ask Siri"
**Screen:** iOS Shortcuts app (or Siri "Calculate with NumPad" query sheet) showing NumPad's
three App Shortcuts — Convert Units, Calculate, Calculate Tip — with the Calculate Tip dialog
result on screen.
**Reach:** Not a NumPad-app screen — capture the system Shortcuts app's NumPad shortcut tiles
directly (they appear automatically once the app is installed, per `NumPadShortcuts`), then
trigger "Calculate a tip with NumPad" via Siri/Shortcuts run to capture the result dialog.

### 8. "Tax and tip, done in two taps"
**Screen:** Keyboard extension, `TaxTipView` overlay open on the "%" long-press, mid-entry
(bill amount entered, tip percent selected).
**Reach:** `numpad://debug/typing` → long-press "%" on the numpad row.

### 9. "Sized for the counter"
**Screen (iPad only, still captured as a pair with shot 10 on iPhone using the Tall preset
instead):** iPad Kiosk-height keyboard preset, full-width numpad visibly larger against the
same host app content.
**Reach:** `numpad://debug/entitle?pro=1` → `numpad://debug/preset?value=kiosk` →
`numpad://debug/typing`. On iPhone, substitute `value=tall` (Kiosk is iPad-only; iPhone mirrors
Tall) so the iPhone half of the pair shows the Tall preset instead — call out "Kiosk on iPad"
in the caption rather than claiming iPhone parity.

### 10. "Up and running in a minute"
**Screen:** Interactive first-run onboarding, "wow" step (the animated keyboard demo) or the
"enable" step with the confetti celebration (`OnboardingConfettiView`) mid-animation.
**Reach:** Fresh install / reset first-run state, or `numpad://debug/guide` as a fallback
capture of `FeaturesGuideViewController` if the onboarding flow itself isn't independently
re-triggerable via a debug route — confirm with the app's own onboarding-reset path (Settings
> re-run onboarding, if present) before relying on a fresh-install-only capture, since fresh
installs are harder to script for repeatable screenshot runs.

---

## Headlines (≤6 words each)

1. Math that computes itself
2. Six packs, one keypad
3. Convert as you type
4. Build your own keyboard
5. Left- or right-handed
6. Liquid Glass, on iOS 26
7. Just ask Siri
8. Tax and tip, two taps
9. Sized for the counter
10. Up and running in a minute

---

## Open questions for whoever shoots these

- **Shot 7** is the only one not native to the NumPad app UI — confirm App Store review
  guidance on showing a system Shortcuts/Siri surface in a screenshot before locking this in;
  a safer fallback is a NumPad-side screen that *describes* Siri support (e.g. a Features Guide
  row) if system-UI screenshots are disallowed for this submission.
- **Shot 10**'s exact reach path needs confirming against whatever onboarding-reset affordance
  (if any) ships in Settings — this storyboard assumes one exists or that a fresh install is
  acceptable for a one-time screenshot session.
- Device frame + caption compositing is out of scope here — raw simulator captures only, fed
  into the existing `marketing/generate_app_store_screenshots.py` / `assemble_cpp_screenshots.py`
  pipeline (not modified by this task).
