# Priority Dictionaries & Key-Selection Accuracy for NumPad Type — Research

**Date:** 2026-07-10
**Scope:** Research only — no code changed. Answers two questions the shipped v1 (`QwertySpellChecker` +
`QwertyAutocorrect` + `QwertyTouchRouting`) deliberately left open: (1) can a bundled word-frequency prior
rank corrections/completions better than `UITextChecker`'s opaque, alphabetically-ordered output, and
(2) what's the next accuracy increment beyond the shipped zero-dead-zone + completions-bias touch router.
**Reads in-repo before this research:** `Keyboard/Libraries/QwertySpellChecker.swift`,
`NumPad/Libraries/Qwerty/QwertyAutocorrect.swift`, `NumPad/Libraries/Qwerty/QwertyTouchRouting.swift`,
and the sibling docs `2026-07-05-oss-prediction-options.md` / `2026-07-05-technical-feasibility.md` (this
doc cross-references rather than re-derives their n-gram/bigram memory math and OSS-engine survey — see
"Relationship to existing research" below).

---

## Executive summary

**Recommendation:** ship a **bundled unigram frequency prior + spatial-aware re-ranking of `UITextChecker`'s
output** as the next increment — not a bigram/n-gram engine (already correctly rejected in
`2026-07-05-technical-feasibility.md` §"memory math": 10–60MB naive, most of the 50–70MB budget). Source
the prior from **Hermit Dave's `FrequencyWords`** (OpenSubtitles-derived, MIT code / CC BY-SA 4.0 data,
`en_50k.txt` = 608KB raw text, confirmed by direct fetch) rather than SUBTLEX-US (murkier commercial-use
permission chain) or raw Google Books Ngrams (huge, needs its own extraction pipeline — `wordfreq` already
did that work and re-exposes it under the same CC BY-SA 4.0 data license). Ship it as a small packed binary
(word + rank) decoded into a **flat sorted array + binary search** — at 50k words this beats the complexity
of a marisa-trie/DAWG/FST FFI bridge (no mature pure-Swift implementation exists; see §2) while landing in
the same low-single-digit-MB range the sibling doc already budgeted for a "unigram layer." Use the prior to
**re-rank**, never to add new candidates: `QwertyAutocorrect.suggestions()`/`decide()` keep calling
`UITextChecker` exactly as today; a new pure `QwertyFrequencyLexicon` module only re-sorts what comes back,
which sidesteps the licensing and quality risk of substituting the system's own spell/guess logic.

