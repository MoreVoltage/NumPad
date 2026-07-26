# Codex remediation handoff

Date: 2026-07-26

Branch: `codex/remediate-qwerty-ipad-kiosk`

Baseline: `7f77d816`

Verified implementation HEAD: `6bf3fa815f1643410927ada30293d6244692806b`

Code/simulator recommendation: **PASS — advance to signed physical-device and TestFlight
validation**

Apple submission recommendation: **NO-GO until the remaining manual and signed-distribution gates
are complete**

## Executive conclusion

The remediation pass is complete at the code and simulator level. The branch now passes:

- 882 unit tests, with three intentional opt-in/environment skips and zero failures;
- all 33 iPad UI tests across the full run and a final-code replacement of its single
  time-limited geometry case;
- 28 iPhone UI tests, with five intentional iPad-only skips and zero failures;
- both generic-device Release compile/link gates;
- localization, plist, privacy-manifest, and privacy-policy parity checks.

The signed UI evidence proves the QWERTY typing experience, adaptive iPad keyboard layouts,
height presets, kiosk/profile workflows, pack-specific screenshots, and the broader app surfaces
covered by the suite. The earlier red full UI results were invalidated by their unsigned simulator
configuration, which removed the app-group entitlement needed by the app and keyboard extension.
The remaining genuine test-contract defects were corrected and independently rerun before the
final matrices. An independent final code review of the resulting remediation reported no
actionable Critical or Important findings.

This is not authorization to submit the app to Apple. Physical accessibility, Guided Access,
hardware keyboard, real host-app, MDM/Files, privacy-label, signed archive, and TestFlight gates
remain outstanding.

The owner reported that Grok attempted to use Opus 4.8. This remediation used the owner-approved
**GPT-5.6-sol/high only, with no Opus or Claude delegation**.

No archive, signing for distribution, upload, TestFlight distribution, App Store Connect change,
or submission was performed.

## Product changes completed

### Profiles, managed configuration, and kiosk

- Profile apply/select operations are transactional instead of partially mutating live state.
- Cloud and managed profiles reject unavailable entitlements instead of silently weakening the
  requested configuration.
- Built-in, imported, managed, duplicated, and edited profiles reconcile through one consistent
  state model.
- Kiosk sessions have explicit start/end/review semantics, inactivity handling, policy reset, and
  safer restoration.
- Pending routes and reset behavior no longer race startup/profile reconciliation.
- The iPad dashboard exposes human-readable readiness, keyboard status, active profile, Full
  Access policy, entitlement fallbacks, Try It, profiles, and kiosk provisioning.
- Kiosk reset destinations are resolved through the live QWERTY rollout gate and current pack
  entitlement at both profile application and keyboard switching time.
- Kiosk inactivity state is bound to the active profile ID, and profile/cloud transactions restore
  both the activity timestamp and profile identity on failure.
- Managed-profile reconciliation fingerprints a single Remote Config snapshot and reapplies when
  the QWERTY kill switch changes in either direction.

### QWERTY typing

- Alternate-key callouts select on release.
- Gesture arbitration separates taps, cursor motion, alternates, page transitions, and glide
  capture.
- Space supports tap, quick swipe, and hold-cursor interaction without swallowing typing.
- Suggestion chips have reliable hit testing and accessibility.
- Autocapitalization no longer produces phantom capitals after correction replacements.
- Correction undo and literal restoration are scoped to the immediate correction and invalidated
  by later edits/page transitions.
- Typing-quality counters and correction evidence are serialized and more trustworthy.
- UI coverage now exercises realistic sentences, punctuation, suggestions, undo, alternates,
  fast typing, page changes, and pack cycling end to end.

Autocorrect remains default-OFF. The frozen corpus still misses precision and visible-candidate
thresholds, so lower-confidence candidates are suggestions rather than silent replacements.
Thresholds were not lowered.

### iPad and kiosk form factor

- The companion app uses a dashboard/sidebar structure suited to the larger display.
- iPad exposes profiles, kiosk readiness, provisioning, policy/fallback state, and a usable
  keyboard preview without presenting phone-style dead space as the primary experience.
- Numpad placement supports automatic, left, right, centered, and full-width modes.
- QWERTY placement supports centered, split, compact-left, and compact-right modes.
- Kiosk is an iPad-only extra-tall preset; Small, Regular, Tall, and Kiosk measure distinctly.
- Custom side columns remain inside the selected geometry and do not overlap the fixed digit grid.
- Alternate callout items scale to compact keyboard widths, including eight-option menus at
  320-point width, without clipping their elevation.

### Concurrency and reset safety

- Personalization reset snapshots are atomic and serialized across app/extension processes.
- Interrupted epochs recover.
- Readers remain non-destructive.
- Stabilized epochs are revalidated before persistence, preventing stale cross-process writes from
  undoing a reset.

## Final verification

