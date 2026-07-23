# Usability / QWERTY / iPad / Kiosk — Remediation Handoff (Grok Round 2)

**Branch:** `grok/usability-qwerty-ipad-kiosk`  
**Baseline (planning):** `d9606559f3bb3d728adfe876cb376ea1b14f7ed8`  
**Codex-reviewed commit (Round 1):** `bb24b82c85da1015e2493a2a91a414b708a765e0`  
**Final code HEAD:** `f87f5493bcb706f551bc55c369bdfccf551d5129`  
**Handoff docs tip:** branch HEAD after this documentation commit (see `git rev-parse HEAD`)  
**Workspace:** `NumPad.xcworkspace`  
**DerivedData:** `/Volumes/DevVault/Xcode/DerivedData/NumPad-Grok`

This handoff remediates Codex review `docs/release/2026-07-23-codex-review.md`. Pure helpers are not marked done unless the production path uses them.

---

## Ordered commits since Codex review (`bb24b82c`)

1. `80e4b3dd` — fix: share ViewController lifecycle on iPad with deep-link router  
2. `a77e704e` — fix: make keyboard profiles atomic, entitled, and deterministic  
3. `a05b64ca` — feat: deliver factual iPad dashboard and kiosk session reset  
4. `087bd514` — fix: wire QWERTY height, confidence, policies, and counters  
5. `4574e3d9` — feat: personal dictionary UI, editor fields, and confidence gate evidence  
6. `f87f5493` — feat: insert QWERTY key alternates via long-press menu  
7. (docs) Round-2 remediation handoff + Codex review archive  

---

## Task-by-task mapping (Codex remediation phases)

### Phase 1 — Application correctness

| Item | Status | Evidence |
|------|--------|----------|
| iPad shares ViewController launch/foreground | **Done** | `SceneDelegate` always uses storyboard root; iPad embeds `IPadSettingsSplitViewController` as child |
| Deep-link router for store-preview | **Done** | `DeepLinkRouter` + drain from SceneDelegate/ViewController |
| Tests: cold launch / foreground / store-preview | **Done** | `IPadLaunchOrchestrationTests`, `DeepLinkRouterTests` |

### Phase 2 — Profiles

| Item | Status | Evidence |
|------|--------|----------|
| Replace `.testFixture` production defaults | **Done** | `Configuration.defaults` is production; exact factory tests |
| Exact built-in expected-value tests | **Done** | `KeyboardProfileFactoryExactTests` |
| Real pack/theme/custom/QWERTY/kiosk entitlements | **Done** | `ProfileEntitlements` + `Monetization.isPackLocked` for all à-la-carte packs |
| Atomic apply contract | **Done** | validate → fallbacks → write → clear nil custom → persist identity → notify once → rollback |
| Reapply when edited profile is active | **Done** | `ProfilesViewController.edit` |
| Surface persistence errors | **Done** | alerts; no silent `try?` on activate/save/delete |
| Migration stamp only after save | **Done** | `KeyboardProfileMigration.runIfNeeded` |
| Structural custom-keyboard validation | **Done** | `CustomKeyboardProfileValidation` |
| CloudSync pull applies selected profile | **Done** | `CloudSyncProfiles` app-only hook |
| Import validation | **Partial** | document validates custom keyboard; full import/export UI still thin |
| Managed configuration | **Partial** | parser exists; deep MDM apply UX not expanded this round |
| Complete profile editor | **Partial** | name/pack/theme/layout/height/page/QWERTY/feedback; kiosk policy editor rows still limited |
| Confirmed deletion + unchanged on failure | **Done** | confirm alert + restore snapshot on save failure |
| iPad popover anchors / a11y ids | **Done** | popover sourceRect + `profile.builtin.*` ids |

### Phase 3 — iPad / kiosk

