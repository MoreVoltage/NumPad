# Codex remediation handoff

Date: 2026-07-24

Branch: `codex/remediate-qwerty-ipad-kiosk`

Baseline: `7f77d816`

Verified implementation HEAD: `0c343b48fbd50a9231292fb37123ffd416ffcbcf`

Release recommendation: **NO-GO**

## Executive conclusion

The remediation substantially hardens profile transactions, kiosk semantics, QWERTY gesture
state, correction evidence, adaptive iPad geometry, personalization reset concurrency, managed
profile provisioning, and iPad dashboard usability. The implementation builds for a generic iOS
device and the clean 876-test unit suite passes.

It is **not ready for TestFlight or Apple submission**. The complete UI matrices fail on both
iPhone and iPad, the required visual matrix is incomplete, autocorrect remains below its frozen
quality gate, and physical-device/external-system gates have not been performed. A prior focused
pass cannot supersede these clean full-suite results.

The owner reported that Grok attempted to use Opus 4.8. This remediation used the
owner-approved **GPT-5.6-sol/high only, with no Opus or Claude delegation**.

No archive, signing, upload, TestFlight distribution, App Store Connect change, or submission
was performed.

## What changed

### Profiles and kiosk

- Profile application and selection now use transactional state transitions.
- Cloud/managed profile entitlement fallback behavior is rejected instead of silently weakening
  the requested configuration.
- Kiosk sessions receive explicit start/end/review semantics and safer restoration behavior.
- Managed provisioning reconciliation, profile integration, pending-route handling, and reset
  safety were completed.
- The iPad dashboard exposes human-readable readiness, active profile, keyboard status, Full
  Access policy, fallback behavior, Try It, and kiosk/profile actions.

### QWERTY

- Gesture arbitration, alternate-key callout release, space cursor behavior, accessibility, and
  continuous interactions were tightened.
- Correction/undo state is scoped and invalidated across page transitions.
- Suggestion/correction counters and confidence evidence were made more trustworthy.
- The release confidence thresholds were preserved. Autocorrect remains default-OFF because
  precision and visible-candidate quality do not pass.

### iPad keyboard geometry

- Adaptive centered/full-width numpad and QWERTY geometry support was added.
- Follow-up fixes addressed the implementation review gaps.
- The clean UI matrix still does not prove the complete geometry contract because QWERTY cannot
  be reached by the current accessibility-driven test helper, and height presets report one
  constant input-view height.

### Personalization and managed provisioning

- Personalization reset snapshots are atomic and serialized across app/extension processes.
- Interrupted reset epochs recover, readers remain non-destructive, and stabilized epochs are
  revalidated.
- Managed profile provisioning workflows and reconciliation paths were completed and reviewed.

## Commit inventory

The remediation range is `7f77d816..0c343b48`:

```text
d9b64130 docs: plan codex remediation pass
0cc80a37 fix: make profile state transitions transactional
a7d6788b fix: reject cloud profile entitlement fallbacks
057d2e47 fix: enforce kiosk profile session semantics
feb17d5a fix: close kiosk session review gaps
c08cf2a0 fix: make qwerty gestures predictable and accessible
ae5cd708 fix: make qwerty ui tests deterministic
95a29f82 fix: make qwerty correction evidence trustworthy
08c4cbbb fix: harden correction scope and counters
f63dbae2 feat: apply adaptive ipad keyboard geometry
2c97839b fix: close ipad geometry review gaps
ded15b30 fix: make personalization reset snapshots atomic
e968139d fix: serialize personalization resets across processes
609754e3 fix: recover interrupted personalization epochs
7b7f555e fix: keep epoch readers non-destructive
05af46f3 fix: revalidate stabilized personalization epochs
188cde2b feat: complete profile provisioning workflows
5d366b02 fix: close managed profile integration gaps
cbf3f5da fix: make managed profile reconciliation complete
79816a0c fix: finish ipad usability and release quality
fb25fbfe fix: close ipad release review gaps
0c343b48 fix: finalize pending route and reset safety
```

## Verification verdicts

| Area | Verdict | Detail |
|---|---|---|
| Clean unit suite | PASS | 876 total; 873 passed, 3 skipped, 0 failed |
| Unsigned generic-device Release build | PASS | `NumPad` and `Keyboard` schemes |
| iPhone full UI | **FAIL** | 33 total; 14 passed, 2 skipped, 17 failed |
| iPad full UI | **FAIL** | 33 total; 16 passed, 0 skipped, 17 failed |
| QWERTY end-to-end proof | **FAIL** | 12 tests per device cannot reach QWERTY |
| Height preset proof | **FAIL** | all phone presets measure 358; all iPad presets measure 408 |
| iPad profile/kiosk focused UI | PASS | 2 focused tests pass on iPad |
| Adaptive geometry proof | **FAIL / INCOMPLETE** | blocked at missing `Letters` control |
| Localization syntax | PASS | 32 tables |
| Privacy/plist syntax | PASS | seven files |
| Autocorrect confidence | **FAIL** | precision 0.8023; visible candidate rate 0.9018 |
| Complete visual matrix | **INCOMPLETE** | only partial valid evidence captured |
| Physical/external gates | **NOT PERFORMED** | required before submission |

