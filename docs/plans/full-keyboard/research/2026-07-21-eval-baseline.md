# Typing-quality eval baseline — Task 6 decision document

- **Date:** 2026-07-21 (run at 14:07 PDT)
- **Branch:** `feat/qwerty-typing-v2`
- **Harness commit:** `4d43a57d` ("feat: offline typing-quality harness (6 arms, per-corpus
  metrics, KSR baseline)") plus three numbers-neutral pre-run edits from the Task-5 code
  review (two comment/notes clarifications in `QwertyEvalHarnessTests.swift`, one
  line-split unification in `QwertyEvalCorpus.swift`), committed together with this doc.
- **Corpora:** `typos_en.tsv` 4539 pairs (synthetic, adjacency-model motor slips);
  `typos_wiki_en.tsv` 4266 pairs (real human cognitive/phonetic misspellings);
  `sentences_en.txt` 313 sentences → 1347 held-out-word prefix queries (KSR baseline).
- **Run duration:** 35.3s total (`testCompletionKSRBaseline` 1.5s,
  `testCorrectionArmsPerCorpus` 33.8s). Both tests PASSED (not skipped).
- **Reproduce** (the env gate must be a real environment variable — the trailing-arg form
  does not reach the runner on this toolchain):

```bash
env TEST_RUNNER_QWERTY_EVAL=1 xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/QwertyEvalHarnessTests
```

The report lands at `<sim data container>/tmp/qwerty-eval-report.md` (path printed as
`EVAL REPORT WRITTEN:` in the log). That file is overwritten by every run; the full
content of this run is pasted verbatim below.

---

## Pre-registered decision gates

Restated verbatim from `docs/plans/full-keyboard/2026-07-05-oss-prediction-options.md` §C.
**These were pre-registered on 2026-07-05, before any of the numbers below were seen, and
are applied mechanically — no post-hoc adjustment.**

> - **Quality gate**: a candidate must beat `UITextChecker`'s corpus score by a clear,
>   pre-registered margin — proposed as **+15 percentage points absolute top-1 hit-rate**
>   (next-word) or an equivalent KSR gain — before it's worth building into the extension
>   at all. A candidate that beats the floor by 2–3pp isn't worth the memory/engineering
>   spend regardless of how technically interesting it is.
> - **Memory gate**: a **hard** ceiling of the candidate's own footprint, not a soft
>   target — proposed as **≤15MB resident delta** above NumPad's current baseline,
>   measured on-device via Jetsam reports (not simulator, per the sibling doc's own
>   caution that this is a per-process, no-graceful-degrade limit), leaving real margin
>   under the ~50–70MB ceiling for the rest of the app's runtime and future growth. Any
>   candidate that can't hit this without heroics is out regardless of quality score.
> - **Latency gate**: p95 added latency per keystroke low enough not to visibly lag
>   typing — proposed as **≤16ms** (one frame at 60fps) for autocorrect-as-you-type, more
>   slack (≤50–100ms) acceptable for a next-word suggestion bar that updates on
>   word-boundary rather than every keystroke.
> - **License gate (hard, non-negotiable)**: no GPL/AGPL code enters the shipped binary
>   under any circumstance, regardless of how the other three gates score.

