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

## Deferred-item closure

Closed Task 1 locale catalog gap; Task 3 inert root demo-field observer/inset path; Task 4
automatic-theme no-op and redundant readiness announcement; Task 5 version action and Kiosk
catalog entries; and Task 6 duplicate Advanced identifier.

## Native-review list and concerns

All 16 app tables contain the 123 direct Studio/onboarding keys and parse validation is required
before handoff. Native review remains pending for every new non-English Studio/onboarding entry;
the Kiosk/status values and all other new catalog entries use explicit English fallbacks. No human
linguistic approval is claimed.
