# Task 1 report — Studio design system

## Scope and changed files

- `NumPad/Libraries/DesignSystem/StudioButton.swift`
- `NumPad/Libraries/DesignSystem/StudioCard.swift`
- `NumPad/Libraries/DesignSystem/StudioMetrics.swift`
- `NumPad/Libraries/DesignSystem/StudioRowView.swift`
- `NumPad/Libraries/DesignSystem/StudioSectionLabel.swift`
- `NumPad/Libraries/DesignSystem/StudioSegmentedControl.swift`
- `NumPad/Libraries/DesignSystem/StudioStatusHeroView.swift`
- `NumPad/Libraries/DesignSystem/StudioTagView.swift`
- `NumPad/Libraries/DesignSystem/StudioTheme.swift`
- `NumPad/Libraries/DesignSystem/StudioTileView.swift`
- `NumPad/Libraries/DesignSystem/StudioTypography.swift`
- `NumPadTests/StudioDesignSystemTests.swift`
- `NumPad.xcodeproj/project.pbxproj` (generated only through `scripts/add_sources.rb`)
- `.superpowers/sdd/2026-07-29-keyboard-studio-cross-device/task-1-report.md`

The inherited DesignSystem sources are included in the Task 1 commit. The production corrections are:

- Locked rows and tiles remain actionable, no longer claim `.notEnabled`, and use the existing localized `Unlock with NumPad Pro` VoiceOver action hint unless callers provide a more specific hint.
- Replacing a tile's lock text removes the old arranged wrapper before adding the new one.
- Segmented controls clamp invalid initializer and replacement-title selections to valid bounds.
- Status heroes prepend a state name (`Ready`, `Needs attention`, or `Unavailable`) to their VoiceOver label and now render the approved circular status-mark well.
- All DesignSystem top-level types are module-internal; this app-only target does not need a public framework API.

## RED → GREEN evidence

All correction tests exercised real UIKit controls. No source-grep assertions or mocks were used.

| Correction | RED command/result | GREEN command/result |
| --- | --- | --- |
| Locked control accessibility | `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/StudioDesignSystemTests/test_lockedControlsRemainActionableAndExplainPro` failed as expected: row/tile had `.notEnabled` and nil Pro hints. | Same command with `-quiet` exited 0. |
| Tile lock-wrapper cleanup | `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/StudioDesignSystemTests/test_replacingTileLockTextDoesNotAccumulateVerticalContent` failed as expected: repeated lock text grew the fitting height from 73.67 to 105.67 points. | The final runtime-arranged-wrapper regression test is included in the focused green suite below. |
| Initial segmented selection | `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/StudioDesignSystemTests/test_segmentedControlClampsAnInvalidInitialSelection` failed as expected: `Optional(99)` was not `Optional(2)`. | Same command with `-quiet` exited 0. |
| Status Hero VoiceOver state | `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/StudioDesignSystemTests/test_statusHeroNamesEveryReadinessStateToVoiceOver` failed as expected for Ready, Needs attention, and Unavailable. | Same command with `-quiet` exited 0. |

The palette, typography, non-color selection, and 44-point target tests are characterization coverage for the inherited WIP design-system sources: they were added after that pre-existing code and deliberately are not presented as test-first changes.

## Final verification

Focused suite:

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/StudioDesignSystemTests -quiet
```

Result: exit 0; 8/8 `StudioDesignSystemTests` passed.

Simulator build:

```sh
xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -quiet
```

Result: exit 0. The build used the simulator's normal `Sign to Run Locally` identity. Existing linker search-path and unrelated test-source warnings remain, but the build succeeded.

Registration:

```sh
ruby scripts/add_sources.rb NumPadTests NumPadTests/StudioDesignSystemTests.swift
```

Result: deterministic registration added the test target source. The inherited DesignSystem sources were already deterministically registered in the uncommitted project diff.

## Self-review

- Reviewed iOS 16 availability: iOS 17 trait observation is availability-guarded and layout refresh remains the fallback.
- Verified cards retain non-clipped shadows; tile/status surfaces deliberately clip only their own rounded content.
- Verified directional anchors/margins are used for RTL and Dynamic Type controls reflow or wrap.
- Verified lock controls retain their tap closures and expose a clear VoiceOver purchase route.
- Verified `git diff --check` is clean and test source registration is present in `NumPadTests`.

## Concerns

- `Ready` already has all app-localization entries. `Needs attention` and `Unavailable` are new `NSLocalizedString` keys in the design-system-only scope and currently fall back to English outside English. A localization pass should add translations before shipping the new status states.
- One stale single-test `xcodebuild` process (PID 91603) was confirmed as this task's command and terminated after it outlived its tool response. The final focused suite and simulator build completed normally.

## Fix Round 1 — review remediation

This round does not recast the inherited WIP as original test-first work. Instead, it performed temporary, uncommitted mutations against the real UIKit implementation to prove each characterization test catches the named regression, then restored the correct implementation and reran green.

| Protected behavior | Temporary mutation and observed RED result | Restored GREEN command/result |
| --- | --- | --- |
| Palette contrast roles | Set the standard palette primary text equal to its surface. `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/StudioDesignSystemTests/test_paletteTextAndFilledActionRolesKeepReadableContrast` failed as intended: primary contrast was 1.0, below 4.5. | Same command with `-quiet` exited 0 after restoring the semantic text color. |
| Dynamic Type scaling | Returned the unscaled base font from `StudioTypography.font`. `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/StudioDesignSystemTests/test_typographyScalesForAccessibilityWithoutShrinkingLabels` failed as intended: 16.0 was not greater than 16.0. | Same command with `-quiet` exited 0 after restoring `UIFontMetrics` scaling. |
| Visible non-color selection | Removed the selected border width, changed its selected border color to clear, then removed the selected checkmark. `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/StudioDesignSystemTests/test_selectedTileKeepsVisibleBorderAndCheckmarkSelectionCues` failed respectively at border width 1.0 versus 2.0, clear versus accent border color, and runtime `XCTUnwrap` of the visible `UIImageView` checkmark. | Same command with `-quiet` exited 0 after restoring all visible cues. The test also retains the VoiceOver selected trait assertion. |
| 44-point interactive sizing | Removed the segmented-control button minimum-height constraint. `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/StudioDesignSystemTests/test_interactiveStudioControlsMeetMinimumTouchHeight` failed as intended: 40.0 was less than 44.0. | Same command with `-quiet` exited 0 after restoring the 44-point constraint. |

The strengthened selection test inspects actual UIKit runtime state: a selected tile must have the selected border width and accent color, the VoiceOver selected trait, and an unhidden image-backed checkmark. It does not inspect source text or use a mock.

All redundant `public` modifiers have been removed from DesignSystem. The types are app-target internals and the test target accesses them through `@testable import NumPad`.

Final Fix Round 1 verification:

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/StudioDesignSystemTests -quiet
xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -quiet
git diff --check
```

Results: focused suite passed (8/8), simulator build exited 0, and `git diff --check` is clean. The existing linker search-path warning remains environmental and does not prevent a signed local simulator build.

Fix Round 1 self-review: confirmed every temporary mutation was restored before staging; verified the selection test now independently catches the missing selected border and missing checkmark; confirmed DesignSystem contains no remaining `public` modifier.