The Task-6 gate from `2026-07-21-typing-v2-implementation.md` (also pre-registered):
**proceed to Tasks 7–9 ONLY IF** the floor/shipped arms leave **≥15pp top-1** (or
equivalent KSR) on the table that a dictionary-based arm could plausibly close — i.e.
intended words that ARE in the 50k lexicon but the checker never surfaced ("reachable
headroom"). Per `tools/data/eval/README.md`, metrics are per-corpus, never pooled — and
the **wiki (human) corpus is the honest one for this gate**: the synthetic corpus's 85%
QWERTY-adjacent noise model is biased toward the spatial arm's prior by construction.

---

## Arm definitions

- **floor** — raw `UITextChecker` guesses (system probability order).
- **shipped** — `lexicon.rerankKnown(guesses)` — production before Task 2.
- **spatial** — `rerankKnown(SpatialScore.rerank(guesses))` — production after Task 2.
- **variants** — `rerankKnown(SpatialScore.rerank(TypoVariants.augment(guesses)))` with
  the verdict-only oracle — CURRENT production.
- **variantsLast** — augment applied AFTER both reranks (an accepted repair takes the
  head unconditionally) — arbitrates the Task-3 ordering question.
- **combined** — single-key sort of the augmented set: spatial cost bucketed to 1
  decimal, then lexicon rank (unknown last), then incoming index — arbitrates the Task-2
  composition question (harness-only experiment).

All arms share one `UITextChecker` (mirroring `QwertySpellChecker`'s exact call shapes,
language en_US) and the production `qwerty_lexicon_en.bin`. The personal-dictionary boost
is part of NO arm — per-user state, unmeasurable offline.

---

## Harness report (verbatim)

The complete harness output for this run, pasted unmodified:

```markdown
# QWERTY offline typing-quality eval

## Corpora

- `typos_en`: 4539 pairs
- `typos_wiki_en`: 4266 pairs

## Arms

- **floor** — raw UITextChecker guesses (system probability order)
- **shipped** — `lexicon.rerankKnown(guesses)` — production before Task 2
- **spatial** — `rerankKnown(SpatialScore.rerank(guesses))` — production after Task 2
- **variants** — `rerankKnown(SpatialScore.rerank(TypoVariants.augment(guesses)))` with the verdict-only oracle — CURRENT production
- **variantsLast** — augment applied AFTER both reranks (repair takes the head unconditionally) — arbitrates the Task-3 ordering question
- **combined** — single-key sort of the augmented set: spatial cost bucketed to 1 decimal, then lexicon rank (unknown last), then incoming index — arbitrates the Task-2 composition question (harness-only experiment)

All arms share one `UITextChecker` (mirroring `QwertySpellChecker`'s exact call shapes, language en_US) and the production `qwerty_lexicon_en.bin`. The personal-dictionary boost is part of NO arm — per-user state, unmeasurable offline.

## Correction accuracy (per corpus — NEVER pooled)

### typos_en

4539 pairs — ed1: 3897, ed2: 642, ed3+: 0; single-substitution adjacent: 2401, non-adjacent: 366; intended-in-lexicon: 99.1%

| arm | top-1 | top-3 | ed1 top-1 | ed2 top-1 | ed3+ top-1 | adj-sub top-1 | non-adj-sub top-1 | reachable headroom |
|---|---|---|---|---|---|---|---|---|
| floor | 69.7% | 85.0% | 67.7% | 81.5% | — | 72.6% | 67.8% | 99.1% of 1377 misses |
| shipped | 67.2% | 85.0% | 65.4% | 78.0% | — | 66.6% | 67.2% | 99.1% of 1491 misses |
| spatial | 63.9% | 82.6% | 62.4% | 73.1% | — | 65.6% | 54.9% | 99.7% of 1639 misses |
| variants | 63.9% | 82.5% | 62.4% | 73.1% | — | 65.6% | 54.9% | 99.7% of 1638 misses |
| variantsLast | 63.0% | 82.3% | 61.6% | 71.8% | — | 63.8% | 54.4% | 99.7% of 1678 misses |
| combined | 73.2% | 84.5% | 72.6% | 77.1% | — | 85.7% | 45.6% | 99.6% of 1215 misses |

### typos_wiki_en

4266 pairs — ed1: 3095, ed2: 1067, ed3+: 104; single-substitution adjacent: 100, non-adjacent: 745; intended-in-lexicon: 87.4%

| arm | top-1 | top-3 | ed1 top-1 | ed2 top-1 | ed3+ top-1 | adj-sub top-1 | non-adj-sub top-1 | reachable headroom |
|---|---|---|---|---|---|---|---|---|
| floor | 78.5% | 91.3% | 79.7% | 79.3% | 34.6% | 84.0% | 86.4% | 78.7% of 916 misses |
| shipped | 78.7% | 91.6% | 80.5% | 78.3% | 32.7% | 83.0% | 84.3% | 78.5% of 907 misses |
| spatial | 76.3% | 90.7% | 78.6% | 74.2% | 29.8% | 87.0% | 78.4% | 81.9% of 1010 misses |
| variants | 77.5% | 90.7% | 80.3% | 74.2% | 29.8% | 87.0% | 78.4% | 82.2% of 959 misses |
| variantsLast | 79.7% | 91.0% | 83.4% | 74.1% | 29.8% | 86.0% | 78.1% | 80.7% of 864 misses |
| combined | 77.4% | 90.6% | 80.6% | 72.7% | 29.8% | 94.0% | 76.6% | 80.5% of 965 misses |

## Latency (uncached, fixed 500-pair sample per corpus)

### typos_en (n=500 uncached calls per arm)

| arm | p50 ms | p95 ms | Δp50 vs floor | Δp95 vs floor |
|---|---|---|---|---|
| floor | 1.044 | 1.673 | +0.000 | +0.000 |
| shipped | 1.183 | 1.815 | +0.139 | +0.143 |
| spatial | 1.237 | 1.951 | +0.193 | +0.279 |
| variants | 1.389 | 2.177 | +0.344 | +0.504 |
| variantsLast | 1.484 | 2.309 | +0.440 | +0.636 |
| combined | 1.456 | 2.264 | +0.412 | +0.592 |

### typos_wiki_en (n=500 uncached calls per arm)

| arm | p50 ms | p95 ms | Δp50 vs floor | Δp95 vs floor |
|---|---|---|---|---|
| floor | 1.808 | 2.846 | +0.000 | +0.000 |
| shipped | 1.820 | 2.799 | +0.012 | -0.047 |
| spatial | 1.859 | 2.880 | +0.051 | +0.034 |
| variants | 2.480 | 3.910 | +0.672 | +1.064 |
| variantsLast | 2.310 | 3.626 | +0.502 | +0.780 |
| combined | 2.314 | 3.679 | +0.506 | +0.833 |

## Completion / keystroke-savings baseline

Corpus: `sentences_en` — 313 held-out final words, 1347 prefix queries (every prefix length 1..<word length).

| metric | value |
|---|---|
| hit@1 (prefix queries) | 31.8% (428/1347) |
| hit@3 (prefix queries) | 48.2% (649/1347) |
| keystroke savings rate | 25.8% (428 of 1660 letters saved) |

KSR counts, per held-out word, `word.count - k` for the EARLIEST prefix
length `k` whose top-1 completion is the word (accepting finishes it);
words never hit at top-1 save nothing but still count their letters in
the denominator. Pipeline: mirror `completions(forPartialWordRange:)` →
`lexicon.rerank` (the production completions path; personal boost
excluded as per-user state).

## Notes

Arbitration questions these arms answer (the harness measures; Task 6 judges):

1. **Task-3 (augment position):** `variants` (augment BEFORE the reranks —
   spatial and frequency retain final authority over the auto-apply slot;
   current production) vs `variantsLast` (augment AFTER — an accepted
   doubling repair takes the head unconditionally).
2. **Task-2 (composition):** `spatial` (frequency fully re-sorts
   corpus-known guesses, overriding spatial order within that group;
   current production) vs `combined` (frequency only arbitrates within a
   0.1-wide spatial-cost bucket — does frequency-within-cost-bucket beat
   frequency-overrides-spatial?).

Corpus bias (tools/data/eval/README.md): `typos_en` is synthetic with an
85% QWERTY-adjacent substitution model — biased toward the spatial arm by
construction. `typos_wiki_en` is real human cognitive/phonetic errors.
Metrics are therefore reported per corpus and must never be pooled.

"Reachable headroom" = among an arm's top-1 MISSES, the share whose
intended word the production lexicon knows — corrections a
dictionary-based engine (SymSpell/bigram) could plausibly reach. This is
the Task-6 gate's key column.

Latency figures cover ONLY the word-boundary correction path —
production also pays a completions call per keystroke that no arm
times. Scoring is case-insensitive, uniform across arms (comparisons
unbiased; absolute accuracy slightly lenient).
```

---

## Findings

What the numbers actually show — including the uncomfortable parts.

### (a) Do the rerank arms beat the floor? Mostly NO — the smoke-run signal is confirmed.

The smoke run suggested the reranks might underperform raw `UITextChecker` order. The
full run **confirms it for every production-lineage arm**:

| arm vs floor (top-1) | typos_en (synthetic) | typos_wiki_en (human) |
|---|---|---|
| shipped | **−2.5pp** | +0.2pp |
| spatial | **−5.8pp** | **−2.2pp** |
| variants (CURRENT production) | **−5.8pp** | **−1.0pp** |
| variantsLast | **−6.7pp** | +1.2pp |
| combined | **+3.5pp** | −1.1pp |

The uncomfortable headline: **the current production pipeline (`variants`) is worse than
doing nothing on BOTH corpora** — 63.9% vs floor's 69.7% on synthetic, 77.5% vs 78.5% on
wiki. The Task-2 spatial rerank is the main culprit: `shipped` → `spatial` costs 3.3pp on
synthetic and 2.4pp on wiki, and the loss is concentrated exactly where the README
predicted the opposite — even on the adjacency-biased synthetic corpus, spatial's
adj-sub top-1 (65.6%) is BELOW floor's (72.6%). `UITextChecker`'s own probability order
already encodes a better prior than our spatial-cost resort. This surprised me; I am
recording it rather than smoothing it. Only two cells beat floor at all, and only one by
a meaningful margin: `combined` on the corpus that is biased toward it by construction
(+3.5pp), and `variantsLast` on wiki (+1.2pp — under the "2–3pp isn't worth it" bar the
gates themselves set for engine candidates, though pipeline reordering is free).

Top-3 tells the same story: floor/shipped hold the best top-3 everywhere (85.0% both on
synthetic; 91.6% shipped / 91.3% floor on wiki); every spatial-lineage arm is below both.

### (b) Task-3 arbitration: variantsLast vs variants (production) — split, wiki favors variantsLast.

- **Wiki (honest corpus): variantsLast 79.7% vs variants 77.5% — +2.2pp**, and
  variantsLast is the best arm on wiki outright (best ed1 top-1 too: 83.4%).
- Synthetic: variantsLast 63.0% vs variants 63.9% — −0.9pp.

Letting an accepted doubling/variant repair take the head unconditionally helps on real
human errors and costs a little on synthetic motor slips. Latency is a wash (both ≈+0.5–1.1ms
Δp95 vs floor, far under any gate).

### (c) Task-2 arbitration: combined vs spatial/shipped — beats spatial everywhere, loses to shipped on wiki.

- vs `spatial`: **+9.3pp synthetic, +1.1pp wiki** — frequency-within-cost-bucket
  beats frequency-overrides-spatial on both corpora.
- vs `shipped` (frequency-only): +6.0pp synthetic, **−1.3pp wiki** — on real human
  errors the plain frequency rerank still wins.
- The mechanism is visible in the substitution splits: combined's adj-sub top-1 is
  dominant (85.7% / 94.0%) but its non-adj-sub collapses (45.6% synthetic — 22pp below
  floor). Bucketed spatial cost buys adjacent-slip wins by sacrificing everything the
  adjacency prior doesn't explain.

No composition wins both corpora: best synthetic arm is `combined` (73.2%), best wiki arm
is `variantsLast` (79.7%).

### (d) Reachable headroom — the gate number.

Converting the report's headroom column (share of top-1 misses whose intended word is in
the production lexicon) to corpus-level percentage points (misses × reachable% ÷ corpus
size):

