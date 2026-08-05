# NumPad 2.1 emoji verification — 2026-08-04

Code-under-test commit: `a5bd166151550ec563f75cab7e237b4fc4c37db0`.

This note records simulator engineering evidence only. It does not certify physical extension
memory, VoiceOver behavior, real-host compatibility, or a speed improvement.

## Scope and static review

- Emoji remains nested inside `QwertyPageHost`; no persisted top-level `Page` changed.
- `QwertySpellChecker.swift`, `QwertyAutocorrect.swift`, suggestion-coalescing files, and Glide
  files are absent from the branch diff against integration base `c254f15d`.
- The branch introduces no runtime network path, embedded text responder, third-party emoji
  picker, popover, bitmap atlas, unbounded recents cache, or search personalization.
- The only URL literals and `print` calls added by the branch are in the deterministic build-time
  catalog generator/provenance output, not extension runtime code.
- `git diff --check c254f15d..a5bd1661` is clean. The worktree has only its pre-existing untracked
  `Pods` symlink outside the branch diff.

## Resources and bounded state

| Resource | Bytes | SHA-256 |
|---|---:|---|
| `emoji_browse_v14.json` | 249,786 | `19f50375055fc3687d08f5e57aeb6e64f0a03a67a944d5ba666457f9c20bada9` |
| `emoji_search_en_cldr40.json` | 431,168 | `1ea22adf036e6931ac9eebfb7dc3ac48e71daabe4ca6eb0376eb78393babac74` |

Both committed resources remain below their separate 1 MiB gates. Unit contracts cover lazy
browse/search loading, zero factory invocation during ordinary QWERTY construction, a ten-result
strip cap, full-grid filtering through the same deterministic ranking, 48-entry exact-sequence
MRU recents, and memory-warning teardown. These contracts do not replace a physical heap trace.

## Localization posture

`Keyboard/en.lproj/Localizable.strings` explicitly inventories the 23 emoji chrome and
accessibility keys, including placeholder parity for `Results for %@`. The localization contract
was observed RED on missing `ABC`, then GREEN at 8/0/0 after the English inventory landed.

The other 15 supported Keyboard locales continue the existing QWERTY source-key fallback to
English. No machine translation was added or represented as native-reviewed localization. The
CLDR search annotation pack is English-only by approved V1 scope; locale packs remain Wave 3.

## Simulator tests

Task 6's exact-tip integration set passed **123/123** at
`e6e9fd0e29062e88318ba13fab3b460f87a496bf` on QA-iPhone16.

The full, non-scoped `NumPadTests` bundle then ran serially on the same QA-iPhone16 simulator
(iPhone 16, iOS 26.5 build 23F77) at exact unchanged commit
`a5bd166151550ec563f75cab7e237b4fc4c37db0`:

- total: **1,088**
- passed: **1,084**
- failed: **1**
- skipped: **3**
- xcresult: `/private/tmp/numpad-emoji-results.5S5Ugo/Full-NumPadTests.xcresult`

The sole failure was
`IPadSettingsTests/test_navigatingFromLettersToSizeAndFeelImmediatelyReturnsTheExistingDockToNumpad`:
`XCTAssertEqual failed: ("numpad") is not equal to ("qwerty")`. It is the pre-existing
state-dependent flapper recorded before this lane in Buzz plan
`PLANS/NUMPAD_21_BUILD_PLAN.md` line 37 and is filed under 2.1.5. No emoji test failed.

Because this verification note changes only documentation after that run, the land request must
also carry a fresh full-package result attributed to the final exact `HEAD`.

## Open physical gates

The emoji release gate remains open until the oldest available supported **iPhone and iPad** run
the following against the exact candidate build in real host apps:

- cold browse and first search, repeated exact insertion, browse backspace, globe, `ABC`, and
  clean re-entry;
- base and mixed-tone modifier choice with the chooser wholly inside phone, iPad standard,
  Split View, and floating bounds where applicable;
- manual VoiceOver traversal, selected states, CLDR names, `Choose skin tone`, query value,
  empty/results focus, and failure announcement;
- memory trace labeled with device, OS, host, and build: retained delta at most 4 MiB after browse,
  at most 8 MiB after browse plus search, and parse peak at most 10 MiB above ordinary QWERTY;
- memory-warning teardown and recovery without crash or host insertion.

Simulator evidence may land the engineering branch, but it cannot close any of those rows. Until
both form factors are recorded, release copy remains emoji-led and makes no speed or broad-device
certification claim.
