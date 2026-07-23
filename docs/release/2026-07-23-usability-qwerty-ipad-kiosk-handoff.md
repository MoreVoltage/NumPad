# Usability / QWERTY / iPad / Kiosk — Implementation Handoff

**Date:** 2026-07-23  
**Implementer:** Grok 4.5 (Cursor)  
**Branch:** `grok/usability-qwerty-ipad-kiosk`  
**HEAD SHA:** `38ce6dd6006fa8f8b9761fed06f6d690c1a09828`  
**Baseline:** `d9606559` (`feat/qwerty-glide-and-accuracy` with both planning docs)

No Apple archive, upload, TestFlight distribution, or App Store submission was performed.

## Ordered commits (since baseline)

```
77332c13 fix: correct keyboard status and home input clearance
09568ffe refactor: organize settings outside the store
c81839ab feat: add versioned keyboard profiles
22281c67 feat: persist apply and migrate keyboard profiles
18d4f365 feat: add profile management
6947968a feat: add qwerty preferences and input feedback
3f4494a7 feat: add qwerty quality policies and layout geometry
b74b6082 feat: add kiosk readiness ipad shell and profile documents
38ce6dd6 docs: prepare usability release review handoff
```

## Diff stat (baseline → HEAD)

62 files changed, 3329 insertions(+), 206 deletions(-)  
`Auto-Company/` remains untracked and was never read, modified, staged, or committed.

## Task-by-task implementation map

| Task | Status | Notes |
|------|--------|-------|
| 1 Status + demo clearance | DONE | `KeyboardStatusPresentation`, `HomeDemoLayout`; fixed Bool `!= nil` bug |
| 2 Settings IA outside Store | DONE | `BehaviorSetting`, `HomeSettingsModel`, `TypingBehaviorViewController`; Store `.controls` removed |
| 3 Profile schema + layout prefs | DONE | `KeyboardProfile`, `QwertyLayoutMode`, `NumpadPlacement` |
| 4 Persist/apply/migrate | DONE | Store/Factory/Applier/Migration; AppDelegate hook; CloudSync keys |
| 5 Profile management UI | DONE | Profiles + editor; Home wired; UITest added |
| 6 QWERTY prefs + feedback | DONE | Typing section; host gates; touch-down → `playClick()` |
| 7 Height presets for QWERTY | PARTIAL | `KeyboardHeightPreset.resolvedHeight` + host `baseHeight` uses it; E2E matrix not extended |
| 8 Confidence autocorrect | PARTIAL | Module + host wiring; **no full corpus threshold sweep executed**; default OFF |
| 9 Suggestion bar 3-slot state | NOT DONE | Existing bar retained; stable `State` API not landed |
| 10 Alternates + punctuation | PARTIAL | Pure modules + tests; alternate menu UI + host insert path not fully wired |
| 11 Backspace/cursor policies | PARTIAL | Pure modules + tests; host still uses prior timer/pan code |
| 12 Personalization context + dictionary UI | PARTIAL | Context type + tests; persistence migration + PersonalDictionary VC not fully landed |
| 13 iPad split + dashboard | PARTIAL | `IPadSettingsSplitViewController` + `DashboardViewController` + SceneDelegate pad root; UI tests / readable-width polish incomplete |
| 14 Layout geometry apply | PARTIAL | Pure geometry resolvers + tests; keyboard view not fully adapted to resolver frames |
| 15 Kiosk session + LA guard | PARTIAL | Readiness/policy + provisioning UI + LA; extension inactivity reset not fully wired |
| 16 Profile document + MDM | PARTIAL | Document/Managed parsers + tests; import UI coordinator minimal/absent |
| 17 Counters + a11y + l10n + docs | PARTIAL | `TypingQualityCounters` + tests; flush/instrumentation/l10n/privacy doc sweep incomplete |
| 18 Handoff | THIS DOC | |

## Deviations (design wins)

1. **QwertySetup Off label:** uses `KeyboardStatusPresentation.detail(...) ?? "Off"` so disabled still shows Off (design only required correcting false On).
2. **Autocorrect default:** set to **false** because a full measured confidence-policy sweep on `typos_wiki_en` was not completed in this session. Suggestions remain default **true**. Gates were **not** lowered.
3. **Home layout switches:** modeled as `SettingsDestination` cases (`numberOrder`/`roundedCorners`/`grid`) rendered as switches.
4. **iPad sidebar style:** used `.insetGrouped` instead of `.sidebar` after compile failure against the active SDK/style surface.
5. **QWERTY height:** resolver added; floating detection via `compactHeight` heuristic may need device tuning.
6. **Tasks 9–12/14–17 UI wiring:** pure logic preferred over incomplete UIKit integrations where time-boxed; see known issues.

