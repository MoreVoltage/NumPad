# Glide/Swipe Typing for NumPad Type: Feasibility, Prior Art, and a v1 Sketch

**Date:** 2026-07-10
**Scope:** Research only — no code changes. Focuses on the *technical* shape of a from-scratch v1
(algorithm, memory, touch-capture architecture) that the two companion docs
(`2026-07-05-oss-swipe-options.md`, `2026-07-05-technical-feasibility.md` §3) didn't go deep on.
Their licensing/patent conclusions are **not re-litigated here** — they're carried forward and
cited, not repeated at length. This doc adds: the SHARK2/neural algorithm lineage in more
technical detail, a concrete lexicon-memory estimate, and — new in this pass — a specific
architectural finding about how glide capture interacts with NumPad Type's existing touch-routing
code.

## Confidence legend

Same convention as the companion docs: **[HIGH]** confirmed against a primary source or NumPad's
own code; **[MED]** corroborated by multiple secondary sources; **[LOW]** single source, estimate,
or inference — treat as a hypothesis.

---

## Executive summary

**Recommendation: do not build glide typing now.** This confirms and sharpens the companion docs'
existing verdict (swipe = v2+, legally gated, off by default) — this pass doesn't find a reason to
override it. If a flagged prototype is greenlit later, the technically sound v1 shape is a
**from-scratch, non-neural, template/shape-matching decoder in the SHARK2/AnySoftKeyboard lineage**
— not a port of any existing OSS code (all license-clean OSS candidates are mediocre quality and
sit near an active Cerence patent; all high-quality options are GPL or non-commercial) — reusing
NumPad's own `QwertyLayout`/`QwertyTouchRouting` geometry as the spatial model instead of shipping
per-word template arrays, and a purpose-built ~50k-word frequency lexicon (**estimated 0.5–1.5MB
resident**, comfortably inside the memory ceiling) as the ranking signal, since the existing
`UITextChecker`-based autocorrect pipeline has no API surface usable for scoring a whole untyped
gesture (§5).

**New architectural finding this pass:** the repo's existing zero-dead-zone touch model
(`QwertyKeyboardView.hitTest` → one `QwertyKeyButton` gets the *entire* touch lifecycle) cannot
carry a glide gesture as-is — a real finger swipe from Q to L would today just cancel the Q button's
own tap-tracking, not travel across buttons (§4.1). Building glide capture means adding a genuinely
new tap-vs-glide disambiguation layer to `QwertyKeyboardView`; it is **not** something that falls
out of `QwertyTouchRouting` for free, even though that module's pure `keyIndex(at:)` function is
exactly the right primitive to reuse *inside* that new layer.

