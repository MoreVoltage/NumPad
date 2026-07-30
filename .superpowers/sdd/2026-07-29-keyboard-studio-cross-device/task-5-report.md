# Task 5 — Features, Help, and Advanced

## Delivered

- Expanded the Features gallery with calculator tools, reusable text, honest Full Access guidance, and Store-backed Custom keys gating.
- Expanded Help with setup status, guides, privacy, feedback, rating, purchase restore, policy, and version.
- Added purple Advanced navigation with Saved setups, Kiosk mode, Move setups, and conditional Managed settings.
- Added Saved setup presentation, list, read-only projected detail/preview, transactional apply, and copy controls.
- Added Move setups import/export UI on top of the existing document validation boundary.
- Renamed the Kiosk surface to Kiosk mode and retained the Guided Access and Full Access limitations.
- Added the shared `KioskModeAccess` guard before all Kiosk apply/save paths: Studio detail/copy/import, legacy Profiles activation/duplicate/edit/import, `KeyboardProfileApplier`, and `ProfileImportCoordinator`.

## Files

- `NumPad/Controllers/Studio/{FeaturesStudioViewController,HelpStudioViewController,AdvancedStudioViewController,SavedSetupsStudioViewController,SavedSetupDetailViewController,MoveSetupsViewController,StudioNavigationFactory}.swift`
- `NumPad/Controllers/{KioskProvisioningViewController,ProfilesViewController}.swift`
- `NumPad/Libraries/{Studio/StudioSavedSetupPresentation,Kiosk/KioskModeAccess,Profiles/KeyboardProfileApplier,Profiles/ProfileImportCoordinator}.swift`
- `NumPadTests/StudioSavedSetupPresentationTests.swift`
- `NumPadUITests/StudioDestinationsUITests.swift`
- `NumPad.xcodeproj/project.pbxproj` (registered using `scripts/add_sources.rb`)

## RED → GREEN

1. Added presentation tests for exact saved-setup copy and stable IDs, conditional Writing, managed ownership, and probe-only projections. The focused test failed because the presentation types were absent, then passed after implementation.
2. Added Kiosk entitlement tests for the pure guard, zero writes on unentitled apply, zero persistence on unentitled import, and permitted entitled apply. The focused test failed because the shared guard/import parameter were absent, then passed after implementation.
3. Added UI coverage for Features, Help, Advanced, Custom keys Store routing, and Kiosk Store routing.

## Validation

- Signed unit test: `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/StudioSavedSetupPresentationTests` — 8 passed.
- Signed UI test: `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadUITests/StudioDestinationsUITests` — 1 passed.
- Signed explicit-ID build: `xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad -destination 'id=37B2DC99-7B78-441D-9F09-220DA1D51CDD'` — BUILD SUCCEEDED.
- `git diff --check` — clean.

## Self-review

- Projection calls `KeyboardProfileApplier.probe`, and the test snapshots every live key to prove that previewing does not write.
- Kiosk enforcement is at the persistence/application boundaries, so a missed UI path cannot mutate state. `Monetization.isProEntitled` remains the entitlement source and includes grandfathered users.
- Import/export continues to use `ProfileImportCoordinator` and its existing schema, size, and personal-content validation; no price is hardcoded.
- Visible Studio controls have stable accessibility identifiers and use the existing Dynamic Type / 44pt Studio components.

## Concerns

- The pre-existing `ProfilesViewController` retains its legacy visual terminology for legacy iPad/deep-link flows; Task 5 routes ordinary Studio users to Saved setups and adds the Kiosk safety guard there. A later cleanup can rename that legacy screen without changing its underlying APIs.
