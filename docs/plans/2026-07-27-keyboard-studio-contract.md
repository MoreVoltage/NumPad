# Keyboard Studio redesign — implementation contract

Branch: `codex/keyboard-studio-ux` · Worktree: `/Users/jamespikover/NumPad-studio` · Base: `0f584a2c`

Primary visual reference: `/tmp/numpad-ux-concepts/.superpowers/brainstorm/8532-1785175219/content/keyboard-studio-full-storyboard-restored.html`

## 0. Environment facts (verified, not assumed)

| Fact | Value | Note |
|---|---|---|
| Deployment target | **iOS 16.0** | `AGENTS.md` says 15.0 — it is **stale**. `project.pbxproj` says 16.0 everywhere. Do not lower it. |
| Xcode project | objectVersion 54, explicit file refs | **No** synchronized root groups → every new `.swift` must be registered. |
| File registration | `ruby scripts/add_sources.rb <target>[,<target>] <paths...>` | Lead agent runs this centrally. Agents must NOT edit `project.pbxproj`. |
| UI framework | UIKit, plus pre-existing SwiftUI islands | Custom Keyboard editor is already SwiftUI. Do not migrate anything else; do not delete the islands. |
| Simulator destinations | must use `id=`, **not** `name=` | `name=` + implicit `OS:latest` fails: sims are OS 26.5. |

### Simulator IDs (verified available)

| Role | Name | id |
|---|---|---|
| Compact iPhone | Shots-5.8 | `8B07966E-F68B-463C-81DE-956317AF67C5` |
| Standard iPhone | QA-iPhone17 | `37B2DC99-7B78-441D-9F09-220DA1D51CDD` |
| Large iPhone | Shots-6.9 | `E4A85493-77E0-4454-93D9-AECFB2CE3C01` |
| iPad (regression only) | QA-iPad-Pro-13 | `5B976E69-A682-4406-BCFD-BCA93FC96352` |

## 1. Approved information architecture

Three bottom tabs + a gear that opens Advanced modally.

```
TabBar
├── Keyboard  → Studio home (DEFAULT destination)
│     ├── Appearance          (theme tiles, match-dark-mode, rounded keys, key grid)
│     ├── Choose keys         (6 plain-language key sets + custom path)
│     ├── Size & feel         (height, number order, haptics, sound, cursor control)
│     └── Letters             (QWERTY — only when the RC gate + entitlement permit)
├── Features  → Feature gallery
│     ├── Calculator tools    (live answer, result tape, insert result, tax/tip)
│     ├── Reusable text       (clipboard + snippets, Full Access explainer)
│     │     └── Snippets      (list: empty/populated/search/add/edit/delete)
│     └── Custom keys         (Pro; live preview + direct edit + reorder)
└── Help     → Setup status (ready / needs-attention / unavailable)
      ├── Using NumPad        (task guides)
      ├── Privacy & Full Access
      └── Support             (feedback, rating, restore, version, policy)

Gear (⚙, from Studio) → Advanced (purple-tinted secondary identity)
      ├── Saved setups        (was: Profiles)
      │     └── Setup detail  (preview + explicit change list + apply / copy)
      ├── Kiosk mode          (guided readiness, no "provisioning" language)
      ├── Move setups         (import + export combined)
      └── Managed settings    (ONLY when managed config actually exists)
```

Pro is **never** a tab. It is a focused sheet reached from a locked feature or a deliberate entry.

### Removed from the ordinary top level
Dashboard (dead), Profiles, Kiosk Provisioning, standalone Theme row, standalone Keyboard Packs row,
standalone Keyboard Height row, generic "Features & Guide", corporate/provisioning terminology,
dead destinations, redundant duplicate paths.
**Underlying functionality is preserved** — only relocated behind progressive disclosure.

## 2. Key-set naming map (user-facing ⇄ internal)

Internal `KeyboardType` identities are **preserved**; only presentation changes.

| User-facing label | Description shown | Internal pack |
|---|---|---|
| Numbers | Clean number entry with basic symbols | `.default` |
| Calculations | Operators, percent, parentheses | `.math` / `.math2` |
| Prices | Currency symbols and finance keys | `.finance` |
| Measurements | Units and quick conversions | `.units` |
| Symbols | Common punctuation and marks | `.symbols` |
| Programming | Hex and bitwise operators | `.programmer` |

