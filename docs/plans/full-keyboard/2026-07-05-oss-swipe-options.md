# Open-Source Swipe/Gesture-Typing Implementations for a Closed-Source Commercial iOS Keyboard

**Date:** 2026-07-05

> **Legal-gate correction (2026-08-04):** this doc's patent-status lines (US 7,706,616,
> expiry 2026-12-21) are historical record from this research date. That patent is not the one
> asserted in Cerence v. Apple; the swipe/glide gate is a **written FTO opinion covering the
> Cerence keyboard patent family** — no date. §6.3's family-review framing is the anchor;
> see `2026-08-04-glide-legal-gate.md`.

**Scope:** Research only — no code changes. Surveys existing open-source swipe/gesture-typing
implementations to determine whether any is legally and technically usable inside NumPad, a
**proprietary, closed-source, paid App Store app**. License compatibility is the gate, evaluated
*before* quality for every candidate. This document is a companion to
`docs/plans/full-keyboard/2026-07-05-technical-feasibility.md` §3, which covers the same topic at
a higher level (patent landscape, buildability) — this doc goes one level deeper into "which
existing OSS code could you actually start from," and adds one material finding that document
didn't have: a **second, currently-active** Cerence-owned gesture-typing patent (see §5).

## Confidence legend

- **[HIGH]** — confirmed directly against a license file, a patent office record, or an official
  project page in this pass.
- **[MED]** — corroborated by multiple independent secondary sources but not pinned to a primary
  document.
- **[LOW]** — single source, inference, or an unconfirmed claim. Treat as a hypothesis.

## The gate, restated

We ship proprietary, closed-source. For a dependency to be *linkable* into that binary:

