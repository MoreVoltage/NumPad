# NumPad Usability, QWERTY, iPad, and Kiosk Design

**Status:** Approved design baseline. The owner approved the preceding product/code review by requesting an implementation plan for “these changes.”

**Target:** The next App Store release after `feat/qwerty-glide-and-accuracy`.

## Objective

Make NumPad easier to configure, make its optional QWERTY page credible for daily tap typing, and turn the iPad companion app into a useful configuration and kiosk-provisioning surface without weakening the proven numpad experience.

The central product addition is **Profiles**: named, versioned bundles of keyboard settings. Profiles organize the app’s existing capabilities and provide the configuration unit used by iPad and kiosk workflows.

## Release Principles

1. Preserve the current numeric keyboard behavior unless a task explicitly changes it.
2. Keep QWERTY opt-in and Pro-gated until the release gates in this document pass.
3. Keep glide typing dark in App Store builds. No task may change its legal gate, production default, marketing, or availability.
4. Keep all typing and personalization data on device. Analytics may contain counters and enum values, never typed text, clipboard text, snippets, learned words, or key coordinates.
5. Keep the app UIKit-first and compatible with iOS 15.0.
6. Continue using the app group and one `SettingsSync.post()` after a transactional configuration change.
7. Do not add a third-party prediction engine, network typing service, or new dependency in this release.
8. Do not submit, upload, archive, distribute, or change App Store Connect state until Codex has reviewed the completed implementation.

## Scope

### Included

- Correct the two false “On” QWERTY/keyboard status labels.
- Remove the home-screen Try It field’s overlap with settings content.
- Reorganize settings and move behavior controls out of the store.
- Add versioned Profiles with built-in presets, local persistence, activation, duplication, deletion, and import/export.
- Add a Kiosk profile and kiosk provisioning/readiness UI.
- Add Managed App Configuration parsing for NumPad-owned profile settings while clearly retaining the manual keyboard-enablement and Full Access requirements.
- Make the iPad companion app use a sidebar/detail layout with a dashboard and live preview.
- Improve QWERTY feedback, settings, height behavior, corrections, suggestions, alternates, deletion, cursor movement, personalization management, and iPad layout.
- Add privacy-safe typing-quality counters and release evaluation gates.
- Update tests, localization, accessibility, kiosk documentation, and release verification artifacts.

### Explicitly deferred

- Enabling or marketing glide typing.
- A new next-word model. The measured bigram implementation remains unwired.
- SymSpell in the extension. Its measured memory/quality gates remain failed.
- A NumPad SDK.
- A standalone kiosk/POS/data-entry application.
- Emoji search or a full emoji keyboard.
- Full multilingual autocorrect. This release must state that QWERTY correction is US English; architecture should permit later locale modules.
- QR profile sharing, cryptographic signing, profile marketplaces, team administration, or a backend.

## Product Architecture

### 1. Profiles

`KeyboardProfile` is an app-side, `Codable`, versioned value type. It captures user-facing configuration, not arbitrary defaults keys.

```swift
struct KeyboardProfile: Codable, Equatable, Identifiable {
    static let currentSchemaVersion = 1

    enum Kind: String, Codable {
        case standard, calculator, finance, inventory, writing, accessibility, kiosk, custom
    }

    var id: UUID
    var name: String
    var kind: Kind
    var configuration: Configuration
    var kioskPolicy: KioskPolicy?
    var schemaVersion: Int
}
```

`Configuration` stores typed or validated raw enum values for:

- selected numpad pack;
- theme and automatic appearance behavior;
- height preset;
- number-row order, rounded corners, and grid;
- structured custom keyboard configuration and handedness;
- global feedback and behavior preferences;
- QWERTY primary strip, reopen behavior, period/comma setting;
- QWERTY autocorrect, suggestions, and double-space-period preferences;
- iPad numpad placement and QWERTY layout mode.

Personal content is not embedded in profiles:

- snippets;
- clipboard history;
- result-tape contents;
- personal dictionary words;
- learned touch offsets;
- purchases or entitlement flags.

`KeyboardProfileStore` persists `[KeyboardProfile]` and the active profile ID as JSON in the app group. It rejects unsupported future schemas without overwriting the current store. A missing or corrupt store falls back to built-ins and preserves the corrupt bytes for diagnostics rather than crashing.

