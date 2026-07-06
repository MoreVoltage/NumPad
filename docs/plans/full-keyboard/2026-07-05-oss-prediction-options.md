# Open-Source Predictive-Text / Autocorrect Engines for a Closed-Source iOS Keyboard Extension

**Date:** 2026-07-05
**Scope:** Research only — no code changes. Answers *which open-source prediction/autocorrect engine (if any) is safe to link into NumPad's closed-source, paid keyboard extension*, under the ~50–70MB Jetsam ceiling, and designs the empirical test harness to decide **whether to ship prediction at all** before committing engineering time to any one engine. This is a deeper, license-first follow-up to §2 of the sibling doc `2026-07-05-technical-feasibility.md`, which covers the same ground at a broader level (KeyboardKit/Fleksy pricing, the free floor, swipe/patent risk) — read that one for the commercial-SDK options and platform-limit context; this one is scoped to **OSS engines specifically** and goes deeper on license mechanics and a runnable evaluation design.

## Confidence legend

- **[HIGH]** — confirmed directly from a license file, vendor docs, or repo the tool fetched in this pass.
- **[MED]** — corroborated by multiple independent secondary sources but not re-verified against the primary license text in this pass.
- **[LOW]** — single source, back-of-envelope estimate, or contested/unconfirmed claim. Treat as a hypothesis to spike, not a fact to build on.

---

## License-first framework (apply this before reading any quality claim)

NumPad is a closed-source, paid app. The disqualifying question for every candidate below is **"does using this require the extension binary to be redistributable in source form, or does it impose terms incompatible with a paid closed-source product?"** — not "is it good."

- **MIT / Apache-2.0 / BSD** — unconditionally fine to statically link into a closed-source binary. Apache-2.0 additionally requires carrying its NOTICE file forward if the upstream project ships one; trivial to comply with.
- **MPL-2.0** — fine *if used file-by-file*: you must publish source for any MPL-licensed *file* you modify, but this does not "infect" the rest of your app the way GPL does. Safe to vendor unmodified; needs a real read before modifying.
- **GPL-2.0 / GPL-3.0 / AGPL-3.0** — **disqualifying for linking**, full stop, for a closed-source shipped binary. Static or dynamic linking both count as "combining" under GPL's own FAQ; there is no clean way to link GPL code into NumPad without open-sourcing NumPad itself (AGPL is stricter still, extending to network use). This is a hard gate, not a threshold to negotiate.
- **"Source-available" / custom licenses** (FUTO Source First, FUTO Model Weights License, Llama-style community licenses) — read the actual clauses every time; "you can see the source" and "OSI open source" are unrelated facts. Some (like FUTO's model-weights license, below) permit commercial use with conditions; others (FUTO's *keyboard app* license) explicitly forbid commercial use and are non-starters regardless of what the code looks like.
- **CC BY / CC BY-SA on data** (word lists, corpora) — these are data licenses, not code licenses. Bundling a CC-BY-SA word list into a closed-source app is fine (attribution required); it does **not** open-source your app. It *does* mean if you redistribute the word list itself as a derivative dataset, that derivative should also carry CC BY-SA — a data-only obligation, easy to satisfy with a credits screen, worth flagging to whoever owns App Store/legal compliance rather than assuming it's identical to GPL's code-level obligation.

---

## Ranked shortlist