On the touch side, the shipped `QwertyTouchRouting.bias(forCompletions:...)` already captures the
"free" 80% of what Google's own *Spatial model personalization in Gboard* (Sivek et al., MobileHCI 2022,
[arXiv:2209.11311](https://arxiv.org/abs/2209.11311)) does — biasing ambiguous touches toward a
statistically likely target. The **next cheapest increment** is a **per-key mean-offset model** (no
covariance, no ML): track a decaying running average of where accepted keystrokes actually land relative to
each key's visual center, and feed that as a second, independently-capped bias term into the same
`biasDistanceCap`-bounded resolver. This is directly the "personalized key center offset means" half of the
Gboard paper's approach, minus the (optional, harder) learned-covariance half — cheap, pure, unit-testable,
no device-side ML runtime. Full Gaussian-covariance personalization, LM-weighted dynamic key resizing
(Apple's own `US 8,232,973` patent), and keyboard-geometry-weighted edit-distance re-scoring of corrections
are real, documented techniques but each is a bigger lift for a marginal gain on top of what's already
shipped — recommended as v2+ candidates, gated behind the same OSS-prediction offline harness the team
already committed to running first (`2026-07-05-oss-prediction-options.md` §"Test harness design").

**Effort:** frequency lexicon + re-ranking ≈ **S–M** (one data-pipeline pass + ~150–250 lines of pure Swift
+ tests, no ML, no device gate beyond the existing memory/latency ones). Per-key offset personalization ≈
**S** (extends the existing pure `QwertyTouchRouting` module with the same bias-cap discipline). Both fit
the "pure logic in `NumPad/Libraries/Qwerty/`, 100%-unit-tested, no Full Access" architecture already in
place — no architectural precedent needs to change.

---

## Relationship to existing research

Two facts from the sibling docs anchor everything below and are **not re-derived** here:

1. `2026-07-05-oss-prediction-options.md` already surveyed full **prediction engines** (SymSpell, AOSP
   LatinIME dictionaries + bigrams, FUTO ContextLM, KeyboardKit, Fleksy) and set up an offline
   keystroke-savings-rate harness as the **pre-decision gate** before building anything beyond the system
   floor. This doc is narrower: it is about the **word-frequency data layer** specifically (which corpus,
   which license, which memory footprint) and about **touch-accuracy techniques**, not about swapping the
   whole prediction engine.
2. `2026-07-05-technical-feasibility.md` §"Building your own frequency/n-gram engine" already did the
   bigram memory math (10–60MB, LOW confidence but directionally trusted) and concluded a **unigram-only**
   layer is "genuinely cheap" (2–6MB estimate). This doc's lexicon recommendation stays inside that
   unigram-only envelope — it does not revisit the bigram decision.

---

## 1. Priority / frequency dictionaries

| Source | License (code / data) | Vocabulary tiers available | Format as distributed | Est. size (25k / 50k / 100k words) | Commercial-use risk | Verdict |
|---|---|---|---|---|---|---|
| **Hermit Dave `FrequencyWords`** (OpenSubtitles-derived) — [GitHub](https://github.com/hermitdave/FrequencyWords), [README](https://github.com/hermitdave/FrequencyWords/blob/master/README.md) | Code: **MIT**; data: **CC BY-SA 4.0** (confirmed live in repo) | Ships `en_50k.txt` and `en_full.txt` (1M+ words) per language; any smaller cut is a trivial top-N slice | Plain text `word count` per line | **Measured directly**: `en_50k.txt` = 608KB raw text (622,749 bytes, confirmed via HTTP HEAD); 25k ≈ ~300KB, 100k ≈ ~1.2MB raw text extrapolated linearly [MED confidence — not independently measured at those exact cuts] | **LOW** — permissive MIT for tooling, CC BY-SA 4.0 for data is share-alike on *redistributing the dataset itself*, not on the app binary (same framing the sibling doc already used for Helium314/FlorisBoard — attribution credits-screen line, not a blocker) | **Recommended primary source** — smallest, cleanest license story, already used by "Wikipedia, input methods, and autocomplete keyboards" per its own README |
| **wordfreq** (rspeer) — [GitHub](https://github.com/rspeer/wordfreq), [PyPI](https://pypi.org/project/wordfreq/) | Code: **Apache 2.0**; data: **CC BY-SA 4.0** | Zipf-bucketed "small" (≥1/million) and "large" (≥1/100M) lists per language, 40+ languages, msgpack-packed for compactness | `.msgpack.gz` per language, designed to "load quickly and take up little space" | Not independently measured; qualitatively described as small (author-optimized for repo size) [LOW confidence — no published MB figure found] | **LOW-MED** — same CC BY-SA 4.0 share-alike consideration as above; additionally *aggregates* Google Ngrams, Leeds Internet Corpus, OpenSubtitles, Wikipedia, Twitter — broader provenance to audit if pursued | **Good fallback / cross-check** — useful as a second frequency source to validate rank ordering, likely overkill as the primary source given Hermit Dave's simpler single-corpus provenance |
| **SUBTLEX-US** — [openlexicon README](http://openlexicon.fr/datasets-info/SUBTLEX-US/README-SUBTLEXus.html), [OSF mirror](https://osf.io/djpqz/) | "CC-BY-SA"-like, but per one source **permission was individually granted by author Marc Brysbaert for non-academic use** — the two accounts found don't fully agree | 74,286-word vocabulary (fixed — not tiered) | TSV (word + frequency-per-million + film-percentage) | Fixed at ~74k words; not independently re-cuttable to 25k/50k without re-deriving frequency ranks yourself | **MED** — best-in-class *psycholinguistic quality* (subtitle-corpus frequency is empirically closer to real spoken/informal usage than book corpora), but the commercial-permission chain is second-hand and not on a canonical OSS license file — **would need a direct-confirmation email to Brysbaert before shipping**, mirroring the "30-minute spike" pattern the sibling doc already used for `requestSupplementaryLexicon` | **Best quality, weakest paper trail** — worth the confirmation email only if the frequency-ranking quality gap versus Hermit Dave/wordfreq proves material in the offline harness |
| **Google Books Ngrams (raw)** — [official exports](http://storage.googleapis.com/books/ngrams/books/datasetsv3.html), [CC BY 3.0](https://books.google.com/ngrams/info) | **CC BY 3.0**, unambiguous | Full historical corpus, effectively unbounded vocabulary depth | Sharded TAB-separated files, "so big storing it is almost impossible" per common description | Not shippable as-is — requires a full extraction/aggregation pipeline (this is exactly what `wordfreq` already did) | **LOW** license-wise, but impractical to use directly | **Not recommended directly** — use `wordfreq`'s pre-extracted output instead of re-deriving from raw dumps |
| **SCOWL / ESDB** (Spell Checking Oriented Word Lists) — [wordlist.aspell.net](https://wordlist.aspell.net/), [GitHub mirror](https://github.com/en-wl/wordlist) | **MIT-like** (current ESDB); older SCOWLv1 permission notice is similarly permissive | Tiered by "size" **10–95**, but these tiers rank *word obscurity/dialect inclusion*, not usage **frequency** — no frequency data at all | Plain word lists, no counts | Size tiers are about vocabulary breadth (common → rare/dialectal), not byte size in the same sense | **LOW** | **Not a frequency source** — useful only as a *validity* dictionary (is this a real word) for things like Hunspell-style spell-check, not for ranking corrections. Keep as a possible *validation* layer, not the priority signal. |

**Bottom line on sourcing:** ship **Hermit Dave's `en_50k.txt`** (or a curated 25k subset for an even
smaller footprint) as the v1 unigram prior. Its license story is the cleanest of the group, the file is
already measured at 608KB raw (well inside a "genuinely cheap" 2–6MB in-memory budget even before any
compaction), and it's already precedent-tested by other keyboard/IME projects for exactly this purpose.
Treat SUBTLEX-US and `wordfreq` as later cross-checks, not blockers.

### Storage format: trie / DAWG / FST / marisa-trie — realistic Swift footprint

- **marisa-trie** (LOUDS-encoded, recursively-compressed Patricia trie): the canonical "memory-efficient
  static trie," commonly cited as **50–100× smaller than a naive language dict/hash map** for string sets
  of this kind ([marisa-trie docs](https://marisa-trie.readthedocs.io/en/latest/benchmarks.html),
  [pytries/marisa-trie](https://github.com/pytries/marisa-trie)). The catch for this codebase: it's a
  **C++ library with Python/Java bindings** — there is no maintained pure-Swift port, so adopting it means
  owning a C++ bridging layer inside a memory-capped keyboard extension for a data structure sized for
  problems far larger than 50k words. Not worth the integration cost here.
- **DAWG (Directed Acyclic Word Graph)**: deduplicates shared suffixes as well as prefixes
  ([Steve Hanov's write-up](https://stevehanov.ca/blog/compressing-dictionaries-with-a-dawg)); a naive trie
  can balloon a 500k-word English dictionary to **500–900MB** by allocating a full child-pointer array per
  node, which a DAWG avoids. At NumPad's 50k-word scale this failure mode is much smaller in absolute terms,
  but the *lesson* (don't use a naive per-node-array trie) still applies if a custom Swift trie is written.
- **FST (Finite State Transducer)**: maps prefixes to compact payloads (here: a rank/frequency value) with
  transitions as delta offsets in one contiguous array — commonly **3–10× smaller than a naive trie**
  ([search-ranking comparison](https://www.systemoverflow.com/learn/search-ranking/search-autocomplete/memory-compression-dawg-fst-and-double-array-tries)).
  Best asymptotic choice, but same problem as marisa-trie: no mature pure-Swift implementation to reuse.
- **Realistic recommendation for 25k–100k words in Swift, no FFI:** a **flat sorted array of
  (word, rank) pairs packed into a single `Data`/bundled resource, decoded once at extension launch, looked
  up via binary search** (`String` comparison or a small custom byte-trie if profiling shows binary search
  isn't fast enough — at these sizes it will be). This avoids both failure modes above: it isn't a naive
  per-node trie (no blowup), and it isn't a new C++ dependency. A `Dictionary<String, Int>` is the *simpler*
  but *more wasteful* option — Swift's native String/Dictionary overhead is commonly cited in the tens of
  bytes per entry beyond the raw string bytes, which at 50k entries is still only single-digit MB, so either
  approach comfortably clears the "genuinely cheap" 2–6MB estimate the sibling doc already used for a
  unigram layer. Prefer the flat sorted array for lower peak memory and simpler Codable-free serialization;
  fall back to `Dictionary` if implementation speed matters more than the last few MB.
- Existing pure-Swift trie libraries surveyed
  ([ACRAutoComplete](https://github.com/acrookston/ACRAutoComplete),
  [Swiftrie](https://github.com/yucelokan/Swiftrie),
  [trie-swift](https://github.com/morishin/trie-swift)) are all naive per-node tries aimed at small
  in-app autocomplete use cases, not memory-optimized for a capped extension — none is a drop-in win over
  a hand-rolled flat sorted array for this specific job.
- Also notable but not needed at this scale: **PruningRadixTrie**
  ([wolfgarbe/PruningRadixTrie](https://github.com/wolfgarbe/PruningRadixTrie), MIT, same author as
  SymSpell already surveyed in the sibling doc) — a radix trie that stores each node's max-child-rank to
  prune low-value branches early, "3 orders of magnitude faster" for top-K prefix lookups on large
  dictionaries. Worth revisiting only if a future phase needs *live-typed prefix* completion ranking over
  a bigger-than-100k vocabulary; overkill for re-ranking `UITextChecker`'s already-short candidate list.

---

## 2. Combining a frequency prior with `UITextChecker` + the user's own vocabulary

**Design constraint from the existing code:** `QwertySpellChecker.analyze(word:)` and
`QwertyAutocorrect.suggestions()`/`decide()` must keep calling `UITextChecker` exactly as they do today —
the frequency prior's job is **re-ranking what comes back**, not replacing the misspelling verdict or
guess generation. This keeps the change small, keeps `UITextChecker`'s actual spelling judgment (which is
the expensive, hard-to-replicate part) as the source of truth, and directly targets the one *documented*
weakness already called out in `QwertySpellChecker`'s own comment: `completions(forPartialWordRange:)`
"returns alphabetically-ordered results on iOS" (the NSHipster finding the code comment cites) — an
alphabetical ordering is exactly what a frequency prior fixes, with no need to touch the spell-check
verdict itself.

**Recommended priority order for the suggestion bar / auto-replace decision**, highest to lowest:
1. **Supplementary-lexicon expansion** (`QwertyAutocorrect.lexiconExpansion`) — exact shortcut match, already wins today; unchanged.
2. **Per-user learned unigram** (new) — a word the user has personally typed and accepted repeatedly; this is *stronger* signal than any static corpus for names, jargon, and personal shorthand, matching how Apple describes QuickType's own on-device personalization ("will learn how a user types and suggest specific slang used over time... all learning... kept on-device," per contemporaneous [MacRumors](https://www.macrumors.com/2014/06/02/quicktype-ios-8-typing-suggestions/) and [iMore](https://www.imore.com/quicktype-keyboards-ios-8-explained) coverage of QuickType's launch).
3. **`UITextChecker` guesses, re-ranked by static frequency prior** when the word is misspelled — the frequency table breaks ties/reorders when the system's own guess ranking is ambiguous or when multiple guesses are equally "valid" spell-check-wise.
4. **`UITextChecker` completions, re-ranked by static frequency prior** — this is the direct fix for the alphabetical-ordering weakness.

Concretely, this is one new pure function alongside `QwertyAutocorrect.suggestions()`:
`QwertyFrequencyLexicon.rank(candidates:) -> [String]` (sort by looked-up frequency rank, unranked words
sort last, ties preserve original system order for stability) — called on `guesses` and `completions`
*before* they're passed into the existing `suggestions(word:guesses:completions:)` merge/dedup logic, so
none of that logic needs to change.

**Per-user learned unigram — design and privacy:**
- A bounded table (e.g. capped at ~1,000–2,000 entries, LRU or frequency-decay eviction) mapping word →
  local acceptance count, incremented when a word is typed to completion *without* being auto-corrected or
  when a suggestion chip is tapped.
- Storage: `UserDefaults.group` (small enough) or a dedicated file in the app-group container, following the
  same `@UserDefault`/`Constants` pattern as everything else in `SharedExtensions.swift`.
- **Privacy — this is a hard constraint already codified in this project's own planning docs**, not a new
  policy: `2026-07-05-rules-and-structure.md` explicitly states *"Consider the autocorrect lexicon to be
  private user data. Do not send it to your servers for any purpose that is not obvious to the user"* and
  separately *"Even with Full Access granted, keystroke and lexicon data still can't be stored/transmitted
  [off-device]"*. The keyboard extension already has **no Firebase/Analytics linked at all** (per
  `CLAUDE.md`'s "the keyboard extension never logs analytics" note), so a per-user unigram store that never
  crosses `SettingsSync`/Darwin notifications and is never read by the app-side `Analytics` wrapper
  satisfies this by construction — the discipline required is simply: **never add a new sync/export path
  for this table**, and provide an in-app "reset personal dictionary" action (mirrors Apple's own Settings
  → General → Transfer or Reset → Reset Keyboard Dictionary, which resets the same category of on-device
  personalization data).
- **`UILexicon` (contacts + Text Replacement) always outranks the frequency prior** — it already does,
  structurally, since it's checked first in `QwertyAutocorrect.lexiconExpansion` before the suggestion list
  is even built.

---

## 3. Key-selection accuracy methods beyond what's shipped

| Method | Benefit | Cost (CPU / memory) | Fit with `QwertyTouchRouting`'s bias-cap design | Verdict |
|---|---|---|---|---|
| **Per-key mean-offset personalization** (no covariance) — decaying running average of touch-vs-key-center offset, learned online from accepted keystrokes | Directly captures the dominant, well-documented effect that "users do not generally press directly on physical centers of keys" and that "touch centroids... can be modeled as a bivariate Gaussian... with a certain offset from the key center" ([Gboard personalization paper, arXiv:2209.11311](https://arxiv.org/abs/2209.11311); general touch-offset literature via the [ResearchGate summary](https://www.researchgate.net/publication/262309962_A_user-specific_machine_learning_approach_for_improving_touch_accuracy_on_mobile_devices)) | Trivial — one `(dx, dy)` running average per key (≤ ~40 keys), updated with simple exponential decay on each accepted (non-corrected/non-backspaced) tap; no matrix math, no training data collection UI needed (learns silently from normal typing, same "≈200 examples is enough" finding a related paper reports for [sparse touch-correction training data](https://www.researchgate.net/publication/261860101_Sparse_selection_of_training_data_for_touch_correction_systems)) | **Direct extension** — feed the per-key offset as a second, independently-capped adjustment to the touch point *before* `keyIndex(at:keyFrames:in:bias:)` runs its existing nearest-key search, or as a second bias channel summed with the completions-bias and still passed through the same `biasDistanceCap = 0.3` ceiling so it can only ever tip an already-ambiguous touch | **Recommended next increment** — same pure-Swift, no-ML shape as what's already shipped |
| **Full Gaussian covariance personalization** (Gboard's actual production approach: per-key offset *and* learned covariance matrix, clustering keys to avoid overfitting) | Modest additional gain over mean-offset alone per the same paper ("small-but-significant improvements in... speed and... accuracy") | Meaningfully higher: covariance estimation needs more data and per-key 2×2 matrix math, plus the paper's own finding that keys must be *clustered* to avoid overfitting on sparse per-key data — real algorithm design work | Would still fit under the same bias-cap architecture, but the marginal accuracy over mean-offset-only is explicitly described as "small," not transformative | **v2+ candidate, not v1** — the mean-offset version already captures most of the value per the cited research |
| **LM-weighted dynamic key/target resizing** (what Apple's own patent describes: enlarging a key's *hit region* — not its visual size — based on predictive-text probability; [US 8,232,973](https://appleinsider.com/articles/12/07/31/apple_granted_patent_for_predictive_text_input_ui); related dynamic-footprint patent language via [techxplore coverage](https://techxplore.com/news/2020-12-apple-patents-keyboard-dynamically-key.html)) | Conceptually the "production" version of what `QwertyTouchRouting.bias` already approximates via distance-shrinkage rather than true hit-region enlargement | Low incremental CPU (same completions/frequency signal already computed), but a real geometry change (actually growing hit regions, not just biasing gap-resolution) is a bigger implementation change to `QwertyKeyboardView`'s touch handling than the current bias-only approach | Conceptually adjacent, but the shipped design *already chose* the lighter "bias the ambiguous-gap resolution" shape over "actually resize hit regions" specifically to avoid this complexity — revisiting it would be a deliberate architecture change, not an incremental add | **Not recommended to pursue** unless the bias-only approach is shown (via real usage data) to be insufficient — treat as a fallback design, not a v1/v2 target |
| **Keyboard-geometry-weighted edit-distance re-scoring** of correction candidates (substitution cost scaled by physical key distance rather than flat Levenshtein cost; concrete implementable reference: [MaxHalford/clavier](https://github.com/MaxHalford/clavier), MIT, Python — computes Euclidean/L1 distance between key positions as substitution cost; conceptually the same idea as the "probabilistic edit distance... adjacent keys have base probability 0.17, non-adjacent 0.01" scheme described in autocorrect patent literature) | Improves ranking when `UITextChecker`'s own guess list already contains the right correction but ranks it below a same-edit-distance-but-spatially-implausible alternative (e.g., a transposition between adjacent keys should outrank one between distant keys) | Low CPU (a fixed 26×26-ish distance table, computed once, looked up per candidate pair) and near-zero memory (a small precomputed matrix, not a corpus) | Complementary to, not competing with, the frequency-prior re-ranking above — could be combined as a second sort key ("spatially-plausible + frequent" beats "spatially-implausible + equally frequent") | **Reasonable v1.5 candidate** — small, self-contained, and directly reuses the pattern already established for re-ranking `UITextChecker`'s guesses rather than replacing them |
| **Double-letter and adjacent-key confusion handling in the corrector** | Two well-known, narrow failure modes: (a) users under/over-typing doubled letters ("acommodate" / "accomodate"), (b) adjacent-key substitution being systematically more likely than distant-key substitution | Very low — a handful of targeted rules/heuristics layered on top of `UITextChecker`'s guesses (e.g., generating a doubled/undoubled variant of the current word and checking whether it's a real word before falling back to the system guess), not a new model | Fits as a small pure helper alongside `QwertyAutocorrect`, independent of the touch-routing bias system entirely — this is a spelling-layer fix, not a touch-layer fix | **Low-effort, worth doing alongside the frequency-lexicon work** — same "re-rank/augment, don't replace `UITextChecker`" shape |
| **Per-user online adaptation, generally, and its cold start** | All personalization approaches above share this problem: a brand-new user (or a user who just reset their personal dictionary) has zero history | The Gboard paper's own framing treats "how much data is needed" as a first-class research question, and a related paper on touch-correction training data reports usable gains from as few as **~200 examples** — i.e., cold start resolves itself within the first few minutes of normal typing, no separate onboarding/calibration flow needed | The bias-cap design already makes this safe by construction: an empty/near-empty per-user model contributes ~0 bias, so behavior degrades gracefully to "exactly today's shipped behavior" rather than misbehaving on day one | **No separate design needed** — cold start is a non-issue as long as the personalization signal is additive and capped, which the shipped architecture already enforces |
| **Full neural spatial model + FST/beam-search decoder** (Gboard's actual production system: LSTM-based Neural Spatial Model + n-gram language-model FST combined via beam search — [Google Research blog](https://research.google/blog/the-machine-intelligence-behind-gboard/)) | This is the real "how a top-tier keyboard actually works" architecture — highest theoretical ceiling | Very high — a trained model, a runtime to execute it on-device, and a decoder architecture NumPad has no precedent for anywhere in the codebase (confirmed zero ML/prediction code today per the sibling technical-feasibility doc) | Fundamentally incompatible with the "no ML, no shipped corpus beyond a tiny static table" design philosophy the shipped `QwertyTouchRouting` doc comment explicitly argues for | **Explicitly out of scope** — this is the ceiling the shipped design's own doc comment already reasoned should not be chased for a "niche keyboard extension," and this research doesn't find a reason to revisit that call |

---

## 4. Concrete phased recommendation

**Phase A — bundled frequency lexicon + spatial re-ranking (next, v1-adjacent):**
- Data: Hermit Dave `en_50k.txt` (or a trimmed 25k cut if the offline harness shows diminishing returns
  past that), converted offline (one-time script, not shipped) into a compact packed binary — e.g. a flat
  list of `(word: String, rank: UInt16)` sorted lexicographically, bundled as an extension resource.
  Include a short attribution line (CC BY-SA 4.0 data license) in the app's credits/about screen, same
  treatment the sibling doc already recommended for AOSP-derived word lists.
- New pure module: `NumPad/Libraries/Qwerty/QwertyFrequencyLexicon.swift` — loads the bundled resource once,
  exposes `rank(of word: String) -> Int?` and a `rank(candidates: [String]) -> [String]` sort helper. Pure,
  no `UIKit`/`Foundation`-networking dependency, testable with a small in-test fixture list (don't need the
  full 50k words loaded in unit tests).
- Wire into `QwertyAutocorrect`: re-sort `guesses`/`completions` through `QwertyFrequencyLexicon.rank(...)`
  before calling the existing `suggestions(word:guesses:completions:)`/`decide(...)` — no signature changes
  to the public autocorrect API, so `QwertySpellChecker`'s `UITextChecker` call sites are untouched.
- Tests: `QwertyFrequencyLexiconTests.swift` (pure ranking logic, fixture word list) +
  extend `QwertyAutocorrectTests.swift` for the new re-ranked-input case. No device/build-time cost beyond
  the existing test suite; no new Full-Access or memory gate beyond re-verifying resident size against the
  existing 50–70MB ceiling once the real bundle is in place.

**Phase B — per-user learned unigram:**
- New pure module (or an extension of the frequency lexicon type): tracks accepted-word counts, bounded
  size, decay/eviction policy, stored via the existing `@UserDefault`/`Constants` pattern in
  `SharedExtensions.swift`. Ranks above the static Phase-A prior but below lexicon expansion, per §2's
  ordering.
- Add a `Constants` key + a "Reset personal dictionary" row in the relevant settings screen (Home or the
  QWERTY setup wizard, `QwertySetupViewController`), matching the project's existing pattern for
  user-controllable, resettable local state.
- Tests: pure logic for increment/decay/eviction and the merged ranking order; no device gate needed.

**Phase C — per-key touch-offset personalization:**
- Extend `QwertyTouchRouting` (or a small sibling module, e.g. `QwertyTouchPersonalization.swift`) with a
  per-key running-average offset, updated from the keyboard's own accepted-keystroke stream (a tap that
  wasn't immediately backspaced/corrected). Feed the offset into `keyIndex(at:...)` as a second bias
  channel, still bounded by the same `biasDistanceCap` philosophy — direct hits still always win, and the
  personalization channel can only ever tip an already-ambiguous gap resolution, exactly like the
  completions-bias today.
- Tests: extend `QwertyTouchRoutingTests.swift` with synthetic offset scenarios (mirrors the existing test
  file's style for the completions-bias feature).

**Phase D — gated, not scheduled:** keyboard-geometry-weighted edit-distance re-scoring (§3) and
double-letter/adjacent-key spelling heuristics (§3) are reasonable low-cost follow-ons to bundle into
Phase A/B's PR if time allows, but are not blocking. Full covariance-based touch personalization, dynamic
hit-region resizing, and any bigger AOSP-dictionary/bigram engine remain correctly gated behind the
pre-existing OSS-prediction offline harness decision point (`2026-07-05-oss-prediction-options.md`) — this
research doesn't find a reason to pull that gate forward.

**Test strategy summary:** every module proposed here is pure Swift with no `UIKit`/system-API dependency
beyond a one-time bundled-resource load, matching the existing 100%-unit-tested discipline in
`NumPad/Libraries/Qwerty/`. None of Phases A–C require a physical-device gate beyond re-checking the
existing memory/latency ceilings once the bundle size is finalized — no new Phase-3-style device gate
category is introduced.

---

## Sources

- Hermit Dave `FrequencyWords` — [repo](https://github.com/hermitdave/FrequencyWords), [README](https://github.com/hermitdave/FrequencyWords/blob/master/README.md), [LICENSE](https://github.com/hermitdave/FrequencyWords/blob/master/LICENSE) (sizes independently measured via direct HTTP HEAD on `content/2018/en/en_50k.txt` = 622,749 bytes and `en_full.txt` = 19,977,552 bytes)
- wordfreq — [GitHub](https://github.com/rspeer/wordfreq), [PyPI](https://pypi.org/project/wordfreq/), [ConceptNet blog](http://blog.conceptnet.io/wordfreq/)
- SUBTLEX-US — [openlexicon README](http://openlexicon.fr/datasets-info/SUBTLEX-US/README-SUBTLEXus.html), [OSF dataset](https://osf.io/djpqz/)
- Google Books Ngram Viewer — [info/license](https://books.google.com/ngrams/info), [dataset exports](http://storage.googleapis.com/books/ngrams/books/datasetsv3.html)
- SCOWL / English Speller Database — [wordlist.aspell.net](https://wordlist.aspell.net/), [GitHub mirror](https://github.com/en-wl/wordlist), [SCOWL readme](https://wordlist.aspell.net/scowl-readme/)
- marisa-trie — [docs/benchmarks](https://marisa-trie.readthedocs.io/en/latest/benchmarks.html), [pytries/marisa-trie](https://github.com/pytries/marisa-trie)
- DAWG compression — [Steve Hanov's blog](https://stevehanov.ca/blog/compressing-dictionaries-with-a-dawg)
- FST vs trie memory comparison — [systemoverflow.com](https://www.systemoverflow.com/learn/search-ranking/search-autocomplete/memory-compression-dawg-fst-and-double-array-tries)
- PruningRadixTrie — [wolfgarbe/PruningRadixTrie](https://github.com/wolfgarbe/PruningRadixTrie)
- Swift trie libraries surveyed — [ACRAutoComplete](https://github.com/acrookston/ACRAutoComplete), [Swiftrie](https://github.com/yucelokan/Swiftrie), [trie-swift](https://github.com/morishin/trie-swift)
- Gboard architecture — [The Machine Intelligence Behind Gboard (Google Research blog)](https://research.google/blog/the-machine-intelligence-behind-gboard/)
- Spatial model personalization in Gboard — [arXiv:2209.11311](https://arxiv.org/abs/2209.11311), [ACM DL](https://dl.acm.org/doi/pdf/10.1145/3546737), [Google Research pub page](https://research.google/pubs/spatial-model-personalization-in-gboard/)
- User-specific touch-accuracy ML — [ResearchGate summary](https://www.researchgate.net/publication/262309962_A_user-specific_machine_learning_approach_for_improving_touch_accuracy_on_mobile_devices)
- Sparse training data for touch correction (≈200-example finding) — [ResearchGate](https://www.researchgate.net/publication/261860101_Sparse_selection_of_training_data_for_touch_correction_systems)
- Apple predictive-text hit-region patent (US 8,232,973) — [AppleInsider coverage](https://appleinsider.com/articles/12/07/31/apple_granted_patent_for_predictive_text_input_ui)
- Apple dynamic key-footprint patent coverage — [techxplore](https://techxplore.com/news/2020-12-apple-patents-keyboard-dynamically-key.html)
- Keyboard-geometry-weighted edit distance (concrete implementation reference) — [MaxHalford/clavier](https://github.com/MaxHalford/clavier)
- QuickType on-device personalization (launch-era reporting) — [MacRumors](https://www.macrumors.com/2014/06/02/quicktype-ios-8-typing-suggestions/), [iMore](https://www.imore.com/quicktype-keyboards-ios-8-explained)
- In-repo cross-references — `docs/plans/full-keyboard/2026-07-05-oss-prediction-options.md`, `docs/plans/full-keyboard/2026-07-05-technical-feasibility.md`, `docs/plans/full-keyboard/2026-07-05-rules-and-structure.md`