**Effort estimate (if the legal gate clears and this is greenlit):** a v1 non-neural decoder
(lexicon build tooling + pruning/scoring engine + touch-capture layer + suggestion-bar integration,
unit-tested per the repo's pure-logic convention) is **4–8 engineer-weeks** of net-new work for one
engineer familiar with the codebase — most of it in the touch-capture layer and lexicon tooling, not
the scoring math itself, which is a well-documented, boundable algorithm. This estimate does **not**
include legal review time, App Store risk absorption, or the ongoing tuning/QA cycle every gesture
keyboard needs post-launch (all three OSS projects surveyed in the companion doc are still tuning
years in).

---

## 1. Constraints verified in-repo

Per the repo's `graphify query` (mandatory before reading source) and direct reads of
`NumPad/Libraries/Qwerty/QwertyTouchRouting.swift`, `Keyboard/Views/QwertyKeyboardView.swift`, and
`Keyboard/Libraries/QwertySpellChecker.swift`:

- **Memory ceiling:** ~50MB documented directly in `QwertyTouchRouting.swift`'s own doc comment
  ("safe for the keyboard extension's ~50MB memory ceiling") and in `CLAUDE.md`; the companion
  technical-feasibility doc puts real-world Jetsam kill thresholds around 66MB on an iPhone
  XS Max-class device **[HIGH]**. Any new engine has to fit in *remaining* headroom (UIKit, theme
  assets, `UITextChecker`, the rest of the extension's own runtime), not the whole budget.
- **No Full Access for core typing today, and that's a hard product requirement to preserve.**
  `QwertySpellChecker`'s own doc comment states the extension "satisfies App Review 4.4.1 by
  construction" because `UITextChecker`/`UILexicon` need no Full Access. A from-scratch lexicon +
  scorer is pure local computation with no network/clipboard/pasteboard dependency, so it can
  preserve this — but it is genuinely new code with its own memory footprint, unlike the
  system-API-backed autocorrect baseline.
- **Touch handling is already a pure, tested module — but it solves a different problem than glide
  capture.** `QwertyTouchRouting` (in `NumPad/Libraries/Qwerty/`, the shared pure-logic directory
  per `CLAUDE.md`) exists to fix *dead zones between static key taps*: `keyIndex(at:keyFrames:in:bias:)`
  maps one point to one key, with a rank-weighted bias derived from `QwertySpellChecker`'s
  already-computed completions (`QwertyKeyboardView.swift:127-153`). It is a single-point,
  single-touch-instant function — it says nothing about a *path* of points over time, and it isn't
  wired to receive one (see §4.1).
- **Architecture convention:** pure logic lives in `NumPad/Libraries/Qwerty/` (compiled into both
  targets, unit-tested), thin glue lives in `KeyboardType/`/`Keyboard/`. Any glide decoder should
  follow this split — a pure `QwertyGlideDecoding`-style module for pruning/scoring, thin
  view-layer glue for touch capture.
- **Autocorrect today is system-API-only, with no owned lexicon.** `QwertySpellChecker` wraps
  `UITextChecker.guesses(forWordRange:)`/`completions(forPartialWordRange:)` — both operate on a
  *partially-typed* word already in the text field. Glide typing has no such partial word; the
  gesture is the entire input. There is no way to hand a full swipe path to `UITextChecker` and get
  a word back — this confirms the companion technical-feasibility doc's §5 finding ("NumPad has
  zero ML/prediction code today") applies just as much to glide as to next-word prediction: **a
  glide decoder needs its own frequency-ranked lexicon regardless of which scoring algorithm is
  chosen.**

---

## 2. How production keyboards actually decode a swipe

### 2.1 The classical lineage: SHARK2 / ShapeWriter (2001–2004)

The foundational algorithm, developed by Shumin Zhai and Per Ola Kristensson at IBM Research
(commercialized as ShapeWriter, Inc., acquired by Nuance in 2010 — chain of custody covered in the
companion doc's §5 patent section) **[MED-HIGH]**:

1. **Sampling** — resample the raw gesture trajectory to a fixed number of points (a widely-cited
   student reimplementation uses 100 uniformly-spaced points; the exact count is a tunable, not a
   fixed constant of the algorithm) **[MED, third-party reimplementation, not the original paper
   text — the shape of the pipeline matches multiple independent descriptions]**.
2. **Pruning** — before scoring, cheaply reject most of the vocabulary using coarse geometric
   checks: start-point and end-point distance between the gesture and each candidate word's ideal
   key-path (the path connecting the word's letters' key centers), which the pipeline computes
   directly rather than needing to be told each candidate's actual key sequence in advance. This is
   the step that makes scoring the *full* vocabulary per keystroke unnecessary — only survivors get
   the expensive step below.
3. **Shape channel** — normalize both the input gesture and each surviving template to the same
   bounding-box scale (`s = L / max(W, H)`) and compare the two 100-point-resampled paths
   point-by-point; this channel is translation/scale-invariant — it scores *contour similarity*
   only, ignoring where on the keyboard the shape actually sits.
4. **Location channel** — the same point-by-point comparison **without** the normalization step, so
   it *does* score absolute position — this is what disambiguates two words with a similar shape
   but different key positions.
5. **Integration** — `score = a·shape_score + b·location_score` (`a + b = 1`, tunable), then weighted
   by each word's lexical frequency; highest weighted score wins.

Source for this exact 5-step breakdown: a public educational reimplementation of the published
algorithm, cross-checked against Wikipedia's and Kristensson's own summary of the SHARK2 paper for
the higher-level claims (50,000–60,000-word vocabulary capacity, low latency) **[MED — the
step-by-step mechanics are from a third-party implementation, not the original 2004 PDF text itself,
but consistent across every secondary description found]**.

**On-device feasibility of this exact shape:** yes, cheaply — this is 2004-era pen-computer
technology, designed for hardware far weaker than a modern iPhone. The real cost driver isn't the
math (point-to-point distance over ~100 samples) but how big the *surviving-candidate set* is after
pruning and how expensively per-word templates are stored/generated (§4.2).

### 2.2 The neural evolution — and why it's a much bigger project

Google moved past pure shape/location matching in production Gboard as of 2015: **[MED-HIGH,
Google Research's own publication + abstract]**

- **Alsharif, Ouyang, Beaufays, Zhai, Breuel & Schalkwyk, "Long-Short Term Memory Neural Network
  for Keyboard Gesture Decoding," ICASSP 2015** — replaced/augmented the shape-matching baseline
  with an LSTM combined with finite-state-transducer decoding, reporting **4–22 percentage points
  absolute accuracy improvement** over the baseline shape-matching system across their test
  conditions. This is the direct, citable evidence that neural decoding meaningfully beats classical
  shape-matching, from the same research lineage (Zhai is a co-author on both SHARK2 and this
  paper).
- **Gboard's decoder today** composes a spatial model (key-likelihood per touch/gesture sample)
  with a language model via finite-state-transducer composition (a `C∘L∘G` structure — character
  transducer ∘ lexicon transducer ∘ grammar/language-model transducer), and a 2024 Google paper
  ("Neural Search Space in Gboard Decoder," arXiv:2410.15575) describes replacing the n-gram
  language-model component specifically because **n-gram LMs "have sparsity problems under device
  model-size constraints"** — i.e., Google's own team treats the on-device memory budget as the
  binding constraint even with far more engineering resources than this project has **[MED]**.
- **FUTO Swipe** (arXiv:2606.25247) is the most directly relevant public precedent for "how small
  can a genuinely neural swipe decoder be and still run on-device," because it was purpose-built for
  a tight budget: a **635K-parameter temporal-convolutional spatial encoder (2.5MB at fp16)** that
  emits a per-timestep spectral (DCT) encoding of intended key position plus an "intention" gate, an
  optional **304K-parameter fixed-layout refinement decoder (0.65MB at fp16)**, reporting **92.94%
  top-1 accuracy encoder-only / 93.49% with the decoder** on their own benchmark, and **1.5ms p50
  encoder latency on a Pixel 4, single-threaded** **[HIGH — directly fetched from the paper]**. This
  is real evidence a sub-3MB, sub-2ms neural model is achievable — but as the companion OSS doc
  establishes, the *reference implementation* of this exact model is GPL and the trained weights
  carry a non-OSI custom license, so this is a "the architecture is provably small enough" data
  point, not a "here's code to adopt" one. Reimplementing this class of model from scratch is a real
  ML project (data pipeline, training infra, quantization, CoreML export) with no existing analog
  anywhere in NumPad's codebase.

**Template matching vs. neural, for NumPad specifically:** template/shape matching is buildable by
one engineer in weeks using only techniques from a 20-year-old paper, at a real but bounded quality
ceiling (both FlorisBoard and AnySoftKeyboard, which use this family of approach, get recurring
"missed word" complaints — companion doc §4). A neural decoder is a materially better ceiling
(Google's own 4–22-point improvement number, FUTO's 93%+) but requires standing up an ML training
pipeline this codebase has never needed for anything — a different order of project, not a variant
of the same one.

---

## 3. Open-source options — condensed (full legal detail in the companion doc)

The companion doc (`2026-07-05-oss-swipe-options.md`) already did the deep license/patent work; this
table condenses it for this doc's purposes and adds nothing new to the legal conclusion:

| Candidate | License | Algorithm | Language | Port effort to Swift | Verdict |
|---|---|---|---|---|---|
| **FlorisBoard** | Apache-2.0 (usable) | Classical shape/location matching (`GlideTypingClassifier`) | Kotlin | Real, bounded — algorithmic port, no ML | License-clean but mediocre quality; near an active Cerence patent (US 7,706,616, expires 2026-12-21) |
| **AnySoftKeyboard** | Apache-2.0 (usable) | Corner-matching (>170° angle turns only) — a known-lossy simplification that conflates words sharing the same corner sequence (e.g. double letters) | Java | Real, bounded — algorithmic port | License-clean but the maintainers' own unmerged 2019 PR (#1870) proposing a replacement signals the shipped algorithm is considered under-baked |
| **FUTO Swipe** (inference lib + weights) | GPL (lib) / custom non-OSI (weights) | Neural (TCN encoder + DFSMN decoder) | C++ / model weights | N/A — disqualified | Best quality signal found, but both pieces needed to run it are disqualifying; only the **1M-swipe training dataset is MIT** and usable for a clean-room retrain |
| **CleverKeys** | GPL-3.0 | Neural (transformer), trained on FUTO's MIT dataset | Python (training) + Kotlin (app) | N/A — disqualified | Proof the MIT dataset is sufficient to train a real model; the code/weights aren't reusable |
| **OpenBoard / HeliBoard (OSS gesture path)** | GPL-3.0 | None shipped — depends on Google's proprietary `libjni_latinimegoogle.so` binary | Java/Kotlin | N/A | Confirms the Apache-licensed AOSP tree never actually shipped an open decoder; HeliBoard's NLnet-funded from-scratch effort is pre-alpha, Android/Linux-only, license unconfirmed (assume GPL/LGPL) |
| **iSwipe** (iOS) | GPL-3.0 | DP + greedy path matching | Objective-C | N/A — disqualified, also targets iOS <8 jailbreak hooking APIs that no longer apply | Dead |
| **Fleksy SDK** | Commercial, $269+/mo | Proprietary, bundled turnkey swipe | N/A (SDK) | None — integration only | Only turnkey option; doesn't remove the Cerence patent question, just shifts it into their contract terms |
| **KeyboardKit Pro** | Commercial, $50–500/mo | No swipe feature found | N/A | N/A | Not a swipe option at all as of this research |

**Bottom line, unchanged from the companion doc:** no candidate clears both the license gate and a
clean patent picture at a quality bar worth shipping. If built, it must be a **clean-room
implementation informed by public research** (the SHARK2 lineage's published description, or FUTO's
published architecture/dataset), not a port of any specific OSS codebase — this is true regardless
of which algorithm family (classical or neural) is chosen.

---

## 4. Algorithm sketch for a from-scratch v1 (classical/template family)

This section assumes the non-neural path, since it's the one buildable without standing up new ML
infrastructure, consistent with the companion docs' recommendation to treat swipe as a bounded,
legally-gated experiment rather than a platform investment.

### 4.1 Touch capture — the part that doesn't already exist

This is the most important finding of this pass, because it's easy to assume `QwertyTouchRouting`
already provides the hard part. **It doesn't — it solves a different, narrower problem.**

Today (`Keyboard/Views/QwertyKeyboardView.swift:127-137`): `hitTest(_:with:)` runs once per touch,
picks the single nearest `QwertyKeyButton`, and returns it — from that point on, **normal `UIButton`
touch tracking owns the rest of that touch's lifecycle** (its own `touchDown`/`touchUpInside`/
`touchUpOutside` targets, per `QwertyKeyboardView.swift:105-111`). A real swipe gesture — finger
touches down over "Q," drags across "W," "E," "R," lifts over "T" — would, under this exact model,
resolve to the **Q button only** at touch-down, and then most likely fire that button's
`touchUpOutside`/cancel path when the finger lifts somewhere outside Q's frame — i.e., today's
architecture would silently **eat** a swipe gesture as a non-event on the origin key, not deliver it
anywhere useful.

Building glide capture therefore means adding a **new disambiguation layer**, not wiring up an
existing one:

1. Track raw touch movement across the whole keyboard view (either a `UIPanGestureRecognizer` added
   to `QwertyKeyboardView` itself, above/alongside the button subviews, or an override of
   `touchesBegan/Moved/Ended/Cancelled` directly on the view — the latter matches the codebase's
   existing preference for manual touch handling over gesture recognizers, seen in the `hitTest`
   override).
2. **Tap-vs-glide disambiguation** — buffer the first N points/M milliseconds; if the touch stays
   within a small radius of the origin key, let it fall through to normal single-button tap tracking
   unchanged (preserving every existing behavior — long-press repeat, the space-bar cursor-drag
   gesture already documented in the product plan, key callouts). Only once movement crosses a
   distance/velocity threshold *and* the path has touched ≥2 distinct key frames does it "upgrade"
   into glide-capture mode — at which point the in-flight button's own tracking needs to be
   explicitly cancelled (e.g. synthesizing `touchesCancelled` or toggling `isEnabled`) so it doesn't
   also fire a spurious tap.
3. For each sample once in glide mode, reuse `QwertyTouchRouting.keyIndex(at:keyFrames:in:)` **as-is**
   — it is already the correct, tested, pure "point → nearest key" primitive; this part genuinely
   does carry over. The bias parameter (today driven by autocorrect completions) is irrelevant here
   and would just be omitted/zero.
4. Collapse the raw per-frame key-index stream into a **coarse letter sequence** (dedupe consecutive
   repeats — `Q,Q,Q,W,W,E,E,E,R,R,R,T` → `Q,W,E,R,T`) for pruning (§4.2), while keeping the **raw
   point path** (with timestamps, for velocity-based corner detection) for shape/location scoring.

This is real, non-trivial UIKit glue work with genuine edge cases (what if the user starts a glide,
pauses on a key long enough to look like a long-press, then continues? what about the space-bar
cursor-drag gesture already in the plan — do the two gestures collide on the same key region?) —
it should be scoped and estimated on its own, not assumed to be a thin adapter over existing code.

### 4.2 Candidate generation and scoring

1. **Pruning:** using the coarse letter sequence from §4.1 (or, more robustly, the corner-detected
   key sequence — points where the path's direction changes sharply, matching the "shape channel"
   literature above) as a first filter: reject any lexicon word whose first/last letter doesn't
   match the gesture's start/end key, and whose length falls too far outside the gesture's
   path-length-implied word-length band. This is the step that keeps per-gesture cost bounded
   regardless of lexicon size — it should cut a 50k-word vocabulary down to a low hundreds of
   survivors before the expensive step runs.
2. **Shape + location scoring** on survivors only: resample the raw path to a fixed point count
   (SHARK2 uses 100; a smaller count, e.g. 32–48, is a reasonable v1 tuning knob given NumPad's much
   smaller on-screen keyboard vs. a pen tablet), generate each survivor's *ideal* key-center path
   **on the fly** from `QwertyLayout`'s existing per-character unit-space key-center geometry (no
   need to precompute/store a template path per word — this is a real memory saving vs. how
   AnySoftKeyboard/FlorisBoard do it, since NumPad already has the layout geometry as live code, not
   just data), then score shape (normalized) + location (unnormalized) exactly as in §2.1.
3. **Rank by `integration_score × word_frequency`**, using the from-scratch lexicon (§4.3) — this is
   the step that has no existing NumPad analog and cannot be satisfied by `UITextChecker`, per §1.
4. **Feed the suggestion bar** — the ranked candidate list is structurally the same shape as
   `QwertySpellChecker.Analysis.completions` (`Keyboard/Libraries/QwertySpellChecker.swift`), so it
   can plug into the same `QwertySuggestionBarView` rendering path and the same autocorrect
   decision/history machinery (`QwertyAutocorrect`/`QwertyAutocorrectHistory`) already documented in
   `CLAUDE.md` — this part of the integration is genuinely low-risk reuse, unlike touch capture.

### 4.3 Lexicon size and memory estimate

**[LOW-MED confidence — this is this doc's own estimate, framed for validation before committing
memory budget, not a cited fact.]** A concrete real-world comparable exists: Peter Norvig's
`count_1w.txt` (Google Web Trillion Word Corpus-derived, MIT-licensed code/methodology) is
**333,333 words in a 4.9MB plain-text file**, word + raw decimal frequency count per line
**[HIGH — directly fetched from norvig.com/ngrams/]**. Scaling and repacking for a NumPad-sized v1:

- **Raw top-50k slice of that file, as-is:** ~50,000/333,333 × 4.9MB ≈ **735KB** — but this format is
  wasteful (13-digit decimal counts as ASCII text, e.g. `the 23135851162`).
- **A packed binary format is much smaller:** length-prefixed UTF-8 word (~6–8 bytes average for the
  top 50k, which skews longer/rarer than the very top few thousand) + a single quantized
  log-frequency byte or `UInt16` bucket (exact counts are unnecessary — only relative rank/
  probability matters for scoring) ≈ **8–10 bytes/entry × 50,000 ≈ 400–500KB on disk**, sorted so the
  same array doubles as a binary-searchable index (no separate hash structure needed).
- **Resident memory is the number that matters, and it's typically larger than the on-disk packed
  size** if loaded naively (e.g., a Swift `Dictionary<String, UInt16>` pays real per-entry overhead —
  heap-allocated `String` storage, hash-table load-factor slack — plausibly **3–8× the packed size**
  for 50k entries, so **1.5–4MB** is a more realistic resident estimate than the raw 500KB packed
  figure, unless the lookup structure is deliberately kept as a flat sorted buffer + binary search
  rather than a hash map). Hunspell's en_US dictionary (companion doc §2), a similar order of
  vocabulary with a comparable structure, runs **3.9–4.5MB resident** — a good sanity-check upper
  bound for this estimate.
- **No per-word template storage needed** (§4.2) — this is the main memory win vs. the classical OSS
  implementations, which do store a corner-path or point-array per dictionary word; NumPad can
  generate a candidate's ideal path from `QwertyLayout` at scoring time, for the small number of
  post-pruning survivors only, and discard it immediately.
- **Net estimate for the lexicon + scoring engine's steady-state resident footprint: roughly
  1–5MB** — comfortably inside the ~50MB ceiling *if* nothing else in the extension is already
  pressed against it, and small relative to the FUTO-scale neural alternative (§2.2's ~3MB model) it
  would eventually compete against on quality.

---

## 5. iOS-specific gotchas

- **No system glide-typing API exists for extensions, at all.** Nothing in `UIInputViewController`,
  `UITextChecker`, or `UILexicon` exposes gesture-to-word decoding — this has to be built or bought
  in full; there's no partial-credit system assist the way there is for spell-check.
- **CPU is not separately hard-capped the way memory is, but there's no documented per-extension CPU
  quota** — Apple's own docs describe Jetsam (memory) as the enforced, hard, no-graceful-degrade
  limit; CPU starvation instead triggers OS-level thread-priority throttling (a background thread
  that hogs CPU gets deprioritized, not killed) **[MED, general iOS scheduling behavior — no
  extension-specific published CPU ceiling was found in this pass]**. Practically this means a
  glide-scoring pass needs to run fast enough per-gesture to not visibly stall the main thread/typing
  responsiveness, not that there's a hard numeric CPU budget to design against the way there is for
  memory.
- **The touch-routing interaction is the sharpest gotcha, and it's specific to this codebase**
  (§4.1) — every other keyboard building glide typing on a from-scratch renderer hits some version
  of "how do I tell a tap from the start of a glide," but NumPad's specific implementation (a
  `hitTest` override that immediately hands the touch to normal `UIButton` tracking) makes this a
  concrete redesign, not a hypothetical.
- **Accessibility interaction, not independently verified in this pass** — VoiceOver users interact
  with custom keyboards via explore-by-touch and double-tap, a fundamentally different touch model
  than sighted glide-typing; any glide layer needs to either coexist cleanly with
  `UIAccessibility`-driven touch handling or be disabled when an assistive technology is running
  (`UIAccessibility.isVoiceOverRunning`) — **this needs its own spike**, not assumed from this
  research.
- **App Store review:** no specific published guideline found prohibiting or specially scrutinizing
  third-party gesture typing (this doc's search did not surface one, and the companion doc's own
  App-Review discussion is scoped to Full Access / 4.4.1, which glide typing as designed above
  wouldn't need). The realistic review risk is generic "does the feature work reliably" quality risk,
  not a named guideline — **[LOW confidence this is exhaustive; a specific keyboard-extension review
  precedent was not found either way]**.
- **CoreML/on-device ML availability is not the constraint if the neural path is chosen later** —
  Core ML and the Neural Engine are available to any process including extensions; the binding
  constraint is model size within the shared ~50MB ceiling (FUTO's ~3MB fp16 encoder+decoder shows
  this is achievable), not API access.

---

## 6. Recommendation

**Build vs. port vs. buy:** **build (clean-room), if and when this becomes a project at all** — not
port (every quality OSS option is disqualified by license or sits near a live patent; the two
license-clean options are mediocre and *also* sit near a live patent per the companion doc's new §5
finding) and not buy by default (Fleksy is the only turnkey vendor and is the most expensive, least
flexible option, and doesn't remove the legal question, just relocates it into a contract). This
matches the companion docs' conclusion; this pass's contribution is *how* a build would actually be
shaped, not a change to *whether*.

**Phased plan, if greenlit post-legal-review:**

1. **Phase 0 (spike, ~1 week):** touch-capture disambiguation layer only (§4.1), no scoring at all —
   validate that tap-vs-glide detection can coexist with every existing gesture (long-press repeat,
   callouts, space-bar cursor drag) without regressing them. This is the highest-uncertainty part of
   the whole project and should be de-risked first, independent of the decoder.
2. **Phase 1 (~2–3 weeks):** lexicon build tooling (Norvig/Kaggle-derived frequency data → packed
   binary format, §4.3) + the pure pruning/shape/location scorer, unit-tested against synthetic
   gesture paths, entirely offline from the touch layer.
3. **Phase 2 (~1–2 weeks):** wire Phase 0's capture into Phase 1's scorer, feed results into the
   existing suggestion bar/autocorrect pipeline, behind a new feature flag (following the
   `FeatureFlags.fullKeyboardEnabled` pattern already used for the whole NumPad Type extension) —
   off by default, no App Store submission, per the product plan's existing §0.5 owner decision.
4. **Defer indefinitely:** any neural decoder. It's a better ceiling (§2.2) but a different project
   category (ML pipeline, training data, quantization/export tooling) with zero existing precedent
   in this codebase — revisit only if the classical v1 ships, proves the UX is worth it, and still
   feels qualitatively behind Gboard/SwiftKey once tuned.

**Risks, restated for this specific shape:**

- **Legal (unchanged from companion docs):** Cerence v. Apple is unresolved (filed September 2025,
  Western District of Texas, over Apple's "slide to type"; no settlement or ruling found as of this
  pass) **[HIGH confidence on the docket facts, LOW on resolution timing]**, and Cerence separately
  holds US 7,706,616 (active through 2026-12-21) covering the classical shape-matching approach
  specifically — the exact family this doc's recommended v1 algorithm belongs to. **Do not ship
  without a real legal review**, regardless of how clean the implementation is.
- **Quality ceiling:** even a well-executed classical decoder plausibly lands where FlorisBoard/
  AnySoftKeyboard sit today — "usable, not competitive with Gboard" — per both projects' own user
  communities (companion doc §4). Set expectations accordingly before investing the 4–8 weeks.
- **Scope creep in the touch-capture layer:** §4.1 is the part most likely to blow past estimate —
  it's genuinely new interaction design (gesture disambiguation, timing thresholds, interaction with
  the already-planned cursor-drag gesture), not a mechanical port of a known algorithm.
- **Maintenance tail:** every surveyed OSS project (FlorisBoard, AnySoftKeyboard, HeliBoard's
  from-scratch effort) is still actively tuning gesture accuracy years into their respective
  projects — a v1 ship is the start of an ongoing tuning cost, not a one-time build.

---

## Sources

- [SHARK2 GitHub reimplementation — pruning/shape/location channel walkthrough](https://github.com/Trisha11r/Decode_Gesture_SHARK2_algo)
- [ShapeWriter — Wikipedia](https://en.wikipedia.org/wiki/ShapeWriter)
- [Per Ola Kristensson: ShapeWriter and Gesture Keyboards](http://pokristensson.com/gesturekeyboard.html)
- [Long-Short Term Memory Neural Network for Keyboard Gesture Recognition — Google Research](https://research.google/pubs/long-short-term-memory-neural-network-for-keyboard-gesture-recognition/) / [PDF](https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/43461.pdf)
- [Neural Search Space in Gboard Decoder — arXiv:2410.15575](https://arxiv.org/abs/2410.15575)
- [FUTO Swipe: Layout-Agnostic Neural Swipe Decoding — arXiv:2606.25247](https://arxiv.org/abs/2606.25247) / [HTML](https://arxiv.org/html/2606.25247)
- [Norvig Natural Language Corpus Data — count_1w.txt](https://norvig.com/ngrams/) / [file](https://www.norvig.com/ngrams/count_1w.txt)
- [English Word Frequency dataset — Kaggle](https://www.kaggle.com/datasets/rtatman/english-word-frequency)
- [FlorisBoard — GitHub](https://github.com/florisboard/florisboard) / [Issue #139](https://github.com/florisboard/florisboard/issues/139) / [Glide Typing Still Works discussion](https://github.com/florisboard/florisboard/discussions/2721)
- [AnySoftKeyboard — GitHub](https://github.com/AnySoftKeyboard/AnySoftKeyboard) / [PR #1870: Gesture typing AI](https://github.com/AnySoftKeyboard/AnySoftKeyboard/pull/1870) / [Issue #3749](https://github.com/AnySoftKeyboard/AnySoftKeyboard/issues/3749)
- [Cerence AI Files Patent Infringement Suit Against Apple](https://www.cerence.com/newsroom/press-releases/cerence-ai-files-patent-infringement-suit-against-apple) / [9to5Mac coverage](https://9to5mac.com/2025/09/04/apple-hit-with-patent-lawsuit-over-hey-siri-and-virtual-keyboard-features/)
- [US 7,706,616 B2 — Google Patents](https://patents.google.com/patent/US7706616B2/en)
- NumPad codebase (read-only, per mandatory `graphify query` pass): `NumPad/Libraries/Qwerty/QwertyTouchRouting.swift`, `Keyboard/Views/QwertyKeyboardView.swift`, `Keyboard/Libraries/QwertySpellChecker.swift`, `CLAUDE.md`
- Companion docs (this project): `docs/plans/full-keyboard/2026-07-05-oss-swipe-options.md`, `docs/plans/full-keyboard/2026-07-05-technical-feasibility.md`, `docs/plans/full-keyboard/2026-07-05-product-plan.md`
