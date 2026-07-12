# Glide Typing (Dark) + QWERTY Accuracy Stack — Design

**Date:** 2026-07-12
**Status:** Approved by owner (this session). Supersedes nothing; implements the recommendations of
`research/2026-07-10-glide-typing.md` and `research/2026-07-10-priority-dictionaries-and-key-accuracy.md`.
**Owner decisions captured here:**
1. **Glide builds dark** — full implementation behind `FeatureFlags.qwertyGlideTypingEnabled`
   (**default `false`**, Store → Beta toggle, DEBUG/TestFlight only) AND'd with a Remote Config
   kill switch (`qwerty_glide_typing_enabled`). No App Store exposure until legal review clears
   the Cerence shape-matching patent (US 7,706,616, active through 2026-12-21) and Cerence v.
   Apple. Flag off = byte-for-byte current behavior.
2. **Accuracy scope = research Phases A + B + C** — bundled frequency lexicon re-ranking,
   per-user learned words with a reset action, per-key touch-offset personalization. Phase D
   extras (geometry-weighted edit distance, double-letter heuristics) stay follow-ons.

## 1. Shared foundation — `QwertyFrequencyLexicon` (Phase A)

One bundled resource powers **both** the suggestion re-ranker and the glide decoder.

- **Source:** Hermit Dave `FrequencyWords` `en_50k.txt` (OpenSubtitles-derived; MIT code /
  CC BY-SA 4.0 data — the cleanest license of the surveyed corpora). Attribution line added to
  the app's credits surface.
- **Build tooling:** a one-time converter in `tools/` (kept in-repo for reproducibility, never
  shipped) packs the text list into a flat, lexicographically sorted binary: length-prefixed
  UTF-8 word + `UInt16` rank bucket ≈ 450–500KB (`qwerty_lexicon_en.bin`, bundled into the
  Keyboard extension target).
- **Runtime:** `NumPad/Libraries/Qwerty/QwertyFrequencyLexicon.swift` (pure) loads the resource
  lazily on first QWERTY-page activation and binary-searches the packed bytes directly — no
  `Dictionary` inflation; resident memory ≈ file size, far inside the ~50MB ceiling.
  API: `rank(of word:) -> Int?`, `rerank(_ candidates: [String]) -> [String]`
  (stable: ranked words by rank ascending, unknown words after, ties preserve input order),
  and `rerankKnown(_ candidates: [String]) -> [String]` (known words reorder by rank among
  themselves, within the slots they occupied; unknown words keep their exact positions).
- **Wiring:** in `QwertyPageHost.refreshSuggestions()` and `applyPendingCorrection()`,
  `completions` pass through the full `rerank` and `guesses` through `rerankKnown` **before**
  the existing `QwertyAutocorrect.suggestions()/decide()` merge — no public API changes;
  `UITextChecker` remains the sole spelling authority (re-rank, never replace).
  - *Completions* need the full re-rank: their alphabetical ordering is **undocumented but
    observed** (NSHipster finding; Apple's docs claim probability sorting — see
    `2026-07-05-technical-feasibility.md` §2) and carries no signal worth preserving.
  - *Guesses* are already probability/edit-likelihood-ranked
    (`2026-07-05-oss-prediction-options.md` §1), so frequency only refines ordering **among
    corpus-known guesses**. A full re-rank would demote a correct out-of-corpus guess (proper
    noun, jargon — `rank = nil` sorts after every known word) below a frequent-but-wrong
    in-corpus word, which could then auto-apply (e.g. "fjrods" → "fjords" losing the replace
    slot). Policy: frequency refines ordering among words the corpus knows; it never
    overrides the checker's judgment about words the corpus doesn't know — a wrong
    correction is worse than a missed one.

## 2. Personal dictionary — `QwertyPersonalDictionary` (Phase B)

