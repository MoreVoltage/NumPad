# NumPad Codebase Review — Bugs, Errors, and Modernization Plan

## PART 1: BUGS AND ERRORS (Fix Immediately)

### BUG-1: Debug colors shipped in ClipboardHistoryView
**File:** `Keyboard/Views/ClipboardHistoryView.swift`
**Lines:** 18, 24, 66
**Severity:** High (user-visible)
**Issue:** Debug background colors (`backgroundColor = .red`, `countLabel.backgroundColor = .yellow`) and debug text ("Clipboard Items: N") were left in. Users see a bright red clipboard overlay with yellow label background.
**Fix:** Change background to `.systemBackground`, remove yellow background, change count label to just "Clipboard History".

### BUG-2: Hardcoded `.black` text color in ClipboardHistoryView
**File:** `Keyboard/Views/ClipboardHistoryView.swift`
**Line:** 92
**Severity:** Medium (dark mode broken)
**Issue:** `cell.textLabel?.textColor = .black` — text is invisible in dark mode.
**Fix:** Change to `.label` (adaptive color).

### BUG-3: Missing SettingsSync.post() after pack selection
**File:** `NumPad/Controllers/PacksViewController.swift`
**Lines:** 93-95
**Severity:** High (keyboard doesn't update)
**Issue:** When the user selects a new keyboard pack, `SettingsSync.post()` is never called. The keyboard extension won't pick up the change until next launch.
**Fix:** Add `SettingsSync.post()` after `KeyboardType.selected = ...`.

### BUG-4: Missing SettingsSync.post() in StoreViewController
**File:** `NumPad/Controllers/StoreViewController.swift`
**Lines:** 42-53, 64-81
**Severity:** Medium (keyboard doesn't reflect flag/pref changes)
**Issue:** Toggling paywall, pro entitlement, haptics, sound, and repurpose-next-key doesn't notify the keyboard extension.
**Fix:** Add `SettingsSync.post()` in each `valueChanged` closure.

### BUG-5: SettingsSync observer never removed in PacksViewController
**File:** `NumPad/Controllers/PacksViewController.swift`
**Line:** 43
**Severity:** Medium (memory leak + potential crash)
**Issue:** `SettingsSync.observe(self)` is called but `SettingsSync.remove(self)` is never called. After the VC is deallocated, the Darwin notification callback fires on a stale pointer stored in `settingsSyncHandlers`.
**Fix:** Add a `deinit` that calls `SettingsSync.remove(self)`.

### BUG-6: Unsafe `[unowned self]` in splash animation
**File:** `NumPad/Controllers/Base/ViewController.swift`
**Line:** 55
**Severity:** Low-Medium (crash if VC deallocated during animation)
**Issue:** `splashView.startAnimation() { [unowned self] in` — if the view controller is deallocated before the animation callback fires (edge case), this crashes.
**Fix:** Change to `[weak self]` with optional chaining.

### BUG-7: NotificationCenter observer never removed
**File:** `NumPad/Controllers/Base/ViewController.swift`
**Line:** 67
**Severity:** Low (resource leak)
**Issue:** `NotificationCenter.default.addObserver(forName: .didBecomeActiveNotification...)` — the returned observer token is discarded. The observer is never removed.
**Fix:** Store the token and remove it in `deinit`.

### BUG-8: Duplicate CFBundleURLTypes in Info.plist
**File:** `NumPad/Info.plist`
**Lines:** 5-15, 30-40
**Severity:** Low (benign but incorrect)
**Issue:** The `CFBundleURLTypes` key appears twice. The second entry overwrites the first. Both define the same `numpad` scheme, so it works but is technically invalid.
**Fix:** Remove the first occurrence (lines 5-15), keeping the more complete entry with `CFBundleTypeRole`.

### BUG-9: StackView cell search doesn't find pack row cells inside UIScrollView
**File:** `Keyboard/Views/StackView.swift`
**Lines:** 110, 120-124
**Severity:** Medium (pan-to-select broken on pack row)
**Issue:** The `cells` lazy var uses `arrangedSubviews(of: Cell.self)` which recurses only into `UIStackView` children. The pack row's inner stack is wrapped in a `UIScrollView` (line 31-43), so those cells are never found. Consequently, the pan gesture recognizer in `KeyboardViewController.panned()` doesn't highlight or activate pack row keys.
**Fix:** Extend the recursive search to also look inside `UIScrollView` subviews.

---

## PART 2: CODE CLEANUP (Non-breaking improvements)

### CLEAN-1: Remove unnecessary `UserDefaults.synchronize()` calls
**Files:** `SharedExtensions.swift:184`, `KeyboardViewController.swift:267`, `KeyboardHeightViewController.swift:173`
**Issue:** `synchronize()` has been unnecessary since iOS 12+ — the system handles flushing automatically.
**Fix:** Remove all 3 calls.

### CLEAN-2: Remove NSClassFromString workaround for haptics
**File:** `Keyboard/Views/Button.swift`
**Lines:** 45-48
**Issue:** `NSClassFromString("UIImpactFeedbackGenerator")` was needed for iOS 9 compatibility. Since min deployment is iOS 14, `UIImpactFeedbackGenerator` is always available.
**Fix:** Use `UIImpactFeedbackGenerator()` directly.

### CLEAN-3: Remove dead `#available(iOS 11.0, *)` check
**File:** `NumPad/Controllers/SnippetsViewController.swift`
**Lines:** 97-101
**Issue:** Always true since min target is iOS 14.
**Fix:** Remove the `if #available` wrapper, keep the contents.

### CLEAN-4: Dead code — LiveHeightMessenger files
**Files:** `NumPad/Libraries/LiveHeightMessenger.swift`, `Keyboard/Libraries/LiveHeightMessenger.swift`
**Issue:** These file-based messenger classes (`LiveHeightMessenger`) appear unused. The actual live height communication uses `NPLiveHeightMessenger` from `SharedExtensions.swift`. The duplicated `LiveHeightMessage` struct also conflicts with the same name in both target copies. Review whether these are actually compiled and used; if not, remove.

### CLEAN-5: Commented-out color code block
**File:** `NumPad/Libraries/SharedExtensions.swift`
**Lines:** 73-103
**Issue:** ~30 lines of commented-out dark/light theme color variants. Dead code clutter.
**Fix:** Remove the commented-out block.

### CLEAN-6: Remove excessive `print()` debug statements
**Files:** Multiple (KeyboardViewController, KeyboardHeightViewController, TableViewController)
**Issue:** Numerous `print("[KB][Height]...")` debug statements throughout the codebase. These should use `os_log` or be removed for production.
**Fix:** Either remove or replace with `os_log` behind a debug flag.

---

## PART 3: iOS MODERNIZATION (with backward compatibility)

These improvements take advantage of newer iOS APIs. Since the minimum deployment target is iOS 14, many "modern" APIs are available unconditionally. For iOS 15+/16+/17+ features, `if #available` guards preserve backward compatibility.

### MOD-1: Replace `@UIApplicationMain` with `@main`
**File:** `AppDelegate.swift:13`
**Scope:** Unconditional (Swift 5.3+)
**Why:** `@UIApplicationMain` is deprecated in favor of `@main`.
**Backward compat:** N/A — purely compile-time, no runtime impact.

### MOD-2: Replace deprecated UINavigationBar appearance API
**File:** `AppDelegate.swift:58-61`
**Scope:** Unconditional (UINavigationBarAppearance is iOS 13+)
**Issue:** `setBackgroundImage(_:for:)` and `shadowImage` are deprecated in iOS 15.
**Fix:**
```swift
let appearance = UINavigationBarAppearance()
appearance.configureWithOpaqueBackground()
appearance.backgroundColor = .primary
appearance.shadowColor = nil
appearance.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.preferredFont(for: .body, weight: .bold)]
UINavigationBar.appearance().standardAppearance = appearance
UINavigationBar.appearance().scrollEdgeAppearance = appearance
UINavigationBar.appearance().tintColor = .white
```
**Backward compat:** `UINavigationBarAppearance` exists since iOS 13, so no guard needed.

### MOD-3: Replace deprecated `traitCollectionDidChange` (iOS 17+)
**File:** `KeyboardHeightViewController.swift:39-42`
**Scope:** Conditional (`if #available(iOS 17, *)`)
**Fix:** Use `registerForTraitChanges([UITraitVerticalSizeClass.self, UITraitUserInterfaceIdiom.self])` in `viewDidLoad`, with the existing `traitCollectionDidChange` as fallback.
**Backward compat:** `#available(iOS 17, *)` guard; fallback to existing code on iOS 14-16.

### MOD-4: Replace deprecated `showsTouchWhenHighlighted`
**File:** `Keyboard/Views/Cell.swift:40`
**Scope:** Unconditional
**Fix:** Remove the line (it's set to `false` anyway, which is the default).

### MOD-5: Replace deprecated `textLabel` / `detailTextLabel` / `imageView` on UITableViewCell
**Scope:** All table view controllers
**Priority:** Low (large refactor) — consider for a future pass
**Issue:** These properties are deprecated since iOS 14 in favor of `UIListContentConfiguration`. However, since the custom `Cell` class overrides `imageView` with a custom property and manages its own layout, these still function correctly.
**Recommendation:** Document as a future task. The current implementation works but won't benefit from new system styling. A migration would touch every VC.
**Backward compat:** `UIListContentConfiguration` is iOS 14+, so no guard needed if done.

### MOD-6: Adopt UIScene lifecycle
**File:** `AppDelegate.swift`
**Priority:** Medium
**Issue:** Still uses the legacy `var window: UIWindow?` app lifecycle. Adopting `UIWindowSceneDelegate` enables proper multi-window support on iPad and better lifecycle management.
**Recommendation:** Add a `SceneDelegate.swift` with `if #available(iOS 13, *)` support (which is always true). Move window creation there. Keep AppDelegate for backward scenarios.
**Backward compat:** No guard needed (iOS 13+).

### MOD-7: Adopt `UIAction`-based button/control handling (iOS 14+)
**Scope:** Various view controllers
**Priority:** Low
**Issue:** Target-action with `@objc` selectors can be replaced with `UIAction` closures for type safety and less boilerplate.
**Backward compat:** Unconditional (iOS 14+).

### MOD-8: Use `UIPasteControl` or handle paste permission banner (iOS 16+)
**File:** `Keyboard/Views/ClipboardHistoryView.swift`
**Priority:** Medium
**Issue:** Starting iOS 16, accessing `UIPasteboard.general.string` triggers a system permission banner. Users may deny access. The clipboard history feature should handle this gracefully.
**Fix:** Wrap clipboard access in a `if #available(iOS 16, *)` check and handle the permission state; fall back to direct access on older iOS.

### MOD-9: Support Dynamic Type in keyboard extension
**Files:** `Keyboard/Libraries/Extensions.swift:85-92`
**Priority:** Low
**Issue:** Font sizes (`.numbers = 27pt`, `.text = 14pt`) are hardcoded. For accessibility, these could scale with Dynamic Type.
**Fix:** Use `UIFontMetrics` to scale the base sizes. Already done correctly in the app target's `Extensions.swift:60-65`.

### MOD-10: Improve keyboard height handling for iOS 16+ changes
**Files:** `KeyboardViewController.swift` height management
**Priority:** Medium
**Issue:** iOS 16 changed how custom keyboard height constraints interact with the system. The current approach of a `.required` priority height constraint may conflict with system-imposed constraints in some configurations.
**Fix:** Test on iOS 16+ devices/simulators and potentially lower the priority to `.defaultHigh` or use `inputView?.allowsSelfSizing = true` (iOS 16+).

---

## PART 4: IMPLEMENTATION ORDER

### Phase 1 — Critical Bugs (Do Now)
1. BUG-1: Fix debug colors in ClipboardHistoryView
2. BUG-2: Fix dark mode text color in ClipboardHistoryView
3. BUG-3: Add SettingsSync.post() in PacksViewController
4. BUG-4: Add SettingsSync.post() in StoreViewController
5. BUG-5: Add deinit with SettingsSync.remove() in PacksViewController
6. BUG-9: Fix StackView cell search to traverse UIScrollView

### Phase 2 — Safety & Correctness
7. BUG-6: Fix unowned self in splash animation
8. BUG-7: Store and remove NotificationCenter observer
9. BUG-8: Remove duplicate CFBundleURLTypes

### Phase 3 — Cleanup
10. CLEAN-1: Remove synchronize() calls
11. CLEAN-2: Simplify haptics code
12. CLEAN-3: Remove dead availability check
13. CLEAN-5: Remove commented-out color code
14. CLEAN-6: Replace debug prints with os_log or remove

### Phase 4 — Modernization (iOS APIs) ✅
15. MOD-1: @main attribute ✅
16. MOD-2: UINavigationBarAppearance ✅
17. MOD-3: traitCollectionDidChange (iOS 17 guard) ✅
18. MOD-4: Remove showsTouchWhenHighlighted ✅
19. MOD-6: UIScene lifecycle (SceneDelegate) ✅
20. MOD-8: UIPasteboard iOS 16 handling (clipboard capture + graceful denial) ✅
21. MOD-9: Dynamic Type support in keyboard extension fonts ✅
22. MOD-10: Height constraint priority lowered to .defaultHigh for iOS 16+ ✅

### Phase 5 — Cleanup (additional) ✅
23. CLEAN-4: Remove dead LiveHeightMessenger files from both targets ✅
24. CLEAN-6: Remove all debug print() statements ✅

### Future Work (deferred — requires min deployment bump to iOS 16+)
- **MOD-5**: Migrate `textLabel`/`detailTextLabel`/`imageView` to `UIListContentConfiguration`.
  Requires `UIListContentConfiguration.valueCell()` (iOS 16+) for value1-style cells used in
  HomeViewController and StoreViewController. The current deprecated properties still function
  correctly. Migrate when minimum deployment target is bumped to iOS 16.
- **MOD-7**: Replace target-action `@objc` selectors with `UIAction` closures (iOS 14+).
  Low priority; current pattern works fine.