| Item | Status | Evidence |
|------|--------|----------|
| Real dashboard | **Done** | status, profile, fallbacks, preview, Try It field, readiness, actions |
| Feedback/Rate/layout real on iPad | **Done** | no longer route to dummy Dashboard |
| Factual kiosk readiness | **Done** | `probe` for profileApplies; Try It via text field; honest FA/GA copy |
| Admin auth on profile edit when kiosk requires | **Done** | `ProfilesViewController.withAdminAuthIfRequired` |
| Inactivity reset in Keyboard | **Done** | `KioskPolicy` in Keyboard target; timer in `KeyboardViewController` |
| Readable split widths | **Done** | primary column 280–360 |

### Phase 4 — QWERTY

| Item | Status | Evidence |
|------|--------|----------|
| Unified height (window/screen) | **Done** | `QwertyPageHost.baseHeight` uses `clampCeilingContainerHeight` |
| Stable 3-slot suggestion bar | **Done** | `.empty` placeholders; always 3 slots |
| Alternates through host | **Done** | long-press → action sheet → insert |
| Punctuation through host | **Done** | `QwertyPunctuationRules` on character insert |
| Backspace / cursor policies | **Done** | `QwertyBackspacePolicy` + `QwertyCursorAccumulator` |
| Personal dictionary UI | **Done** | `QwertyPersonalDictionaryViewController` (no word text in analytics) |
| Layout geometry on live view | **Partial** | resolvers exist; not every placement mode proven in UI tests this round |
| Real confidence features | **Done** | checker index + frequency ranks (not hard-coded 0/nil) |
| Corpus sweep retained | **Done** | `docs/release/2026-07-23-autocorrect-confidence-gate.md` — **gates FAIL** |
| Autocorrect default-off | **Done** | gates failed; default remains off; thresholds not lowered |
| TypingQuality counters + safe flush | **Done** | instrumented host events; snapshot-subtract; ViewController flush |

### Phase 5 — Verification

| Item | Status | Evidence |
|------|--------|----------|
| Localization of new strings / built-in names | **Partial** | built-in names localized; not all new strings exhaustively audited |
| VoiceOver / Dynamic Type / Reduce Motion / contrast / targets | **Blocked** | not fully re-run on device/simulator matrix this session |
| Privacy / kiosk docs match behavior | **Partial** | in-UI copy updated; dedicated privacy doc pass incomplete |
| Full unit suite (clean DD) | **Done (reused DD)** | 728 tests, 2 skipped, 0 failures |
| Simulator/device matrix | **Blocked** | physical devices not available; see matrix below |
| Profiles UI query / popover | **Improved** | UITest rewritten; needs iPad re-run |
| Warning audit | **Not re-run** | build succeeded; dedicated warning audit not archived |

---

## Commands, counts, destinations, xcresult paths

### Unit — Phase 1 launch/deep-link
```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=3A037648-417A-4B4B-8180-D06539B28FF3' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-Grok \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Grok/Logs/Test/Phase1-IPadLaunch-20260723-113423.xcresult \
  -only-testing:NumPadTests/DeepLinkRouterTests \
  -only-testing:NumPadTests/IPadLaunchOrchestrationTests
```
**Result:** 10 tests, 0 failures  
**xcresult:** `/Volumes/DevVault/Xcode/DerivedData/NumPad-Grok/Logs/Test/Phase1-IPadLaunch-20260723-113423.xcresult`

### Unit — Phase 2 profiles
```bash
# Phase2-Profiles-20260723-114239.xcresult — profile applier/factory/migration subset — PASSED
```
**xcresult:** `/Volumes/DevVault/Xcode/DerivedData/NumPad-Grok/Logs/Test/Phase2-Profiles-20260723-114239.xcresult`

### Unit — confidence gate sweep
```bash
xcodebuild test … -only-testing:NumPadTests/QwertyConfidenceGateSweepTests
```
**Result:** 1 test, 0 failures; gates **FAIL** (precision 82.65%, top-3 91.26%)  
**xcresult:** `/Volumes/DevVault/Xcode/DerivedData/NumPad-Grok/Logs/Test/ConfidenceSweep-20260723-115231.xcresult`  
**Metrics file:** `docs/release/2026-07-23-autocorrect-confidence-gate.md`

