# Keyboard store links on iOS 18+: result

Branch `key/opus-store-link-ios18`, based on live `478430f5` (2.1.1 build 15). Version and build numbers are unchanged.

## 1. Hypothesis: CONFIRMED (by reading the code)

Evidence at `478430f5`:

- **Toolchain:** Xcode 26.6 (17F113), iPhoneOS SDK **26.5**. The app is built with an SDK newer than iOS 18, so the iOS 18 SDK-linked behavior applies. `IPHONEOS_DEPLOYMENT_TARGET = 16.0` for all targets. The Keyboard target builds with `APPLICATION_EXTENSION_API_ONLY = YES`.
- **Helper:** `KeyboardViewController.openContainerApp(_:) -> Bool` (old line 331). It ran `NSSelectorFromString("openURL:")`, which is the legacy **one-argument** `-[UIApplication openURL:]`. The SDK header marks it `API_DEPRECATED_WITH_REPLACEMENT("openURL:options:completionHandler:", ios(2.0, 10.0))`. The helper walked the responder chain to the first object that `responds(to:)` that selector and called `perform(selector, with: url)`. It **threw away the BOOL result** and returned `true` once any responder matched. It never checked whether anything actually opened.
- **Callers:** all three used the return value to count a store open:
  - locked key, old line 620: `if let url = …source=key_lock, openContainerApp(url) { LockFunnelCounters.incrementStoreDeeplinkOpens() }`
  - locked pack in the pack picker, old line 1106: `source=pack_picker`, same pattern
  - locked conversion category, old line 1176: `source=conversion_lock`, same pattern
  - The What's New chip (old line 1211) also called it, but ignored the result.
- **Effect:** `storeDeeplinkOpens` feeds `Snapshot.analyticsAttributes["store_deeplink_opens"]`. The app flushes that into the `keyboard_lock_funnel` Firebase event (`LockFunnelCounters.flushIfNeeded`, called from `ViewController.swift:79`). On iOS 18+ the legacy call fails, so the store never opens, yet every tap was still counted as a store open. That inflated the funnel and hid the broken link.

## 2. Red

Commit `45e8952d`. The legacy logic was moved **verbatim** into a new shared file, `NumPad/Libraries/ContainerAppOpener.swift`, compiled into the app and the Keyboard target (this is what makes it testable). The only new piece is the injection seam protocol `ContainerURLOpening`. The new `NumPadTests/ContainerAppOpenerTests.swift` uses a fake responder chain. Nothing touches `UIApplication.shared` and nothing launches an app.

- `FakeApplication` models UIApplication on iOS 18+: it answers `openURL:` but the call does nothing, and only the modern path opens (with a configurable `success`).
- `LegacyOnlyResponder` answers only the legacy selector.

Red run (`-only-testing:NumPadTests/ContainerAppOpenerTests`): **TEST FAILED, 4 tests, 7 failures.**
- `testFailedOpenDoesNotCountStoreOpen`: `("1") is not equal to ("0") - a failed open must not be counted as a store open`; the legacy selector was dispatched (1 ≠ 0); the modern API was never called.
- `testLegacySelectorOnlyResponderIsNotReportedAsSuccess`: counted 1 ≠ 0, and the legacy selector was dispatched.
- `testSuccessfulOpenCountsExactlyOnceViaModernAPI`: the modern API was not used and the legacy selector was dispatched.
- `testNoOpenerInChainDoesNotCount`: passed (a control case).

## 3. Fix

Commit `1d6189e5`.

- `ContainerAppOpener.open(_:from:onOpened:)` walks the responder chain to the first `ContainerURLOpening`. `UIApplication` conforms by calling **`open(_:options: [:], completionHandler:)` directly**. No selector is used. This direct reference is allowed in an app extension: the SDK marks only `sharedApplication` as `NS_EXTENSION_UNAVAILABLE_IOS`, not `openURL:options:completionHandler:`. The Keyboard target compiled cleanly with `-application-extension`.
- `onOpened` runs **only when `success == true`** in the completion. The three lock handlers now pass `{ LockFunnelCounters.incrementStoreDeeplinkOpens() }` as `onOpened`. `incrementLockedKeyTaps()` is still counted on every tap, as before.
- Unchanged: all URLs and `source=` values, the lock and paywall checks, pricing, and monetization. There are no subscription IDs.
- One behavior difference: the counter now increments asynchronously, on the main actor, from the completion handler. The fix requires this.

## 4. Green

Full unit suite, run once:

```
UDID=$(~/bin/sim-pool checkout --wait --owner $$)
~/bin/ai-gate run --heavy -- xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination "id=$UDID" -parallel-testing-enabled NO -derivedDataPath /tmp/key-opus/p18-dd \
  -only-testing:NumPadTests
~/bin/sim-pool return $UDID
```

Result: **TEST SUCCEEDED, 312 tests, 0 failures.** All 4 `ContainerAppOpenerTests` pass. The red step used the same command with `-only-testing:NumPadTests/ContainerAppOpenerTests` and exited 65. No UI tests were run, and Settings.app was never opened. Pods were set up with `pod install --deployment`, which changed no tracked files.

## Open risks

- **A real-device check on iOS 18+ is STILL NEEDED.** The unit tests prove the reporting logic and that the modern API is called. They cannot prove that iOS actually opens `numpad://store-preview?...` from a keyboard extension through the responder-chain UIApplication. The keyboard needs Full Access on. Check all three locked entry points (key, pack picker, conversion category) and the What's New chip, and confirm the Store screen appears with the right `store_viewed` source.
- Apple could stop handing a UIApplication to keyboard extensions through the responder chain. If that happens, the helper fails safely: nothing opens and nothing is counted, with no crash and no false count.
- Historical `store_deeplink_opens` data from iOS 18+ users is inflated (it counted every locked tap). Expect a visible drop in that metric after this ships.