`.cooking` and `.datetime` remain reachable; decode-only leftovers
(`.scientific`/`.business`/`.international`/`.programmerPlus`) stay non-selectable.

## 3. Built-in saved-setup descriptions (plain language, stable IDs)

Identifiers must NOT change — only display name + description.

| Display name | Explicit effects shown to the user |
|---|---|
| Everyday numbers | A clean NumPad for forms, codes, and ordinary number entry |
| Calculator | Math operators, calculator number order, regular-height keys |
| Prices & payments | Currency and finance keys |
| Measurements | Units and conversion keys |
| Writing | Letters page and suggestions — **only listed when the gate permits** |
| Easy to see | Taller, high-contrast keys with stronger sound and vibration |
| Kiosk | Shared-use setup that clears session state after inactivity |

Setup detail must list exactly which choices change, and preview the result.

## 4. Copy rules

- Outcome language, never implementation terms. No "pack", "profile", "provisioning", "MDM",
  "kill switch", "remote config", "entitlement", "app group" in user-facing text.
- "Adds currency symbols" ✓ / "Finance profile" ✗.
- Never claim the app can reliably read Full Access state.
- Never claim NumPad can enable Guided Access itself.
- Autocorrect is **off by default** and must never be described as on.
- **No Glide** implementation and no Glide promises anywhere.
- Do not hardcode a price — read the localized price from StoreKit.

## 5. Non-negotiable preservation list

Settings writes go to `UserDefaults.group` and **must** call `SettingsSync.post()` when the
extension needs to react. Preserve: StoreKit 2 purchase/restore/grandfathering, Remote Config
gates, the QWERTY kill switch, deep links (old routes must still land somewhere valid),
localization tables (16 app + keyboard), privacy manifests, app-group behaviour, keyboard
extension memory limits, profile/kiosk transactional apply + rollback + admin auth,
import signature/schema/entitlement validation.

## 6. Accessibility bar (every screen)

Dynamic Type to accessibility sizes without clipping · VoiceOver label/value/traits/hints ·
logical reading order · ≥44×44pt targets · sufficient contrast · Reduce Motion · Bold Text ·
RTL via leading/trailing anchors · portrait + landscape · long localized strings.
**State is never communicated by color alone** — readiness, selection, lock, and error each
carry a glyph and/or text in addition to color.

## 7. Analytics

Add/update: onboarding step viewed + completed · studio opened · quick change opened ·
key set selected · feature detail opened · advanced opened · saved setup applied ·
repair action opened · pro sheet source.
Remove events tied only to deleted navigation.
**Never** log typed content, snippets, clipboard contents, or imported setup contents.

## 8. iPad contract (owner-approved 2026-07-29)

The iPad design is now approved and is part of this implementation.

- Use the additional width for a two-region Studio: a spacious keyboard canvas/preview and a
  contextual inspector. Do not stretch the iPhone card list edge-to-edge.
- Keep the keyboard preview **permanently visible and physically anchored to the bottom** of the
  available app window. The only exception is an explicitly labelled visual sample inside a
  chooser. Scrolling content must end above the dock and must never carry the dock with it.
- Landscape/regular width: canvas and inspector sit side-by-side above the dock.
- Portrait or narrower multitasking widths: controls become a single scrollable column above the
  dock; the dock remains fixed. At very narrow widths, fall back to the phone presentation.
- The preview uses a centered NumPad with useful side rails when width permits. Placement follows
  the existing Automatic/Left/Center/Right preference and falls back safely in split view.
- The Keyboard, Features, and Help information architecture remains identical across idioms.
  iPad may use a sidebar/inspector presentation, but it must not expose a second product model.
- On first install on iPad, ask which keyboard height the user prefers and show honest visual
  samples for Compact, Regular, Tall, and Kiosk.
- Kiosk height and Kiosk mode are Pro features. Locked selection opens the existing StoreKit-backed
  Pro surface; it does not write Kiosk state before entitlement succeeds.
- Kiosk copy remains plain-language and honest: NumPad can prepare a shared-use setup but cannot
  enable Guided Access itself.
- Reuse shared design tokens, keyboard preview models, feature cards, status presentation, and
  Advanced destinations. Do not duplicate settings or entitlement logic by idiom.

## 9. Verification gates (all must pass before completion is claimed)

