# Result: locked-tap -> Store handoff (draft, on top of PR #20)

Branch `key/opus-store-handoff` (local only, not pushed), based on PR #20 head `ec86b2d4`.

## Precondition check
Both targets share an App Group, so the work went ahead:
- `NumPad/NumPad.entitlements` and `Keyboard/Keyboard.entitlements` both list `group.morevoltage.numpad.container`.
- `UserDefaults.group` (`SharedExtensions.swift`) is that suite, and both targets compile it.
- No entitlements were changed.

## Design
**In the keyboard.** Every locked tap goes through `LockedTapResponse.handle`. It already counts the tap and shows the hint. It now also calls `StoreHandoffStore.record(source:pack:)`, which overwrites one dictionary in the group defaults under `Constants.storeHandoffRecord`. The dictionary holds:
- `t`: epoch seconds
- `s`: the Store source string
- `p`: the pack raw value, when known

The latest tap overwrites any earlier one. The pack is filled in for key taps (`effectiveKeyboardType`) and pack-picker taps (the picked type). It is `nil` for converter taps, because the converter delegate does not say which pack the category belongs to. The keyboard still does not open a URL or deep link, and it does not bump `storeDeeplinkOpens`. The PR #20 source audit still passes.

**In the app.** `ViewController.presentStoreHandoffIfNeeded()` runs at two points:
- on every `didBecomeActive`, right after `handlePendingDeepLink()`
- at the end of `finishLaunch()`, after `launchFinished = true`, which covers a cold launch

It calls the pure `StoreHandoff.consume`, which decides as follows:

| Record state | Decision | Record |
|---|---|---|
| none | nothing | — |
| malformed | nothing | cleared |
| older than the window, or timestamp in the future | discard | cleared |
| item no longer locked (entitled / paywall off) | discard | cleared |
| a Store is already in the nav stack | discard (goal already met) | cleared |
| fresh and locked, but app not ready (launch not finished, a modal is up, a deep link is pending, or UI-test `-skipOnboarding`) | wait | **kept** for a later foreground inside the window |
| fresh, locked, app ready | push the existing `StoreViewController` with `source` = `key_lock` / `pack_picker` / `conversion_lock` | cleared |

These source strings are the ones the Store already uses for hero copy and for the `store_viewed` analytics source. There are no new products, prices, SKUs, analytics events or copy.

**What "still locked" means:**
- Paywall off: never locked.
- A pack was recorded: `Monetization.isLocked(pack:)`.
- Converter tap with no pack: locked if Units or Cooking is locked.
- Anything else: `!isProEntitled`.

**Window: 10 minutes** (`StoreHandoff.window`). The real path is: see the hint, leave the host app, find NumPad and open it. That can include finishing a sentence or a short interruption. Ten minutes covers that comfortably. It also stays well short of the user opening NumPad much later for something else, when an unrequested Store would feel like an ad instead of a continuation of what they just tried.

**No double Store.** The three delayed (0.6 s) upsell pushes are: early-bird first-run, new-buyer first-run and session milestone. Each now also requires `!isStoreInNavigationStack`. A handoff push on the same foreground therefore suppresses them, and their one-shot flags are not used up.

## Files
- `NumPad/Libraries/StoreHandoff.swift` (new, both targets): source mapping, `StoreHandoffRecord`, `StoreHandoffStore` (injected defaults and clock), `StoreHandoffContext`, `StoreHandoffDecision`, `StoreHandoff.decide/consume/isStillLocked`.
- `NumPad/Libraries/LockedTapResponse.swift`: writes the record. Adds an optional `pack:` parameter to both entry points and a test-swappable `handoffStore`.
- `NumPad/Libraries/SharedExtensions.swift`: `Constants.storeHandoffRecord`.
- `Keyboard/KeyboardViewController.swift`: passes `pack:` at the key-tap and pack-picker call sites.
- `NumPad/Controllers/Base/ViewController.swift`: `presentStoreHandoffIfNeeded()`, `isStoreInNavigationStack`, and the upsell guards.
- `NumPad.xcodeproj/project.pbxproj`: registers the new source (App + Keyboard) and the new test file.
- `NumPadTests/StoreHandoffTests.swift` (new, 26 tests).
- `NumPadTests/LockedTapResponseTests.swift`: forwarding fixtures updated for `pack:`. Its tests now use a throwaway defaults suite so they don't write into the real App Group.