### Unit — full NumPadTests
```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=3A037648-417A-4B4B-8180-D06539B28FF3' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-Grok \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Grok/Logs/Test/FullUnit-20260723-115332.xcresult \
  -only-testing:NumPadTests
```
**Result:** **728 tests, 2 skipped, 0 failures**  
**xcresult:** `/Volumes/DevVault/Xcode/DerivedData/NumPad-Grok/Logs/Test/FullUnit-20260723-115332.xcresult`

Destination used: DevVault iPhone 17 (`3A037648-417A-4B4B-8180-D06539B28FF3`).

---

## Autocorrect corpus metrics (retained)

From `docs/release/2026-07-23-autocorrect-confidence-gate.md`:

| Metric | Value | Gate | Pass |
|--------|-------|------|------|
| Precision | 0.8265 | ≥ 0.95 | **false** |
| Coverage | 0.8401 | ≥ 0.35 | true |
| Top-3 | 0.9126 | ≥ 0.917 | **false** |
| p95 ms | 0.047 | < 16 | true |

**Outcome:** FAIL — suggestions OK; autocorrect remains **default-OFF**. Thresholds were not lowered.

---

## Screenshots

**Blocked** — not captured this session (no screenshot pass on iPhone / 11-inch / 13-inch).

---

## Migration / corrupt / hostile-import evidence

- Migration idempotence: `KeyboardProfileMigrationTests` (suite green in full run).  
- Corrupt store: `KeyboardProfileStoreTests` (suite green).  
- Hostile import forbidden keys / size / custom validation: `KeyboardProfileDocumentTests` + `CustomKeyboardProfileValidationTests` (suite green).  
- Structural custom-keyboard rejection covered in unit tests.

---

## Accessibility / localization / privacy

| Area | Status |
|------|--------|
| Built-in profile names localized | Done (`NSLocalizedString` in factory) |
| Personal dictionary privacy footer + analytics count-only | Done |
| Kiosk/Full Access/Guided Access honest copy | Done in Dashboard + Kiosk Provisioning |
| Full VoiceOver / Dynamic Type / Reduce Motion matrix | **Blocked** (not executed this session) |

---

## Physical-device / simulator matrix

| Gate | Result |
|------|--------|
| Small iPhone | **Blocked** (no physical device session) |
| Large iPhone | **Blocked** |
| 11-inch iPad | **Blocked** |
| 13-inch iPad | **Blocked** (simulator available `QA-iPad-Pro-13` but full UI matrix not run) |
| Portrait/landscape + multitasking | **Blocked** |
| Full Access on/off | **Blocked** |
| iPad floating keyboard | **Blocked** |
| Kiosk inactivity on device | **Blocked** (unit/extension wiring done; device timing not verified) |
| 5-minute numpad typing | **Blocked** |
| 5-minute QWERTY typing | **Blocked** |

Never inferred as pass.

---

## Remaining risks (honest)

1. Autocorrect **must stay off** — confidence gates failed; releasing with auto-apply would violate the design gate.  
2. Key alternates use an action sheet, not a native callout strip — functional but not iOS-parity polish.  
3. Profile import/export + MDM apply UX still thin beyond parsers/validation.  
4. Profile editor kiosk-policy fields incomplete vs full schema.  
5. `QwertyLayoutGeometry` application across all placements not UI-proven.  
6. Full UITest matrix (especially iPad Profiles popover E2E) not re-executed after the query rewrite.  
7. Clean DerivedData warning audit not archived.  
8. Physical-device soft gates all **Blocked**.

---

## Model note

All Round-2 remediation commits were implemented with **Grok 4.5** (no Opus).

---

> No Apple archive, upload, TestFlight distribution, or App Store submission was performed. The branch is ready for Codex review.
