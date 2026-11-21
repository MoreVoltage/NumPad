# Store link: App Review-compliant alternative to PR #19

Branch `key/opus-store-link-compliant`, based on live 2.1.1 (`478430f5`). Local commits only. Nothing pushed.

## 1. Inventory: every keyboard path that tries to open the app (at 478430f5)

All four go through `KeyboardViewController.openContainerApp(_:)`. That method walks the responder chain looking for the legacy `openURL:` selector.

| # | Trigger | Location (pre-change) | URL | Counters |
|---|---|---|---|---|
| 1 | Tap a key with a lock chip | `tapped(_:)`, ~line 615 | `numpad://store-preview?source=key_lock` | `lockedKeyTaps` +1; `storeDeeplinkOpens` +1 if a responder answered the selector |
| 2 | Tap a locked pack in the pack picker | `packPickerView(_:didSelectLocked:)`, ~line 1104 | `…?source=pack_picker` | same |
| 3 | Tap a locked category in the conversion overlay | `conversionViewDidSelectLockedCategory(_:)`, ~line 1170 | `…?source=conversion_lock` | same |
| 4 | Tap the What's New chip | `whatsNewChipViewDidTap(_:)`, ~line 1209 | `numpad://whats-new` | none |

**What the user sees today on iOS 18+:** nothing, most likely. The legacy `openURL:` selector no longer opens URLs on iOS 18. So the tap is swallowed: no key is typed and no app opens. Paths 2 and 3 also dismiss their overlay first. `storeDeeplinkOpens` can still increment whenever some responder answers the selector, so that count overstates real opens. (I inferred this from the code and from PR #19's analysis. I did not check it on a device.)

## 2. What changed

- **`NumPad/Libraries/LockedTapResponse.swift`** (new, compiled into both targets). `LockedTapResponse.handle(source:presenter:)` increments `lockedKeyTaps` and asks the presenter to show the hint. It has no URL and no `open` call, and it does not increment `storeDeeplinkOpens`. It also defines `LockedTapSource` and the `LockedTapHintPresenting` protocol. The hint lasts 2.5 s.
- **`Keyboard/Views/LockedTapHintView.swift`** (new, keyboard only). A pill styled like the existing What's New and math-preview chips: same font, colour scheme, height and shadow. It has `isUserInteractionEnabled = false`, so the keys under it stay tappable.
- **`KeyboardViewController`**: paths 1–3 now call `LockedTapResponse.handle(..., presenter: self)`. The hint sits at the top centre (6 pt inset, 28 pt high) and fades out after 2.5 s. A repeat tap restarts the timer. While the hint shows, the math-preview and What's New chips are hidden; when it fades, the What's New chip is refreshed. It respects Reduce Motion and posts a VoiceOver announcement. No band is pushed into the layout and nothing overlays the key grid for longer than the hint.
- **Path 4 (What's New chip) is unchanged**, as instructed. It is now the only remaining `openContainerApp` caller. MOR-400 removes the chip on another branch; once that lands, `openContainerApp` can be deleted too. Until then this path is still a 4.4.1 risk (see risks).
- Pricing, paywall, StoreKit and monetization gating are unchanged. No subscription IDs were added. Version and build are unchanged. The app-side `store-preview` route and the `LockFunnelCounters.storeDeeplinkOpens` field stay in place; the keyboard just no longer increments it.

## 3. Red / green

Tests: `NumPadTests/LockedTapResponseTests.swift` (6 tests).
- A locked tap from every source never reaches a spy responder chain that implements both `openURL:` and `openURL:options:completionHandler:`.
- Exactly one hint is shown, and its text names NumPad.
- `lockedKeyTaps` increments once per tap (3 after 3 sources).
- `storeDeeplinkOpens` stays 0.
- The hint duration is between 0 and 3 s.
- A source guard reads `Keyboard/KeyboardViewController.swift` and checks it has no `store-preview`, no `incrementStoreDeeplinkOpens`, and exactly two `openContainerApp(` occurrences (the definition and the What's New call).

- **RED** (commit `d1ce2b6a`, tests only): `-only-testing:NumPadTests/LockedTapResponseTests` → `** TEST FAILED **`, `error: cannot find type 'LockedTapHintPresenting' in scope`. This is a compile-level red: the API did not exist yet.
- **GREEN** (after `cfb71415`): full `NumPadTests` suite once, gated (`ai-gate --heavy`), pool sim, `-parallel-testing-enabled NO`, DerivedData `/tmp/key-opus/p20-dd` → **314 tests, 0 failures**, `** TEST SUCCEEDED **`, Keyboard.appex built. (314 = 308 at 2.1.1 + 6 new. PR #19's 312 included its 4 opener tests.)
- `pod install --deployment` was needed (no `Pods/`). It left tracked files unchanged.

## 4. Screenshot

`docs/screenshots/store-link-compliant/locked-pack-hint-iphone.png` (commit `63062c87`).

Read-only check first: the pool sim's `.GlobalPreferences.plist` `AppleKeyboards` already listed `com.morevoltage.NumPad.Keyboard`. So I installed the built app, launched it with `-skipOnboarding -debugRoute typing`, and used Maestro to pick NumPad from the globe menu. Then I long-pressed the pack-switch key and tapped the locked **Finance** pack. The hint appeared and NumPad did not come to the foreground.

I did not open Settings and did not change any sim settings. The sim was returned afterwards (apps wiped, shut down).

## 5. Missing locales

New string, added to `Keyboard/en.lproj/Localizable.strings` only: `"Open the NumPad app to unlock this."`. Nothing was machine-translated. Until it is translated, the English text falls back in these 15 Keyboard locales:

ar, de, es, fr, he, hi, it, ja, ko, nl, pl, pt-PT, ru, zh-Hans, zh-Hant.

(No existing string fit. The closest were "Unlock" and "… in the NumPad app." sentences about clipboard and snippets.)

## 6. Comparison with PR #19

| | PR #19 (`ae369b03`) | This branch |
|---|---|---|
| Locked tap result | Tries to foreground NumPad on the Store screen via `UIApplication.open` found on the responder chain | Stays in the keyboard and shows a 2.5 s hint |
| App Review 4.4.1 | At risk (Astra review: High) | No launch attempt on locked taps |
| Purchase friction | One tap to the Store, if UIKit allows it (not verified on device) | User must open NumPad themselves, then find the Store |
| `store_deeplink_opens` | Increments only on a reported successful open | No longer incremented from the keyboard (stays 0) |
| `locked_key_taps` | Unchanged | Unchanged |
| Source attribution (`key_lock` / `pack_picker` / `conversion_lock`) | Kept in the URL | Lost: the app can't tell which lock brought the user in |
| What's New chip | Moved to the new opener | Untouched (still the legacy selector; MOR-400 removes it) |
| New code | `ContainerAppOpener` + 4 tests | `LockedTapResponse` + hint view + 6 tests |

## 7. Open risks

1. **What's New chip still calls `openContainerApp`** (legacy `openURL:` selector). It probably does nothing on iOS 18+, but App Review could still read it as an attempted launch. It stays a 4.4.1 exposure until MOR-400 lands. After that, delete `openContainerApp`; the source-guard test count will need changing from 2 to 0.
2. **The hint partly covers the top row** (keys 1–3 in the default layout; it would cover the pack row, including any +/- key, when a pack row is on top) for 2.5 s. It passes touches through, so those keys still work, but their labels are partly hidden. If that's not acceptable, a narrower pill or a shorter duration (e.g. 1.5 s) is a one-constant change.
3. **The funnel metric changes meaning.** `store_deeplink_opens` will read 0 from now on. Any dashboard that tracks lock → store conversion needs to switch to `store_viewed` (with no source) or drop that step.
4. **Conversion may drop**, because there is now no direct path from a lock to the Store. A follow-up could have the app open on the Store (or show a badge) after recent locked taps, using a shared-defaults flag the app reads. That keeps the keyboard compliant; it was not built here.
5. **Hint untranslated** in 15 locales (section 5).
6. **Tested only on an iPhone sim.** The iPad side-panel mode was not checked, but the hint is pinned to the container's top centre, independent of the overlay layout.