## Localization
No new user-visible strings. No locales are missing.

## Red / green
- **Red:** `build-for-testing` failed with exit 65. The errors were `cannot find type 'StoreHandoffRecord' / 'StoreHandoffStore' / 'StoreHandoffContext' in scope` in `StoreHandoffTests.swift` (log `/tmp/key-opus/p25-red.log`).
- **Green:** the full NumPadTests unit suite ran once. **350 tests, 0 failures, `** TEST SUCCEEDED **`, exit 0** (log `/tmp/key-opus/p25-green.log`). All 26 StoreHandoffTests and all LockedTapResponseTests passed, including the source audit and the forwarding mutation checks.

The tests cover:
- record write: with a pack, without a pack, latest wins, malformed data, each entry point, and an unlocked tap writing nothing
- window: exact edge, expired, future timestamp
- single consumption, and stale/entitled/malformed records being cleared
- waiting while the app is busy, then presenting
- skipping when a Store is already visible
- entitlement mapping: paywall off, pack-specific, converter, Pro fallback
- source names matching the Store's existing lock sources

## Commands
```
pod install --deployment          # Pods/ was missing; no tracked files changed
UDID=$(~/bin/sim-pool checkout --wait --owner $$)
~/bin/ai-gate run --heavy -- xcodebuild build-for-testing -workspace NumPad.xcworkspace -scheme NumPad \
  -destination "id=$UDID" -derivedDataPath /tmp/key-opus/p25-dd -parallel-testing-enabled NO      # red
~/bin/ai-gate run --heavy -- xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination "id=$UDID" -derivedDataPath /tmp/key-opus/p25-dd -parallel-testing-enabled NO \
  -only-testing:NumPadTests                                                                     # green
~/bin/sim-pool return $UDID       # done after each run
```

## Commits
- `2eacb5de` feat: hand a locked keyboard tap over to the Store on next app open
- this report (docs commit)

## Open risks / follow-ups
- **App Review (4.4.1 / 5.1.1).** The keyboard still never launches the app. The record holds only a timestamp, a lock source and a pack id. It contains no typed text and nothing about the host app, and it stays on device inside the App Group. The Store is reached only because the user opened NumPad themselves, and only once. I don't see a 4.4.1 issue.
  - A reviewer could still read an automatic Store on launch as an unsolicited upsell. Mitigations: the 10-minute window, a single presentation, and the item-still-locked check.
  - If you want to be more conservative: shorten the window, or add a Remote Config kill switch. Neither is done here.
- **Locked tap in the app's own demo field.** The NumPad keyboard can be used inside NumPad itself. A locked tap there writes a record. The app is already active, so nothing happens immediately. If the user backgrounds the app and returns within 10 minutes, the Store opens once. That is arguably still the right "continue what you tried" behavior, but it is untested on a device.
- **Converter taps don't record a pack.** "Still locked" falls back to "Units or Cooking is locked". So a user who owns Units, taps a locked Cooking category, and then buys nothing still gets the Store, which is intended. Precision is coarse only for the converter.
- **Small race.** If the keyboard writes a new record between the app's read and its clear, that new record is lost. This needs a locked tap in another process at the same moment the app comes to the foreground. The only effect is one missed handoff.
- **What's New.** The What's New sheet (1.0 s delay) could still present modally over a handoff Store. That is the same as the existing deep-link Store behavior and was not changed.
- **Entitlement freshness.** Entitlements are read from the cached group flags at foreground. `refreshEntitlementsOnForeground` runs asynchronously. A purchase made on another device moments earlier could still show the Store once, and the Store then shows the owned state.
- **No device or UI test pass.** Only the unit suite ran. The presentation path in `ViewController` (cold launch vs. warm foreground, onboarding up) needs a manual device check.
- Version/build, pricing, StoreKit products, monetization rules and converter logic are unchanged. No subscription IDs were added.
