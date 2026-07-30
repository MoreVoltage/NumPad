# SDD ledger — plan: docs/superpowers/plans/2026-07-29-keyboard-studio-cross-device.md

Branch base: `0f584a2c`
Plan/spec commit: `2eae645b`
Inherited pre-plan commits:
- `d6956396` — audit and initial Keyboard Studio contract
- `530616b8` — separate pre-existing QWERTY iPad geometry remediation

Task 1: in progress — inherited uncommitted design-system sources compile in a Debug iPhone
simulator build; awaiting independent WIP review and TDD hardening.
Task 1: minor (deferred): add non-English translations for `Needs attention` and `Unavailable`
during Task 8 localization.
Task 1: fix round 1/5 (3 addressed, 0 open; commits 4b9f0017..4829b459)
Task 1: complete (commits 2eae645b..4829b459, review clean)
Task 2: fix round 1/5 (2 addressed, 1 new open; commits 1906d2f7..85662897)
Task 2: fix round 2/5 (2 addressed, 1 new open; commits 85662897..3836106c)
Task 2: fix round 3/5 (1 addressed, 0 open; commits 3836106c..238e68c2)
Task 2: complete (commits 4829b459..238e68c2, review clean)
Task 2: parked for final review — device-specific dedicated globe-key parity is not representable
by the approved Wave 1 preview model; preview intentionally uses `needsSwitchKey: false`.
Task 3: minor (deferred): lifecycle coordinator retains inert phone demo-field keyboard-observer and
inset-management code after the Studio shell replacement; triage during final review.
Task 3: fix round 1/5 (1 addressed, 0 open; commits 919876c3..d9948ab7)
Task 3: complete (commits 238e68c2..d9948ab7, review clean)
Task 4: minor (deferred): automatic appearance leaves theme tiles actionable but silently ignores
taps; final review should require disabled/explanatory treatment before ship.
Task 4: minor (deferred): `viewWillAppear` announces readiness even when unchanged; final review
should suppress redundant VoiceOver announcements.
Task 4: fix round 1/5 (3 addressed, 0 open; commits f8711a47..0765397d)
Task 4: complete (commits d9948ab7..0765397d, review clean)
Task 5: minor (deferred): Help version row is informational/noninteractive despite the plan's
literal every-visible-row-action requirement; make it open useful version/release details.
Task 5: minor (deferred): add all 16 locale catalog entries for new Kiosk authentication and
fallback strings from `KioskMutationAuthorizer`, `SavedSetupDetailViewController`,
`MoveSetupsViewController`, and `HomeViewController` during Task 8.
Task 5: fix round 1/5 (2 addressed, 0 important open; commits 1ae5be30..ac753c22)
Task 5: complete (commits 0765397d..ac753c22, review clean with 2 deferred minors)
Task 6: minor (deferred): iPad rail Advanced and Keyboard navigation Advanced share
`studio.keyboard.advanced`; assign a distinct rail identifier during final accessibility cleanup.
Task 6: fix round 1/5 (2 addressed, 1 short-window finding open; commits 928d89a8..f02f1004)
Task 6: fix round 2/5 (implementation corrected, physical UI proof open; commits f02f1004..37707f77)
Task 6: fix round 3/5 (physical proof exposed and fixed reserve; 0 open; commits 37707f77..97045239)
Task 6: complete (commits ac753c22..97045239, review clean)
Task 7: fix round 1/5 (real first-install signed progression coverage added; 0 open;
commits 25e40ad1..01a9c546)
Task 7: complete (commits 97045239..01a9c546, review clean)
Task 8: fix round 1/5 (retired screenshot route and visible internal terminology corrected;
commits 2ca4f28b..65b2262c)
Task 8: fix round 2/5 (app-catalog Enter parity and screenshot test-name compatibility corrected;
commits 65b2262c..175c4966)
Task 8: complete (commits 01a9c546..175c4966, review clean; native linguistic review remains a
release gate)
Task 9: initial full signed verification and remediation passed:
971 units (968 passed, 3 skipped, 0 failed), 39 focused safety tests, signed compact/standard/large
iPhone Studio UI 5/5 each, signed iPad Studio/onboarding UI 6/6, and generic-device Release builds
for NumPad and Keyboard. Fixed stale Pro-only Kiosk test fixtures, first-run value-sheet UI
expectation, and four missing Studio accessibility catalog entries (commits ba65327c, 3f86c110,
5316439b, 37cdc554). Native linguistic review and physical-device keyboard testing remain release
gates; no Apple submission action occurred.
Task 9: independent review follow-up complete — added coordinator-level unentitled built-in Kiosk
state-preservation coverage (RED 0/1 with the guard removed; GREEN coordinator suite 20/20),
hardened first-install iPad upsell detection with source-specific `store.first-run-upsell` proof
(signed RED 0/1; GREEN 1/1), and replaced the ad-hoc localization inventory with a checked-in exact
37-source / 131-key / 16-catalog XCTest covering parse, duplicate declarations, placeholder parity,
and uncatalogued direct literals (RED 0/1; GREEN 1/1). Exact phone, iPad, safety, and localization
commands are recorded in the evidence/report. No external model, push, or Apple action occurred.
Task 9: second scoped review follow-up complete at tested code commit `9736f4cb` — expanded the
unentitled managed Kiosk regression to cover the complete profile store, all live/transaction/Kiosk
state, all managed applied/digest/lock metadata, unchanged SettingsSync count, and the intentional
single in-process `stateDidChange`; made the 37-source localization gate self-discovering under its
documented include rule. Diagnostic RED runs failed 0/1 for the removed guard and 0/1 for a
temporary extra discovered source; restored combined focused coverage passed 21/21. Final signed
units at `9736f4cb`: 972 total, 969 passed, 3 skipped, 0 failed. Evidence labels RED bundles as
non-release diagnostics and records every current exact command/result. No external model, push,
or Apple action occurred.