- **Usable:** MIT, Apache-2.0, BSD (2/3-clause), MPL-2.0 (file-level copyleft only — fine as long
  as you don't modify MPL files and can keep them in separate files), CC0.
- **Disqualifying for linking:** GPL (any version), AGPL, SSPL, and FUTO-style "source-first"
  licenses (non-commercial-only grants that require a separate negotiated commercial license).
  This is true regardless of code quality — a GPL-licensed gesture decoder cannot be statically or
  dynamically linked into NumPad's binary and shipped on the App Store without relicensing the
  entire keyboard extension under GPL, which is not something a paid, closed-source app can do.
- **Apache-2.0's patent grant is not a shield against third parties.** Apache-2.0 §3 grants you a
  patent license only from *that project's contributors*, covering *their own* contributions. It
  does nothing against an unrelated outside patent holder — like Cerence — asserting a patent over
  the general technique the code implements. This matters directly below: two of the license-clean
  candidates (FlorisBoard, AnySoftKeyboard) sit in exactly that exposed position.

---

## 1. Candidate-by-candidate verdicts

| Candidate | License verdict | Language / port cost to Swift | Quality signal | Maintenance |
|---|---|---|---|---|
| **FUTO Keyboard** (android-keyboard repo) | **DISQUALIFYING** — FUTO Source First License 1.1-kb, non-commercial only | Kotlin | N/A (license kills it) | Active |
| **FUTO Swipe — models** (Encoder/ContextLM/Decoder weights) | **DISQUALIFYING** — "FUTO Model License," commercial use not granted | N/A | High (purpose-built for tiny memory budgets) | Active |
| **FUTO Swipe — inference library** (C++ decoder/beam search) | **DISQUALIFYING** — GPL | C++ (would otherwise be the easiest port — C++ bridges to Swift cleanly) | High | Active |
| **FUTO Swipe — 1M-swipe dataset** | **USABLE** — MIT | N/A, it's training data, not code | N/A | Released once (Mar 2025), static |
| **FlorisBoard** (glide typing) | **USABLE license** — Apache-2.0 | Kotlin, algorithmic (not neural) — real but bounded port | Mediocre — user reports call it "rough," trailing Gboard/SwiftKey | Active, beta, restructuring in 2026 |
| **AnySoftKeyboard** (gesture typing) | **USABLE license** — Apache-2.0 | Java, corner-matching algorithm — real but bounded port | Mediocre-to-poor — recurring user complaints about missed words | Active but slow-moving |
| **OpenBoard** | **DISQUALIFYING** — GPL-3.0 | Java (AOSP-derived) | N/A — no swipe support at all (AOSP shell has none, see §3) | **Dead** — no commits since Dec 2022 |
| **HeliBoard** (OpenBoard fork) | **DISQUALIFYING** — GPL-3.0 | Kotlin/Java | N/A for OSS swipe — ships *no* OSS decoder; optionally loads Google's proprietary binary (see §3) | Active; building a from-scratch OSS decoder (§4), not ready |
| **AOSP LatinIME "Apache 2.0 gesture code"** | **N/A — doesn't exist** | — | — | The Apache-licensed shell has no gesture decoder; see §3 |
| **SHARK2 / ShapeWriter** (academic algorithm) | **N/A, no shippable code** — original authors' reference implementation was never released as installable OSS; the *concept* underlies FlorisBoard/AnySoftKeyboard's algorithms | Algorithm description only (2004 paper) | Foundational, credible | Dormant (2004-era); **patents active/recently-expired, see §5** |
| **Gesture2Text** (Meta Reality Labs, 2024) | **N/A, no code released** | — | Best published accuracy numbers found (83.3% top-1 in XR test) | Research paper only, no repo found |
| **CleverKeys / CleverKeys-ML** (tribixbite) | **DISQUALIFYING** — GPL-3.0 | Python (training) + Kotlin/Android (app), transformer encoder-decoder | Credible — trained on FUTO's MIT dataset, "auditable" per its own docs | Active |
| **iSwipe** (iOS, pre-iOS 8) | **DISQUALIFYING** — GPL-3.0 | Objective-C, runtime-hooking tweak | Real decoder (dynamic-programming + greedy path matching) but built against a jailbreak-era hooking API that no longer applies to modern extensions | **Dead** — targets iOS <8 |
| **JustType** (iOS) | Usable license (CC0) but **wrong feature** — word-jump navigation swipes, not gesture-to-word decoding | Swift | N/A — doesn't do what we need | Unclear |
| **Fleksy / KeyboardKit** | Commercial SDKs, not OSS — out of scope here, covered in the companion technical-feasibility doc §2–3 | — | — | — |

---

## 2. FUTO in detail — why the earlier "MIT" read needs correcting

The companion technical-feasibility doc (§2, §3) characterized "FUTO Swipe (MIT)" as the standout
open option. That's **only true of one piece of it** — worth stating plainly since it changes the
practical conclusion:

Per FUTO's own site (`swipe.futo.tech`) and the `android-keyboard` repo's `LICENSE.md` **[HIGH]**:

| Component | License | Commercial use? |
|---|---|---|
| 1M-swipe dataset (HuggingFace, released Mar 2025) | **MIT** | Yes |
| Encoder/ContextLM/Decoder model weights | **FUTO Model License** | No (non-commercial grant; FUTO retains the right to negotiate separately) |
| C++ inference library (decoding + beam search) | **GPL** | No (viral copyleft — can't link into a closed binary) |
| FUTO Keyboard app itself | **FUTO Source First License 1.1-kb** | No — "You may modify the software only for non-commercial purposes"; distribution must be "free of charge for non-commercial purposes" |

So the code you'd actually need to run inference — the GPL C++ library — and the trained weights
that make it useful — the FUTO Model License — are **both disqualifying**. The only piece that
clears the gate is the **dataset**. That's still meaningfully useful: it means "train your own
model from scratch on FUTO's MIT-licensed 1M-swipe corpus, write your own from-scratch inference
code" is a legitimate, license-clean path — it's just a from-scratch ML project, not "adopt FUTO
Swipe." **CleverKeys (tribixbite)** is direct proof this works in practice — an independent
transformer-based swipe decoder trained on that same dataset, described as "fully reproducible and
auditable" — but CleverKeys itself ships as **GPL-3.0**, so its trained weights and code aren't
directly reusable either; it demonstrates the dataset is sufficient to build a real model, not that
there's a shortcut around doing so yourself.

---

## 3. AOSP LatinIME — confirmed dead end, and confirmed by two independent sources

The task's suspicion here was correct. AOSP's `packages/inputmethods/LatinIME` Java/resource layer
is genuinely Apache-2.0, and it does contain a gesture-input feature *flag*
(`gesture-input.xml`) — but the actual trajectory-to-word decoder has never been open-sourced. It
ships only as a prebuilt proprietary binary, `libjni_latinimegoogle.so`, distributed inside
Google's closed GApps package (informally called "swypelibs") **[MED-HIGH, multiple independent
XDA/technical sources describing the same binary and file name]**.

Independent confirmation: **HeliBoard** — a currently-maintained, fully-open (GPL-3.0) AOSP-derived
keyboard with no commercial constraints on using proprietary interop — *still* has no OSS gesture
decoder of its own. Its documented workaround is to have the user manually extract and load that
exact same `libjni_latinimegoogle.so` file from GApps or the OpenBoard repo's mirror of it
(Settings → Advanced → "Load Gesture Typing Library") **[HIGH, HeliBoard's own wiki/FAQ]**. If a
GPL-licensed, community-maintained fork with zero commercial-use restriction still can't avoid
depending on Google's closed binary for this feature, that's strong corroboration the Apache-2.0
AOSP tree genuinely contains no usable decoder — it's not a licensing quirk blocking access to code
that exists, the code itself was simply never released.

The one thing genuinely in motion here: HeliBoard is the beneficiary of an **NLnet/NGI Mobifree
grant** (started June 2025) explicitly to build "a well working and completely open-source
implementation of gesture typing" as a drop-in replacement for that same proprietary binary
**[MED]**. As of this pass it shipped a "4.0-alpha2" in June 2026 and is still in an active
training-data-collection phase (collection window stated to run through November 30, 2026) — i.e.,
**pre-alpha for the actual decoder, not something to build on today**. Its target license isn't
stated on the project page, but given it's funded to replace a component of a GPL-3.0 project and
developed by the same maintainers, a GPL/LGPL outcome should be the working assumption until
proven otherwise. Android/Linux-only scope was stated; no iOS mention anywhere in the project's own
materials. **Recommendation: watch, don't build on.**

---

## 4. FlorisBoard and AnySoftKeyboard — the two genuinely license-clean candidates, and why they're still a hard sell

Both clear the license gate outright (Apache-2.0, no share-alike, no commercial restriction, no
GPL entanglement in the gesture-typing code itself as far as this research could determine).
Neither is a good foundation in practice, for three independent reasons:

1. **Quality.** Both use classical algorithmic decoders — geometric corner-matching
   (AnySoftKeyboard's `GestureTypingDetector`/`SimpleGestureTypingDetector`, which reduces a
   swiped path to a sequence of >170°-angle corners and matches it against per-word key-center
   paths) or a similar statistical/shape-matching approach in FlorisBoard's
   `GlideTypingClassifier`/`GlideTypingManager`. Both get real, repeated user complaints about
   missed/wrong words in production use, and both are explicitly described by their own user
   communities as behind Gboard/SwiftKey **[MED, multiple independent user reports/reviews for
   both projects]**. An unmerged AnySoftKeyboard PR (#1870, opened 2019, still open as of this
   pass) proposes a more sophisticated Gaussian-probability template-matching replacement — a sign
   the maintainers themselves consider the shipped algorithm under-baked, four-plus years later.
2. **Port cost.** Both are JVM-language (Kotlin/Java) implementations with no existing Swift or
   even C/C++ intermediate form. This is "port the algorithm," not "recompile a library" — real,
   non-trivial engineering work with no shortcut, unlike (say) a C++ library that could bridge into
   Swift directly.
3. **Patent exposure specifically attaches to *this* category of algorithm** — see §5. This is the
   part the license check alone doesn't catch.

---

## 5. Patent overlay, restated — and one material addition

Per `docs/plans/full-keyboard/2026-07-05-technical-feasibility.md` §3 **[carried forward, HIGH
confidence on the facts, LOW on eventual legal outcome]**: open-source code does not immunize
against patents. Separately from copyright/license terms, the underlying *technique* of
continuous-stroke gesture-to-word decoding traces to a Swype Inc. (Cliff Kushler) patent family
(US 7,098,896 / 7,382,358 / 7,453,439, ~2003 priority) that moved Swype Inc. → Nuance (2011) →
Cerence (2019 spinoff). **Cerence filed an active patent-infringement suit against Apple in
September 2025** over Apple's own "slide to type" QuickPath feature, alleging exactly this category
of infringement; that suit remains unresolved as of this pass. Apple is the target, not any
third-party developer, but the point stands: the current rights-holder over swipe-typing IP is
actively litigating this exact feature category right now, and the fact that any individual patent
in the family is old enough to have likely expired doesn't settle the question of whether the
current implementation crosses a *different*, still-live claim.

**New finding from this pass, not in the companion doc:** the classical "algorithmic template/shape
matching" lineage — the *specific* approach both FlorisBoard and AnySoftKeyboard use — has its own,
separate patent history, and it also rolled up into Cerence:

- SHARK2 (a.k.a. SHARK / ShapeWriter), the foundational academic word-gesture-keyboard decoding
  algorithm, was developed by **Shumin Zhai and Per Ola Kristensson at IBM Research** starting
  ~2001–2003, commercialized via their company **ShapeWriter, Inc.**, which **Nuance Communications
  acquired in 2010** **[MED-HIGH, Wikipedia + Kristensson's own academic bio page, cross-checked]**.
- Two resulting patents, checked directly against Google Patents' live legal-status data
  **[HIGH — directly queried, current as of this pass]**:
  - **US 7,706,616 B2** — *"System and method for recognizing word patterns in a very large
    vocabulary based on a virtual keyboard layout"* — filed 2004-02-27, granted 2010-04-27.
    **Current assignee: Cerence Operating Company. Status: ACTIVE, expires 2026-12-21** (historical
    — per the 2026-08-04 correction above, this expiry is not the gate) — i.e., still live for
    roughly five more months as of this research date.
  - **US 8,311,796 B2** — *"System and method for improving text input in a shorthand-on-keyboard
    interface"* — priority 2005-10-22, granted 2012-11-13. Same assignment chain (Nuance → Cerence,
    2019), through a Barclays and then Wells Fargo security interest, both since released.
    **Status: expired (fee-related) 2025-10-22** — expired only about nine months before this
    research date.
- Practical read: **Cerence's portfolio is not limited to the original Swype/Kushler claims.** It
  independently holds a second gesture-keyboard patent family from the IBM/ShapeWriter/
  Zhai-Kristensson lineage, whose title — *"recognizing word patterns... based on a virtual
  keyboard layout"* — reads, in plain English, like a description of exactly what FlorisBoard's and
  AnySoftKeyboard's corner/shape-matching decoders do. One member of that family (US 7,706,616) is
  **still active for several more months** as of this pass (historical — 2026-08-04 correction: no
  single expiry is the gate); another only expired very recently.
  This doesn't mean either OSS project actually infringes it — that's a claim-construction question
  no engineer can answer and this research didn't attempt to answer — but it means "the algorithmic
  approach is old and probably safe because it predates modern neural swipe" is **not** a
  conclusion this research can support. The same corporate patent holder that's suing Apple over
  swipe typing has, at minimum, one more live patent and one recently-expired patent covering an
  adjacent slice of the same problem space, and no check was done here for further, still-unexpired
  continuations in either family.
- Apache-2.0's contributor patent grant (§3, restated) covers nothing here — Cerence is not a
  contributor to FlorisBoard or AnySoftKeyboard.

**This does not change the recommendation in the companion doc** (treat swipe as a separately
legally-gated decision, not a v1 default) — it strengthens the case for it, and specifically extends
the gate to cover the "just clone an Apache-licensed algorithmic decoder, skip the ML" path, which
someone might otherwise have assumed was the *safer*, patent-lite alternative to a neural approach.
Per this research, it is not obviously safer — it may in fact be closer to the specific claim
language of a family with a currently-active member.

---

## 6. Ranked shortlist + recommendation

1. **Do nothing now; defer.** No candidate found here clears *both* gates (license **and** a
   patent picture clean enough to build on) at a quality bar worth shipping. The two
   license-clean options (FlorisBoard, AnySoftKeyboard) are Apache-2.0 but mediocre quality, real
   JVM→Swift port cost, and sit closer to a live/recently-live Cerence patent than the "old and
   safe" framing would suggest. The technically strongest options (FUTO Swipe, CleverKeys) are
   GPL/non-commercial and disqualified outright. Gesture2Text has no released code.
2. **If a flagged prototype happens anyway, scope it to:** (a) NumPad's own from-scratch decoder,
   trained only on FUTO's MIT-licensed 1M-swipe dataset (the one piece of the FUTO stack that's
   actually usable) with fully original inference code — not a port of any GPL/source-first FUTO
   code; or (b) a from-scratch algorithmic decoder inspired by, but not copied from, FlorisBoard/
   AnySoftKeyboard's public approach. Either path is "clean-room, informed by public research," not
   "adopt existing OSS," and neither should ship or even be built past a throwaway spike without
   legal sign-off given §5.
3. **Gate any real work behind:** (a) a real legal review of the Cerence patent family (both the
   Kushler/Swype claims and this pass's new finding — the Zhai/Kristensson/Cerence-owned
   US 7,706,616, active through Dec 2026 — historical; 2026-08-04 correction: the family FTO is
   the gate, no date), and (b) watching Cerence v. Apple to resolution. Keep
   swipe entirely behind a feature flag, off by default, no App Store submission, until both clear.
4. **Watch, don't adopt yet:** the HeliBoard/NLnet-funded open gesture-typing library — it's the
   only project actively trying to solve "genuinely open, no proprietary binary, no GPL-locked
   dependency" for gesture typing, but it's pre-alpha, Android/Linux-scoped with no iOS mention,
   and its eventual license is unconfirmed (working assumption: GPL/LGPL, given its parent
   project). Revisit in 6–12 months.
5. **Bottom line for NumPad specifically:** given NumPad's core identity is a numeric/symbol
   keyboard, not a full QWERTY replacement, this reinforces the companion doc's existing
   recommendation — swipe is a v2+, legally-gated, flag-only bet, not a v1 requirement, and "build
   it ourselves from an OSS reference" turns out to *not* meaningfully de-risk the patent question
   relative to licensing a commercial SDK (Fleksy) or building from scratch without any OSS
   reference at all.

---

## Sources

- [FUTO android-keyboard LICENSE.md](https://github.com/futo-org/android-keyboard/blob/master/LICENSE.md)
- [FUTO Swipe](https://swipe.futo.tech/) / [FUTO Swipe dataset — HuggingFace](https://huggingface.co/datasets/futo-org/swipe.futo.org) / [FUTO Swipe models — HuggingFace](https://huggingface.co/futo-org/futo-swipe) / [FUTO Swipe inference library — GitLab](https://gitlab.futo.org/keyboard/swipe-library) / [FUTO Swipe: Layout-Agnostic Neural Swipe Decoding — arXiv](https://arxiv.org/abs/2606.25247)
- [FUTO Statement on Open Source](https://www.futo.org/about/futo-statement-on-opensource/) / [HN discussion of the FUTO license](https://news.ycombinator.com/item?id=40832506)
- [FlorisBoard — GitHub](https://github.com/florisboard/florisboard) / [Issue #139: Implement gesture/glide/swipe typing](https://github.com/florisboard/florisboard/issues/139) / [PR #544: Implement gesture typing](https://github.com/florisboard/florisboard/pull/544) / [FlorisBoard Long-Term Review — Factually](https://factually.co/product-reviews/electronics-tech/florisboard-long-term-review-glide-typing-prediction-progress-40ef0a)
- [AnySoftKeyboard — GitHub](https://github.com/AnySoftKeyboard/AnySoftKeyboard) / [LICENSE](https://github.com/AnySoftKeyboard/AnySoftKeyboard/blob/main/LICENSE) / [PR #1870: Gesture typing AI](https://github.com/AnySoftKeyboard/AnySoftKeyboard/pull/1870) / [Issue #3749: swipe issues](https://github.com/AnySoftKeyboard/AnySoftKeyboard/issues/3749)
- [OpenBoard — GitHub](https://github.com/openboard-team/openboard) / [OpenBoard — Wikipedia](https://en.wikipedia.org/wiki/OpenBoard_(keyboard))
- [HeliBoard — GitHub](https://github.com/HeliBorg/HeliBoard) / [HeliBoard FAQ — gesture library loading](https://github.com/HeliBorg/HeliBoard/wiki/FAQ) / [NLnet: Gesture Typing for AOSP-derived Keyboards](https://nlnet.nl/project/GestureTyping/)
- [Enable Gesture Typing/Swype on AOSP Keyboard — Gist](https://gist.github.com/EmberHeartshine/0109248c8f76c67f742f67e7e78ded4a) (documents the proprietary `libjni_latinimegoogle.so` dependency)
- [ShapeWriter — Wikipedia](https://en.wikipedia.org/wiki/ShapeWriter) / [Per Ola Kristensson: ShapeWriter and Gesture Keyboards](http://pokristensson.com/gesturekeyboard.html) / [SHARK2 — IBM Research](https://research.ibm.com/publications/sharklesssupgreater2lesssupgreatera-large-vocabulary-shorthand-writing-system-for-pen-based-computers)
- [US 7,706,616 B2 — Google Patents](https://patents.google.com/patent/US7706616B2/en)
- [US 8,311,796 B2 — Google Patents](https://patents.google.com/patent/US8311796B2/en)
- [Gesture2Text: A Generalizable Decoder for Word-Gesture Keyboards in XR — arXiv](https://arxiv.org/abs/2410.18099)
- [CleverKeys — GitHub](https://github.com/tribixbite/CleverKeys) / [LICENSE (GPL-3.0)](https://github.com/tribixbite/CleverKeys/blob/main/LICENSE) / [CleverKeys-ML](https://github.com/tribixbite/CleverKeys-ML)
- [iSwipe — GitHub](https://github.com/akemin-dayo/iSwipe)
- [JustType — GitHub](https://github.com/tonqa/JustType)
- Cerence v. Apple, Cerence patent portfolio, and the original Swype/Kushler patent family: carried forward from `docs/plans/full-keyboard/2026-07-05-technical-feasibility.md` §3 (sources listed there).
