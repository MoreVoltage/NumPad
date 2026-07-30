# Keyboard Studio Task 8 evidence

## Deferred-item closure

- Automatic device appearance disables theme tiles and explains how to choose a theme.
- The readiness hero posts VoiceOver announcements only for an actual state transition.
- Help's Version row opens a version and release-details alert.
- The iPad rail Advanced control is `studio.ipad.rail.advanced`; the Keyboard gear keeps
  `studio.keyboard.advanced`.
- The retired root demo-field keyboard observers and inset-management path are removed. The
  production root presents only the Studio phone tabs or iPad workspace; retained legacy
  controllers are compatibility implementation details, not visible navigation.

## Localization inventory

The inventory scans direct `NSLocalizedString` literals in Studio controllers, Studio design-system
sources, Studio libraries (including `StudioKeyboardPreviewModel`), and onboarding step
controllers. It found 126 keys; every one now has a parseable entry in each of the 16 app locale
tables. The preview model's `Enter` value reuses each locale's Keyboard catalog translation. The
required status and Kiosk authentication/fallback keys are catalogued in every locale.

Native linguistic review is pending for the new Studio and onboarding catalog. New non-English
entries, including the status and Kiosk authentication/fallback copy, intentionally use the English
source fallback until native review replaces them. This document does not claim human linguistic
approval.

## Safety and accessibility audit

- Studio controls use Dynamic Type, directional layout margins, minimum 44-point targets, and
  state text/glyphs in addition to color; the appearance-disabled state also exposes the VoiceOver
  `.notEnabled` trait and explanation.
- The iPad dock remains a structural sibling of the upper scroll surface and screenshot evidence
  uses the permanent bottom-anchored dock states.
- Studio analytics use fixed surface/source/state values. No typed field, snippet, clipboard, or
  imported setup content is included in the Studio analytics attributes.
- Autocorrect remains default-off; no Glide code or promise was introduced.
- Screenshot slot 03 and slot 04 setup now enters Choose keys and selects Calculations through
  stable Studio accessibility identifiers; their signed focused run passed 2/2 on the explicit
  QA iPhone simulator.
- Help describes the guide in approved plain language as covering “key sets, gestures, and
  calculator tools.”

## Native-review queue

`ar`, `de`, `es`, `fr`, `he`, `hi`, `it`, `ja`, `ko`, `nl`, `pl`, `pt-PT`, `ru`, `zh-Hans`, and
`zh-Hant`: review all new Studio/onboarding entries, prioritizing Needs attention, Unavailable,
Authentication Failed, Authenticate to change saved setups, Some choices will use available
options, and The setup could not be used.