- [ ] `git diff --check` clean; worktree contains only intended changes
- [ ] Full unit suite green (with exact counts recorded)
- [ ] Signed iPhone simulator UI matrix green (signing must NOT be disabled for app-group tests)
- [ ] iPad tests green or honestly justified
- [ ] Generic iOS **Release** build passes — NumPad target
- [ ] Generic iOS **Release** build passes — Keyboard target
- [ ] All localization tables parse (`plutil`/`plistutil` on every `.strings`)
- [ ] All plists + privacy manifests parse
- [ ] Privacy policy copies stay synchronized
- [ ] Autocorrect still default-off
- [ ] QWERTY still safely gateable (gate off ⇒ safe fallback)
- [ ] No Glide code or promises added
- [ ] No archive / upload / App Store Connect action taken
- [ ] Remaining physical-device + translation-review gates documented

## 10. Baseline (recorded before any change)

Recorded in `docs/release/2026-07-27-keyboard-studio-evidence.md` as work proceeds.

---

# Wave 0 audit results (verified against source)

## A. Root lifecycle — the single insertion point

Root VC comes from **Main.storyboard** via `SceneDelegate.swift:19-29` → `InteractiveNavigationController`
wrapping `ViewController`. `ViewController` is a *lifecycle coordinator*, not a settings screen.

- `ViewController.installContentShell()` (`Controllers/Base/ViewController.swift:45`) is the **one place**
  the shell is chosen. Idempotent (`guard tableView == nil, iPadSplit == nil`).
  - `.pad` → `IPadSettingsSplitViewController()` and returns early (:47-53)
  - else → `HomeViewController.instantiate()` + a phone-only demo `UITextField` (:54-85)
- `ViewController.preferredContentShellIdiom` (:41) is the **existing test seam** — override to force a branch.
- `PhoneShellViewController` does **not** exist in app source; it is a test-only subclass in
  `NumPadTests/IPadLaunchOrchestrationTests.swift:104`. The real phone shell is `HomeViewController`.
- `HomeViewController`, `ThemeViewController`, `InstructionsViewController` are **storyboard-instantiated**
  (`.instantiate()`) — they cannot simply be `init()`-ed.

**Plan:** the 3-tab shell replaces the phone branch of `installContentShell()`. Leave the `.pad` branch
alone (iPad stop-line).

## B. Current destinations — the 19 to replace

`Libraries/Settings/HomeSettingsModel.swift` — `enum SettingsDestination` (19 cases),
`HomeSection.ID` (`dashboard, keyboard, typingBehavior, content, account, help`),
`static func sections(fullKeyboardVisible:isPad:) -> [HomeSection]`.

16 rows min (phone, flag off) · 17 (phone + full keyboard) · 17 (iPad) · 18 (iPad + full keyboard).

| Row | Destination | Fate in redesign |
|---|---|---|
| `.dashboard` | **phone no-op** (`break`, HomeViewController.swift:211) | DELETE — this is the dead row |
| `.profiles` | `ProfilesViewController()` | → Advanced ▸ Saved setups |
| `.keyboardSetup` | `InstructionsViewController.instantiate()` | → Help ▸ repair / setup guide |
| `.theme` | `ThemeViewController.instantiate()` | → Keyboard ▸ Appearance |
| `.packs` | `PacksViewController()` | → Keyboard ▸ Choose keys |
| `.height` | `KeyboardHeightViewController()` | → Keyboard ▸ Size & feel |
| `.numberOrder` | inline `SwitchCell` → `Keyboard.isReversedMode` | → Keyboard ▸ Size & feel |
| `.roundedCorners` | inline → `Keyboard.hasRoundedCorners` | → Keyboard ▸ Appearance |
| `.grid` | inline → `Keyboard.hasGrid` | → Keyboard ▸ Appearance |
| `.customKeyboard` | `CustomKeyboardEditorViewController()` | → Features ▸ Custom keys |
| `.qwerty` *(iff `FeatureFlags.isFullKeyboardActive`)* | `QwertySetupViewController()` | → Keyboard ▸ Letters |
| `.typingBehavior` | `TypingBehaviorViewController()` | → split: Size&feel + Features ▸ Calculator tools |
| `.snippets` | `SnippetsViewController()` | → Features ▸ Reusable text ▸ Snippets |
| `.pro` | `StoreViewController()` (`source="home"`) | → Pro **sheet** only, never a tab |
| `.privacy` | `PrivacyViewController()` | → Help ▸ Privacy & Full Access |
| `.featureGuide` | `FeaturesGuideViewController()` | → Help ▸ Using NumPad |
| `.feedback` | `mailto:` — no VC | → Help ▸ Support |
| `.rate` | `SwiftRater.rateApp` — no VC | → Help ▸ Support |
| `.kioskProvisioning` *(iff `isPad`)* | `KioskProvisioningViewController()` | → Advanced ▸ Kiosk mode |