`KeyboardProfileApplier` validates a profile, resolves entitlement fallbacks, writes all changed settings, and posts exactly one Darwin settings notification. A locked feature remains in the saved profile but applies its documented fallback.

Built-in profiles are immutable templates. Activating one creates or updates the active configuration without making the template itself editable. Users duplicate a built-in to customize it.

### 2. Settings information architecture

#### iPhone

The existing table-navigation style remains, organized into sections:

- Dashboard
- Keyboard
- Typing & Behavior
- Content & Automation
- Account
- Help

The dashboard contains reliable keyboard status, the active profile, a compact preview, and the Try It field. Commerce remains under NumPad Pro; operational toggles move to Typing & Behavior.

#### iPad

`UISplitViewController` provides:

- a primary sidebar of destinations;
- a readable-width detail navigation controller;
- a dashboard detail showing active profile, readiness, live keyboard preview, and Try It field.

The app supports portrait, landscape, Split View, Slide Over, Stage Manager sizes, pointer interaction, keyboard navigation, Dynamic Type, and VoiceOver. It does not stretch phone rows across the full display.

### 3. QWERTY behavior

#### Feedback

QWERTY key touch-down uses the same centralized click/haptic path as numpad keys and honors the existing global settings and Full Access behavior.

#### User preferences

The QWERTY setup screen exposes:

- autocorrect;
- suggestions;
- double-space period;
- period/comma keys;
- primary top strip;
- reopen behavior;
- iPad layout mode where applicable;
- personal dictionary management;
- reset typing personalization.

#### Height

QWERTY uses the same `KeyboardHeightPreset` selection and clamp rules as the numpad. Floating iPad keyboard behavior remains system-sized. The 44-point suggestion bar is part of the selected total height.

#### Correction policy

Automatic correction becomes confidence-gated. Candidate generation and suggestion ordering remain separate from the decision to auto-apply.

The evaluation harness must report:

- top-1 and top-3 candidate accuracy;
- automatic-correction precision;
- automatic-correction coverage;
- p50/p95 latency.

The selected policy must achieve, on `typos_wiki_en`:

- at least 95% auto-apply precision;
- at least 35% coverage of misspelled inputs;
- top-3 candidate accuracy no lower than the current 91.7% baseline;
- p95 correction latency below 16 ms.

If no tested policy clears every gate, suggestions remain available but automatic correction defaults off. The implementer must not silently weaken the gates.

When a correction is applied, the suggestion bar visibly marks the correction and preserves the typed literal as the immediate undo choice. One backspace continues to revert the correction.

#### Suggestion bar

The bar always renders three stable slots. Empty slots remain noninteractive placeholders so widths do not jump. While typing, slot one is the literal and slots two/three are candidates. At a boundary, the bar clears to stable empty slots; the rejected bigram predictor is not wired.

#### Alternates and punctuation

Long-press on supported character keys presents an accessible alternate-character menu. The first release supports Latin diacritics and common punctuation/currency alternates through a static, tested map.

Pure punctuation rules handle:

- straight-to-curly apostrophe in contractions where safe;
- replacing a second opening quote with a closing quote based on local context;
- removing an unwanted space before `. , ? ! : ;`;
- retaining the existing double-space period behavior behind its user preference.

Rules must never inspect or persist more than the text proxy’s current local context.

#### Backspace and cursor movement

Backspace behavior has:

- an initial hold delay;
- character-repeat phase;
- accelerated repeat;
- optional word deletion after a longer hold, using the existing user preference and safe boundary logic.

The space bar enters cursor mode only after a hold. It displays an active state and uses a pure accumulator to convert motion to caret steps without oscillation. Unsupported selection operations are not simulated.

#### Personalization

Touch personalization is scoped by a context key containing device class and QWERTY layout mode. Legacy unscoped phone data migrates to phone/automatic; legacy iPad data is not inferable and is safely reset.

The personal dictionary screen lists learned words, supports explicit add/delete, and retains the existing reset-all operation.

### 4. iPad keyboard geometry

`QwertyLayoutMode`:

- `automatic`
- `centered`
- `split`
- `compactLeft`
- `compactRight`

Automatic chooses centered for regular-width iPad, compact behavior for narrow/floating contexts, and the existing full phone layout on iPhone.

Centered mode caps the keyboard content width and centers it. Split mode divides character rows into left/right groups separated by a thumb gap while retaining one stable bottom command row. Compact modes cap width and pin to the chosen side.

`NumpadPlacement`:

- `automatic`
- `center`
- `left`
- `right`
- `fullWidth`

Automatic centers the numpad on regular-width iPads and preserves the current full-width behavior on iPhone and narrow/floating contexts. Custom side columns remain attached according to the existing handedness semantics.

Geometry calculations live in pure layout resolvers and are unit-tested independently from UIKit.

### 5. Kiosk operation

The Kiosk built-in profile uses:

- Kiosk height where entitled, otherwise Tall;
- high-contrast theme;
- centered numpad placement;
- large, rounded targets with grid on;
- QWERTY page off by default;
- clipboard history off;
- result-tape/session clearing enabled;
- automatic return to the profile’s default pack/page after inactivity.

`KioskPolicy` contains:

- inactivity timeout, constrained to 30–3,600 seconds;
- reset page/pack flag;
- dismiss overlays flag;
- clear result tape flag;
- clear clipboard history flag;
- require administrator authentication before editing flag.

Configuration locking uses `LocalAuthentication` in the companion app. It is an administrative guard, not a claim of cryptographic or MDM security. Guided Access/SAM remains responsible for preventing operators from leaving the host application.

The provisioning screen reports:

- keyboard enabled status;
- intended Full Access policy, with a manual confirmation when the OS state cannot be read reliably;
- active profile and entitlement fallback status;
- a successful Try It field check recorded on this device;
- acknowledgment of the Guided Access “Software Keyboards” requirement;
- readiness as ready, warning, or blocked.

The UI and documentation state that MDM cannot enable a third-party keyboard or grant Full Access.

### 6. Profile import/export and managed configuration

Export uses a `.numpadprofile` JSON document containing one profile and an envelope version. Import:

- accepts only supported schema versions;
- validates names, enum values, array sizes, string lengths, kiosk timeout, and custom key tokens;
- assigns a new UUID on ID collision;
- never imports entitlement, analytics, personal dictionary, clipboard, or purchase state.

Managed App Configuration is read from the standard `com.apple.configuration.managed` dictionary. Supported keys select a profile by embedded profile JSON or built-in kind and optionally lock editing. Invalid managed configuration produces a visible diagnostic and leaves the current local profile active.

### 7. Privacy-safe metrics

The extension records only integer counters:

- key taps;
- suggestions shown and accepted;
- automatic corrections applied;
- immediate correction reverts;
- backspace taps and repeat sessions;
- QWERTY/numpad page switches;
- typing sessions abandoned within ten key taps.

Counters contain no text, word hashes, timestamps precise enough to reconstruct typing, coordinates, app identifiers, or field traits. The app flushes aggregate counters through the existing analytics wrapper and clears them after a successful flush.

## Migration

On first launch after the update:

1. Create built-in profile templates.
2. Snapshot the user’s current settings into a custom profile named “My Current Setup.”
3. Make that profile active, preserving behavior.
4. Leave personal content and entitlements in their existing stores.
5. Add the profile keys to iCloud sync only after profile creation succeeds.
6. Never rewrite or delete existing settings during migration; profiles become the authoritative writer only after activation.

Migration is idempotent and covered by tests using isolated `UserDefaults` suites.

## Verification and Release Gates

### Automated

- All existing unit tests remain green.
- New domain and geometry logic has direct unit coverage.
- Full `NumPadTests` suite passes on a current iPhone simulator.
- Selected UI tests pass on iPhone and iPad simulators where system keyboard activation is available.
- No new compiler warnings in NumPad-owned source.

### Physical-device matrix

- Small supported iPhone on iOS 15 or the oldest available compatible OS.
- Current large iPhone.
- 11-inch iPad.
- 13-inch iPad.
- Portrait and landscape.
- Full Access off and on.
- Numpad, QWERTY, floating iPad keyboard, Split View, and kiosk profile.

Record:

- cold keyboard appearance;
- 5-minute typing session;
- correction-revert rate;
- memory/high-water behavior;
- height switching;
- pack/page switching;
- profile application while the keyboard is visible;
- kiosk inactivity reset.

### Review boundary

The implementation is complete only when it has:

- atomic commits;
- a clean diff excluding `Auto-Company/`;
- test logs and result-bundle paths;
- current iPhone and iPad screenshots;
- a release handoff listing deviations and known issues.

At that point work stops. Codex performs an independent code, test, UX, privacy, and release review. Apple archive/upload/submission work begins only after the owner explicitly accepts that review.
