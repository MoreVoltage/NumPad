# OPUS_RESULT — MOR-400: keyboard "What's New" chip can't be opened/dismissed, covers + and −

**Branch:** `key/opus-mor400-remove-chip` (local only, not pushed) · **Base:** `478430f5` (live 2.1.1 (15)) · version/build **not** bumped.
**Fix:** remove the chip from the keyboard (`git cherry-pick -x 746b52e9`). The in-app What's New sheet, the `numpad://whats-new` deep link and the one-shot 24h notification are unchanged.

## 1. Evidence: 478430f5 ships the chip
- `Keyboard/Views/WhatsNewChipView.swift`: a 28pt-tall pill labelled "What's New". Its only interaction is a tap → `whatsNewChipViewDidTap`. **It has no dismiss affordance.**
- `KeyboardViewController.installWhatsNewChip()` (`viewDidLoad`, line 140) pins it to `inputView` at top 6 / leading 8, added **after** the key grid, so it sits above the keys and takes their touches. `refreshWhatsNewChip()` runs on every appearance, on SettingsSync and on overlay dismiss. Visibility = `WhatsNew.isChipVisibleNow && !overlay && !floating`.
- Tap → `openContainerApp(URL("numpad://whats-new"))`, which walks the responder chain and calls `perform("openURL:")`.
- The chip only hides when `WhatsNew.lastSeenVersion` ≥ 2.0.3. That value is written by the **container app** (`WhatsNewViewController.present` → `markSeen`) into `UserDefaults.group` and read by the keyboard.

### The three likely causes
| # | Cause | Status |
|---|---|---|
| H3 | Chip covers the top-left keys (+ / −) | **VERIFIED (iPhone sim). iPad not run.** The red UI run found the live chip at `{8,505} 100×28`; Math-row `+` = `{0,499} 44×59.3`, `−` = `{45,499} 44×59.3`. The chip covers the top ~half of both keys and the left edge of `*`, and sits above them in z-order. See `docs/screenshots/mor400/before-478430f5-iphone17pro-ios26.5.png`. On iPad the same constraints (top 6 / leading 8 / ~100pt wide) land on the first one or two keys of the top row. That is reasoned from code, not run: **no iPad sim in the pool.** |
| H1 | "Can't be opened": `openURL:` via `perform` is a no-op on iOS 18+ | **HYPOTHESIS, unverified here.** The code path is confirmed: `UIApplication` answers `openURL:` (so `openContainerApp` returns `true`), but the deprecated selector reportedly logs "BUG IN CLIENT OF UIKIT… Force returning false" and opens nothing on iOS 18+. No iOS 18 runtime or device was available to observe it. |
| H2 | "Can't be dismissed": the keyboard never sees the container app's seen-version, so the chip never hides | **UNPROVEN HYPOTHESIS (corrected after review).** The original wording blamed the Full Access sandbox. That is not supported: Apple lets a keyboard read its shared app-group container with Full Access off. The observation (chip still visible after two app launches in one test) does not show that the sheet presented, that `markSeen` wrote the seen-version, or that the extension failed to read it. Both launches used `-skipOnboarding`, which suppresses the automatic recap sheet, so `markSeen` most likely never ran at all. What *is* established directly from the code: the chip had no dismiss action and only hid after the container app presented the sheet. |

## 2. Red (on 478430f5 + tests only), commit `test(MOR-400)`
Run: iPhone 17 Pro pool sim (sim-pool-1), iOS 26.5, `-parallel-testing-enabled NO`, via `ai-gate --heavy`.
- `NumPadTests/KeyboardWhatsNewPromotionRemovedTests` (in `WhatsNewTests.swift`): **4 tests, 7 failures**. Chip file exists; `KeyboardViewController` references `WhatsNewChip`/`installWhatsNewChip`/`refreshWhatsNewChip`/`WhatsNew.`; the pbxproj compiles `WhatsNewChipView.swift`. `testInAppSheetAndNotificationPathsRemain` passes on both sides, as intended.
  - The keyboard extension isn't linked into the app-hosted unit bundle, so these unit tests check the source files. The live behaviour is covered by the UI test below.
- `NumPadUITests/ScreenshotCaptureTests/testMOR400_mathRowPlusMinusUnobstructed`: **failed** with `a What's New promotion is on the keyboard: Button {{8.0, 505.0}, {100.0, 28.0}}, label: 'What's New. Opens NumPad to see this update and turn on a reminder.'`

## 3. Fix, commit `Remove persistent What's New promotion from the keyboard` (cherry-picked from 746b52e9, `-x`)
- Applied with **no conflicts**. It deletes `WhatsNewChipView.swift` and its pbxproj entries, removes the install/refresh/tap/overlay-hide code from `KeyboardViewController`, removes `WhatsNew.isChipVisible[Now]` and the chip test, and drops the chip bullet from the sheet.
- **Not touched:** live-math chip (`MathPreviewChipView`/`installMathPreviewChip`), converter, `openContainerApp`.
- The sheet bullet string is its own `NSLocalizedString` key. It had no translations in any `.strings`, so no locale regresses.
- Still in place: `WhatsNewViewController.presentIfNeeded/present`, `WhatsNew.shouldPresent/markSeen/matchesDeepLink`, `WhatsNewNotification` + tap handler, the `whats-new` deep-link route. These are covered by the existing gate, deep-link and notification tests plus `testInAppSheetAndNotificationPathsRemain`.

## 4. Green
- Full unit suite (`-only-testing:NumPadTests`): **311 tests, 0 failures**.
- MOR-400 UI test: **passed**. No "What's New" element on the keyboard; `+` and `−` are hittable, and tapping them typed `+-` into the field.
- `** TEST SUCCEEDED **`, xcodebuild exit 0. DerivedData `/tmp/key-opus/p15-dd`. The pool sim was returned after every run.
- Screenshot (after): `docs/screenshots/mor400/after-cherry-pick-iphone17pro-ios26.5.png`. The Math top row `+ - * / = % # $ (` is unobstructed.
- **No iPad simulator in the pool** (both pool sims are iPhone 17 Pro / iOS 26.5). None was created, and the iPad layout was not exercised.

## Open risks / follow-ups
1. **Physical iPad on iOS 18 check still needed.** Confirm that the top row is clear on iPad (the reported device) and, separately, observe H1 (`openURL:` no-op) on iOS 18.
2. **Same `openContainerApp` helper elsewhere:** the locked-key, pack-picker and conversion-lock store deep links (`KeyboardViewController` ~lines 620/1106/1176) use the same `perform("openURL:")` responder trick. If H1 holds, those upsell links are also dead on iOS 18+. Out of scope here; worth its own issue.
3. H2 is an unproven hypothesis (see the corrected table row). Full Access off does not block app-group reads, so it is not evidence of a broader container-read problem. No longer relevant to What's New after this fix.
4. As committed at `c5a9dbdc`, the UI test called `launchNumPadOnTypingSurface`, whose `ensureKeyboardEnabled()` opens Settings and adds NumPad when it is absent, so it could change a pool sim's settings. Fixed in the MOR-400 nits follow-up (read-only preflight + `XCTSkip`); see `OPUS_RESULT_MOR400_NITS.md`.
5. `pod install --deployment` was run (Pods/ is gitignored; no tracked files changed).

## Commits (local, unpushed)
- `test(MOR-400): keyboard must carry no What's New chip over + / −` (red tests + before screenshot)
- `Remove persistent What's New promotion from the keyboard` (cherry picked from commit 746b52e9…)
- `docs(MOR-400): result report + after screenshot`
