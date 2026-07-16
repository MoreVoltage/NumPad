# In-App Copy Pass (marketing + clarity) — 2026-07-12

Branch: `feat/growth-quickwins` (off `master`). Companion to `docs/research/2026-07-12-aso-features-competitive-review.md`.
Scope: **in-app user-facing copy only.** App Store listing metadata is Tier A (separate, next).

All strings are English base values of `NSLocalizedString`. Non-English locales are English-fallback for
most of these already; changed keys will need a translation refresh when the owner runs the localization
pass (tracked separately). No behavior changed — copy + one small onboarding label only.

## Threads implemented

### Thread 2 — Positioning (WOW headline)
- `OnboardingWowViewController.swift` — headline "Math, right where you type." → **"Fast numbers for spreadsheets, forms & finance."** Claims the unowned Excel/data-entry gap (owner picked option B). Header + inline comments updated (no longer "five words").

### Thread 1 — Surface the no-subscription differentiator
- `HomeViewController.swift` (`.store` row) — price detail now shows **"<price> · one-time"** when unentitled, reinforcing no-subscription at the decision point. (Entitled state "✓ Unlocked" unchanged.)
- `OnboardingTryItViewController.swift` — added a tertiary footnote before the paywall handoff: **"No subscriptions, ever. Pro is a one-time unlock."** Careful: NumPad is a **paid** app, so this never implies "free."

### Thread 3 — Full Access as a privacy flex (optional, not a hurdle)
- `Extensions.swift` (`instructionsFooter`, used on Instructions + onboarding ENABLE) → **"NumPad works fully without Full Access. Turn it on only for click sounds, haptics, and clipboard history — nothing you type is ever tracked."**
- `PrivacyViewController.swift` (`.access` row) → detail now adds **"NumPad works fully without Full Access — turn it on only if you want click sounds, haptics, or clipboard history."**

### Thread 4 — Clarity renames (the "7-8-9 on Top" playbook; behaviors verified first)
- `Extensions.swift`: "Rounded" → **"Rounded Keys"**; "Grid" → **"Key Grid Lines"** (used only on Home).
- `StoreViewController.swift` (Settings section): "Repurpose Next Key" → **"Pack Switch Shortcut"**; "Smart Pack Defaulting" → **"Auto-Match Pack to Field"**.
- **Deliberately NOT renamed:** "Inline Calculator" / "Live Math Preview" sit side-by-side and read alike, but the Settings `ToggleRow` has no subtitle field — clarifying them well needs a subtitle (small UI change), not a rename that could mislead. Flagged as a follow-up.

### Thread 5 — Accuracy/consistency
- `StoreViewController+Hero.swift` (Free-vs-Pro table): "All 7 packs" → **"Every pack."** Removes a hardcoded count that clashed with the 6-pack lists elsewhere (7 counted free Math; the à-la-carte unlock is 6). "Every pack" is unambiguous and matches the hero's "Every keyboard pack."
- Early-bird "50% off" left as-is — $5.99 vs $11.99 ≈ 50%, tracks the real SKU.

## Follow-ups (not done here)
- Translation refresh for the changed English keys (owner-gated localization pass).
- Optional: add a subtitle to the Settings `ToggleRow` so Inline Calculator / Live Math Preview (and others) can carry one-line explanations.
- Known separate item: App Store **description** still says "WHAT YOU GET FOR FREE" on a paid app — that's listing metadata (Tier A), not in-app, and is queued for 2.0.1.

## Verification
- App-target build (`NumPad` scheme, iOS Simulator) — see session; all edits are app-target, no keyboard-extension changes.