`CustomKeysViewController` has **no app call site** — orphan.
`DashboardViewController` is the iPad split's secondary root; its `Row` enum is
`readiness, keyboardStatus, activeProfile, fullAccess, fallbacks, tryIt, profiles, kiosk`.

### Hard contracts that break if rows are renamed
- `IPadSettingsSplitViewController.IPadPresentationLocalization.requiredKeys` (:207-271) — asserted by tests.
- iPad sidebar a11y id format `"sidebar.\(destination)"` (:142).
- `NumPadTests/HomeSettingsModelTests.swift` (:10, :17, :24) and `NumPadTests/IPadSettingsTests.swift:92`.

## C. Deep links — **already tab-bar compatible**

`Libraries/DeepLinkRouter.swift`. `DeepLinkRoute`: `.storePreview(source:)`, `.profileDocument(URL)`,
`.featuresGuide(source:)`, `#if DEBUG .debug(...)`.

```
static func parse(_ url: URL) -> DeepLinkRoute?
@discardableResult static func present(_ route:, from host: UIViewController) -> Bool
@discardableResult static func drainPending(from host: UIViewController) -> Bool
static func activeNavigationController(from host: UIViewController) -> UINavigationController?
static func isRouteablePresentedContainer(_ controller: UIViewController) -> Bool
```

**`activeNavigationController` already recurses into `UITabBarController.selectedViewController`
(:216-220)** and `isRouteablePresentedContainer` already whitelists tab bars (:179).
⇒ A 3-tab shell works with the router **unmodified**, provided every tab is nav-wrapped.

Production routes: `numpad://store-preview?source=`, `numpad://features-guide?source=`,
`*.numpadprofile` file URLs. DEBUG: `numpad://debug/{entitle,preset,height,editor,typing,guide,
fullkeyboard,qwertytestreset,qwertylayout,numpadplacement}`.

Drained from `ViewController.handlePendingDeepLink()` (:367) at viewDidLoad/viewDidAppear/
didBecomeActive/finishLaunch/onboarding-completion.

## D. Keyboard preview — **NOT truthful today; must be rebuilt**

`Views/KeyboardPreviewView.swift` — sole API is `var theme: KeyboardTheme`. It renders a **hard-coded
4×4 grid** (`1 2 3 ⌫ / 4 5 6 − / 7 8 9 + / . 0 % ⏎`).

It does **NOT** reflect: the selected pack, height preset, `isReversedMode` (number order),
`hasRoundedCorners`, `hasGrid`, or the custom keyboard layout. Theme fidelity *is* honest
(real `UIVisualEffectView` for glass themes).

⇒ "Preview before commitment" and "visual parity with actual keyboard settings" **require a new
preview abstraction**. This is the single biggest new-code risk in the project.
Call sites to migrate: `ThemeViewController.swift:40`, `DashboardViewController.swift:161`,
`Views/OnboardingKeyboardMockView.swift:21`.

## E. Readiness / onboarding

- `Keyboard.isKeyboardEnabled` (`Libraries/Keyboard.swift:11`) is the source of truth.
  **Full Access is explicitly NOT detectable** — never claim otherwise.
- `KeyboardEnablementTracker.resolve(...)` / `.refresh(...)` / `.consumeNewBuyerTrigger()` — pure
  decision table + latched `triggerPending`; consume only after real presentation.
- `KeyboardStatusPresentation.detail(isEnabled:)` is trivial ("On"/nil). Richer status strings currently
  live inside `DashboardViewController` — extract them into a reusable presentation type.
- `OnboardingFlow.shouldShow(remoteEnabled:onboardingAlreadyShown:keyboardAlreadyEnabled:isExistingUser:)`
  · `.alreadyShown` · `.markShown()`. `OnboardingStep { wow, enable, tryIt }` with `.analyticsValue`.