| Area | Verdict | Detail |
|---|---|---|
| Unit suite | **PASS** | 885 total; 882 passed, 3 skipped, 0 failed |
| Signed iPhone UI | **PASS** | 33 total; 28 passed, 5 iPad-only skips, 0 failed |
| Signed iPad UI | **PASS, combined** | full run passed 32 cases; its sole 120-second timeout passed on final code with a 300-second allowance |
| QWERTY end-to-end | **PASS** | realistic typing, suggestions, undo, gestures, page/pack transitions |
| iPad adaptive geometry | **PASS** | five numpad and four QWERTY placements |
| iPad height ordering | **PASS** | 358 < 408 < 478 < 558 pt |
| Pack screenshot state | **PASS** | Math and conversion setup survives scenario relaunch |
| Generic-device Release builds | **PASS** | `NumPad` and `Keyboard`, unsigned compile/link gates |
| Localization syntax | **PASS** | 32 tables |
| Plist/privacy syntax | **PASS** | seven files |
| Visual attachment export | **PASS** | 36 phone files; 54 iPad files |
| Autocorrect confidence | **FAIL / contained** | precision 0.8023, top-three 0.9018; default remains OFF |
| Physical/external/signed gates | **NOT PERFORMED** | required before Apple submission |
| Independent final code review | **PASS** | no actionable Critical or Important findings through `6bf3fa81` |

The exact commands, result bundle names, visual manifest hashes, warning inventory, and remaining
gate matrix are in
`docs/release/2026-07-23-evidence-log.md`.

## Visual review

The final green-run exports provide distinct, readable evidence for:

- the iPad dashboard and keyboard preview;
- Kiosk locked/entitled states;
- all four height presets;
- automatic/left/right/center/full-width numpad;
- centered/split/compact-left/compact-right QWERTY;
- QWERTY correction and interaction states;
- Store, custom editor, Math, conversion, theme, and height screenshot slots.

The larger-form-factor result is materially better than the original settings-table experience:
status and kiosk operations are visible without deep navigation, while adaptive keyboards make
intentional use of the iPad width.

One automated visual limitation remains: the Math pack and typed expression are proven, but the
debounced Live Math Preview chip did not appear during screenshot capture. Its decision logic is
unit-tested; hardware timing still needs validation.

The green UI tests functionally cover kiosk readiness/provisioning, but the export does not include
a dedicated provisioning-detail image or landscape-dashboard image. Capture both during the signed
physical-iPad pass; the visual matrix should not be called complete before then.

## Warning posture

The final incremental Release builds pass with:

- one missing Metal-toolchain search-path warning per target;
- an always-run app script-phase note.

Re-evaluate these in the exact Xcode/toolchain used for the signed archive. The unsigned build is
not a substitute for distribution signing and archive validation.

## Commit inventory

The verified implementation range is `7f77d816..6bf3fa81`. Documentation commits are included in
the branch history but are not part of the implementation-head identifier above:

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
90809712 docs: record codex remediation evidence
b703d560 fix: restore signed UI verification contracts
500c5d00 test: align UI gates with conservative policies
4044422c test: preserve adaptive geometry fixture
0b2c36e8 docs: finalize remediation release evidence
b5d236b8 docs: record remaining visual capture gates
a2f07eb7 fix: enforce kiosk reset gates and compact callouts
4db37269 fix: align kiosk readiness with qwerty kill switch
6f4a950e fix: reconcile managed qwerty rollout changes
6bf3fa81 fix: preserve kiosk clock on cloud rollback
```

The four commits after the first evidence handoff are the final independent-review remediation:
live-gate-safe kiosk resets, rollout-aware readiness, compact alternate callouts, managed-profile
reconciliation across kill-switch changes, and transactional preservation of kiosk activity state.

## Remaining pre-submission checklist

1. Run the physical iPhone/iPad matrix:
   - VoiceOver discoverability and activation;
   - QWERTY/numpad typing in Notes, Messages, Safari, Mail, and at least one third-party app;
   - hardware-keyboard coexistence;
   - alternate keys, cursor gesture, suggestions, undo, and page/pack transitions;
   - all iPad placement modes and height presets.
2. Run a Guided Access kiosk session on a physical iPad, including inactivity reset, overlay/tape/
   clipboard cleanup, administrator-auth policy, app backgrounding, and relaunch.
3. Exercise real MDM, Files-provider import/export, signed external URLs, malformed/rejected
   profiles, and recovery behavior.
4. Verify the Live Math Preview chip under real timing.
5. Compare App Store Connect privacy labels with manifests and policy; obtain native-speaker review.
6. Produce and validate a signed archive with the intended release Xcode.
7. Install from TestFlight and repeat the smoke/device matrix.
8. Review the resulting evidence before any App Store upload or submission.

## Handoff boundary

The branch is ready for final signed physical-device validation. Do not enable autocorrect by
default, lower its quality thresholds, submit to Apple, or treat simulator success as signed
distribution proof. The next action is the physical/external/signed gate sequence above, followed
by one final review.