| arm | typos_en (synthetic) | typos_wiki_en (human) |
|---|---|---|
| floor | 1365/4539 = **30.1pp** | 721/4266 = **16.9pp** |
| shipped | 1478/4539 = 32.6pp | 712/4266 = **16.7pp** |
| variants (production) | 1633/4539 = 36.0pp | 788/4266 = 18.5pp |
| variantsLast | 1673/4539 = 36.9pp | 697/4266 = 16.3pp |

On the human corpus the floor/shipped arms leave **16.9pp / 16.7pp** of the corpus as
misses a dictionary-based engine could plausibly reach. On the synthetic corpus the
headroom is much larger (30.1pp+, intended-in-lexicon 99.1% by construction) but that
corpus is biased and does not gate.

Honest caveats on this number, recorded before Tasks 7–9 spend anything:

- 16.9pp is the **ceiling of a perfect engine**, not an expectation. The engine quality
  gate (+15pp over floor) sits just under that ceiling — a SymSpell/bigram arm would have
  to convert essentially ALL reachable misses to clear it. The gate passes, narrowly.
- "Reachable" counts lexicon membership only; 21.3% of floor's wiki misses have intended
  words OUTSIDE the 50k lexicon (ed3+ cognitive rewrites dominate there — floor's ed3+
  top-1 is 34.6%), permanently out of reach for any dictionary-based arm at this lexicon size.
- Part of the headroom is already captured at top-3 (floor wiki top-3 91.3% vs top-1
  78.5%) — a rank-1-vs-rank-3 problem, addressable by reranking, not only by new engines.

---

## Gate verdict (mechanical application — no re-negotiation)