- Existing controllers already match the approved 3 steps:
  `OnboardingViewController(completion:)` → `OnboardingWowViewController.onContinue` /
  `OnboardingEnableViewController.onEnabled` / `OnboardingTryItViewController.onDone`.
  Analytics `onboarding_step_viewed` / `onboarding_skipped` / `onboarding_completed` already exist.
  Transition is already skipped under Reduce Motion.
  ⇒ **Restyle these, do not rewrite the flow.**
- Fallback: if onboarding not shown AND keyboard not enabled → `InstructionsViewController` (:245).

## F. Settings API (exact names — do not guess)

| Concept | API |
|---|---|
| number order | `Keyboard.isReversedMode` (default false) |
| rounded keys | `Keyboard.hasRoundedCorners` (default false) |
| key grid | `Keyboard.hasGrid` (**default true**) |
| theme | `KeyboardTheme.selected` / `.selectedOrAutomatic` |
| match dark mode | `KeyboardTheme.automaticDarkMode` (default false) |
| pack | `KeyboardType.selected` |
| height | `KeyboardHeightPreset.selected`, `.effective(stored:kioskEntitled:)` |
| haptics / sound | `UserPrefs.hapticsEnabled` / `.soundEnabled` (both default true) |
| cursor control | `UserPrefs.cursorControls` (default true) |
| clipboard | `UserPrefs.clipboardHistoryEnabled` (default true) |
| live math / tape | `UserPrefs.liveMathPreview` / `.lastResultTape` / `.inlineCalculator` |
| qwerty prefs | `UserPrefs.qwertyPeriodComma`, `.qwertySuggestions`, **`.qwertyAutocorrect` (default FALSE)** |
| notify extension | `SettingsSync.post()` |

**Privacy rule:** never call `SettingsSync.post()` after writing `qwertyPersonalDictionaryData` or
`qwertyTouchOffsetsData`; never log or export them (`SharedExtensions.swift:604`, `:621`).

## G. Packs — naming hazard

`KeyboardType.packs` = `[.math, .math2, .finance, .symbols, .programmer, .datetime, .units, .cooking]`.

⚠️ **`.math` and `.math2` both display "Math"** — a naive list renders two identical rows. In
"Choose keys", surface **one** "Calculations" choice; `toggleMath()` swaps between them.
⚠️ `.datetime` ("Date & Time") is a real, sold pack with no slot in the approved six names — it needs a
seventh tile or a deliberate decision. **Flag to owner.**
Decode-only (never list): `.tax, .scientific, .business, .international, .programmerPlus`.
QWERTY-strip-only (no SKU): `.grammar, .punctuation, .snippets`.

## H. Monetization

`Monetization.isProEntitled` · `isLocked(pack:)` · `isLocked(theme:)` · `isKeyLocked(pack:row:)` ·
`isPackLocked(_:proEntitled:ownedPackProductIDs:)` (pure) · `isKioskHeightEntitled` ·
`isCustomKeyboardEntitled` · `isFullKeyboardEntitled` (= `!paywallEnabled || isProEntitled`).

`ProductCatalog.pro = "numpad.pro.lifetime"`, `.proEarlyBird`, `.packProductID(for:)`, `.allProductIDs`.

**Price (never hardcode):** `StoreManager.start()` → `await StoreManager.shared.loadProducts()` →
`StoreManager.shared.proProduct?.displayPrice`. Existing helper:
`StoreViewController.price(for:fallback:)` (:122). `"$11.99"` at `StoreViewController.swift:224` is only
the not-yet-loaded fallback. Upgrade deltas via `PriceAnchoring.upgradeDelta(proPrice:ownedPackPrice:)`.

⚠️ `numpad.feature.customkeyboard` is **not** in `ProductCatalog` — no StoreKit writer exists, so in
practice `isCustomKeyboardEntitled == isProEntitled`.

## I. Profiles → "Saved setups" (7 built-ins, stable UUIDs — DO NOT CHANGE)

`KeyboardProfileFactory.builtIns()`, IDs `00000000-0000-4000-8000-00000000000{1..7}`:

| UUID tail | Kind | Current name | New display name |
|---|---|---|---|
| 1 | `.standard` | Standard | Everyday numbers |
| 2 | `.calculator` | Calculator | Calculator |
| 3 | `.finance` | Finance | Prices & payments |
| 4 | `.inventory` | Inventory | Measurements |
| 5 | `.writing` | Writing | Writing *(list only when gate permits)* |
| 6 | `.accessibility` | Accessibility | Easy to see |
| 7 | `.kiosk` | Kiosk | Kiosk |

