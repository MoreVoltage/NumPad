# QWERTY Typing Test Protocol

**Status:** ACTIVE — run Part A before any keyboard-behavior commit; run Part B before/after any
device install that touches typing behavior.
**Why this exists:** two bugs shipped to the owner's device that the unit suite could not see
(chip taps dead — keyboard `hitTest` stole suggestion-bar touches, fixed 1e60372b; phantom
mid-sentence capitals — autocap on transiently-empty proxy context, fixed 386b010b). Both were
*integration* failures between real typing and the extension pipeline. This protocol is the
regression net: an automated realistic-typing E2E suite (Part A) plus a structured manual device
script (Part B), with a standing triage rule (Part C).

---

## Part A — Automated (simulator): `NumPadUITests/QwertyRealisticTypingTests`

Each test types a real sentence key-by-key through the extension process on the QWERTY page and
asserts the FINAL text — the whole pipeline (shift machine, autocap, boundary autocorrect,
suggestion chips, revert) is exercised the way a user exercises it.

| # | Test | Types | Asserts |
|---|------|-------|---------|
| 1 | `testCleanSentenceTypesVerbatim` | `the quick brown fox jumps over the lazy dog ` | Exact: `The quick brown fox …` — one autocap'd capital, nothing else rewritten |
| 2 | `testAutocorrectRepairsCheckerHeadAndSuggestsVariantRepair` | `helllo there. i need to accomodate` then ` them ` | Exact: `Hello there. I need to accomodate them ` — checker-head repair lands, the checker-validated `accommodate` variant is visibly suggested but not silently applied, and continuation remains lowercase |
| 3 | `testSuggestionChipTapInsertsCandidate` | `teh`, then taps the "the" candidate chip **near its bottom edge** | `text.lowercased() == "the "` — candidate landed + chip's trailing space, and NO stolen top-row letter (hitTest net; this test fails on any build before 1e60372b) |
| 4 | `testChipLiteralKeepsTypedWord` | `fone`, taps the literal `“Fone”` chip, types `fone ` again | Exact: `Fone fone ` — typed form survives and is never re-corrected (session reject list) |
| 5 | `testSentencePunctuationAutocap` | `this is one. and this is two.` | Exact: `This is one. And this is two.` — capital after `. `, nowhere mid-sentence |
| 6 | `testBackspaceRevertsAutocorrect` | `teh ` (→ `The `), then ONE backspace | Exact: `Teh` — pinned mechanics: one backspace consumes the boundary char + corrected word and restores the original **without** a trailing space |
| 7 | `testFastTypingBurstNoPhantomCapitals` | 20-word paragraph, continuous, no inserted delays | Zero uppercase after position 0 (targeted assert), then exact-string equality |