**[PROCEED to Tasks 7–9.]** Reachable headroom on the human (wiki) corpus is
**16.9pp (floor) / 16.7pp (shipped) ≥ 15pp** — the pre-registered Task-6 gate is met.
The synthetic corpus (30.1pp) is consistent but does not gate, per the corpus-bias rule.
The engine candidates built in Tasks 7–9 must then individually clear the §C gates
(+15pp top-1 over floor — nearly the whole reachable ceiling, see caveat above — plus
≤15MB resident, ≤16ms p95 added latency, no GPL/AGPL) before any extension wiring.

**Separate recommendation — pipeline composition (NOT implemented; requires
orchestrator/owner sign-off as a small follow-up):** the data does not support keeping
the current composition as-is. Specifically:

1. The Task-2 spatial rerank **reduces** top-1 on both corpora (−3.3pp synthetic /
   −2.4pp wiki vs `shipped`); the pre-Task-2 `shipped` pipeline or plain `floor` order
   beats current production everywhere. Consider reverting or demoting the spatial
   resort in the guess pipeline.
2. If the augment step stays, the wiki corpus favors `variantsLast` over `variants`
   (+2.2pp on human errors, −0.9pp on synthetic) — augment-after-reranks is the better
   ordering on the honest corpus.
3. `combined` should NOT ship: its synthetic win is the corpus bias talking, and it
   loses to `shipped` on human errors while collapsing on non-adjacent substitutions.

Per the implementation plan's own rule ("if spatial+variants already moved top-1
meaningfully: ship them regardless — they're free"), the honest reading is that they
moved top-1 meaningfully **downward**; that rule's premise did not materialize.

---

## Reproduction appendix — harness mechanics

- **Env gate:** both tests `XCTSkipUnless` on `QWERTY_EVAL == "1"` in the runner's
  environment. `xcodebuild` forwards `TEST_RUNNER_`-prefixed variables into the test
  runner, hence `env TEST_RUNNER_QWERTY_EVAL=1 xcodebuild test …`. Passing it as a
  trailing argument does NOT reach the runner on this toolchain — the tests skip.
- **Single-process assumption:** the harness accumulates report sections in static
  storage and flushes the merged document after each test (`flushReport`); the two tests
  must run in one test-runner process (the default for `-only-testing` on one class) for
  the final file to contain all sections. The first flush (after the KSR test) is
  partial; the file written after `testCorrectionArmsPerCorpus` is the complete one.
- **Report location:** `FileManager.default.temporaryDirectory` inside the app's
  simulator data container; the exact path is printed as `EVAL REPORT WRITTEN: <path>`
  and is host-readable. Overwritten every run — this doc is the archival copy.
- **Checker mirror:** the harness reproduces `QwertySpellChecker`'s exact
  `UITextChecker` call shapes (en_US, `startingAt: 0`, `wrap: false`, guesses only when
  misspelled). The eval is valid only while those shapes stay byte-identical to the
  extension's — change the two files together.
- **Timing hygiene:** 50 warm-up checker calls before any timed window; latency measured
  on a fixed 500-pair uncached sample per corpus; percentiles via linear-index rounding
  (`round((n−1)·q)`), identical convention across arms.
- **Oracle caching:** real-word oracle verdicts are cached per probed word WITHIN each
  arm only — probes are part of an arm's own cost model, never shared across arms.

---

## Task 6b addendum — the missing arm, measured; production rewired (2026-07-21)

The main run above never measured the cleanest candidate its own findings pointed at:
`shipped + augment-last` WITHOUT the spatial step, i.e.
`augment(rerankKnown(guesses))`. Task 6b added it as a 7th harness arm
(**noSpatialAugmentLast**) and re-ran the full harness (2026-07-21, ~14:14 PDT, same
simulator destination, both tests PASSED in 38.1s; the six pre-existing arms'
accuracy rows reproduced the main run verbatim, validating the re-run).

### 7-arm correction tables (verbatim from the re-run report)

#### typos_en

4539 pairs — ed1: 3897, ed2: 642, ed3+: 0; single-substitution adjacent: 2401, non-adjacent: 366; intended-in-lexicon: 99.1%

| arm | top-1 | top-3 | ed1 top-1 | ed2 top-1 | ed3+ top-1 | adj-sub top-1 | non-adj-sub top-1 | reachable headroom |
|---|---|---|---|---|---|---|---|---|
| floor | 69.7% | 85.0% | 67.7% | 81.5% | — | 72.6% | 67.8% | 99.1% of 1377 misses |
| shipped | 67.2% | 85.0% | 65.4% | 78.0% | — | 66.6% | 67.2% | 99.1% of 1491 misses |
| spatial | 63.9% | 82.6% | 62.4% | 73.1% | — | 65.6% | 54.9% | 99.7% of 1639 misses |
| variants | 63.9% | 82.5% | 62.4% | 73.1% | — | 65.6% | 54.9% | 99.7% of 1638 misses |
| variantsLast | 63.0% | 82.3% | 61.6% | 71.8% | — | 63.8% | 54.4% | 99.7% of 1678 misses |
| combined | 73.2% | 84.5% | 72.6% | 77.1% | — | 85.7% | 45.6% | 99.6% of 1215 misses |
| noSpatialAugmentLast | 65.9% | 84.7% | 64.1% | 76.6% | — | 64.5% | 66.4% | 99.2% of 1549 misses |

#### typos_wiki_en

4266 pairs — ed1: 3095, ed2: 1067, ed3+: 104; single-substitution adjacent: 100, non-adjacent: 745; intended-in-lexicon: 87.4%

