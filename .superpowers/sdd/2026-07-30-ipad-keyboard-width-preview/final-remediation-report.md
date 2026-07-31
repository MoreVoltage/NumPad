# Final Audit Remediation Report

Base: `67e479c5f2526dabc9cb62fdb9439dc953551fab`

## Remediations

1. **Dock width ownership:** `IPadStudioLayout` remains the sole resolver for the dock outer
   frame. `StudioKeyboardDockView` tells its preview to render the NumPad into the already-resolved
   available content rather than applying `NumpadGeometry` a second time. Standalone previews still
   resolve their own width with live trait and floating inputs. No vertical sizing policy changed.
2. **iPad Theme header:** the swatch collection header is now explicitly sized and reassigned on
   iPad; the inline preview footer remains phone-only.
3. **Full Keyboard calculator overlays:** Tax/Tip and Conversion place their controls in the
   calculator `overlayFrame` and temporarily reflow the existing real `StackView` into
   `inputFrame`. Dismissal deactivates only those temporary pins and restores the original
   composition. No height constraint was added or changed.
4. **Automatic Dark Mode:** Theme uses `StudioSettingsWriter.setAutomaticDarkMode`, which performs
   one defaults write, one local refresh notification, and one Darwin settings sync.
5. **Localization:** added `Numpad Width`, `iPad Layout`, and `Full Keyboard Numpad Side` to all
   16 app localization tables. Non-English additions are marked as machine-translated and pending
   native review. The localization inventory now includes Profile Editor and explicitly verifies
   the new Profile Editor labels in every bundle without expanding this audit into its unrelated
   historic translation backlog.
6. **Width-choice affordance:** Size & Feel uses five proportional horizontal bars derived from
   the 60/70/80/90/100 production fractions, retaining the visible label, selected state,
   percentage accessibility value, and existing 44pt control size.

## Test-first evidence

- Added a dock-rendered-bounds regression that would fail with the prior nested 60%-of-60%
  behavior; it now verifies the five direct 60/70/80/90/100 outer widths and unchanged vertical
  key bounds.
- Added iPad Theme header/swatch reachability coverage, automatic-mode writer cardinality,
  proportional-sample monotonicity, Profile Editor bundle checks, and Full-left/Full-right
  calculator input-surface routing/hit-testing coverage.

## Verification

All commands used the booted `QA-iPad-Pro-13` simulator
`5B976E69-A682-4406-BCFD-BCA93FC96352` unless noted.

- Focused remediation suites: `StudioSettingsWriterTests`, selected `IPadSettingsTests`, and
  `QwertyLayoutGeometryTests` — **32 tests, 0 failures**.
  XCResult: `Test-NumPad-2026.07.30_23-37-04--0700.xcresult`.
- Resource lint/localization tests — **2 tests, 0 failures**.
  XCResult: `Test-NumPad-2026.07.30_23-38-44--0700.xcresult`.
- Full `NumPadTests` from the existing shared DerivedData — **1,019 tests, 3 skipped, 0 failures**.
  XCResult: `Test-NumPad-2026.07.30_23-38-57--0700.xcresult`.
- Targeted iPad UI width/layout tests — **2 tests, 0 failures**.
  XCResult: `Test-NumPad-2026.07.30_23-39-13--0700.xcresult`.
- Targeted iPad Theme dock test — **1 test, 0 failures**.
  XCResult: `Test-NumPad-2026.07.30_23-40-03--0700.xcresult`.
- Debug generic simulator build — **BUILD SUCCEEDED**.
- Release generic iOS device build — **BUILD SUCCEEDED**.
- `git diff --check` — clean.

## Manual QA and release status

Not manually exercised in this remediation pass: a physical device Full-left and Full-right
calculator long-press flow with the keyboard extension attached, and native-speaker review of the
15 non-English new translations. The attempted iPhone screenshot Theme UI run was terminated after
inspection found overlapping stale `xcodebuild`/`xctest` processes contending for the simulator; it
therefore is not recorded as passing. No App Store submission, archive, upload, or release action
was performed.

## Follow-up: iPad Theme empty footer

Re-review found that `TableViewController` provides an empty footer. After the iPad header-sizing
fix, `ThemeViewController` was sizing that placeholder to the phone preview height and reserving
about 260 points of blank table space. Theme now removes the inherited footer on iPad and only
sizes a footer on phone, preserving the phone inline preview.

- RED: the iPad Theme header/swatch test failed with `260.0 > 0.5` for the footer height.
- GREEN: the same test passed after the iPad footer removal. XCResult:
  `Test-NumPad-2026.07.30_23-48-53--0700.xcresult`.
- Full `NumPadTests`: **1,019 tests, 3 skipped, 0 failures**. XCResult:
  `Test-NumPad-2026.07.30_23-49-07--0700.xcresult`.
- Targeted iPad Theme UI: **1 test, 0 failures**. XCResult:
  `Test-NumPad-2026.07.30_23-49-17--0700.xcresult`.