Built-ins have **no `description` field** — descriptions are UI-side copy.

**Transactional apply** — `KeyboardProfileApplier.apply(_:entitlements:) throws -> ApplyResult`
snapshots `transactionSettingKeys`, writes, and on throw calls `restore(previous)` and rethrows.
**Use `probe(_:entitlements:)` for any read-only preview — it never mutates.** This is exactly what
"Setup detail: list which choices will change + preview the result" needs.

`ApplyResult { changedKeys, fallbacks, appliedConfiguration }`;
`ProfileFallback { heightKioskToTall, packLocked, customKeyboardLocked, qwertyPageLocked, themePremiumToWhite }`.

Import/export: `KeyboardProfileDocument.encode/decodeAndValidate` (envelope v1, max 256 KB,
forbidden-key scan blocks personal content). **There is no cryptographic signature** — validation is
envelope version + schema + forbidden-key scan + size bound. Do not claim signing in UI copy.
User-facing errors already exist: `ProfileDocumentUserError` (`.tooLarge/.invalidDocument/
.unreadableDocument/.saveFailed/.exportFailed`) with `errorDescription`.

## J. Kiosk

`KioskReadiness.evaluate(Input) -> ReadinessReport { status: .ready/.warning/.blocked, reasons: [String] }`
with `Input { keyboardEnabled, activeProfileIsKiosk, kioskConfigurationIsValid, fullAccessConfirmed,
profileApplies, usedEntitlementFallback, tryItConfirmed, guidedAccessAcknowledged }`.
**Reasons are already localized — reuse verbatim** as the plain-language readiness list.

`KioskPolicy { inactivityTimeout (30…3600), resetPageAndPack, dismissOverlays, clearResultTape,
clearClipboardHistory, requireAdministratorAuthentication }`.
Reset fallback: `"qwerty"` page → `"numpad"` when `!qwertyAvailable`; locked pack → `.default`.
Admin auth is `LAContext` in `KioskProvisioningViewController.swift:279` — explicitly "an administrative
guard, not cryptographic lock-down". **NumPad cannot enable Guided Access itself — never imply it can.**
No kiosk-specific rollback; it reuses `KeyboardProfileApplier.restore`.

## K. QWERTY gate — two flags, do not confuse them

```
FeatureFlags.isQwertyPageAvailable  = fullKeyboardRemoteEnabled && Monetization.isFullKeyboardEntitled
                                      // gates the ACTUAL PAGE
FeatureFlags.isFullKeyboardActive   = fullKeyboardRemoteEnabled && fullKeyboardEnabled
                                      // gates APP-SIDE ROW SURFACING ONLY
```
`isQwertyPageAvailable` deliberately **excludes** the local `fullKeyboardEnabled` flag
(`SharedExtensions.swift:756-760`) — requiring it once made the keyboard unreachable (owner-reported
regression 2026-07-09). Use `isQwertyPageAvailable` for the Letters *screen* gate; the "Writing" saved
setup must list only when the gate permits.

**Autocorrect default-off is enforced in 3 places — all must stay false:**
`UserPrefs.qwertyAutocorrect` (`SharedExtensions.swift:631`),
`Configuration.productionDefaults.qwertyAutocorrect` (`KeyboardProfileFactory.swift:185`),
Writing built-in (`KeyboardProfileFactory.swift:56`).

## L. Managed settings — exact visibility predicate

```swift
ManagedProfileCoordinator.hasManagedOwnership(defaults: .group)   // Profiles/ManagedProfileCoordinator.swift:46
ManagedProfileCoordinator.isEditingLocked(defaults: .group)       // :42 — disable mutating controls
```
Observe `Notification.Name("managedProfileStateDidChange")` to refresh live.
Gate **every** mutating saved-setup control behind `!isEditingLocked()`.

---

# Open questions for the owner (do not guess)

1. **Pre-existing test failures.** On the unmodified base `0f584a2c`: 885 tests, 876 pass, 3 skipped,
   **7 fail** — all iPad QWERTY geometry (`QwertyKeyboardViewHitTestTests` ×4,
   `QwertyLayoutGeometryTests` ×2/3 assertions; e.g. `("3.5") is not greater than ("500.0")`).
   Out of redesign scope. Quarantine + document, fix first as a separate commit, or ignore?