| arm | top-1 | top-3 | ed1 top-1 | ed2 top-1 | ed3+ top-1 | adj-sub top-1 | non-adj-sub top-1 | reachable headroom |
|---|---|---|---|---|---|---|---|---|
| floor | 78.5% | 91.3% | 79.7% | 79.3% | 34.6% | 84.0% | 86.4% | 78.7% of 916 misses |
| shipped | 78.7% | 91.6% | 80.5% | 78.3% | 32.7% | 83.0% | 84.3% | 78.5% of 907 misses |
| spatial | 76.3% | 90.7% | 78.6% | 74.2% | 29.8% | 87.0% | 78.4% | 81.9% of 1010 misses |
| variants | 77.5% | 90.7% | 80.3% | 74.2% | 29.8% | 87.0% | 78.4% | 82.2% of 959 misses |
| variantsLast | 79.7% | 91.0% | 83.4% | 74.1% | 29.8% | 86.0% | 78.1% | 80.7% of 864 misses |
| combined | 77.4% | 90.6% | 80.6% | 72.7% | 29.8% | 94.0% | 76.6% | 80.5% of 965 misses |
| noSpatialAugmentLast | 82.0% | 91.7% | 84.9% | 78.2% | 31.7% | 82.0% | 83.8% | 77.5% of 770 misses |

Latency (re-run): noSpatialAugmentLast Δp95 vs floor +0.378ms (typos_en) /
+0.739ms (typos_wiki_en) — comparable to the other augment arms, far under any gate.

### Winner — mechanical rule applied

Pre-committed decision rule (orchestrator, before the arm was measured): production
becomes whichever of `variantsLast` and `noSpatialAugmentLast` has higher top-1 on the
WIKI corpus (tie → the simpler `noSpatialAugmentLast`); no other arm is a candidate.

**Winner: `noSpatialAugmentLast` — wiki top-1 82.0% vs variantsLast 79.7% (+2.3pp).**
No tie-break needed; the simpler configuration also wins outright. It is additionally
the best wiki arm on top-3 (91.7%) and ed1 top-1 (84.9%), beats floor by +3.5pp and
old production (`variants`) by +4.5pp on wiki, and on the synthetic corpus recovers
2pp of the spatial arms' losses (65.9% vs variants 63.9%), though floor still leads
there (69.7% — synthetic does not gate, per the corpus-bias rule).

### What production now runs

`QwertyPageHost.rankedGuesses(for:analysis:)` was rewired to the winning shape:

```swift
let reranked = frequencyLexicon.rerankKnown(analysis.guesses)
guard analysis.isMisspelled else { return reranked }
return QwertyTypoVariants.augment(
    guesses: reranked, word: word,
    isRealWord: { !spellChecker.isMisspelled(word: $0) })
```

- The spatial resort (`QwertySpatialScore`) is **dropped from the production ranking
  path** (net-negative on both corpora in every composition measured). The module and
  `QwertyKeyGeometry` are retained — the harness arms use them, and geometry feeds the
  synthetic corpus generator; its module doc now records the demotion.
- Augment-last means a checker-validated doubling repair now takes the auto-apply head
  slot unconditionally; frequency orders the corpus-known guesses beneath it, and
  out-of-corpus guesses keep the checker's slots.
- The `isMisspelled` gate and the verdict-only lean oracle are unchanged.
- Pinned composed-pipeline tests updated to the arbitrated behavior:
  `testAdjacentKeyRivalOutranksTypoRepairInComposedPipeline` →
  `testTypoRepairTakesHeadOverAdjacentRivalInComposedPipeline` (the repair now wins the
  head); `testSpatialRerankFeedsDecide` and the former
  `testProductionPipeSpatialThenRerankKnown` (→ `testSpatialThenRerankKnownComposition`)
  are re-framed as `QwertySpatialScore` module tests.

---

## Task 7 addendum — SymSpell arm (2026-07-21)

Run at ~14:40 PDT, same pinned simulator destination; both harness tests PASSED
(`testCorrectionArmsPerCorpus` 55.7s, total 57.2s). The seven pre-existing arms'
accuracy rows reproduced the Task-6b run **verbatim**, validating the re-run.

### Framing — pre-registered, restated before the numbers

The §C engine-adoption gates: **+15pp absolute top-1**, **≤15MB resident delta**,
**≤16ms p95 added latency**, no GPL/AGPL. The baseline for the quality gate is
ambiguous between "floor" and "current production", so it is resolved
conservatively here by reporting BOTH deltas. The ceiling math was known in
advance of building anything: current production (`noSpatialAugmentLast`) misses
770 wiki pairs, of which 77.5% (≈597 pairs, **14.0pp** of the corpus) are
lexicon-reachable — so even a PERFECT dictionary corrector caps at **+14.0pp vs
production** (already under the +15pp gate); vs floor the perfect-engine cap is
**16.9pp**. This arm exists to measure the honest number, not to force a pass.

### The arm

**symspell** — production (`noSpatialAugmentLast`) PLUS SymSpell backfill: a
clean-room reimplementation of the symmetric-delete algorithm (MIT-published
algorithm; no third-party code) over the production `qwerty_lexicon_en.bin`,
`maxEditDistance 2` / `prefixLength 7`, geometry-free unit-cost OSA
verification, ranked (edit distance ASC, lexicon rank ASC). Engine corrections
are **APPENDED** after the base list (case-insensitive dedupe, base order
preserved) — engine candidates backfill where the checker had nothing useful;
measuring replace-the-checker would be a different product than planned.
Consequence worth stating plainly: an append-only arm can change top-1 **only
when the base list is empty**, so its top-1 delta is structurally the "checker
returned nothing" slice — that is the design being measured, not an accident.

Module: `NumPad/Libraries/Qwerty/QwertySymSpellCorrector.swift` — NumPad **app
target only** (like `QwertyEvalCorpus`), never the Keyboard extension; 21 unit
tests in `NumPadTests/QwertySymSpellCorrectorTests.swift`.

### 8-arm correction tables (verbatim from the run report)

#### typos_en

4539 pairs — ed1: 3897, ed2: 642, ed3+: 0; single-substitution adjacent: 2401, non-adjacent: 366; intended-in-lexicon: 99.1%