| # | Candidate | License verdict | Est. memory (English) | Latency | Port/integration effort | Quality ceiling | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | **`UITextChecker` + `UILexicon`** (control) | Apple platform API, N/A | +0MB (already resident) | <5ms | None — available today | Spell-check + prefix-completion only, no next-word context | **Ship as v1 floor** |
| 2 | **SymSpell** + **marisa-trie** | MIT (SymSpell) + BSD-2-Clause *or* LGPL-2.1+ dual (marisa-trie — pick BSD) | ~2–6MB unigram; **90%+ reduction available** via prefix-length indexing per the project's own README | <5ms lookup | LOW–MED (C#→Swift port or thin C++ bridge; algorithm is simple, ports exist) | Real spelling-correction precision; **no next-word prediction** — a building block, not a full engine | **Candidate — autocorrect layer only** |
| 3 | **AOSP LatinIME dictionaries + prediction logic** | Apache-2.0 (app/tooling code, confirmed); word-list data is Apache-2.0 for Google's own compiled binaries, or **CC BY-4.0 / CC BY-SA-4.0** for community-rebuilt lists (Helium314/FlorisBoard) | ~4–10MB for unigram+bigram at a comparable vocabulary size (160,715 words in the community English rebuild — ~2× SymSpell's) | <10ms | **MED–HIGH** — binary trie dictionary format is documented and has existing Java/C++ decoders, but there is no existing Swift reader; realistic path is decode-once-offline into a flat table rather than porting the live trie decoder | Real word-completion + bigram continuation — closest OSS analog to "how a real mobile keyboard's dictionary layer works" | **Candidate — best quality-to-effort ratio among OSS options** |
| 4 | **KeyboardKit (open core)** | MIT, confirmed — but ships **no real prediction engine** | ~0MB (it's an empty interface) | N/A | LOW to integrate, but buys nothing on its own | **None** — free tier is protocols/architecture only; the actual autocomplete implementation is Pro-only ($50–500/mo, see sibling doc) | **Not a candidate as OSS** — it's a paid SDK with an MIT-licensed integration shim, not an open-source engine |
| 5 | **FUTO Swipe / ContextLM** | **Mixed, and the previous research pass's "MIT" characterization was wrong** — see deep dive | Model itself tiny: ~2.5M params (1.36M active), plausibly 1–3MB quantized | Sub-millisecond per the paper's own claims (device class unspecified) | **HIGH** — cannot adopt the reference implementation as-is; needs a clean-room reimplementation of the decoder | Swipe-decoding + small context-LM re-ranker; narrow use case, not general next-word prediction | **Conditional — weights maybe usable, reference code is not; high rebuild cost for a narrow win** |
| 6 | **Presage** | **GPLv2, confirmed** | N/A | N/A | N/A | N/A | **Disqualified — do not spend further time** |
| 7 | **Mozilla DeepSpeech** (and successors) | MPL-2.0 (permissive enough) but **abandoned**: formally discontinued June 2025, repo archived read-only, no commits since 2021 | N/A | N/A | N/A | It's an ASR (speech-to-text) engine — **wrong category entirely**, not predictive text | **Disqualified — dead project + wrong tool for the job** |
| 8 | **llama.cpp + tiny GGUF LM** (SmolLM2-135M / MobileLLM-125M class) | llama.cpp itself is **MIT**; model weights vary by model, checked separately | The smallest broadly-capable small language models today are ~125–135M params. At 4-bit quantization alone that's **~65–70MB for weights before tokenizer, KV-cache, and runtime overhead** — i.e., it can consume the *entire* remaining Jetsam headroom by itself | Not latency-limited for single-token next-word inference (one forward pass per keystroke, not a generation loop) — tokens/sec is a non-issue at this use case; **memory is the sole blocker** | HIGH effort, and the math doesn't close at current model sizes | Would be genuinely good if it fit | **Not viable today** — revisit only if sub-10–20M-parameter general LMs with real quality emerge; FUTO's 1.5M-param ContextLM (#5) is the only public precedent anywhere near this budget, and it's purpose-built for swipe re-ranking, not general typing |

---

## Deep dives

### 1. `UITextChecker` + `UILexicon` — the control arm

Already researched in depth in the sibling technical-feasibility doc (§2, §1's "text-replacement surprise") — not re-derived here. The load-bearing fact for this doc: this is **free, requires no Full Access, and is already running in every keyboard extension whether you use it or not**. It is the baseline every OSS candidate below must beat by a pre-registered margin (see Decision Thresholds) before it earns engineering time. `guesses(forWordRange:)` gives probability-ranked spelling correction; `completions(forPartialWordRange:)` gives prefix completion that Apple's docs claim is probability-sorted but NSHipster's testing found returns roughly alphabetically on iOS — a real, measurable quality gap that the offline harness below should reproduce and quantify rather than take on faith.

### 2. SymSpell (+ marisa-trie)

**License [HIGH]:** SymSpell's `LICENSE` is explicit MIT — "permission is hereby granted, free of charge... to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software." Cleared for closed-source linking with no conditions beyond the standard copyright/permission notice. marisa-trie is dual-licensed BSD-2-Clause OR LGPL-2.1-or-later [HIGH, from its own `COPYING.md`] — pick the BSD option and there are zero LGPL obligations (no dynamic-linking notice requirements, no source-availability clause).

**Memory [MED-LOW]:** the bundled `frequency_dictionary_en_82_765.txt` covers 82,765 English words. The project's own README doesn't publish a raw MB figure for the precalculated maxEditDistance=2 dictionary, but it does state that **prefix-length indexing achieves "more than 90% memory reduction, depending on prefix length and edit distance"** relative to the naive full-delete-set precomputation — which is the actual number to design around rather than a fabricated MB figure. Combined with marisa-trie as the backing store (marisa's own selling point is memory-efficient static tries, commonly 5–10% of raw text size for comparable structures), a maxEditDistance=2 English SymSpell index is very plausibly a low-single-digit-MB structure once tuned, which is why it's paired with SymSpell in the task brief rather than shipped with SymSpell's own default in-memory `Dictionary<string,...>` (a naive .NET/JVM hash map at this word count and edit distance is the thing that gets expensive, not the algorithm itself).

**What it is not:** SymSpell is fuzzy spelling correction via the symmetric-delete algorithm — genuinely fast, genuinely precise for "did you mean X," and **has no concept of next-word prediction**. It answers "is this typed token close to a real word," not "what word comes next." Pairing it with the AOSP bigram layer (#3) for next-word, with SymSpell handling in-word correction, is a more coherent system than either alone.

### 3. AOSP LatinIME dictionaries + prediction

**License [HIGH for code, MED for data]:** the LatinIME app/tooling source (`dicttool_aosp.jar`, the dictionary-maker pipeline) is Apache-2.0 as part of AOSP. The nuance the task brief anticipated correctly: **Google's own original production English word list was never fully published in AOSP in human-readable ("`.combined`") form** — only as compiled `.dict` binaries, whose deeper provenance is murky. This is exactly why community projects rebuilt their own dictionaries from scratch: Helium314's `aosp-dictionaries` (used by HeliBoard/FlorisBoard-adjacent projects) sources its English word list under **CC BY-4.0** for the current build, and FlorisBoard's own dictionary pipeline pulled from **wordfreq**, whose data is **CC BY-SA-4.0**. Both are fine to bundle into a closed-source app (attribution required; share-alike only binds *redistributing the dataset itself*, not the app binary — see the license-first framework above) but need a credits-screen line, not a "just vendor it silently" treatment.

**Quality/scale [HIGH, MED for size estimate]:** the community-rebuilt English main dictionary runs **160,715 words** — roughly double SymSpell's 82,765 — and importantly ships **bigram continuation data** ("the `.combined` file structure documents bigram support" per the repo's own format spec), which is the actual next-word-prediction layer this candidate brings that SymSpell doesn't. Comparable-order-of-magnitude dictionaries (Hunspell's en_US at 3.9–4.5MB in memory, per the sibling doc) put a reasonable estimate for a unigram+bigram AOSP-format English dictionary at **roughly 4–10MB** [LOW confidence, extrapolated from comparable projects, not independently measured].

**Port effort [MED-HIGH]:** the binary dictionary trie format (versions gated at "greater than 18" for AOSP-keyboard compatibility) is documented and has existing Java (`dicttool`) and C++ (LatinIME's own native code) decoders — but **no existing Swift decoder was found**. The pragmatic path is not "port the live trie-walking decoder to Swift" but "decode the `.dict`/`.combined` format once, offline, with the existing Java tool, and emit a flat unigram+bigram table NumPad loads directly" — this sidesteps porting trie-walk code entirely and turns a genuine engineering project into an offline data-pipeline step, at the cost of losing the format's on-disk compression (which matters less once you control your own in-memory representation anyway, e.g. via marisa-trie).

**Verdict:** this is the strongest OSS candidate for "prediction that actually predicts the next word," at real but bounded (data-pipeline, not decoder-porting) engineering cost, with a data-license footnote to route through legal/compliance rather than a code-license blocker.

### 4. KeyboardKit open core

**License [HIGH]:** MIT, confirmed from the repo's own README. **But the free tier's autocomplete surface is architecture only** — protocols and an `autocomplete:` configuration slot you can plug a *custom* implementation into, not a shipped word-prediction engine. The README's own framing draws the line explicitly: KeyboardKit Pro is what "unlocks... autocomplete" as a real feature; the base library's role is the integration harness. Concretely: adopting free KeyboardKit buys you zero prediction quality by itself — you'd still be writing (or licensing) the actual engine, just inside their component model instead of your own. Not excluded from the shortlist for license reasons; excluded because **there's no OSS engine to evaluate here**, only a paid one already covered in the sibling doc.

### 5. FUTO Swipe / ContextLM — the license nuance the prior pass got wrong

The sibling technical-feasibility doc characterized "FUTO Swipe (MIT) — ... code and trained weights are MIT-licensed" [flagged MED there]. This pass fetched the actual license files directly and that characterization needs correcting — the truth is **three separate licenses on three separate artifacts**:

1. **Training dataset** (1M+ anonymized swipe gestures, `futo-org/swipe.futo.org` on HuggingFace) — genuinely **MIT** [HIGH]. Irrelevant to us directly (we're not training our own swipe model), but confirms the prior doc wasn't wrong about *everything*.
2. **Model weights** (`futo-org/futo-swipe` on HuggingFace: a 635K-param spatial encoder, 300K-param QWERTY decoder, 1.5M-param English ContextLM) — **FUTO Model Weights License 1.0**, a *custom* license, **not MIT** [HIGH, fetched directly]. Its actual terms are more permissive than the name suggests: commercial use is explicitly allowed ("a non-exclusive, royalty-free, worldwide... license to use, copy, distribute, make available, and prepare Derivative Models of the Weights for any purpose"), modification is allowed, and redistribution inside a closed-source app is allowed — **conditioned on** (a) a visible end-user attribution notice ("powered by FUTO Swipe"), (b) passing the same license terms to anyone you redistribute a derivative model to, and (c) a **patent-peace clause**: if you ever assert a patent claim against the Weights, your license terminates immediately. This is structurally similar in spirit to Meta's Llama community license — source-available-with-conditions, not OSI-open, but genuinely commercially usable if the attribution and patent-peace terms are acceptable.
3. **Reference inference/decoding library** (`swipe-library`, hosted at `gitlab.futo.org/keyboard/swipe-library` — the actual C++ code that runs trie-constrained beam search over the model outputs to produce ranked word candidates) — **GPL** [MED-HIGH, one independent source; not independently re-verified against the raw LICENSE file in the gitlab.futo.org repo in this pass, so treat as MED rather than HIGH and re-check before any commitment]. This is the piece that's actually disqualifying for direct adoption: **the license that would matter most for a "just link the library" plan is the one that's GPL.**

**Net verdict:** the *weights* are plausibly usable standalone (attribution + patent-peace terms are a business decision, not a legal blocker), but the *only public reference implementation of how to actually consume them* — the beam search / trie-constrained decoding logic — is GPL and cannot be linked into NumPad. Using this candidate at all means **reimplementing the decoder from FUTO's own arXiv paper (2606.25247) as a clean-room implementation**, using only the paper's described architecture and the separately-licensed weights, never touching the GPL repo's code. That's a real, non-trivial engineering cost for a payoff that's narrower than it first looks: this is a **swipe-gesture decoder + a 1.5M-param context re-ranker**, not a general next-word prediction engine for tap-typing. It's the strongest available proof that a sub-2M-parameter model can do *something* useful in this memory class (relevant precedent for candidate #8's ceiling math), but it is not itself a drop-in "prediction engine" for NumPad's actual use case unless NumPad grows swipe-to-type — which the sibling doc already flags as a separate, patent-live decision (Cerence v. Apple, ongoing).

### 6. Presage

**License [HIGH]:** GPLv2, confirmed directly from the project's own README/SourceForge listing ("Presage is free software distributed under the term of the General Public License... GNU General Public License version 2.0"). Disqualifying per the license-first framework, full stop — no amount of quality justifies further evaluation. Also, independently, the project shows no evidence of active maintenance for mobile/iOS in this pass — even absent the license issue, it's a 2000s-era desktop-era engine with no modern precedent for this use case.

### 7. Mozilla DeepSpeech (and the "text models" framing generally)

**Status [HIGH]:** formally discontinued by Mozilla in June 2025; the GitHub repo is archived and read-only; the last tagged release was 0.9.3 in December 2020 with no git activity since 2021. License (MPL-2.0) would actually be *fine* under the license-first framework — this is disqualified for an entirely different reason: **DeepSpeech is an automatic-speech-recognition (speech-to-text) engine, not a predictive-text/autocorrect engine.** It answers "what did the user say," not "what word comes next after what the user typed." Even setting aside abandonment, it's the wrong tool category for this task, and Apple's own microphone block (sibling doc §1) means a keyboard extension can't feed it audio anyway. Community successors (Coqui STT — also since ceased maintenance in early 2024; Whisper; Vosk) are all in the same wrong category for this specific decision.

### 8. llama.cpp + a tiny general-purpose LM

**License [HIGH]:** llama.cpp itself (`ggml-org/llama.cpp`) is MIT — no code-license blocker at all. **The blocker is pure memory arithmetic, not licensing:**

- The smallest *broadly capable* small language models available today (SmolLM2-135M, MobileLLM-125M class, per current small-model surveys) sit around 125–135M parameters.
- At 4-bit quantization (a realistic floor for acceptable quality — going lower trades further into quality most users would notice), that's roughly **65–70MB for weights alone** — before the tokenizer/vocabulary tables, KV-cache for context, GGUF/llama.cpp runtime overhead, and everything else NumPad's own process already needs (UIKit, theme assets, the rest of the extension's runtime).
- That single number is already at or above the **entire** ~50–70MB Jetsam ceiling the sibling doc documents — meaning this isn't "tight," it's "doesn't fit," for anything in the current generation of general-purpose small LMs.
- Tokens/sec is genuinely a non-issue for this use case even if the memory problem were solved: next-word prediction needs exactly **one forward pass per keystroke or per completed word**, not a multi-token generation loop, so even modest on-device CPU throughput (llama.cpp benchmarks on iPhone-class hardware report meaningfully higher tok/sec on models 100–1000× smaller than the 7B-class models most public benchmarks target) would feel instant. The problem is entirely "can the weights be resident at all," not "is inference fast enough once resident."
- The one public precedent for a model small enough to plausibly fit is FUTO's 1.5M-parameter ContextLM (candidate #5) — two orders of magnitude smaller than SmolLM2/MobileLLM, and purpose-narrowed to re-ranking swipe candidates rather than general next-word prediction. There is no public general-purpose LM at that parameter count with comparable quality found in this research pass.

**Verdict:** not viable today at any acceptable model size/quality tradeoff. Worth re-checking in 6–12 months as sub-20M-parameter general LMs mature, but not worth spiking now.

---

## Test harness design

The goal is to answer, empirically and before committing to any one engine: **does OSS prediction beat the free floor enough to justify the engineering cost, and by how much?** Two complementary pieces — an offline evaluation corpus that's fast to iterate on and doesn't require a build, and an in-extension switcher for real feel-testing once a candidate clears the offline bar.

### A. Offline evaluation corpus (no device needed)

1. **Ground-truth vocabulary + frequency**: reuse SymSpell's bundled `frequency_dictionary_en_82_765.txt` as the baseline unigram frequency table — it's MIT, already scoped to exactly the "real English word + frequency rank" shape this needs, and gives every candidate a shared, licensed-for-our-use reference vocabulary to score against.
2. **Typo injection**: two sources, combined —
   - **GitHub Typo Corpus** [confirmed public dataset, 350K+ real typo/correction edit pairs across 15+ languages, from actual commits] as the *real-world* typo distribution (not synthetic noise).
   - A **programmatic QWERTY-adjacency + Damerau-Levenshtein noise generator** (insert/delete/transpose/substitute at edit distance 1–2, weighting substitutions toward physically adjacent keys) replayed against clean sentences from a permissively-licensed sentence corpus (e.g., Tatoeba's CC-BY sentence pairs) — this gives volume and reproducibility the real-typo corpus alone can't (350K edits is a good sample, not enough for exhaustive per-candidate regression testing).
   Together these produce a repeatable `(typed_token, intended_token, sentence_context)` triple set that every candidate is scored against identically.
3. **Metrics** (computed per candidate, per corpus pass):
   - **Autocorrect precision/recall**: did the candidate's top-1 (and top-3) correction match ground truth, split by edit distance (1 vs 2) and by whether the typo was keyboard-adjacent vs random.
   - **Next-word hit-rate@1 / hit-rate@3** and **keystroke-savings-rate (KSR)** — the standard word-prediction metric (percentage reduction in keystrokes a user would need if they always accepted the top suggestion when correct) — computed by holding out the final word of each corpus sentence and checking whether it appears in the candidate's ranked suggestion list.
   - **Latency**: p50/p95 wall-clock per correction/prediction call, measured in isolation (no device needed for a first pass — Instruments/on-device profiling comes in phase B).
   - **Memory delta**: peak resident-set-size increase versus a bare `UITextChecker`-only baseline, measured via a standalone harness binary before ever touching the extension target.
   - **Control arm**: `UITextChecker.completions(forPartialWordRange:)` / `guesses(forWordRange:)` run through the identical corpus and identical metrics — this *is* the free floor every OSS candidate must beat, not a theoretical baseline.

### B. In-extension DEBUG-flag switcher (real feel-testing)

Reuse the exact pattern already shipping in this codebase (`FeatureFlags`, DEBUG/TestFlight-gated, surfaced in Store → Beta section, with the same Remote Config kill-switch precedent as `customKeyboardDragReorderEnabled`):

- Add `FeatureFlags.predictionEngine`: an enum-backed flag (`.systemFloor`, `.symSpellAutocorrect`, `.aospNgram`, …) rather than a bool, so testers can switch which engine is live without a rebuild, in the same overlay UI slot each time (keep the suggestion-bar UI identical across arms so testers are comparing engines, not UI).
- Since **the keyboard extension never logs analytics** (per this codebase's own documented constraint — Firebase isn't even linked into the Keyboard target), accept/reject/edit-after-accept telemetry can't be captured in-process the way the rest of the app captures events. Two workable options, neither requiring new cross-process plumbing beyond what already exists: (a) write lightweight counters to `UserDefaults.group` keyed by engine + outcome, and have the **app** (which already logs analytics) read and flush them on next launch — mirrors the existing pattern of the app being the analytics-authoritative side; or (b) for a first pass, skip automated telemetry entirely and rely on a short structured TestFlight feedback form per build (fewer moving parts, faster to ship for a decision this exploratory).
- Kill switch: same two-layer pattern as drag-reorder — local `FeatureFlags` toggle for the DEBUG/TestFlight population, plus a Remote Config key if/when any candidate is promoted past internal testing, so a bad engine choice in the field is a remote flip, not a re-submission.

### C. Decision thresholds — what has to be true to ship

These are proposed judgment calls to make explicit and pre-register before looking at results, not values derived from an external benchmark — flag as **[LOW confidence, deliberately a policy choice]**:

- **Quality gate**: a candidate must beat `UITextChecker`'s corpus score by a clear, pre-registered margin — proposed as **+15 percentage points absolute top-1 hit-rate** (next-word) or an equivalent KSR gain — before it's worth building into the extension at all. A candidate that beats the floor by 2–3pp isn't worth the memory/engineering spend regardless of how technically interesting it is.
- **Memory gate**: a **hard** ceiling of the candidate's own footprint, not a soft target — proposed as **≤15MB resident delta** above NumPad's current baseline, measured on-device via Jetsam reports (not simulator, per the sibling doc's own caution that this is a per-process, no-graceful-degrade limit), leaving real margin under the ~50–70MB ceiling for the rest of the app's runtime and future growth. Any candidate that can't hit this without heroics is out regardless of quality score.
- **Latency gate**: p95 added latency per keystroke low enough not to visibly lag typing — proposed as **≤16ms** (one frame at 60fps) for autocorrect-as-you-type, more slack (≤50–100ms) acceptable for a next-word suggestion bar that updates on word-boundary rather than every keystroke.
- **License gate (hard, non-negotiable)**: no GPL/AGPL code enters the shipped binary under any circumstance, regardless of how the other three gates score. This is a gate, not a threshold — it eliminated Presage and the FUTO reference decoder outright in this pass without needing any quality data at all.

---

## Recommendation

**Run the offline harness (A) first, cheaply, before writing any Swift.** It requires no device time and immediately produces the one number that matters most: does `UITextChecker` alone already clear a "good enough, ship nothing extra" bar, or is there real daylight for an OSS engine to close? Score AOSP's dictionary+bigram data (candidate #3) and SymSpell (#2) against the same corpus and control arm. If either clears the +15pp quality gate on paper, only then invest in the Swift port and move to the in-extension switcher (B) for real feel-testing against the memory and latency gates on-device. Skip FUTO Swipe/ContextLM (#5) and llama.cpp-class tiny LMs (#8) entirely for this decision cycle — both require disproportionate engineering (clean-room reimplementation; or simply don't fit in memory) for payoffs that are either narrow (swipe-only) or currently mathematically infeasible. Presage (#6) and DeepSpeech (#7) need no further evaluation time at all — one is license-disqualified, the other is both dead and the wrong category.

---

## Sources

- [SymSpell — GitHub (wolfgarbe/SymSpell)](https://github.com/wolfgarbe/SymSpell) / [README](https://github.com/wolfgarbe/SymSpell/blob/master/README.md)
- [marisa-trie — GitHub (s-yata/marisa-trie)](https://github.com/s-yata/marisa-trie) / [COPYING.md](https://github.com/s-yata/marisa-trie/blob/master/COPYING.md)
- [AOSP dictionary-tools — florisboard/dictionary-tools](https://github.com/florisboard/dictionary-tools) / [README](https://github.com/florisboard/dictionary-tools/blob/main/README.md)
- [Helium314/aosp-dictionaries — Codeberg](https://codeberg.org/Helium314/aosp-dictionaries)
- [FlorisBoard — GitHub](https://github.com/florisboard/florisboard) (Apache-2.0)
- [KeyboardKit — GitHub](https://github.com/KeyboardKit/KeyboardKit) / [README](https://github.com/KeyboardKit/KeyboardKit/blob/master/README.md)
- [KeyboardKitPro — GitHub](https://github.com/KeyboardKit/KeyboardKitPro)
- [FUTO Swipe — Hugging Face model card](https://huggingface.co/futo-org/futo-swipe) / [LICENSE.md](https://huggingface.co/futo-org/futo-swipe/blob/main/LICENSE.md) / [training dataset](https://huggingface.co/datasets/futo-org/swipe.futo.org)
- [FUTO Swipe: Layout-Agnostic Neural Swipe Decoding — arXiv 2606.25247](https://arxiv.org/abs/2606.25247v1)
- [swipe-library — gitlab.futo.org/keyboard/swipe-library](https://gitlab.futo.org/keyboard/swipe-library)
- [FUTO android-keyboard — GitHub](https://github.com/futo-org/android-keyboard) / [FUTO Source First License 1.1](https://raw.githubusercontent.com/futo-org/android-keyboard/refs/heads/master/LICENSE.md) / [FSF's nonfree characterization — GNU license list](https://www.gnu.org/licenses/license-list.en.html)
- [Presage — GitHub mirror (Manouchehri/presage)](https://github.com/Manouchehri/presage) / [Presage — SourceForge](https://sourceforge.net/projects/presage/) / [Free Software Directory entry](https://directory.fsf.org/wiki/Presage)
- [Mozilla DeepSpeech — GitHub (archived)](https://github.com/mozilla/DeepSpeech) / [Mozilla Formally Discontinues Its DeepSpeech Project — Phoronix](https://www.phoronix.com/news/Mozilla-DeepSpeech-Discontinued) / [Top open-source STT options 2026 — AssemblyAI](https://www.assemblyai.com/blog/top-open-source-stt-options-for-voice-applications)
- [llama.cpp — GitHub (ggml-org/llama.cpp)](https://github.com/ggml-org/llama.cpp) (MIT) / [llama.cpp — Wikipedia](https://en.wikipedia.org/wiki/llama.cpp)
- [Best Small Language Models on Hugging Face — KDnuggets](https://www.kdnuggets.com/best-small-language-models-on-hugging-face-right-now)
- [GitHub Typo Corpus — arXiv 1911.12893](https://arxiv.org/abs/1911.12893) / [ACL Anthology](https://aclanthology.org/2020.lrec-1.835/)
- [Evaluating Word Prediction: Framing Keystroke Savings — ResearchGate](https://www.researchgate.net/publication/220874693_Evaluating_Word_Prediction_Framing_Keystroke_Savings)
- [UITextChecker — NSHipster](https://nshipster.com/uitextchecker/)
- Sibling doc (this project, read for cross-reference, not re-derived): `docs/plans/full-keyboard/2026-07-05-technical-feasibility.md` §1–2 (platform limits, `UITextChecker`/`UILexicon` control detail, KeyboardKit/Fleksy pricing, swipe patent risk)
- NumPad codebase (read-only, for the DEBUG-flag switcher design): `CLAUDE.md` (`FeatureFlags`, `SettingsSync`, Analytics-not-linked-in-Keyboard-target constraint), existing `customKeyboardDragReorderEnabled` kill-switch precedent