2. **`.datetime` pack** ("Date & Time") is selectable and sold but has no slot in the approved six
   key-set names. Add a seventh tile, fold it in, or hide it?
3. **iOS 15 vs 16.** Brief and `AGENTS.md` say 15.0; `project.pbxproj` says **16.0** everywhere.
   Building to 16.

---

# Owner decisions (2026-07-27)

1. **Pre-existing QWERTY failures** — fix as a **separate atomic commit**, before/independent of the
   redesign. Not folded into redesign commits.
2. **`.datetime` gets its own tile.** "Choose keys" shows **seven** key sets, not six.
3. **Session protocol** — orchestrate subagents to complete work, then lead-agent review. At ~50%
   context usage: document everything, clear, resume from the documented state.

## Choose keys — final seven tiles

| Tile | Description | Pack | Locked when |
|---|---|---|---|
| Numbers | Clean number entry with basic symbols | `.default` | never (free) |
| Calculations | Operators, percent, and parentheses | `.math` (⇄ `.math2` via `toggleMath()`) | never (free) |
| Prices | Currency symbols and finance keys | `.finance` | `isLocked(pack:)` |
| Measurements | Units and quick conversions | `.units` | `isLocked(pack:)` |
| Date & time | Insert today's date or the time | `.datetime` | `isLocked(pack:)` |
| Symbols | Common punctuation and marks | `.symbols` | `isLocked(pack:)` |
| Programming | Hex and bitwise operators | `.programmer` | `isLocked(pack:)` |

`.cooking` ("Cooking & Baking") is a sold pack still reachable via saved setups and the conversion
overlay; it is **not** a Choose-keys tile (it would read as a near-duplicate of Measurements).
Surface exactly one "Calculations" tile — `.math`/`.math2` share the display name "Math" and must
never render as two tiles.

---

# Wave 1 API contract — `StudioKeyboardPreviewView`

The existing `Views/KeyboardPreviewView.swift` reflects **theme only** and is a hard-coded 4×4 grid.
It is replaced (not edited) by a truthful preview. Both the Keyboard tab and Advanced setup detail
code against this exact interface.

```swift
/// A truthful, non-interactive rendering of what the keyboard will actually look like.
/// Pure presentation: reads no globals, performs no writes, imports only UIKit.
struct StudioKeyboardPreviewModel: Equatable {
    var theme: KeyboardTheme
    var pack: KeyboardType
    var heightPreset: KeyboardHeightPreset
    var isReversedMode: Bool        // number order: true == 7-8-9 on top
    var hasRoundedCorners: Bool
    var hasGrid: Bool
    var showsLettersRow: Bool       // QWERTY page available AND enabled
    var idiom: UIUserInterfaceIdiom

    /// Snapshot of the CURRENT live settings. The only place that touches globals.
    static func current(idiom: UIUserInterfaceIdiom) -> StudioKeyboardPreviewModel

    /// Snapshot of what a profile WOULD produce. Must use
    /// `KeyboardProfileApplier.probe(_:entitlements:)` — never `apply`.
    static func projected(from configuration: KeyboardProfile.Configuration,
                          idiom: UIUserInterfaceIdiom) -> StudioKeyboardPreviewModel
}

final class StudioKeyboardPreviewView: UIView {
    init(model: StudioKeyboardPreviewModel, palette: StudioPalette = .standard)
    var model: StudioKeyboardPreviewModel { get set }   // setter re-renders
    var isCompact: Bool { get set }                     // tiny inline variant
    /// Optional caption strip, e.g. "LIVE PREVIEW" / "Regular · Calculations".
    func setCaption(leading: String?, trailing: String?)
}
```

**Truthfulness requirements** (this is the point of the whole redesign — a preview that lies is worse
than no preview):
- Key captions come from the **real pack layout** (`Item.pack(type:)` / `PackKeys`), never a literal array.
- `isReversedMode` actually reorders the digit rows.
- `heightPreset` changes the rendered aspect ratio proportionally.
- `hasRoundedCorners` and `hasGrid` visibly change corner radius and inter-key spacing.
- Theme fidelity must not regress: glass themes keep the real `UIVisualEffectView`.
- Locked packs still render (the user is previewing what they would get), but the caller overlays
  the lock affordance.

Accessibility: the whole view is ONE accessibility element with a descriptive label
(e.g. "Keyboard preview: Calculations key set, Night teal theme, regular height"), trait `.image`,
and it must never trap VoiceOver focus per-key.