## Autocorrect confidence

**Selected production posture:** suggestions available; automatic correction **default off**.

**Policy implemented (`QwertyCorrectionConfidence.decide`):**
- typed length ≥ 3
- edit distance == 1
- checker index == 0
- frequency rank ≤ 5000 when known
- runner-up margin ≥ 5 ranks when both ranks known

**Measured gate results on `typos_wiki_en`:** **NOT RUN** in this session (BLOCKED for release until Codex/owner runs harness).  
Required gates (design): ≥95% precision, ≥35% coverage, ≥91.7% top-3, <16 ms p95 — **unverified**.

## Test / build evidence

Destination used: `platform=iOS Simulator,id=3A037648-417A-4B4B-8180-D06539B28FF3` (DevVault iPhone 17, iOS 26.5).  
DerivedData: `/Volumes/DevVault/Xcode/DerivedData/NumPad-Grok`

| Suite | Result | xcresult |
|-------|--------|----------|
| Task 1 focused | 3/3 pass | `.../Results/Task1-KeyboardStatus.xcresult` |
| Wave A full unit | 685 pass (2 skipped) | `.../Results/WaveA-FullUnit.xcresult` |
| Final full `NumPadTests` | **711 pass, 2 skipped, 0 failures** | `.../Results/Final-FullUnit.xcresult` |
| Generic iOS device build (no archive) | SUCCEEDED | `/tmp/numpad-device-build.log` |

UI suites (`ProfileAndKioskTests`, `IPadSettingsTests`, `QwertyRealisticTypingTests`): **not fully executed** in this session after final commits — treat as **open** before release.

## Privacy review

- Profiles exclude snippets, clipboard contents, tape contents, personal dictionary, touch offsets, purchases/entitlements.
- Document hostile-input tests reject `isProPurchased` / personalization keys.
- `TypingQualityCounters` stores integer counters only (`keyTaps`, `suggestionsShown`, `suggestionsAccepted`, `correctionsApplied`, `correctionReverts`, `backspaceTaps`, `backspaceRepeatSessions`, `pageSwitches`, `shortAbandonedSessions`).
- Glide remains dark/forced off; bigram predictor and SymSpell remain unwired.
- Analytics counters not yet flushed from AppDelegate (instrumentation incomplete).

## Migration / corrupt-data / hostile import

- Migration idempotence: `KeyboardProfileMigrationTests` pass.
- Corrupt store preserves bytes + backup key: `KeyboardProfileStoreTests` pass.
- Document/managed hostile inputs: unit tests pass for forbidden keys / huge docs / invalid MDM dict.

## Accessibility / layout

- iPhone Home sections + Profiles/Kiosk screens compile.
- iPad split root selected in SceneDelegate for `.pad`.
- Full Dynamic Type / VoiceOver / screenshot matrix: **BLOCKED** (not captured).

## Physical-device matrix

**BLOCKED — not executed.** No physical-device pass may be assumed.

| Gate | Status |
|------|--------|
| Small iPhone oldest OS | BLOCKED |
| Large iPhone | BLOCKED |
| 11" iPad | BLOCKED |
| 13" iPad | BLOCKED |
| Full Access on/off | BLOCKED |
| Floating iPad keyboard | BLOCKED |
| Kiosk inactivity reset on device | BLOCKED |
| 5-minute typing session | BLOCKED |

Connected devices observed earlier: `James’s iPhone`, `James’s iPhone 17` (not used for the matrix).

## Known issues / remaining release risks

1. Autocorrect gate numbers unverified — keep default off until harness clears gates.
2. Suggestion bar still uses pre-Task-9 variable rendering.
3. Alternates menu UI / punctuation insert path not fully integrated in `QwertyPageHost`.
4. Backspace/cursor policies not replacing host timers yet.
5. Personal dictionary management screen missing; touch-offset context migration incomplete.
6. Kiosk inactivity reset not enforced inside Keyboard extension.
7. Profile import/export UI (`ProfileImportCoordinator`) not completed.
8. Localization sweep / PrivacyPolicy / kiosk doc updates incomplete.
9. UI test + screenshot evidence incomplete.
10. Compiler warning audit of full clean build not separately tallied beyond successful builds.

## Confirmation

- `Auto-Company/` was untouched.
- Workspace used: `NumPad.xcworkspace`.
- No force-push / reset / rebase of shared history.
- No Apple archive, upload, TestFlight distribution, or App Store submission was performed.