- Pure module: bounded word → acceptance-count table (cap ~1,500 entries, frequency-decay
  eviction), incremented when a word is typed to a boundary **without** being auto-corrected or
  when a suggestion chip is tapped. Entries fold case and the curly apostrophe (\u{2019} → ')
  on both the recording and lookup paths, so don't/don’t accumulate as ONE entry.
- **Decay tuning (as built, review follow-up):** counts halve (zeros drop) every **2,000**
  recordings, not 200 — every accepted word advances the clock, so at ~40wpm a 200-word window
  halved everything every ~5 minutes and a name accepted 3× lost `isKnown` protection almost
  immediately. Protection must survive normal typing volume; decay exists to age out one-off
  noise and bound the table. The halving runs BEFORE the boundary recording, so a first-seen
  word landing exactly on the interval survives at count 1.
- Persistence: `UserDefaults.group` snapshot via the `@UserDefault`/`Constants` pattern.
- Ranking priority (research §2): lexicon expansion (unchanged, already first) → personal words →
  frequency-re-ranked guesses → frequency-re-ranked completions.
- **Auto-replace protection:** words at/above an acceptance threshold are treated as known in
  `decide()` — the corrector stops "fixing" names and jargon the user demonstrably types.
- **Privacy (hard constraint, per `2026-07-05-rules-and-structure.md`):** the table never crosses
  `SettingsSync`/Darwin notifications, is never read by app-side `Analytics`, and gains no
  export/sync path. A **Reset Typing Personalization** row in `QwertySetupViewController` clears it
  (also clears the Phase-C touch model — one "reset typing personalization" action).
- **Reset generation (as built, review follow-up):** the reset row also increments a
  **contentless** `qwertyPersonalResetGeneration` Int in the app group. `QwertyPageHost`
  captures it at load and re-checks before every persist: on mismatch it discards its
  in-memory table and applies only the current mutation on top of freshly-loaded storage.
  Without this, a keyboard raised in the adjacent iPad Split View app would write its whole
  stale pre-reset table back on the next accepted word. Only an integer crosses the app
  group — never dictionary content — so the privacy constraint holds; the Phase-C touch
  model reuses the same generation key.

## 3. Per-key touch offsets — `QwertyTouchPersonalization` (Phase C)

- Pure module: per-key decaying running-average offset `(dx, dy)` between accepted touch points
  and the key's visual center — the mean-offset half of Gboard's spatial personalization
  (arXiv:2209.11311), no covariance, no ML.
- Keyed by the key's **base character** (not flattened index) and stored in key-size-normalized
  units so rotation/layout changes don't invalidate it. Learned from taps that aren't
  immediately backspaced/corrected; persisted like Phase B.
- Applied as a **second, independently-capped bias channel** through the existing
  `QwertyTouchRouting.biasDistanceCap` resolver: direct hits always win; the model can only tip
  an already-ambiguous gap touch. An empty model contributes zero bias, so cold start degrades
  to exactly today's shipped behavior.

## 4. Glide typing (dark)

### 4.1 Touch capture (the genuinely new layer — research §4.1)

`QwertyKeyboardView` gains a `touchesBegan/Moved/Ended/Cancelled` disambiguation layer (matching
the codebase's manual-touch-handling preference over gesture recognizers):

- Only touches **originating on a letter key** are glide-eligible — the space bar keeps its
  cursor-pan, backspace its autorepeat, shift/globe/strip keys their tap behavior, untouched.
- The first N points/M ms buffer; if movement exceeds a distance threshold **and** the path has
  crossed ≥2 distinct key frames, the touch upgrades to glide mode and the origin button's own
  tracking is explicitly cancelled (no spurious tap). Below threshold, everything falls through
  to normal tap handling unchanged (callouts included).
- In glide mode each sample reuses `QwertyTouchRouting.keyIndex(at:keyFrames:in:)` as-is (bias
  omitted); consecutive duplicate key indices collapse into the coarse letter sequence while the
  raw timestamped point path is kept for scoring.
- A lightweight fading polyline trail renders during capture.
- Disabled entirely when `UIAccessibility.isVoiceOverRunning` and when the feature gate is off —
  gate off means the new touch layer is never installed at all.

### 4.2 Decoder (pure, clean-room)

`QwertyGlidePath.swift` + `QwertyGlideDecoder.swift` in `NumPad/Libraries/Qwerty/`, implementing
the published SHARK2-lineage pipeline from its public description (no OSS code ported):

1. **Prune** the 50k lexicon by gesture start/end key (with adjacent-key tolerance) and a
   path-length-implied word-length band → low hundreds of survivors.
2. **Score** survivors: resample the raw path to ~48 points; generate each survivor's ideal
   key-center path **on the fly** from `QwertyLayout` unit-space geometry (no stored templates —
   the research's key memory win); shape channel (bounding-box normalized) + location channel
   (absolute) point-by-point distances; `score = a·shape + b·location` (a+b=1, tunable).
3. **Rank** by `score × frequency` from the shared lexicon; emit a ranked candidate list.

### 4.3 Pipeline integration

The ranked list is structurally identical to `Analysis.completions`, so it feeds the existing
`QwertySuggestionBarView` + `QwertyAutocorrectHistory` machinery: top candidate inserts
immediately (with a leading space when chaining a glide after a glided word), alternates fill
the bar, backspace-revert and reject work exactly as for autocorrect. Accepted glide words also
feed the Phase-B personal dictionary.

## 5. Testing

TDD throughout; every new module is pure Swift in `NumPad/Libraries/Qwerty/` matching the
100%-unit-tested convention:

- `QwertyFrequencyLexiconTests` — packed-format decode, rank lookup, stable re-rank (fixture
  list, not the shipped 50k).
- `QwertyPersonalDictionaryTests` — acceptance counting, decay, eviction, threshold protection,
  merged ranking order.
- `QwertyTouchPersonalizationTests` + extended `QwertyTouchRoutingTests` — offset convergence,
  normalization, cap behavior (bias can tip a gap, never steal a direct hit).
- `QwertyGlidePathTests`/`QwertyGlideDecoderTests` — resampling/normalization invariants;
  synthetic ideal paths decode to their source word; jittered paths still decode; start/end
  pruning never drops the true word within tolerance.
- Manual device pass for glide feel (flag on, DEBUG build) — accuracy tuning is explicitly an
  ongoing cost, not a one-time gate.

## 6. Delivery

Branch `feat/qwerty-glide-and-accuracy` off `feat/full-keyboard-v1`; one commit per phase
(A → B → C → glide capture → decoder → wiring); `graphify update .` after code changes.
Implementation order front-loads user-visible accuracy wins (A–C ship-ready) while glide stays
dark behind its flag pending legal.

## Non-goals

- No neural decoder, no ML runtime, no training pipeline (research §2.2 — different project).
- No bigram/n-gram engine (memory math already rejected it; unigram only).
- No replacement of `UITextChecker` verdicts — re-rank and augment only.
- No change to numpad-page behavior in any configuration.
