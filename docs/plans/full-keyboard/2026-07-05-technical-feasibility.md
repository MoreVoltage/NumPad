# Full-Keyboard Technical Feasibility: What a Third-Party iOS Keyboard Can and Can't Replicate (iOS 18/26)

**Date:** 2026-07-05
**Scope:** Research only — no code changes. Answers what NumPad would be signing up for if it grew a full QWERTY typing mode (autocorrect, prediction, swipe) alongside the numpad, and which engine to build it on.

## Confidence legend

- **[HIGH]** — confirmed by Apple's own documentation/security guide, official API docs, or directly observed in NumPad's own shipped code.
- **[MED]** — corroborated by multiple independent secondary sources (dev blogs, vendor docs, patent filings, press) but not independently re-verified against a live Apple doc page in this pass.
- **[LOW]** — single source, back-of-envelope estimate, or a claim that's contested/unconfirmed. Treat as a hypothesis to spike, not a fact to build on.

---

## 1. Hard platform limits

| Limit | Third-party keyboard? | Confidence | Detail |
|---|---|---|---|
| Dictation / microphone | **Blocked, categorically** | HIGH | No app extension type — keyboards included — has ever had microphone access, since iOS 8 (2014). Apple's stated rationale is that a background extension can't visibly signal "the mic is on," so it's a blanket privacy policy, not a technical gap. Nothing in iOS 18/26 changes this. |
| Secure text fields (`secureTextEntry == true`) | **Blocked** | HIGH | The system silently swaps in the stock keyboard whenever focus lands in a secure field (password entry, etc.) and swaps your keyboard back the moment focus leaves it. You never see keystrokes typed there. |
| Phone-pad fields (`UIKeyboardTypePhonePad` / `NamePhonePad`) | **Blocked** | HIGH | Same swap-out behavior as secure fields — e.g. the Contacts phone-number field. |
| Globe / "next keyboard" key | **Required, self-provided** | HIGH | You must supply your own button and call `advanceToNextInputMode()`. `needsInputModeSwitchKey` tells you whether the system expects you to be showing one at all (it's sometimes provided by the host UI instead). |
| Long-press globe → "choose keyboard" list | **Fully achievable** | HIGH | Contrary to the common claim that this can't be replicated, `UIInputViewController.handleInputModeList(from:with:)` hands you the *exact* system menu — wire it to a long-press recognizer on your own globe key and you get pixel-identical behavior for free. |
| Inline QuickType suggestion bar / inline ghost-text | **Not shared with you** | HIGH | The system's predictive bar and inline-prediction surface belong to the system keyboard only. A third-party keyboard gets zero space in that UI — any suggestion strip, ghost text, or predictive bar has to be drawn inside your own input view, competing with your own key rows for vertical space. |
| Key-press callout / magnified letter popup | **Can't draw above your own top edge** | HIGH | Apple's Custom Keyboard guide states directly that you cannot draw key artwork above the top edge of your primary view the way the system keyboard does on long-press. Frameworks like KeyboardKit fake a similar effect *within* your own bounds (an overlay bubble that stays inside the extension's frame), but the literal "pops up above the keys" effect is off-limits. |
| Memory ceiling | **~50–70MB, enforced by Jetsam, no graceful degrade** | HIGH | NumPad's own `CLAUDE.md` documents this as "~50MB." Independent Jetsam-report data puts it at 66MB on an iPhone XS Max-class device. This is *per process*, well below a container app's multi-GB budget, and the extension is simply killed if it's exceeded — there's no soft warning to catch. NumPad is already living inside this ceiling today; any new engine has to fit in the *remaining* headroom, not the whole budget. |
| Text selection / edit menu (cut/copy/paste UI) | **Not available** | HIGH | Selection is owned by the host app; you can insert/delete text via `UITextDocumentProxy` but cannot present a native selection/edit menu. |
| Access to Settings → Keyboard system options (auto-cap toggle, caps-lock toggle, dictionary reset) | **Not available** | HIGH | You can only mirror these via your own in-app settings bundle/screen — you cannot read or drive the system's own toggles. |

### Full Access — what genuinely needs it

Apple's default keyboard sandbox blocks network access and anything that could exfiltrate keystrokes. `RequestsOpenAccess` (Full Access) lifts that. Concretely, **[HIGH]** confidence, cross-checked against NumPad's own code:

- **Haptics** — genuinely require Full Access. `UIImpactFeedbackGenerator` is a **silent no-op** without it (confirmed on Apple's own developer forums, and matches NumPad's `Button.swift` comment: *"Whether the keyboard has Full Access. Haptics in a keyboard extension are a silent no-op"* without it — `Button.isFullAccessAvailable` gates `hapticsActive` directly).
- **Key click sound** — `UIDevice.playInputClick()` requires Full Access. NumPad's `KeyboardViewController.swift` already guards this call behind `hasFullAccess`.
- **Network / cloud sync / iCloud / Game Center / In-App Purchase** — require Full Access (this is why NumPad's iCloud sync and any server-side feature are Full-Access-gated).
- **Shared pasteboard / clipboard reads, Address Book, Camera Roll, Location Services** — all require Full Access. NumPad's clipboard-history overlay is gated on `hasFullAccess` for exactly this reason.
- **`UITextChecker` (system spell-check/completions) and `requestSupplementaryLexicon()`** — **do NOT require Full Access [MED]**. Both are local, on-device system APIs with no network or shared-container dependency, and multiple independent developer guides describe them as available in the default sandbox. This matters directly for the autocorrect discussion below: a baseline autocorrect/lexicon layer is available to *every* keyboard, Full Access or not.

### The text-replacement surprise

The prompt's assumption was that reading the user's system Text Replacement shortcuts (Settings → General → Keyboard → Text Replacement) is "almost certainly not" possible. Research says **the opposite is more likely true, with caveats [MED]**: `UIInputViewController.requestSupplementaryLexicon(completion:)` returns a `UILexicon` object that, per Apple's own older App Extension Programming Guide language (repeated verbatim across several independent developer tutorials), contains *"words from... unpaired first and last names from the user's Address Book"* **and** *"text shortcuts defined in the Settings → General → Keyboard → Shortcuts list"* — which is the pre-rename name for today's Text Replacement feature. Each `UILexiconEntry` exposes a `userInput` (the shortcut, e.g. "omw") and a `documentText` (the expansion, e.g. "On my way!"). This does **not** require Full Access.

I could not re-confirm the current wording verbatim on Apple's live documentation page in this pass (the fetch returned only the page shell), so this is flagged MED rather than HIGH — **recommend a 30-minute spike**: register a test Text Replacement shortcut on a real device, call `requestSupplementaryLexicon` from a bare extension, and confirm it shows up before relying on it in a shipped feature. If it holds, it's a genuinely nice inversion of the common assumption — free, sandboxed access to a piece of the user's personalization data most developers assume is locked away.

---

## 2. Autocorrect / prediction engine options, ranked

| Option | Cost | Effort | On-device? | Quality ceiling | Confidence |
|---|---|---|---|---|---|
| `UITextChecker` (system) | Free | Low | Yes | Spell-check tier only | MED |
| `UILexicon` / `requestSupplementaryLexicon` | Free | Low | Yes | Contacts + text-replacement assist only, not prediction | MED |
| Build your own frequency/n-gram engine | Free (eng. time) | High | Yes | Depends entirely on memory budget discipline | LOW (math below is an estimate) |
| KeyboardKit Pro autocomplete | $50–500/mo | Low–Med | Local *and* remote options | Real product-grade, actively developed | HIGH (direct vendor pricing page) |
| Fleksy SDK | $269+/mo (free dev tier) | Low | Yes (+ swipe bundled) | Real product-grade, includes swipe | MED |
| Open-source (SymSpell, Hunspell, FUTO) | Free (license terms vary) | Med–High (porting work) | Yes | Ranges from spell-check to genuinely modern | MED |

### `UITextChecker` — the free baseline everyone already has

Two distinct APIs live here, and they behave differently **[MED, per NSHipster's tested findings]**:
- `guesses(forWordRange:)` — spelling-correction guesses for a typo, closer to genuinely probability-ranked.
- `completions(forPartialWordRange:)` — prefix-based word completion. Apple's documentation claims these are sorted by probability; NSHipster's testing found iOS actually returns them in roughly **alphabetical order**, unlike the macOS `NSSpellChecker` equivalent, which does behave as documented. That's a real quality gap between "what the docs promise" and "what you get" if completions are your whole strategy.
- No context awareness at all — it can't distinguish "there/their/they're" from surrounding words, and has no concept of "next word after this one." It's a spell-checker, not a predictor.
- `learnWord(_:)` additions are supposedly global to the device but scoped so one app's learned vocabulary doesn't leak into another app's suggestions — an interesting claimed isolation model, but **[LOW]**, worth testing rather than trusting blindly.

**Verdict:** this is "good enough to not look broken," not "competitive with Gboard." It's the free floor, not a real prediction engine.

### Building your own frequency/n-gram engine — the memory math

This is the crux of the "from scratch" option, and it's genuinely tight against the ~50–70MB ceiling **[LOW confidence — my own estimate, framed for validation, not a cited fact]**:

- **Unigram frequency table:** a real-world comparable exists — SymSpell's shipped English frequency dictionary covers ~83,000 words and is roughly 1–2MB as raw text; Hunspell's en_US spell-check dictionary (not frequency-ranked, but a similar order of vocabulary) runs **3.9–4.5MB in memory** with alias compression. Call it **2–6MB** for a solid unigram layer with Swift/Foundation overhead. This part is genuinely cheap.
- **Bigram model:** this is where it gets expensive. A naive full matrix over a 30–50k-word vocabulary is 900M+ theoretical cells — completely infeasible — so any real system prunes to *observed* pairs only. A well-pruned bigram table built from a moderate corpus commonly yields somewhere in the low millions of distinct surviving pairs after a frequency cutoff. At a packed ~8–12 bytes per pair (two compact token IDs + a quantized count/probability), that alone is plausibly **10–60MB** — which can eat most or all of the *remaining* headroom in a 50–70MB budget once UITextChecker/UIKit/theme assets/the rest of NumPad's own runtime are already accounted for.
- **Trigram+ models** are very likely off the table in-process at this vocabulary scale without moving to a compressed/mmap'd trie structure rather than an in-memory hash map, and even then it's a serious engineering undertaking with real risk of Jetsam kills during development.
- The more memory-efficient shape for this budget looks less like a classic n-gram count table and more like a small **quantized neural model** — which is exactly the architecture FUTO Swipe's companion "ContextLM" demonstrates (1.5M parameters, purpose-built for this exact constraint — see §3). That's real precedent that the tiny-neural-model path is more memory-efficient than the classic-statistical-model path at this scale, though it trades simplicity for an ML pipeline you now own.

**Verdict:** buildable, but the naive version (in-memory n-gram counts) is genuinely risky against the ceiling, and the safer version (a small trained model) requires ML capability the codebase doesn't currently have anywhere (NumPad has zero ML/prediction code today — see §5).

### KeyboardKit Pro

Confirmed directly from `keyboardkit.com/pricing` **[HIGH]**:

| Tier | Price | Includes |
|---|---|---|
| Basic | $50/mo | 1 language, autocomplete & autocorrect, iOS support, GitHub support |
| Silver | $150/mo | + 5 languages, AI support, in-keyboard typing, email support |
| Gold | $500/mo | + 75+ languages, app utilities, clipboard, dictation*, emoji keyboard, themes, priority support |
| Business | Custom | + on-device license file, custom terms/billing, escrow, dedicated support — required once a company clears $10M revenue or an app clears $1M/yr |

(Annual billing saves ~17% off any tier.) *Gold's "Dictation" line item is worth double-checking directly with KeyboardKit before assuming it bypasses the platform's hard microphone block described in §1 — it's far more likely to be a hand-off button to the system keyboard/host app than in-extension mic capture, but I could not confirm the mechanism in this pass **[LOW]**.

KeyboardKit 10.3 (Feb 2026) added **local, on-device next-word prediction using Apple's own Foundation Models framework** (`SystemLanguageModel`), available on iPhone 15 Pro+ running iOS 26.1+ **[MED]**. This is notable evidence that keyboard *extensions* can call into Apple's ~3B-parameter on-device model at all — since KeyboardKit's entire product is literally shipping other people's keyboard extensions, if this ships as a real customer-facing feature it strongly implies the model runs out-of-process (a shared, system-managed daemon) rather than being loaded into the extension's own ~50–70MB address space, which would be an instant Jetsam kill. I could not independently confirm the out-of-process architecture from Apple's own docs in this pass, so treat "extensions can safely use Foundation Models" as **[MED]**, worth a direct spike before relying on it.

No evidence found of KeyboardKit offering swipe-to-type as of this research pass — their gestures feature page describes generic gesture handling (taps, long-press, drag-to-move-cursor), not continuous-stroke word decoding **[MED-LOW, absence of evidence rather than a confirmed absence]**.

### Fleksy SDK

**[MED]**: free developer tier to prototype; paid plans start around **$269/mo** (their "Yearly One" plan) and scale up from there, evolved in 2022 from an older flat white-label license into a SaaS model. Feature set is broader out of the box than KeyboardKit for this specific ask: autocorrection, next-word prediction, autocompletion, **swipe input**, and emoji across 82 languages, with explicit swipe configuration parameters (`swipeTyping`, `swipeTriggerFactor`, `swipeGesturesLength`, `swipeRightToAddSpace`) in their own SDK docs **[HIGH, vendor's own documentation]**. This is the one turnkey option that includes gesture typing without you building or licensing it separately — see the patent discussion in §3 before treating that as risk-free, though.

### Open-source options

- **SymSpell** (MIT) — extremely fast fuzzy spelling correction via the "symmetric delete" algorithm, ships a ~83k-word English frequency dictionary. Good autocorrect-precision building block; **no built-in next-word prediction** — you'd still need to add that layer yourself. Ports exist in several languages; a Swift port or C-bridge would be real (if modest) work.
- **Hunspell** (GPL/LGPL/MPL tri-license) — the spell-checker inside macOS, Chrome, LibreOffice, and Firefox; ~4–4.5MB in memory for en_US. Battle-tested spelling correction, no ranking/prediction model. **License note:** the GPL/LGPL/MPL tri-license needs a real look from whoever owns App Store compliance before bundling it into a closed-source paid app — LGPL/MPL terms are more permissive if you dynamically link and comply with their specific terms, but this isn't a "just vendor the source" decision.
- **FUTO Swipe** (MIT) — genuinely the most interesting find here for the memory-constrained context: a complete open on-device swipe stack (a 635K-parameter layout-agnostic spatial encoder, a 300K-parameter QWERTY decoder, and a 1.5M-parameter context language model), explicitly engineered to be tiny enough to run locally in milliseconds. It ships today only as part of FUTO's **Android** keyboard — there is no iOS build, and an iOS feature request is open (unresolved) on their GitHub. The code and trained weights are MIT-licensed and public, so porting the architecture to iOS (via Core ML or a lightweight C++ inference bridge) is real, bounded engineering work rather than a research problem from zero **[MED]**.
- **Presage** (GPL) — an older (2000s-era) predictive-text engine; no evidence of active maintenance for mobile/iOS use today. Likely a dead end for this project **[LOW-MED]**.

### How close do Gboard/SwiftKey get to "native," per users?

**[MED, synthesized from press/aggregated review commentary, not a controlled study]**: both are generally rated as beating the stock iOS keyboard's autocorrect on tighter grammar/context handling and swipe accuracy in 2025–2026 comparisons; SwiftKey is more often cited as ahead on long-form/context-aware correction and reduced "wrong autocorrect" complaints, Gboard is cited as ahead on emoji/URL prediction. Neither is anywhere close to solving actual *grammar* correction (one informal comparison found both catching only 3 of 10 grammar errors, and only the spelling-adjacent ones). The realistic bar to aim for is "typing feels competent and gets out of the way," not "indistinguishable from native" — and both Google and Microsoft have full-time teams and years of user data behind that bar.

---

## 3. Swipe / QuickPath gesture typing

**Technically buildable: yes**, with two independent real-world proofs:
1. Grammarly ships a production **Neural Swipe Decoder** on iOS today — a deep-learning model that decodes the swipe gesture trajectory into word candidates, then re-ranks them through the same autocorrect/context system it uses for tap typing **[MED, Grammarly's own engineering blog]**.
2. **FUTO Swipe** (see §2) demonstrates the same class of solution built specifically for a tiny on-device memory budget, open-source, MIT-licensed — the strongest evidence that this doesn't strictly require licensing a commercial SDK.

**Patent landscape: real, live, and unresolved — flag this honestly.** **[HIGH confidence the following facts are accurate as of the current research pass; LOW confidence on eventual outcome, because there isn't one yet]**

- Swipe/continuous-stroke gesture typing traces to Swype Inc. (founded ~2002 by Cliff Kushler, co-creator of T9), with a foundational patent family including US 7,098,896 / 7,382,358 / 7,453,439 ("System and method for continuous stroke word-based text input"), originally filed around 2003.
- Ownership chain: Swype Inc. → acquired by **Nuance Communications** in 2011 (~$102.5M) → those patents reassigned within Nuance in 2014 → spun off into **Cerence Inc.** in 2019 (Nuance's automotive/voice-AI unit) → Nuance itself was separately absorbed into **Microsoft** in 2022's $19.7B acquisition, but the swipe-typing patent family rode with Cerence, not Microsoft.
- The original 2003-priority patents are most likely expired by their standard 20-year term (~2023) — but **this is not a settled, risk-free space**: **Cerence filed an active patent-infringement lawsuit against Apple** in the U.S. District Court for the Western District of Texas in **September 2025**, alleging Apple's own "slide to type" (QuickPath) feature infringes its continuous-stroke text-input patents (bundled in the same suit as a "Hey Siri" wake-word patent claim). Cerence says it approached Apple about licensing in 2021, no deal was reached, and Apple kept shipping the feature anyway. As of this research pass, no public settlement or ruling has been found — **the case is ongoing**.
- The practical read for NumPad: this isn't "the original patents definitely bar you" (they're probably expired) — it's "the current holder of this patent family is actively litigating over exactly this feature category, against the single most defensible possible target, and hasn't lost or settled yet." That's meaningfully different from a dead legal question. A small indie app is a much less attractive litigation target than Apple in terms of expected damages, but is also far less equipped to defend a suit if one ever came.
- Apple itself separately holds its own swipe-gesture patents (filed circa 2013, per contemporaneous TechCrunch coverage) — those are a defensive asset for Apple's own QuickPath, not something that protects a third party building a similar feature.

**Vendor swipe offerings:** Fleksy bundles swipe typing as a first-party, documented SDK feature (§2). KeyboardKit shows no evidence of a swipe feature as of this pass. Licensing Fleksy shifts *some* exposure onto their contract's indemnification terms — but that should be read directly, not assumed, before treating it as a full legal shield.

**Recommendation specific to swipe:** treat it as an explicit, separately-gated decision — not bundled into a general "build the prediction engine" plan — pending either (a) a real legal review, or (b) watching how Cerence v. Apple resolves. If built anyway, architecture matters: FUTO's approach (a layout-agnostic spatial encoder predicting per-character key likelihoods from the raw touch trajectory, decoded against the *current* keyboard layout at inference time, plus a separate context-LM re-ranker) is a meaningfully different technical shape than the classic "continuous stroke maps directly to a word shape" claim language in the original Swype-era patents — closer, in spirit, to how modern ASR-style decoding works. That's not a legal opinion, just a technical observation that "buildable in a way that doesn't obviously restate 2003-era claim language" and "legally safe" are two different questions, and only one of them is answerable by an engineer.

---

## 4. Emoji, autocapitalization, double-space period, text replacement, keyboard switching

| Feature | Achievable? | How | Confidence |
|---|---|---|---|
| Emoji keyboard | Yes, fully | Just Unicode + your own picker UI (categories, search, skin-tone modifiers, recents) — several open-source reference implementations exist (e.g. ISEmojiView). No API blocks this. | HIGH |
| Apple's "Genmoji" (AI-generated custom emoji) | No | Tied entirely to Apple Intelligence's own generation pipeline; not exposed to third-party keyboards. | MED |
| Autocapitalization | Yes, but entirely self-implemented | `UITextInputTraits.autocapitalizationType` (via `textDocumentProxy`) tells you the *policy* the current field wants (sentences/words/all/none) — there's no keystroke-level assist. You read the trait, then apply shift-state and casing yourself on every insert. | HIGH |
| Double-space → period | Yes, but entirely self-implemented | No API surface for this at all — you buffer recent input, detect the two-space pattern, and swap in ". " yourself. Every custom-keyboard tutorial reproduces this manually because there's no shortcut. | HIGH |
| Read user's Text Replacement shortcuts | **Plausibly yes**, no Full Access needed | `requestSupplementaryLexicon(completion:)` → `UILexicon` entries, per repeated (if not independently re-verified live) documentation language — see §1's "text-replacement surprise." Spike before relying on it. | MED |
| Keyboard switching UX (tap = next, long-press = list) | Yes, matches system exactly | `advanceToNextInputMode()` for tap; `handleInputModeList(from:with:)` for the long-press picker — both are real, documented APIs. | HIGH |

---

## 5. What NumPad's existing engines carry over for free

Per `graphify query "keyboard extension engines: calculator, packs, overlays, custom keyboard, themes"` and `CLAUDE.md`: none of NumPad's current engines are autocorrect/prediction/swipe systems, but very little of the *surrounding* product would need to be rebuilt if the project grew a full QWERTY typing mode alongside the numpad. The RPN math engine (`Calculator` — `tokenize()` → `toRPN()` → `evalRPN()` → `format()` in `SharedExtensions.swift`), `UnitConverter`, `TaxTipMath`, `ResultTape`, `ClipboardHistoryManager`, `SnippetsManager`, and the 17-case `KeyboardTheme` system are all input-agnostic — they operate on inserted text and computed results, not on the specific key layout that produced them, so they'd sit under a QWERTY row exactly as they do under the numpad today. The Custom Keyboard v2 architecture (`CustomKeyboardConfig`'s `topRow?`/`column1?`/`column2?` model, `Handedness`, `CustomKeyboardLayout.bodyRows`) already generalizes "arbitrary peripheral sections around a fixed body," which is a reasonable skeleton to extend for a full keyboard's row layout rather than starting over. `StackView`'s grid rendering and `Button`'s press/haptics/continuous-press handling — including the exact Full-Access gating described in §1 — carry over directly and don't need to be re-derived. What's entirely new, with zero existing analog anywhere in the codebase, is the actual typing engine: autocorrect, prediction, and swipe. That gap is the entire subject of this document.

---

## 6. Parity scorecard (condensed)

| Native feature | Achievable by a third-party keyboard? | How |
|---|---|---|
| Dictation / mic input | **No** — hard platform block | n/a, no workaround exists |
| Secure-field typing | **No** — by design | System keyboard force-swaps in |
| Globe key + long-press keyboard list | **Yes** | `advanceToNextInputMode()` + `handleInputModeList(from:with:)` |
| Inline QuickType bar | **No shared access** — build your own | Own suggestion UI inside your input view |
| Key-press popup above the keys | **No** | Apple docs explicitly block drawing above your own top edge |
| Spell-check / basic autocorrect | **Yes, free** | `UITextChecker` (no Full Access) |
| Read text-replacement shortcuts | **Plausibly yes, free** [MED] | `requestSupplementaryLexicon` — spike to confirm |
| Real next-word prediction | **Yes, at a cost** — engineering time, SaaS fee, or both | Own n-gram/small model, KeyboardKit, or Fleksy |
| Swipe / gesture typing | **Technically yes; legally live risk** | FUTO-style tiny model, Grammarly-style deep model, or license Fleksy — Cerence v. Apple suit is active and unresolved |
| Emoji keyboard | **Yes** | Own Unicode picker |
| Genmoji | **No** | Apple-Intelligence-only |
| Autocapitalization / double-space period | **Yes, fully self-implemented** | No API assist exists for either |
| Haptics / key-click sound | **Yes, Full-Access-gated** | Confirmed in NumPad's own code |
| Memory budget | **~50–70MB hard ceiling** | Jetsam kill, no graceful degrade |

---

## 7. Recommended engine path

**A. Build on KeyboardKit** — $50–500/mo recurring, low-to-medium effort, medium control. Fastest route to "materially better than free `UITextChecker`" text prediction without a research team; as of 10.3 it's also the path most likely to get you Apple Foundation Models-backed local prediction for free engineering effort. No swipe. Ongoing SaaS cost never goes away, and it's a dependency on someone else's roadmap and pricing.

**B. License Fleksy** — $269+/mo, low effort, lowest control of the three. Only path that hands you swipe-to-type turnkey. Most expensive floor, least flexible historically (already pivoted its business model once), and licensing swipe doesn't erase the Cerence patent question — it just moves who's contractually on the hook, which needs to be read in their terms, not assumed.

**C. From scratch** (`UITextChecker` + `UILexicon` now, a small trained model later) — $0 recurring, highest effort, highest control. The free baseline is available immediately and costs nothing. A real prediction model is buildable but memory-tight — the honest math above says a naive n-gram table can plausibly consume most of the remaining budget, and the safer shape looks like a small quantized model (FUTO's 1.5M-parameter ContextLM is the closest public precedent) rather than a classic count table. Swipe, if ever pursued, means porting FUTO's open MIT architecture to iOS — real work, no vendor, and the same Cerence exposure as any other implementation, with no one else's legal team to lean on.

**Recommendation:** start with **C's free floor** (`UITextChecker` + `UILexicon`, zero cost, no Full Access, available today) as v1, evaluate whether **KeyboardKit's $50/mo Basic tier** meaningfully beats it in real usage before paying for anything recurring (the tier is cheap enough to trial against a real build before committing), and treat **swipe-to-type as a separate, explicitly legally-reviewed v2+ decision** gated on the outcome of Cerence v. Apple — not a v1 requirement. Skip Fleksy unless swipe becomes a hard launch requirement; it's the most expensive and least flexible option for a product whose core identity is a numeric/symbol keyboard first, not a full QWERTY replacement.

---

## Sources

- [App Extension Programming Guide: Custom Keyboard](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html)
- [Configuring open access for a custom keyboard — Apple](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard)
- [requestSupplementaryLexicon(completion:) — Apple](https://developer.apple.com/documentation/uikit/uiinputviewcontroller/requestsupplementarylexicon(completion:))
- [handleInputModeList(from:with:) — Apple](https://developer.apple.com/documentation/uikit/uiinputviewcontroller/1649584-handleinputmodelistfromview)
- [playInputClick() — Apple](https://developer.apple.com/documentation/uikit/uidevice/1620050-playinputclick)
- [UIImpactFeedbackGenerator — Apple](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator) / [Apple Developer Forums thread on haptics + Full Access](https://developer.apple.com/forums/thread/63493)
- [On the Limitations of iOS Custom Keyboards — MacStories](https://www.macstories.net/notes/on-the-limitations-of-ios-custom-keyboards/)
- [Limitations of custom iOS keyboards — Medium](https://medium.com/@inFullMobile/limitations-of-custom-ios-keyboards-3be88dfb694)
- [UITextChecker — NSHipster](https://nshipster.com/uitextchecker/)
- [Identifying high-memory use with jetsam event reports — Apple](https://developer.apple.com/documentation/xcode/identifying-high-memory-use-with-jetsam-event-reports)
- [KeyboardKit Pricing](https://keyboardkit.com/pricing) / [KeyboardKit 10.3 release notes](https://keyboardkit.com/blog/2026/02/13/keyboardkit-10-3) / [KeyboardKit Autocomplete feature page](https://keyboardkit.com/features/autocomplete)
- [Fleksy Keyboard SDK Pricing — G2](https://www.g2.com/products/fleksy-keyboard-sdk/pricing) / [Fleksy SDK Developer Platform](https://www.fleksy.com/developers/) / [Fleksy switches to SaaS — TechCrunch](https://techcrunch.com/2022/05/04/fleksy-sdk-saas/)
- [SymSpell — GitHub](https://github.com/wolfgarbe/SymSpell)
- [Hunspell — Wikipedia](https://en.wikipedia.org/wiki/Hunspell) / [Hunspell-iOS — GitHub](https://github.com/aaronSig/Hunspell-iOS)
- [FUTO Swipe: Layout-Agnostic Neural Swipe Decoding — arXiv](https://arxiv.org/abs/2606.25247v1) / [FUTO Keyboard iOS feature request — GitHub](https://github.com/futo-org/android-keyboard/issues/1594)
- [How We Use Deep Learning for Swipe Typing on the Grammarly iOS Keyboard](https://www.grammarly.com/blog/engineering/deep-learning-swipe-typing/)
- [Swype — Wikipedia](https://en.wikipedia.org/wiki/Swype) / [US7098896B2 — Google Patents](https://patents.google.com/patent/US7098896B2/en) / [US7453439 — Google Patents](https://patents.google.com/patent/US7453439?oq=swype)
- [Cerence AI Files Patent Infringement Suit Against Apple — investor release](https://investors.cerence.com/news-events/press-releases/detail/350/cerence-ai-files-patent-infringement-suit-against-apple) / [9to5Mac coverage](https://9to5mac.com/2025/09/04/apple-hit-with-patent-lawsuit-over-hey-siri-and-virtual-keyboard-features/) / [Apple Swipe Keyboard Patent — TechCrunch, 2013](https://techcrunch.com/2013/09/24/apple-keyboard-swipe-patent/)
- [Foundation Models — Apple Developer Documentation](https://developer.apple.com/documentation/FoundationModels) / [SystemLanguageModel — Apple](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- Gboard/SwiftKey vs. native comparisons: synthesized from multiple 2025–2026 press/review aggregations (AirDroid, ClevertType, BossAI, Mundobytes) — no single controlled study found.
- NumPad codebase (read-only): `CLAUDE.md`, `graphify query`, `Keyboard/Views/Button.swift`, `Keyboard/KeyboardViewController.swift`, `NumPad/Libraries/SharedExtensions.swift`
