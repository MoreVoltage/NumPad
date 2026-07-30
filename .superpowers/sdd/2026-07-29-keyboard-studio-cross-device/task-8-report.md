# Task 8 report — localization and accessibility hardening

## Files

- Studio appearance, status, Help, iPad workspace, root lifecycle, screenshot fixtures, and focused tests.
- All 16 `NumPad/*.lproj/Localizable.strings` catalogs.
- `docs/release/2026-07-29-keyboard-studio-evidence.md`.

## RED / GREEN

- RED: focused tests failed because the status hero could not report whether a readiness update
  changed, and the new Advanced rail identifier did not exist.
- GREEN: the focused `KeyboardStudioRefreshTests` and `IPadSettingsTests` command passed after
  the smallest behavior changes.
- Review RED: signed `testSlot03_mathPreview` failed at
  `ScreenshotCaptureTests.swift:270` because the retired Home `Keyboard Packs` row did not exist.
- Review GREEN: signed `testSlot03_mathPreview` and `testSlot04_conversion` passed on
  `37B2DC99-7B78-441D-9F09-220DA1D51CDD` with `CODE_SIGNING_ALLOWED=YES` (2 passed, 0 failed,
  0 skipped). The helper now selects the stable Keyboard Studio Choose keys and Calculations
  identifiers.

## Deferred-item closure

Closed Task 1 locale catalog gap; Task 3 inert root demo-field observer/inset path; Task 4
automatic-theme no-op and redundant readiness announcement; Task 5 version action and Kiosk
catalog entries; and Task 6 duplicate Advanced identifier.

## Native-review list and concerns

All 16 app tables contain the 126 direct Studio/onboarding keys, including the preview model's
`Enter` label, and parse validation is required before handoff. The `Enter` values reuse each
locale's Keyboard catalog translation. Native review remains pending for every new non-English
Studio/onboarding entry; the Kiosk/status values and all other new catalog entries use explicit
English fallbacks. No human linguistic approval is claimed.

## Review follow-up

- Replaced the last screenshot-fixture path through the retired Home/Keyboard Packs UI with
  `studio.keyboard.choose-keys` → `studio.keyset.calculations`.
- Replaced the visible Help term “packs” with the approved “key sets” copy and replaced the exact
  localization key in all 16 app tables.
- Restored the slot 04 named-invocation contract as `testSlot04_conversion`.
- Signed `testSlot04_conversion` passed on
  `37B2DC99-7B78-441D-9F09-220DA1D51CDD` with `CODE_SIGNING_ALLOWED=YES` (1 passed, 0 failed,
  0 skipped).