### Run command (pinned destination is MANDATORY)

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadUITests/QwertyRealisticTypingTests
```

- On "Application failed preflight checks":
  `xcrun simctl bootstatus 37B2DC99-7B78-441D-9F09-220DA1D51CDD -b`, retry once.
- Runs are minutes each — launch detached (`nohup … &`) and poll the log.
- The smoke (`-only-testing:NumPadUITests/QwertyTypeSmokeTests`) stays a separate,
  complementary run: it covers page/pack/layer navigation; this class covers typing realism.

### When to run

1. Before ANY commit that touches keyboard behavior (`Keyboard/`, `NumPad/Libraries/Qwerty/`).
2. Before installing a build on a physical device (Part B assumes Part A is green).

### Determinism rules (read before adding scenarios)

- **Personal-dictionary contamination:** the dictionary persists in the app group and protects a
  word after **3** recorded acceptances. Typo words the suite needs CORRECTED (`teh`, `helllo`,
  `accomodate`) must never accumulate acceptances: corrected words record none; the literal-chip
  test uses a **dedicated** typo (`fone`); the revert test deliberately stops after the revert
  (a boundary after it would record an acceptance of `teh`).
- **Never anchor on a letter key's current label** — autocap relabels the grid. The typing
  helper taps whichever case of a letter currently exists; assertions judge the OUTPUT.
- Settings-app keyboard enablement is driven at most once per runner process (static flag).

### Known automation gaps (covered by Part B instead)

- **Real-finger chip precision:** the sim tap is a synthesized point; real fat-finger geometry
  at the chip/key border (and the 4pt hitTest slop) only exists on a device digitizer → B5.
- **Candidate casing/vocabulary:** `UITextChecker` guess casing and ranking are OS-vocabulary
  details; tests 3's asserts are case-insensitive by design — exact candidate wording is
  eyeballed on device → B4.
- **Personal-dictionary protection (3 acceptances) + Reset Typing Personalization:** stateful
  and app-UI-dependent; automating it would leave persistent cross-run state → B9/B10.
- **ALL-CAPS words:** caps-lock is a double-tap shift timing gesture; not automated → B8.
- Haptics/sound, glide typing (flag-dark), and typing *feel*/latency are device-only by nature.

---

## Part B — Device protocol (manual, ~10 min)

On a physical iPhone, in **Notes** (or the harness app's typing surface), NumPad keyboard active,
QWERTY page frontmost. Type exactly the text shown; check PASS only if the expected outcome
matches exactly. Anything else → FAIL + a note (what appeared, verbatim).

| # | Do | Expect | PASS | FAIL | Notes |
|---|----|--------|------|------|-------|
| 1 | New note. Type `hello. it works` | `Hello. It works` — capitals at both sentence starts only | ☐ | ☐ | |
| 2 | Type a full clean paragraph: `the meeting moved to friday so we should plan to review the notes before lunch and send the summary after` | Lands verbatim except leading `The`; NO other capitals, NO surprise corrections | ☐ | ☐ | |
| 3 | Type `helllo there ` then `i need to accomodate`; confirm `accommodate` is suggested, type ` them ` without choosing it | `Hello there I need to accomodate them` — checker-head repair lands; lower-confidence variant stays literal; `there`/`them` lowercase | ☐ | ☐ | |
| 4 | Type `teh` (no space). Tap each chip once across three tries (retype `teh` each time): literal `“teh”`, then each candidate | Literal keeps `teh` + space; each candidate replaces the word + space. All three chips respond to a single tap | ☐ | ☐ | |
| 5 | Retype `teh`; tap a chip deliberately at its BOTTOM edge (almost touching the top key row). Repeat 3× | Chip activates every time — never a top-row letter (q/w/e/r/t/y…) inserted | ☐ | ☐ | |
| 6 | Phantom-capitals repro: type `helllo ` and KEEP TYPING fast: `there is more text here` | `Hello there is more text here` — no stray capital on ANY word after the correction | ☐ | ☐ | |
| 7 | Type `teh ` (autocorrects to `The `), then ONE backspace | Text becomes `Teh` (original restored, no trailing space). Type space — it must NOT re-correct | ☐ | ☐ | |
| 8 | Type an ALL-CAPS word: enable caps (double-tap shift), type `ASAP ` | Stays `ASAP` — acronym never autocorrected or downcased | ☐ | ☐ | |
| 9 | Proper noun ×3: type `Zaneta ` three times (accept it as typed each time — tap the literal chip if a correction is offered) | By the 3rd acceptance the word is personally known: no correction attempt, and it ranks in the bar | ☐ | ☐ | |
| 10 | App → Home → NumPad Type → **Reset Typing Personalization**, then repeat step 9 ONCE | Protection is gone: the word is treated as unknown again (correction/suggestion behavior back to step-9-first-try) | ☐ | ☐ | |

Time-box: ~10 minutes. If a step FAILs, finish the script anyway — later steps often localize
the mechanism.

---

## Part C — Triage

- **Where results go:** append a dated entry to the Results Log below (copy the template).
  Part A failures carry their xcresult path; Part B failures carry the step number + verbatim
  observed text.
- **The rule: any FAIL → file the mechanism.** Follow the eval-baseline doc pattern
  (`docs/plans/full-keyboard/research/2026-07-21-eval-baseline.md`): (1) diagnose the mechanism
  (not the symptom) and write it down, (2) fix it, (3) add a regression test to Part A
  (respecting the determinism rules above) — a Part B step is only "covered" once its failure
  mode has an automated net or a documented automation gap.

### Results Log

#### 2026-07-21 — (template / first entry)

- Build: `feat/qwerty-glide-and-accuracy` (this commit)
- Part A: all 7 green on the pinned sim (176s total; one preflight-checks flake before the run,
  cleared by the documented bootstatus retry)
- Part B device: `<device model, iOS version>`
- Steps: 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10 ☐
- FAILs + mechanism notes: _(none yet — device pass pending)_
