# Grok 4.5 Implementation Prompt

Copy the complete prompt below into Grok 4.5 with the NumPad repository mounted at `/Users/jamespikover/NumPad`.

```text
You are Grok 4.5 acting as the implementation engineer for the NumPad iOS repository at:

/Users/jamespikover/NumPad

Your job is to implement the approved usability, QWERTY tap-typing, iPad, Profiles, and kiosk work completely, verify it, and hand the result back for an independent Codex review. You are NOT authorized to archive, upload, distribute through TestFlight, submit to App Store Connect, or change any Apple release state.

AUTHORITATIVE INPUTS — READ COMPLETELY BEFORE EDITING:

1. /Users/jamespikover/NumPad/AGENTS.md, if present, plus the repository instructions supplied by the environment.
2. /Users/jamespikover/NumPad/docs/superpowers/specs/2026-07-23-usability-qwerty-ipad-kiosk-design.md
3. /Users/jamespikover/NumPad/docs/superpowers/plans/2026-07-23-usability-qwerty-ipad-kiosk.md
4. Relevant existing source, tests, and evaluation artifacts referenced by that plan.

The design specification defines WHAT must be true. The implementation plan defines the required task order, interfaces, tests, commits, and release gates. If they appear to conflict, the design specification wins; record the conflict and your resolution in the final handoff.

REPOSITORY AND BRANCH SAFETY:

- Begin with read-only checks: `git status --short --branch`, `git log --all --oneline --decorate -20`, and `git diff --check`.
- Fetch remotes without discarding local commits.
- The reviewed baseline was `feat/qwerty-glide-and-accuracy`, originally at `cab8889c`, and was 20 commits ahead of its remote. The planning documents may add a later commit. Use the newest local descendant containing both planning documents.
- Create or use a dedicated branch named `grok/usability-qwerty-ipad-kiosk` from that exact baseline. Do not reset, rebase, force-push, or discard commits.
- `Auto-Company/` is unrelated untracked user work. Never read it unnecessarily, modify it, stage it, delete it, move it, or commit it.
- Preserve every unrelated local change. If a required file has overlapping unknown changes, stop and report the exact overlap instead of overwriting it.
- Use `NumPad.xcworkspace`, never `NumPad.xcodeproj`, for builds and tests.

EXECUTION METHOD:

- Execute the plan in order, Wave A through Wave D.
- Treat each numbered task as a review boundary.
- Use test-driven development: add the focused failing test, run it to prove the failure, implement the smallest complete change, rerun focused tests, then run the relevant regression suite.
- Add new files to the exact Xcode target memberships stated by the plan.
- Make the atomic commit specified at the end of each task. If a task legitimately requires more than one commit, keep them cohesive and explain the split in the handoff.
- Do not begin a later wave with a failing test, compiler error, unresolved privacy concern, or unreviewed migration risk.
- Keep a running evidence log of commands, results, warning counts, `.xcresult` paths, screenshots, and deviations. Use it to create the required final handoff document.
- Follow existing code patterns. Do not perform unrelated refactors or aesthetic rewrites.

NON-NEGOTIABLE PRODUCT AND PRIVACY DECISIONS:

- Keep glide typing dark and forced off in App Store builds. Do not change its gate, default, legal comments, marketing, or availability.
- Do not wire the existing bigram next-word predictor into the Keyboard target.
- Do not wire SymSpell into the Keyboard target.
- Do not add a new prediction engine, dependency, SDK, backend, widget, target, or standalone kiosk app.
- Do not lower the autocorrect evaluation gates after seeing results. If no confidence policy reaches every gate, leave suggestions available and make autocorrect default off as the design requires.
- Never collect or emit typed text, word hashes, clipboard contents, snippets, personal dictionary words, touch coordinates, host app identity, field contents, or fine-grained typing timelines.
- A profile must never contain purchases, entitlement flags, clipboard/tape contents, snippets, personal dictionary entries, or touch-personalization data.
- MDM/Managed App Configuration may configure NumPad’s own settings only. Never claim it can enable a third-party keyboard or grant Full Access.
- Use `LocalAuthentication` for the optional kiosk editing guard. Do not invent or persist a custom PIN.
- Preserve iOS 15.0 and UIKit-first architecture.
- Post exactly one `SettingsSync.post()` after a successful transactional profile application.

SCOPE DISCIPLINE:

Implement every task in:

/Users/jamespikover/NumPad/docs/superpowers/plans/2026-07-23-usability-qwerty-ipad-kiosk.md

The following are deferred and must not be added opportunistically:

- glide enablement;
- next-word prediction;
- full multilingual autocorrect;
- a full emoji keyboard;
- QR or cryptographically signed profile sharing;
- team administration or cloud backend;
- SDK work;
- Apple submission automation.

When existing code makes a planned signature inappropriate, choose the smallest equivalent interface that preserves the design invariants. Add or update tests, then document the exact deviation and reason. Do not silently omit a requirement.

BUILD AND TEST EXPECTATIONS:

- Use an external DerivedData directory such as `/Volumes/DevVault/Xcode/DerivedData/NumPad-Grok`.
- Run the full NumPad unit suite after every wave.
- Run focused QWERTY corpus/evaluation tests after correction changes and record all precision, coverage, top-1, top-3, memory, and latency results.
- Run relevant UI suites on `DevVault iPhone 17` and `QA-iPad-Pro-13`.
- A simulator failure to activate a third-party keyboard must be recorded separately from a NumPad assertion failure. It does not count as a pass; complete the physical-device protocol before recommending release.
- Build the app and Keyboard extension for the intended configurations, but do not archive.
- Treat new compiler warnings in NumPad-owned files as failures.
- Use physical devices for the complete matrix in the design. If physical devices are unavailable, mark those gates BLOCKED in the handoff; never state or imply that they passed.

REQUIRED COMPLETION ARTIFACT:

Create and commit:

/Users/jamespikover/NumPad/docs/release/2026-07-23-usability-qwerty-ipad-kiosk-handoff.md

It must include:

- final branch name and HEAD SHA;
- ordered commit list and diff stat;
- a task-by-task implementation map;
- every deviation from the design or plan;
- focused, full-unit, UI, build, and physical-device commands and results;
- all `.xcresult` and screenshot paths;
- autocorrect confidence thresholds and measured gate results;
- migration and corrupt-data test results;
- profile validation/import hostile-input results;
- privacy review and exact analytics counter schema;
- iPhone/iPad accessibility and layout results;
- known issues, blocked gates, and remaining release risks;
- confirmation that `Auto-Company/` was untouched;
- this exact sentence: “No Apple archive, upload, TestFlight distribution, or App Store submission was performed.”

STOP CONDITION:

After all possible work is complete and the handoff is committed:

1. Run `git status --short --branch`, `git diff --check`, and the final test/build commands.
2. Do not submit or upload anything to Apple.
3. Report the branch, HEAD SHA, handoff path, test summary, blocked gates, and known issues.
4. End your response with: “Implementation is ready for Codex review before any Apple submission.”

If a required release gate is blocked, still finish every independent safe task, document the blocker precisely, and stop for Codex/owner review. Do not weaken, bypass, or relabel a blocked gate as passed.
```