| arm | top-1 | top-3 | ed1 top-1 | ed2 top-1 | ed3+ top-1 | adj-sub top-1 | non-adj-sub top-1 | reachable headroom |
|---|---|---|---|---|---|---|---|---|
| floor | 69.7% | 85.0% | 67.7% | 81.5% | — | 72.6% | 67.8% | 99.1% of 1377 misses |
| shipped | 67.2% | 85.0% | 65.4% | 78.0% | — | 66.6% | 67.2% | 99.1% of 1491 misses |
| spatial | 63.9% | 82.6% | 62.4% | 73.1% | — | 65.6% | 54.9% | 99.7% of 1639 misses |
| variants | 63.9% | 82.5% | 62.4% | 73.1% | — | 65.6% | 54.9% | 99.7% of 1638 misses |
| variantsLast | 63.0% | 82.3% | 61.6% | 71.8% | — | 63.8% | 54.4% | 99.7% of 1678 misses |
| combined | 73.2% | 84.5% | 72.6% | 77.1% | — | 85.7% | 45.6% | 99.6% of 1215 misses |
| noSpatialAugmentLast | 65.9% | 84.7% | 64.1% | 76.6% | — | 64.5% | 66.4% | 99.2% of 1549 misses |
| symspell | 66.6% | 90.4% | 64.9% | 76.9% | — | 65.4% | 66.7% | 99.1% of 1514 misses |

#### typos_wiki_en

4266 pairs — ed1: 3095, ed2: 1067, ed3+: 104; single-substitution adjacent: 100, non-adjacent: 745; intended-in-lexicon: 87.4%

| arm | top-1 | top-3 | ed1 top-1 | ed2 top-1 | ed3+ top-1 | adj-sub top-1 | non-adj-sub top-1 | reachable headroom |
|---|---|---|---|---|---|---|---|---|
| floor | 78.5% | 91.3% | 79.7% | 79.3% | 34.6% | 84.0% | 86.4% | 78.7% of 916 misses |
| shipped | 78.7% | 91.6% | 80.5% | 78.3% | 32.7% | 83.0% | 84.3% | 78.5% of 907 misses |
| spatial | 76.3% | 90.7% | 78.6% | 74.2% | 29.8% | 87.0% | 78.4% | 81.9% of 1010 misses |
| variants | 77.5% | 90.7% | 80.3% | 74.2% | 29.8% | 87.0% | 78.4% | 82.2% of 959 misses |
| variantsLast | 79.7% | 91.0% | 83.4% | 74.1% | 29.8% | 86.0% | 78.1% | 80.7% of 864 misses |
| combined | 77.4% | 90.6% | 80.6% | 72.7% | 29.8% | 94.0% | 76.6% | 80.5% of 965 misses |
| noSpatialAugmentLast | 82.0% | 91.7% | 84.9% | 78.2% | 31.7% | 82.0% | 83.8% | 77.5% of 770 misses |
| symspell | 82.9% | 94.3% | 85.7% | 79.6% | 33.7% | 83.0% | 84.6% | 76.3% of 729 misses |

### Latency (uncached, fixed 500-pair sample per corpus — verbatim)

#### typos_en (n=500 uncached calls per arm)

| arm | p50 ms | p95 ms | Δp50 vs floor | Δp95 vs floor |
|---|---|---|---|---|
| floor | 1.074 | 1.693 | +0.000 | +0.000 |
| shipped | 1.086 | 1.671 | +0.012 | -0.022 |
| spatial | 1.118 | 1.730 | +0.044 | +0.037 |
| variants | 1.362 | 2.118 | +0.288 | +0.425 |
| variantsLast | 1.352 | 2.106 | +0.278 | +0.413 |
| combined | 1.371 | 2.117 | +0.296 | +0.424 |
| noSpatialAugmentLast | 1.386 | 2.198 | +0.312 | +0.505 |
| symspell | 2.723 | 5.758 | +1.649 | +4.065 |

#### typos_wiki_en (n=500 uncached calls per arm)

| arm | p50 ms | p95 ms | Δp50 vs floor | Δp95 vs floor |
|---|---|---|---|---|
| floor | 1.781 | 2.826 | +0.000 | +0.000 |
| shipped | 1.748 | 2.768 | -0.033 | -0.058 |
| spatial | 1.844 | 2.952 | +0.062 | +0.127 |
| variants | 2.228 | 3.593 | +0.447 | +0.768 |
| variantsLast | 2.246 | 3.478 | +0.465 | +0.652 |
| combined | 2.223 | 3.622 | +0.442 | +0.797 |
| noSpatialAugmentLast | 2.147 | 3.470 | +0.365 | +0.645 |
| symspell | 2.934 | 4.951 | +1.153 | +2.126 |

The symspell arm's timing INCLUDES its `corrections(for:)` call; the one-time
index build is forced before any timed window.

### Index build and memory (verbatim from the run report)

- Index build time (lazy build forced once via `prepareIndex()` before any scoring; shared by both corpora): 1116 ms
- Lexicon words indexed: 49052; unique delete-variant keys: 462907 (avg 5.2 UTF-8 bytes); postings (rank entries): 1085288
- Approximate resident memory of the as-built `[String: [UInt32]]` index (count×entry-size arithmetic, NOT a Jetsam/resident measurement): dictionary storage 462907 keys × 24 B entry stride (16 B Swift String — inline, keys ≤ 7 chars — + 8 B array ref) ÷ 0.75 load factor = 14.1 MB; posting lists 462907 × 32 B heap header + 1085288 × 4 B = 18.3 MB; rank→word table 49052 × 16 B = 0.7 MB; **total ≈ 33 MB** (order of magnitude; a flattened CSR layout would roughly halve it)

### Mechanical gate application (no re-negotiation)

Wiki (`typos_wiki_en`) is the gating corpus, per the corpus-bias rule.