Full commands, result bundle paths, failure inventory, warning classification, visual manifest,
and the unperformed-gate matrix are in
`docs/release/2026-07-23-evidence-log.md`.

## Blocking findings

### 1. QWERTY is not reachable through the tested accessibility contract

The current numpad presents a grid glyph where the UI tests require an accessible
`Letters`/ABC control. Eleven realistic-typing tests and the QWERTY smoke test therefore fail on
both simulators before they exercise typing. This leaves autocapitalization, alternate callouts,
correction undo, suggestion selection, cursor gestures, burst typing, and page/pack transitions
without clean end-to-end evidence.

Treat this first as a product/accessibility contract question, not merely a test rename:

- decide the intended visible title, accessibility label, hint, identifier, and tap behavior;
- verify VoiceOver can discover and activate it;
- make the test helper use the stable intended contract;
- rerun every QWERTY UI test on phone and iPad.

### 2. Height presets do not produce distinct observed heights

The full matrix observes 358 points for small, regular, tall, and kiosk on phone and 408 points
for every preset on iPad. Determine whether:

- the extension is ignoring the setting;
- the host retains a stale input-view constraint;
- settings synchronization is not reaching the extension;
- or the UI test is measuring the wrong element.

Do not weaken the strict-order assertion without first proving the intended user-visible
behavior on hardware and in a third-party host.

### 3. Screenshot scenarios reset their own setup

The Math screenshot scenarios select the Math pack, then relaunch through a helper that resets
the app group. The tests consequently cannot find `*` or `=`. Define one reset at scenario
start, preserve state within the scenario, and assert the pack before opening the keyboard.

### 4. iPad-only tests run assertions on iPhone

The phone suite expects an iPad Kiosk preset and iPad sidebar. Gate those assertions by idiom or
split the platform-specific cases so the complete suite is meaningful on both destinations.

### 5. Visual and physical proof is incomplete

The portrait iPad dashboard and current centered numpad are readable. The two manual
centered/full-width numpad files are byte-identical and therefore cannot prove different modes.
Phone QWERTY, adaptive iPad QWERTY, split/compact states, landscape dashboard, and dedicated
provisioning screens are missing. The Mac was locked during the manual pass, so blocked states
were not marked passed.

VoiceOver, Guided Access, hardware keyboard, third-party hosts, real MDM/Files provisioning,
signed profile URLs, privacy-label parity, native-speaker review, signed archive validation, and
TestFlight installation remain unperformed.

## Warning debt

The unsigned clean Release build succeeds but reports:

- first-party deprecated `UIButton.contentEdgeInsets`;
- a never-mutated local variable;
- missing Metal toolchain search-path warnings for both targets;
- FirebaseCrashlytics, SwiftRater, and TextAttributes warnings;
- App Intents metadata/dummy-object tooling warnings;
- an always-running script phase.

The first-party warnings are light cleanup. Dependency/toolchain warnings should be reviewed
against the Xcode version intended for submission. None should be silently treated as a signed
archive pass.

## Autocorrect release posture

The frozen 4,266-pair gate currently reports:

- precision 0.8023 — fail against 0.9500;
- coverage 0.3687 — pass against 0.3500;
- visible three-slot candidate rate 0.9018 — fail against 0.9170;
- p95 latency 4.1308 ms — pass against 16 ms.

Keep autocorrect default-OFF. Do not lower the gate to enable it.

## Recommended remediation order

1. Fix the QWERTY transition accessibility/product contract and restore all 12 QWERTY UI cases.
2. Diagnose and fix the height-preset behavior with production-level evidence.
3. Fix per-scenario reset semantics for pack-specific screenshot tests.
4. Correct platform scoping for iPad-only UI cases.
5. Run a clean unit suite and both complete UI matrices; require all green.
6. Capture a deterministic visual matrix:
   - phone QWERTY;
   - iPad centered/full-width QWERTY;
   - iPad split/compact QWERTY;
   - centered/full-width numpad;
   - dashboard portrait/landscape;
   - Kiosk Provisioning and readiness states.
7. Perform physical-device VoiceOver, Guided Access, hardware-keyboard, and third-party-host
   checks.
8. Exercise real MDM, Files-provider, and signed external URL provisioning and failure recovery.
9. Reconcile privacy manifests/policy with App Store privacy labels and obtain native-speaker
   review.
10. Only then produce and validate a signed archive, distribute to TestFlight, and run the final
    installation/smoke matrix before considering App Store submission.

## Handoff boundary

This branch should be treated as an implementation candidate that still requires a focused
release-blocker remediation cycle. The clean unit and build results are useful, but they do not
authorize distribution. The next reviewer should start from the red full UI results, retain the
frozen autocorrect gate and default-OFF policy, and avoid any Apple-side action until every
blocking gate above has current evidence.
