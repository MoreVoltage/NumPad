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

- Resolved in Fix Round 1: public routes now use Studio Saved setups/Move setups and the retained legacy screen uses Saved setups terminology.

## Fix Round 1

### Delivered

- Added app-only `KioskMutationAuthorizer`, the single LocalAuthentication and active-Kiosk-policy decision point. It accepts an injectable authentication closure, resolves on the main queue, and ignores repeated authentication callbacks.
- Routed Studio apply, copy, and imported-save mutations through that authorizer, preserving the managed-settings and Kiosk entitlement checks before it runs.
- Routed legacy Profiles mutations through the same boundary, including confirmed deletion/import and the Profile Editor's actual Save persistence (rather than only editor presentation).
- Preserved profile-document deep-link parsing while routing its presentation to Studio Move setups. Home, Dashboard, and iPad Saved setups entries now open the Studio list; visible labels use Saved setups/Kiosk mode/Move setups, and Home no longer uses a hardcoded Pro price.
- Replaced the remaining reachable legacy screen title and section labels, and added every new iPad presentation key to all supported localizations.

### Tests and validation

- Test-first: expanded `KioskMutationAuthorizerTests` for no-policy, failure, cancellation, success, main-queue completion, and duplicate callbacks; added `StudioMutationAuthorizationTests` for cancelled no-write and authorized apply; updated deep-link and iPad/UI navigation assertions before routing changes.
- Signed focused unit/navigation command on `id=37B2DC99-7B78-441D-9F09-220DA1D51CDD` — 37 passed: `KioskMutationAuthorizerTests`, `StudioMutationAuthorizationTests`, `DeepLinkRouterTests`, `IPadSettingsTests`.
- Signed UI smoke on that same explicit simulator — `StudioDestinationsUITests`: 1 passed.
- Signed explicit-ID build — `BUILD SUCCEEDED`.
- `git diff --check` — clean.