1. **Quality gate (+15pp absolute top-1): FAIL.**
   - vs floor: symspell 82.9% − floor 78.5% = **+4.4pp** (gate needs +15pp; the
     perfect-engine cap vs floor was 16.9pp).
   - vs current production: symspell 82.9% − noSpatialAugmentLast 82.0% =
     **+0.9pp** (perfect-engine cap vs production was 14.0pp — the gate was
     unclearable from this baseline before the arm was built).
   - Synthetic (does not gate): 66.6% — −3.1pp vs floor, +0.7pp vs production.
   - The honest read: with backfill-only composition, most of the reachable
     headroom sits at ranks the checker DID fill — symspell converts it at
     top-3 (wiki 94.3%, +3.0pp vs floor and best in the table; synthetic 90.4%,
     +5.4pp vs floor) but by construction cannot move those pairs' top-1.
2. **Latency gate (≤16ms p95 added): PASS.** Worst Δp95 vs floor +4.065ms
   (typos_en); added over the production arm +3.560ms (typos_en) / +1.481ms
   (typos_wiki_en). Well under one frame.
3. **Memory gate (≤15MB resident delta): FAIL** on the stated arithmetic
   estimate — ≈33MB as-built; even an optimistic flattened re-layout (~half)
   still sits at the gate line, and the gate is defined as a hard ceiling
   measured on-device, leaving no benefit of the doubt to claim.
4. **License gate: PASS** — clean-room reimplementation of the MIT-published
   algorithm; no third-party code in the binary.

**Verdict: the SymSpell arm does not clear the pre-registered adoption gates
(quality FAIL, memory FAIL, latency PASS, license PASS). Nothing is wired —
Task 9 owns all wiring decisions regardless of outcome.** The reusable positive
finding for Task 9's file: backfill lifts wiki top-3 to 94.3% (best measured)
at ~+2ms p95 — a candidate-coverage improvement, not a top-1 engine.

---

## Task 8 addendum — next-word bigram arm (2026-07-21)

Run at ~15:04 PDT, same pinned simulator destination; both harness tests PASSED
(56.8s total). **Reproduction check: all 16 pre-existing accuracy rows (8 arms ×
2 corpora) AND the 3 completions-baseline KSR rows reproduced the Task-7 run
byte-identically** — the shared-helper refactor (the production-base pipeline
expression, previously duplicated between the `noSpatialAugmentLast` and
`symspell` arm builders, now one `productionBasePipeline` both call) and the
new next-word instrumentation are numbers-neutral, as intended.

### Framing — pre-registered, restated before the numbers

§C quality gate, verbatim: "**+15 percentage points absolute top-1 hit-rate**
(next-word) *or an equivalent KSR gain*". Baseline (this doc's KSR section):
completion hit@1 31.8%, hit@3 48.2%, KSR 25.8%. Next-word prediction at
prefix 0 is a capability the completions path structurally lacks (it needs ≥1
typed character), so the cleanest apples-to-apples gate reading is the
**combined-KSR delta** — predictor at prefix 0 (a top-1 hit saves the WHOLE
word), completions at prefixes ≥1, against the completions-only 25.8%.

### Data source — license verification (full story: `tools/data/eval/README.md`, "Next-word bigram source")

Unlike the eval fixtures, this source would ship in the app binary if adopted,
so provenance had to clear the hard license gate:

- **Rejected:** the standard en_US wordlist in Helium314's aosp-dictionaries —
  its provenance file points at OpenBoard v1.4.5 (GPL-3.0 repo) and the hosting
  repo's own top-level LICENSE is GPL-3.0 with no per-dictionary carve-out.
- **Adopted:** the **experimental** en_US wordlist
  (`wordlists_experimental/main_en_US.combined`, retrieved 2026-07-21) — built
  by the maintainer from Leipzig Wortschatz word lists; per-file license
  statement "source lists under CC BY 4.0". Leipzig's own Terms of Usage were
  verified (Internet Archive capture — the live page is bot-gated): *"The text
  corpora offered for download are made available under the Creative Commons
  licence CC BY"* — the CC BY-NC sentence on the same page covers their web
  query applications, NOT the downloadable corpora. Commercial redistribution
  with attribution is permitted; attribution recorded in
  `tools/data/bigrams_provenance.txt`.
- **Bigram presence verified by inspection:** 104,703 `bigram=` lines across
  47,184 heads, max 3 continuations per head, `f=1` = most frequent (confirmed
  against the source's `scripts/wordlist.py`, lines 357–387).

### The artifact and the arm

`tools/make_qwerty_bigrams.swift` filters to bigrams whose head AND
continuation are both in the production 50k lexicon (top-8 per head by the
source's own frequency attribute — the source caps at 3, so the cap never
binds) and packs ranks-only:
`Keyboard/Resources/qwerty_bigrams_en.bin` — **225,469 bytes**, 27,982 heads,
70,757 bigram entries. Bundled into **NumPadTests resources ONLY** (nothing
ships it; Task 9 owns Keyboard membership). Reader:
`NumPad/Libraries/Qwerty/QwertyNextWordPredictor.swift` (NumPad app target
only, like `QwertySymSpellCorrector`; corrupt/truncated data degrades to an
empty predictor — 21 unit tests in `QwertyNextWordPredictorTests.swift`, suite
now 652 tests + 2 gated skips, green).

### Next-word / combined-KSR table (verbatim from the run report)

Corpus: `sentences_en` — 313 held-out final words, 1347 prefix queries.

| metric | value |
|---|---|
| hit@1 (prefix queries) | 31.8% (428/1347) |
| hit@3 (prefix queries) | 48.2% (649/1347) |
| keystroke savings rate | 25.8% (428 of 1660 letters saved) |
| nextword hit@1 (boundaries, prefix 0) | 2.2% (7/313) |
| nextword hit@3 (boundaries, prefix 0) | 4.5% (14/313) |
| nextword coverage (any predictions) | 100.0% (313/313) |
| combined KSR (nextword@0 + completions@≥1) | 26.8% (445 of 1660 letters saved) |

Coverage is 100% — every one of the 313 boundaries had stored continuations
for its previous word — so the misses are genuine ranking misses, not table
sparsity. The predictor's marginal contribution is the whole-word saves behind
the 7 top-1 hits: +17 letters, **combined KSR 26.8% vs baseline 25.8% =
+1.0pp**.

### Mechanical gate application (no re-negotiation)

1. **Quality gate (+15pp top-1 or equivalent KSR gain): FAIL.**
   - KSR reading (apples-to-apples): 26.8% − 25.8% = **+1.0pp** against a
     +15pp-equivalent bar.
   - Hit-rate reading: next-word top-1 at prefix 0 is **2.2%** per boundary
     (top-3 4.5%). The denominators differ from the baseline's per-prefix-query
     rates, but on no reading does the arm come within an order of magnitude of
     the gate.
2. **Memory gate (≤15MB): PASS.** The blob is 225,469 bytes; the reader adds a
   rank→word table (~49k strings, the same 1–2MB class as the lexicon's
   documented `allEntries()` inflation). Total well under 15MB.
3. **Latency gate (≤16ms p95): PASS (note).** The harness does not time the
   predictor inside a per-keystroke window (it fires once per word boundary); a
   host-side measurement over all 49,052 lexicon words as heads (swiftc -O,
   Apple silicon macOS — not an on-device number) gives p50 0.0006ms /
   p95 0.0008ms / max 0.032ms per `predictions(after:)` call — a binary search
   over 27,982 fixed records; four orders of magnitude under the gate on any
   plausible hardware.
4. **License gate: PASS.** CC BY 4.0 with attribution (chain verified above);
   no GPL/AGPL anywhere near the artifact.

**Verdict: the bigram next-word arm does not clear the pre-registered adoption
gates (quality FAIL — decisively; memory PASS, latency PASS, license PASS).**

Honest reading of WHY the quality number is so low, recorded for Task 9's
file: (a) the source stores at most 3 continuations per head with ordinal
frequencies — a shallow table can rank well only when the true continuation is
one of the 3 globally-most-frequent followers, which everyday-sentence final
words (often content words) rarely are; (b) the source corpora are
news/web-register Leipzig text, while `sentences_en` is deliberately common
everyday vocabulary — register mismatch; (c) single-previous-word context is
structurally weak — 313 boundaries is also a small sample (7 hits), so the
2.2% carries wide error bars in either direction, none of which approach the
gate. A next-word FEATURE (suggestion bar at prefix 0) could still be a
product decision on UX grounds someday — but this data source does not earn
engine adoption under the pre-registered gates, and nothing is wired.

---

## Task 9 verdict — wiring decision (2026-07-21)

Mechanical application of the pre-registered §C gates to the two engine arms
measured above — no re-negotiation:

- **SymSpell (Task 7): NOT wired.** Quality FAIL (+0.9pp wiki top-1 vs current
  production, +4.4pp vs floor, against a +15pp bar) AND memory FAIL (≈33MB
  as-built arithmetic estimate vs the ≤15MB hard ceiling). Latency and license
  passed; either failed gate is disqualifying on its own.
- **Bigram next-word (Task 8): NOT wired.** Quality FAIL, decisively — +1.0pp
  combined KSR (26.8% vs 25.8%) and 2.2% hit@1 at prefix 0, an order of
  magnitude under any reading of the gate. Memory, latency, and license
  passed; the quality failure alone disqualifies.

**Therefore NO engine wiring.** Both modules remain harness-only, compiled into
the NumPad app target only (`QwertySymSpellCorrector.swift`,
`QwertyNextWordPredictor.swift`). The Keyboard extension binary carries neither
module, and the bigram blob (`qwerty_bigrams_en.bin`) sits in the NumPadTests
resources phase only — pbxproj-verified in the Task 7/8 reviews and re-verified
in the Task-10 closure sweep (only the NumPadTests Resources build phase
references `qwerty_bigrams_en.bin` and `typos_wiki_en.tsv`; the NumPad app,
Keyboard, and NumPadUITests phases carry neither).

What ships from this branch is therefore exactly the Task-6b rewiring recorded
above — `rerankKnown` + augment-last with the spatial resort dropped in
`QwertyPageHost.rankedGuesses` (82.0% wiki top-1, +4.5pp over pre-branch
production) — plus the branch's other production-path behavior changes: the
lean verdict-only `isMisspelled` oracle, the `matchCase` all-caps branch, and
`decide`'s `@autoclosure` laziness.

### Attribution status (Task-10 sweep)

- The existing app-binary attribution — Hermit Dave / FrequencyWords
  (OpenSubtitles-derived), CC BY-SA 4.0, in `NumPad/Settings.bundle/Root.plist`
  — is unchanged and remains correct (it covers `qwerty_lexicon_en.bin`, which
  does ship).
- **No new app-binary attribution is owed:** the Wikipedia misspellings fixture
  (`typos_wiki_en.tsv`) and the Leipzig-derived bigram table are
  NumPadTests-only and never enter the app or Keyboard bundles (membership
  verified above).

### License-record follow-ups for any future re-adoption

1. **DONE (this task):** the Leipzig Terms of Usage verification now pins the
   exact Internet Archive snapshot in `tools/data/bigrams_provenance.txt`:
   `http://web.archive.org/web/20260206070156/https://wortschatz.uni-leipzig.de/en/usage`
   (capture dated 2026-02-06; snapshot content re-verified 2026-07-21 to
   contain the quoted "The text corpora offered for download are made
   available under the Creative Commons licence CC BY" sentence, with the
   CC BY-NC sentence covering the web query applications only).
2. **OPEN (owner action):** obtain an explicit statement from the
   aosp-dictionaries maintainer that the experimental `.combined` derivative
   files are THEMSELVES offered under CC BY — the per-file statement covers
   the *source lists*; a direct statement about the derivative would close
   the chain before anything ships.
