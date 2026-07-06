# NumPad Type — Master Product Plan (working name)

**v2 — 2026-07-05, owner decisions incorporated.** §0 below records eight owner decisions made on a
second pass over the v1 draft plus the two OSS research companions that landed the same day
(`2026-07-05-oss-swipe-options.md`, `2026-07-05-oss-prediction-options.md`). Where a decision
conflicts with v1 language elsewhere in this file, **the decision wins** — the affected sections
(§2, §3, §4, §6) have been edited in place to carry it through, rather than leaving two
contradictory versions in the same document. Nothing below is a placeholder; this is the current
plan.

**Date:** 2026-07-05. Planning doc only — no code changes, not committed.
**Inputs:** `2026-07-05-{technical-feasibility,competitive-landscape,complaint-evidence-bank,rules-and-structure,oss-swipe-options,oss-prediction-options}.md`
(this directory) and `docs/plans/moonshot/2026-07-03-roadmap.md`. Cross-checked against the live
`ProductCatalog`/`Monetization` architecture in `NumPad/Libraries/SharedExtensions.swift` (generic
over `ProductCatalog.allProductIDs` — confirmed via `graphify query`, not assumed) and the shipped
3-step onboarding machine (`OnboardingViewController` + `OnboardingStep`: WOW → ENABLE → TRY IT,
skippable at every step, `NumPad/Controllers/OnboardingViewController.swift` /
`NumPad/Libraries/OnboardingStep.swift`).

---

## 0. OWNER DECISIONS (v2) — authoritative, made 2026-07-05

Eight decisions, each stated here in full and then carried through into the section that governs
its execution. These are inputs to the plan, not proposals still open for debate in this doc.

1. **BASELINE PARITY.** QWERTY must match the iPhone default keyboard as closely as a third-party
   keyboard is platform-permitted to, in **both appearance and behavior** — key geometry, light/dark
   colors, shift/caps-lock behavior, callout styling, and sound/haptic semantics. NumPad's own
   additions (number row, numpad-flip, packs, overlays) layer on top of that familiar baseline
   without altering it — a user should be able to forget they're not on the system keyboard until
   they reach for one of NumPad's features. **New parity-spec workstream:** a side-by-side
   screenshot-diff checklist against the native keyboard is an explicit QA gate (§2, §4), not an
   informal "looks close enough" judgment call.
2. **PERIOD + COMMA on the main letter layer.** Both keys live on the main QWERTY letter row (not
   behind a `123` shift tap), governed by **one simple on/off settings switch — both keys together,
   not independently toggleable — default ON.** Rationale for default-on: this is the second most-
   cited native-keyboard layout complaint after the missing number row itself, and shipping the
   switch default-off would bury the exact parity win it exists to prove; the escape hatch exists for
   users who want strict system-keyboard row geometry, but the informed default ships the
   improvement. See §2 for the parity-spec geometry implications (row-width budget, shift-key
   resize) this key placement creates.
3. **SWAPPABLE NUMBER LINE.** The top row toggles between the persistent number row and a
   QWERTY-appropriate pack family, reusing the existing `Item.pack(type:)` / `KeyboardType` /
   `ProductCatalog` entitlement machinery — no new gating system. **Grammar** ships first in that
   family (em dash, en dash, curly quotes, semicolon, ellipsis, degree sign, section sign). See §2 for
   the full pack-crossover table (which existing packs cross over to QWERTY vs. stay numpad-only).
4. **SETUP WIZARD for both keyboards.** Evolves — does not duplicate — the shipped 3-step onboarding
   (`OnboardingViewController`: WOW → ENABLE → TRY IT). Scope: enable/disable the QWERTY keyboard
   entirely; choose a default pack; and choose the pack-display behavior, **LAST-USED vs.
   PRIMARY-SELECTED** (new `Constants` key + `SettingsSync` semantics defined in §2). Re-runnable from
   Settings — unlike today's one-shot `onboardingShown` flag, this is a flow users can revisit.
5. **SWIPE stays a flagged prototype, legally gated — not a V1 requirement.** Per
   `2026-07-05-oss-swipe-options.md`: no OSS candidate clears both the license gate and the patent
   gate at a shippable quality bar. Deferred, feature-flagged, off by default, no App Store
   submission, until a real legal review of the Cerence patent family clears — notably the
   **currently-active** US 7,706,616 (Zhai/Kristensson/ShapeWriter lineage, expires 2026-12-21) — and
   Cerence v. Apple resolves. Do not market "swipe coming soon."
6. **PREDICTION ships only if it beats the free floor.** Per `2026-07-05-oss-prediction-options.md`,
   the OSS test harness (offline corpus + in-extension DEBUG switcher) is an explicit **pre-decision
   milestone** gating Phase 2 (§4) — not an implementation task assumed to succeed. Shipping any OSS
   prediction candidate (AOSP LatinIME dictionaries, SymSpell + marisa) over the `UITextChecker`
   control requires clearing all four stated gates: **+15pp** absolute top-1 quality improvement,
   **≤15MB** resident memory delta, **≤16ms p95** added latency, and **zero GPL** in the shipped
   binary. Missing any one gate means ship the free floor, not the candidate.
7. **ALL LANGUAGES, not Latin-first-only.** V2's multilingual rollout (§3) is redefined from a
   Latin-script-first wave to the **complete matrix** across NumPad's actual 17 shipped `.lproj`
   locales — `ar`, `de`, `en`, `es`, `fr`, `he`, `hi`, `it`, `ja`, `ko`, `nl`, `pl`, `pt-PT`, `ru`,
   `zh-Hans`, `zh-Hant`, `zh-HK` — and beyond. §3 covers per-locale layout availability
   (QWERTY/QWERTZ/AZERTY, RTL for `ar`/`he`), lexicon sourcing per the prediction doc, honest CJK
   scoping (`ja`/`ko`/`zh-*` IME-class input staged as its own engineering problem, not folded into
   "another locale"), and a rollout order justified by NumPad's **actual sales locales** — owner:
   NumPad has strong non-English sales, so sequencing follows revenue data, not engineering
   convenience or script familiarity.
8. **ABSOLUTE DEFINITION OF DONE.** Owner mandate, verbatim: *"no mistakes, complete testing, ready
   for review and minor cleanup."* §7 turns this into a literal, checkable bar that every phase in §4
   must clear before it counts as done — not just its own phase's task list.

**One-line thesis:** NumPad already owns "the numeric layer of iOS" per the moonshot roadmap. NumPad
Type is not a pivot away from that — it's the numeric layer growing a typing mode so users never have
to leave it, closing the exact gap the competitive-landscape doc identifies as open and defensible:
*a full keyboard that treats numbers as first-class, with no Full Access required for core typing.*

---

## 1. DECISION — extend NumPad vs. standalone app

### Recommendation: **extend the existing NumPad app with a second keyboard extension target.**

This is Option A from the rules-and-structure doc (§4), not Option B. Rationale, weighed against the
four factors the task calls out:

| Factor | Extend NumPad (chosen) | Standalone app (rejected) |
|---|---|---|
| **Entitlement sharing** | `numpad.pro.lifetime` and the 6 à-la-carte packs already exist as non-consumables in one app. A new keyboard slots into the same `ProductCatalog`/`Monetization` gating map — `StoreManager` needs **zero changes**, it's already generic over `ProductCatalog.allProductIDs`. Existing Pro/pack owners get the QWERTY keyboard the moment it ships, at $0 marginal friction. | IAP entitlements are hard-scoped per bundle ID (rules doc §4) — a standalone app **cannot** honor existing NumPad Pro purchases. Only lever is a discounted Paid App Bundle (still a new purchase) or custom server-side receipt sharing (real, unscoped engineering). Directly punishes the ~installed base the moonshot roadmap is trying to grow. |
| **Pricing** | Fits directly under the existing $11.99 Pro anchor and the 6-pack à-la-carte ladder — no new pricing model to design or explain. | Forces an immediate "buy it twice" narrative or a whole new subscription/bundle mechanism NumPad has deliberately avoided (see §5). |
| **App Store positioning** | One listing, one set of reviews, one privacy label to maintain — and the competitive doc's positioning wedge ("the keyboard for people who type numbers") is *strengthened*, not diluted, by shipping QWERTY typing as an extension of the numeric identity rather than a second, unrelated product competing for its own install base from zero. | Two listings means two review counts to build from scratch, splitting the "category ownership" acquisition bullet (moonshot §6, bullet 1) instead of compounding it. A second app also has to win its own App Store SEO/ASA fight independently — expensive, slow, and duplicative of work already being spent on NumPad's own funnel (Growth lens, Tier 1/2). |
| **Risk to NumPad's 4.x rating if the new keyboard stumbles** | **Real risk, but containable.** A second *extension* is a separate Settings → Keyboard entry the user enables independently — if NumPad Type's autocorrect is rough at launch, the failure mode is "I turned off that one keyboard," not "I uninstalled the app," because the numpad extension keeps working untouched. Reviews on a shared listing *can* still get contaminated by a bad typing-mode review — mitigated by (a) TestFlight-gating hard before GA (§4), (b) framing NumPad Type as clearly opt-in/experimental in its own onboarding, and (c) the rules doc's 4.4.1 finding that *each* extension is reviewed independently, so a rough QWERTY extension doesn't put the numpad extension's App Review status at risk either. | A standalone app fully isolates the blast radius (a bad NumPad Type app doesn't touch NumPad's 4.x rating at all) — this is the one real advantage of Option B, and it's the strongest argument *against* this recommendation. It doesn't outweigh the entitlement/pricing/positioning cost, but it's the reason §4's rollout gates below are unusually conservative for a "just ship a second target" project. |

**Net:** extend-in-place wins on 3 of 4 factors decisively and the 4th (rating risk) is manageable
with rollout discipline, not avoidable by a doc decision — so the plan leans on TestFlight/RC gates
(§4) rather than structural isolation to manage it. Two keyboard extensions in one containing app is
explicitly supported by Apple's own multi-language guidance (rules doc §4, Option A) and matches how
NumPad already gates features via shared `Monetization` flags read by both targets.

**Naming:** ship it as a **second entry under the same NumPad app** in Settings → Keyboard (its own
extension target, own bundle ID suffix, own Info.plist) — user-facing name TBD (marketing exercise,
out of scope here), but structurally it is "NumPad" → two keyboards: **NumPad Numbers** (today's
extension, renamed for clarity once a second exists) and **NumPad Type** (new). One deep-link scheme
(`numpad://`) continues to serve both.

---

## 2. V1 SCOPE (English) — full QWERTY with NumPad integrations

### Engine path: **Option C from the technical-feasibility doc — free floor first**

Start with `UITextChecker` (spell-check) + `UILexicon`/`requestSupplementaryLexicon` (contacts +
Text Replacement shortcuts — spike the Text Replacement claim in Phase 0, technical doc §1) as the
v1 prediction/autocorrect layer. Both are **zero cost, zero Full Access, on-device, available today**
— and per the rules-and-structure doc §1, this is not just the cheap option, it's the **only
guideline-compliant default**: 4.4.1 requires core typing (including autocorrect) to work with
network and Full Access both off, and Apple has flagged keyboards for functionally gating core
typing behind Full Access in the past.

Gate a **KeyboardKit Basic ($50/mo)** trial as an explicit Phase 2 decision (§4) once the free floor
is shipped and real usage data exists to judge whether it meaningfully beats `UITextChecker` alone —
don't pre-commit recurring spend before there's a live extension to test it against. Fleksy is
**out of scope for V1** entirely (technical doc §2/§7: most expensive floor, least flexible,
swipe-only differentiator that doesn't matter until swipe itself is approved — see non-goals below).

**OSS prediction test harness runs alongside/ahead of the KeyboardKit decision, not after it (owner
decision §0.6).** `2026-07-05-oss-prediction-options.md` designs a two-part evaluation — an offline
corpus (typo injection + keystroke-savings-rate scoring against `UITextChecker` as the control arm)
and an in-extension DEBUG-flag switcher — specifically so the free-floor-vs-something-better question
gets answered with data before *any* engineering commitment, paid SaaS or from-scratch. The two
strongest OSS candidates found (AOSP LatinIME's dictionaries + bigram data, SymSpell + marisa-trie)
only earn a Swift port if they clear all four pre-registered gates against the control: **+15
percentage points** absolute top-1 quality, **≤15MB** resident memory delta, **≤16ms p95** added
latency, and **zero GPL** code in the shipped binary. This is a genuine three-way decision at Phase 2
(ship the free floor as-is / build the OSS candidate that cleared the gates / trial KeyboardKit
Basic) — not a two-way KeyboardKit-vs-nothing choice.

### V1 feature list

**Parity baseline (per technical-feasibility §4/§6; per owner decision §0.1, this is now a
hard requirement, not a best-effort aim):**
- Full QWERTY letter layout + shifted symbol/number layer, matching system key geometry and spacing
  as closely as `UIInputViewController`'s canvas allows — including light/dark color values, not just
  shape, since §0.1 scopes parity to appearance *and* behavior
- Shift/caps-lock logic, self-implemented against `UITextInputTraits.autocapitalizationType`
  (no keystroke-level OS assist exists — technical doc §4), matching the system's shift/caps-lock
  visual and timing behavior (double-tap-shift-for-caps-lock, auto-unshift after a letter), not just
  its end state
- Double-space → period, self-implemented buffer/detect/swap (no API assist exists)
- **Period + comma on the main letter layer, one on/off switch, default ON (owner decision §0.2).**
  Both keys sit on the main QWERTY row rather than behind the `123` shift layer — the single switch
  in Settings controls both together, never independently. Default ON because this is the change
  most likely to register as "finally fixed" against the native layout; the parity-spec workstream
  below must document exactly which native key each one displaces and how the row absorbs the width
  (candidates: narrowing the shift/backspace keys slightly, matching how some Android/system-adjacent
  QWERTY layouts already handle a denser bottom row) — this is the one place baseline parity (§0.1)
  and this feature intentionally diverge from the system layout, and the divergence must be
  deliberate and measured, not an accident of implementation.
- `UITextChecker.guesses(forWordRange:)` for typo correction + `completions(forPartialWordRange:)`
  for prefix completion (accept the documented alphabetical-ordering quirk as a known v1 limitation,
  not a blocker — NSHipster finding, technical doc §2)
- `requestSupplementaryLexicon` pull of Contacts names + Text Replacement shortcuts, spiked first
  (Phase 0) before being relied on in shipped UI
- Globe key: tap → `advanceToNextInputMode()`; long-press → `handleInputModeList(from:with:)` for
  the pixel-identical system keyboard-list menu (technical doc §1/§4 — fully achievable, no gap)
- Cursor movement gestures: left/right drag-to-move-cursor on the space bar (matches the system
  keyboard's known gesture; no API blocks a custom implementation of the same interaction)
- Own emoji keyboard: Unicode categories, search, skin-tone modifiers, recents (technical doc §4 —
  fully achievable; Genmoji explicitly out of reach, listed as a non-goal below)
- Key-press callout: an **in-bounds** magnified-letter bubble (KeyboardKit-style — stays inside the
  extension's own frame), explicitly not the system's "pops up above the keys" effect, which Apple's
  own docs block outright (technical doc §1)
- **Parity-spec QA gate (new workstream, owner decision §0.1):** a side-by-side screenshot-diff
  checklist — NumPad Type vs. the stock iOS keyboard, same device, same light/dark mode, same
  field type — covering key geometry, corner radius, color values, shift/caps states, and the
  in-bounds callout bubble's position/timing. This is a named deliverable in §4 (Phase 1 build item,
  Phase 3 gate), not an implicit "looks right to the reviewer" sign-off.

**NumPad integrations that make this a "NumPad Type," not a QWERTY clone:**
- **Persistent number row, swappable (owner decision §0.3, supersedes the v1 "always the same row"
  framing below)** — a `1234567890` row visible above/adjacent to QWERTY by default, not behind a
  `123` shift tap. This is the single most-cited, most durable complaint in the evidence bank
  (Theme 5 — outlived two full Apple autocorrect rewrites, still the top reader reaction as of the
  Apr 2026 iOS 27 rumor coverage) and the positioning doc's literal one-line pitch: *"the keyboard
  for people who type numbers."* **The top row is not fixed to numbers** — a dedicated toggle swaps
  it between the number row and a QWERTY-appropriate pack family, reusing the same
  `Item.pack(type:)` / `KeyboardType` / `ProductCatalog` entitlement machinery that already gates
  numpad packs today, so this is a rendering/UI change, not a new gating system.
  - **Grammar ships first in the QWERTY pack family:** em dash (—), en dash (–), curly quotes
    (" " ' '), semicolon, ellipsis (…), degree sign (°), section sign (§) — punctuation that's
    genuinely awkward to reach on the stock keyboard and squarely fits NumPad's "the keys you
    actually reach for shouldn't be three taps away" identity.
  - **Pack crossover table** — which existing packs make sense on a QWERTY top row vs. stay
    numpad-only:

    | Pack | Crosses to QWERTY top row? | Rationale |
    |---|---|---|
    | Grammar *(new)* | Yes — ships first | Purpose-built for prose; no numpad analog needed |
    | Symbols & Science | Yes | Symbol-heavy, not numeric-entry-specific; useful mid-sentence |
    | Finance | Yes | Currency symbols belong in prose ("costs €12") as much as in numeric entry |
    | Programmer | Yes | Bitwise operators and hex prefixes show up inline in written technical text |
    | Date & Time | Partial — the live token keys are numpad-native; consider a QWERTY-side subset (e.g. inserting a formatted date string) rather than the full token row | Token-insertion behavior is arguably more useful mid-sentence than numeric-entry-adjacent |
    | Units & Conversion | No — stays numpad-only | The "=" live-converter overlay is built around a numeric-entry workflow, not prose |
    | Cooking & Baking | No — stays numpad-only | Same reasoning as Units — the converter overlay is the point, not the keys alone |
    | Custom | Yes, unconditionally | User-authored; whatever the user put there is by definition QWERTY-appropriate to them |

    This table is a starting recommendation for Phase 1 design review, not a final cut — Units and
    Cooking's "stays numpad-only" calls should be revisited if usage data says otherwise once V1 is
    live.
- **One-tap numpad flip** — a dedicated key that swaps the entire canvas to today's full NumPad
  keyboard as a layer, and back again, without going through the globe-key/next-keyboard system flow.
  This is the direct product answer to the competitive-landscape doc's core finding: existing numeric
  addon apps (NumPad's own App Store sibling products included) force a manual globe-key switch to
  type a word, which is the #1 documented abandonment friction (rules/complaint docs both name
  "global switching friction" independently). NumPad Type removes that tax entirely for its own users.
- **Live math preview everywhere** — the already-shipped `04f87423` compute-as-you-type chip
  (deterministic parsing, not an LLM — moonshot roadmap §2) ports directly; it's input-agnostic per
  the technical doc §5 finding that `Calculator`'s RPN engine doesn't care which layout produced the
  inserted text.
- **Packs as an optional row** — Finance/Symbols/Programmer/Date&Time/Units/Cooking packs surface as
  a togglable row under QWERTY exactly as they do today under the numpad (same `Item.pack(type:)`
  layout data, same `KeyboardType` enum — no new pack-authoring work).
- **Clipboard/Snippets/Tape overlays carry over unmodified** — `ClipboardHistoryView` (long-press
  "0" equivalent — needs a QWERTY-appropriate trigger key, likely long-press on a punctuation key),
  `SnippetsListView`, `ResultTapeView` are all input-agnostic per the technical doc §5's direct
  finding: none of NumPad's existing overlay engines care about the key layout that produced the
  inserted text.
- **Themes including Glass** — the 17-case `KeyboardTheme` system (including the Liquid Glass premium
  theme shipped in `7710b230`) applies to `StackView`'s grid rendering regardless of which layout
  (numpad vs. QWERTY) is currently drawn — no new theme-authoring work, just extending the rendering
  path to the new row shapes.
- **Full Access model unchanged** — haptics, key-click sound, clipboard reads stay Full-Access-gated
  exactly as today (technical doc §1, confirmed in NumPad's own `Button.swift`); core typing
  (including the free-floor autocorrect above) works with Full Access off, satisfying 4.4.1 by
  construction rather than by a later compliance pass.

### Setup wizard — for both keyboards (owner decision §0.4)

This is deliberately scoped as **evolving the shipped onboarding, not building a second one.**
`OnboardingViewController` already runs a 3-step sequence (`OnboardingStep`: `.wow → .enable →
.tryIt`), skippable at every step, shown once via the `onboardingShown` flag ahead of the legacy
Instructions push. NumPad Type's setup needs land inside that same machine rather than a
parallel flow presented at a different time:

- **Enable/disable QWERTY entirely.** A clear on/off decision, distinct from *which* pack it
  defaults to — surfaced during the ENABLE step (where the flow already walks the user through
  turning a keyboard on in Settings) and again as its own row in Settings so it's not a one-time
  choice frozen at first run.
- **Default pack selection.** Presented once QWERTY is enabled — which pack (if any) occupies the
  swappable top row (§2, pack-crossover table) the first time the user opens NumPad Type. This is a
  starting point, not a lock; changing it later doesn't require re-running the wizard.
- **Pack-display behavior: LAST-USED vs. PRIMARY-SELECTED.** A real product decision the wizard must
  surface, not bury in a settings submenu no one finds:
  - **LAST-USED** — the top row (numpad-side and/or QWERTY-side) always reopens on whichever pack
    was showing when the keyboard was last dismissed. Mirrors how most people expect a stateful tool
    to behave; no extra taps to get back to what you were doing.
  - **PRIMARY-SELECTED** — the top row always reopens on one pack the user pinned as their default,
    regardless of what was showing last. Better for someone who wants a stable, predictable layout
    (e.g., always Finance) and treats deviating from it as a temporary, self-reverting excursion.
  - **New `Constants` key:** `packDisplayBehavior` (raw-string-backed enum, following the existing
    `Constants` pattern in `SharedExtensions.swift` — e.g. alongside `smartPackDefaultingEnabled`),
    values `.lastUsed` / `.primarySelected`, default **LAST-USED** (matches the existing
    `smartPackDefaultingEnabled` GA behavior's spirit — least-surprise, no extra decision required
    of users who never open the wizard's advanced options).
  - **`SettingsSync` semantics:** written by the app (wizard UI) into `UserDefaults.group`, followed
    by `SettingsSync.post()` exactly like every other cross-process setting in this codebase — the
    keyboard extension observes via `SettingsSync.observe(...)` and re-reads the flag on the next
    reload rather than needing a live push mid-session, matching how `handedness` and
    `customKeyboardConfig` already propagate.
- **Re-runnable from Settings.** Unlike today's `onboardingShown` one-shot flag (consumed once,
  never shown again), the wizard needs its own re-entry point — e.g. a "Set Up Keyboards" row in
  `HomeViewController` that re-presents `OnboardingViewController` (or a wizard-scoped subset of its
  steps) on demand. The existing one-shot flag stays as-is for the *first-run* trigger; re-runnability
  is an additive entry point, not a change to when the automatic first-run flow fires.

### V1 explicit non-goals (set expectations up front)

1. **Dictation is impossible, categorically, not "not yet."** No app extension type has ever had
   microphone access since iOS 8; this is Apple privacy policy, not a technical gap that a future iOS
   release could close (technical doc §1). Do not put a mic icon in the UI, even disabled — it invites
   "why doesn't this work" support load for a feature that structurally cannot exist.
2. **Swipe-to-type is deferred, not rejected — pending legal review (owner decision §0.5).** The
   Cerence v. Apple suit is active, unresolved, and filed against the single most defensible target
   in the industry (Apple itself) in Sept 2025 (technical doc §3). The dedicated OSS survey
   (`2026-07-05-oss-swipe-options.md`) went a level deeper and found the exposure is *broader* than
   the original Kushler/Swype patent family: Cerence separately holds the Zhai/Kristensson/
   ShapeWriter-lineage patent **US 7,706,616** ("recognizing word patterns... based on a virtual
   keyboard layout"), **status ACTIVE, expires 2026-12-21** — a title that reads, in plain English,
   like a description of the classical corner/shape-matching decoders both license-clean OSS
   candidates (FlorisBoard, AnySoftKeyboard) actually use. No OSS candidate surveyed clears both the
   license gate *and* a patent picture clean enough to build on at a shippable quality bar — treat
   swipe as a separate, explicitly-gated, feature-flagged, off-by-default V2+ decision, not a V1
   requirement, gated on (a) that patent's 2026-12-21 expiry *and* subsequent continuations, and (b)
   Cerence v. Apple resolving. Building it now risks a full rebuild or worse if the legal read
   changes, and per the competitive doc, swipe is exactly the axis (per Fleksy's collapse) where
   NumPad has no structural advantage over Gboard/SwiftKey anyway. Do not market "swipe coming soon."
3. **System Text-Replacement sync is one-directional and unconfirmed, not "any keyboard can write
   there."** `requestSupplementaryLexicon` is a **read** of the user's existing shortcuts (technical
   doc §1/§4) — NumPad Type cannot create, edit, or delete Settings → Text Replacement entries, and
   even the read path is [MED] confidence pending the Phase 0 spike. Snippets remain NumPad's own
   separate, fully-owned expansion system; do not brand the lexicon read as "text replacement
   integration" until the spike confirms it works on-device.
4. **No inline QuickType bar / ghost-text.** The system's predictive strip is not shared with
   third-party keyboards at all (technical doc §1) — any suggestion UI has to compete for space inside
   NumPad Type's own canvas, not sit above it. Budget vertical space for this in the layout design,
   don't assume it's "free" screen real estate the way it is for the system keyboard.
5. **No Genmoji.** Tied entirely to Apple Intelligence's own generation pipeline (technical doc §4).
6. **No key-press popup above the keyboard's own top edge.** Apple's Custom Keyboard guide blocks this
   explicitly; ship an in-bounds callout bubble instead (see V1 feature list above) and don't promise
   pixel parity with the system's floating popup.
7. **No cloud-assisted/ML autocorrect in V1.** Per the rules doc §1, that's an explicit, disclosed,
   opt-in enhancement behind Full Access at earliest — V1 ships fully on-device by construction, which
   is also the marketing wedge (§5/§6), not a compromise to apologize for.

---

## 3. V2 — multilingual rollout (rewritten, owner decision §0.7 — all languages, not Latin-first)

**The v1 draft of this section was wrong about which languages NumPad actually ships, and this
rewrite exists specifically to fix that, not just to add more locales on top of it.** V1 sequenced
"Spanish, French, German, Italian, Portuguese, Dutch" then "Turkish, Polish, Swedish/Norwegian/Danish,
Vietnamese" — but NumPad's repo has **no** `tr`, `sv`, `no`, `da`, or `vi` `.lproj` directories at all;
those languages aren't in NumPad's actual locale set. What the repo actually ships, verified directly
against `NumPad/*.lproj` and `Keyboard/*.lproj` (17 locales, both targets, confirmed via `ls`, not
assumed from CLAUDE.md's "16 localized languages" line): **`ar`, `de`, `en`, `es`, `fr`, `he`, `hi`,
`it`, `ja`, `ko`, `nl`, `pl`, `pt-PT`, `ru`, `zh-Hans`, `zh-Hant`, `zh-HK`.** `en` is the V1 baseline
(§2); this section covers the other 16 — and it covers **all** of them, not a Latin-script-only
subset, per the owner's explicit correction.

### Why "Latin-first" quietly dropped two locales NumPad already ships

The v1 tiering only had buckets for "Latin," "RTL," and "CJK" — which meant **Russian (`ru`,
Cyrillic script) and Hindi (`hi`, Devanagari script)**, both already-shipped NumPad locales, didn't
fit into *any* v1 tier and were silently absent from the whole plan. Neither is Latin-script, RTL, or
CJK/IME-class — they're LTR, non-Latin, non-IME, and each needs its own script/layout treatment. This
rewrite adds them as their own group precisely because the old tiering had no place to put them.

### Per-locale layout availability, grouped by actual engineering shape (not by geography or script family alone)

| Group | Locales | Layout | What's actually new engineering, beyond translation |
|---|---|---|---|
| **A — QWERTY-variant, diacritics only** | `es`, `it`, `nl`, `pt-PT` | Standard QWERTY, national dead-key sets (e.g. `es` ñ/accents, `it`/`pt-PT` accented vowels) | Lowest-risk: dead-key state machine on top of the V1 QWERTY canvas; no physical key-position changes |
| **B — Non-QWERTY Latin physical layout** | `de` (QWERTZ), `fr` (AZERTY) | Y/Z swap (`de`) or full letter-position remap (`fr`) plus their own dead keys | Real layout-variant work, not just diacritics — key *positions* differ from V1's QWERTY, not just which accented glyphs are reachable |
| **C — Latin, complex diacritic/AltGr handling** | `pl` | QWERTY-based, but the full Polish diacritic set (ą, ć, ę, ł, ń, ó, ś, ź, ż) needs an AltGr-style secondary layer or long-press accent picker | More dead-key/secondary-layer states than Group A, still no RTL/script-engine work |
| **D — Non-Latin script, LTR (the group v1 missed entirely)** | `ru` (Cyrillic, ЙЦУКЕН/JCUKEN layout), `hi` (Devanagari) | Real alternate-script keyboards — not a QWERTY variant at all | `ru` needs a genuine Cyrillic layout (JCUKEN is the standard, not a Latin-transliteration scheme); `hi` needs an explicit decision between a native Devanagari/INSCRIPT-style layout and a transliteration-input scheme (type Latin, get Devanagari) — that choice should get its own short spike before committing, since it changes the engineering shape substantially |
| **E — RTL** | `ar`, `he` | Mirrored key layout + RTL text flow | As described in the RTL subsection below — structural UI work, not a translation pass |
| **F — CJK / IME-class (staged separately, explicit scoping, not silently dropped)** | `ja`, `ko`, `zh-Hans`, `zh-Hant`, `zh-HK` | Full input-method-editor architectures (Kana/Kanji conversion, Hangul composition, Pinyin/Zhuyin/Cangjie/Jyutping depending on script and region) | Categorically different engineering problem from "another QWERTY variant" — see the CJK scoping subsection below. `zh-Hant` and `zh-HK` both use traditional characters but serve different input-method conventions (Taiwan vs. Hong Kong), so they don't collapse into one build even within "Chinese." |

### Rollout order — justified by actual sales locales, not script convenience

**This is a data gate this plan cannot fill in from research alone.** The owner's stated basis for
sequencing is that **NumPad has strong non-English sales** — but this plan doesn't have access to
NumPad's App Store Connect sales-by-territory report, so the honest position is: **pull that report
before finalizing rollout order**, and weight Groups A–F above by actual per-locale revenue, not by
which group looks easiest to an engineer. The engineering-risk grouping (A → B/C → D → E → F) above is
a reasonable *default* ordering *within* a revenue tier if two locales are close in sales — it is not
a substitute for the sales data itself. Concretely: if `ja` or `de` sales materially outweigh a
Group A locale's sales, that locale's tier assignment in §4's milestone table should move up
regardless of its engineering-risk group, and whoever owns App Store Connect access should be looped
in before Phase 4 (§4) is scheduled, not after.

### Autocorrect-lexicon sourcing per language (per `2026-07-05-oss-prediction-options.md`)

- **Where system `UITextChecker` covers the language:** no NumPad-side lexicon work — the system
  spell-checker already has the dictionary if the device's language pack is installed. Verify per
  language in Phase 0-equivalent spikes before assuming coverage (some minority-script or
  low-resource languages may have thin system dictionaries even where `UITextChecker` technically
  supports the locale) — this applies across Groups A–E; Group F is out of scope for `UITextChecker`-
  style autocorrect entirely (see CJK scoping below).
- **Where system coverage is thin or absent:** the prediction doc's deeper survey found the strongest
  fallback isn't Hunspell alone — **Helium314's `aosp-dictionaries`** (the community-rebuilt AOSP
  LatinIME word lists used by HeliBoard/FlorisBoard-adjacent projects) ships multiple languages beyond
  English under **CC BY-4.0**, which is a data-license attribution obligation (credits screen), not a
  code-license blocker — check per-locale coverage there before assuming a from-scratch build is
  needed. Hunspell remains a fallback for languages `aosp-dictionaries` doesn't cover, with its
  GPL/LGPL/MPL tri-license needing the same per-component legal read the prediction doc flags for
  English. SymSpell's approach ports to additional languages only if a suitable frequency corpus
  exists per language — treat as a build task per language, not a drop-in, same as v1's read.
- **RTL languages (`ar`, `he`):** confirm `UITextChecker` locale coverage before committing engineering
  time to the RTL layout work in Group E — if system coverage is thin, the lexicon-sourcing cost
  compounds with the RTL structural cost below.
- **`ru`/`hi` (Group D):** confirm `UITextChecker` Cyrillic/Devanagari coverage specifically — this is
  a real open question this plan hasn't spiked, precisely because v1's tiering never surfaced these
  two locales as needing it.

### RTL — summary of what's structurally new

Beyond the lexicon question above: mirrored key geometry (not just mirrored text direction), a
right-to-left-aware `StackView` layout mode, cursor/selection behavior sanity-checked against
`UITextDocumentProxy` in an RTL host context, Arabic-Indic vs. Western digit handling for the
swappable number row (§2) — a real per-locale decision point, and whether it's user-configurable — and
every existing overlay (Clipboard, Snippets, Tape, Conversion, Tax/Tip) re-verified for RTL chrome.
This is real UI engineering, not a translation pass, and keeps its own phase gate (§4) rather than
being folded into "just another locale."

### CJK — explicit staging, not a silent scope decision

Chinese (`zh-Hans`/`zh-Hant`/`zh-HK`), Japanese (`ja`), and Korean (`ko`) all require full IME
(input-method-editor) architectures — Pinyin/Zhuyin/Cangjie/Jyutping candidate composition, Kana/Kanji
conversion, Hangul composition — a categorically different engineering problem from "add another
QWERTY variant," closer to building a second product than adding a V2 locale. This plan **stages CJK
as its own explicitly-tracked decision (§4 Phase 7)**, not a silent omission and not a blanket
rejection either — the numbers/data-entry positioning (§1/§6) doesn't obviously carry into IME markets
the way it does into Latin-script/RTL markets, but whether that's still true depends on the sales-
locale data this section already flags as missing. Do not let "staged" quietly become "decided" —
Phase 7 exists so someone has to actively make and record the call once real sales/demand data exists.

---

## 4. MILESTONES, effort estimates, device-verification gates, memory budget, rollout strategy

### Effort key: S = <1wk, M = 1–3wk, L = 3–6wk, XL = 6wk+

| Phase | Workstream | Effort | Notes |
|---|---|---|---|
| **0 — Spikes (gate before any UI work)** | Text-Replacement lexicon spike (register a real shortcut, call `requestSupplementaryLexicon`, confirm it surfaces) | S | Technical doc §1 flags this MED, not HIGH — do not build UI around it unconfirmed. |
| | Memory spike: instantiate `UITextChecker` + basic QWERTY canvas in a throwaway extension target, profile against the ~50–70MB ceiling | S | Establishes the *remaining* headroom baseline before any prediction-layer decision (technical doc §1/§2). |
| | Typing-latency baseline spike: measure keydown→glyph-rendered latency on the throwaway canvas across an old (min-spec, e.g. iPhone SE-class) and new device | S | See device-verification gates below — this number gates go/no-go on the whole project, not just a nice-to-have metric. |
| | **OSS prediction offline harness (owner decision §0.6, pre-decision milestone — no device or extension build needed)**: build the typo-injection + keystroke-savings-rate corpus and score `UITextChecker`, AOSP-dictionary, and SymSpell candidates against it | S | Per `2026-07-05-oss-prediction-options.md` §"Test harness design" — this runs *before* Phase 1's UI work commits to an engine assumption, not after. Output feeds Phase 2's decision gate directly. |
| **1 — V1 core QWERTY** | Layout + `StackView` extension for QWERTY row shapes, shift/caps state machine, double-space-period | L | Reuses `StackView`/`Button` press-and-haptics plumbing per technical doc §5; new row-shape logic is the actual new work. |
| | **Parity-spec build item (owner decision §0.1)**: implement the QWERTY canvas against the screenshot-diff checklist as a build constraint, not a post-hoc check — geometry, color, shift/caps timing, callout bubble | M | The checklist itself is produced in this phase; the Phase 3 gate re-runs it against the finished build. |
| | **Period + comma on the main letter layer + single on/off switch, default ON (owner decision §0.2)** | S | Row-width/shift-key-resize implications documented in §2 — a deliberate, measured parity divergence, not an oversight. |
| | `UITextChecker` integration (guesses + completions), in-bounds key-press callout bubble | M | Free-floor engine per §2 recommendation. |
| | Globe key (tap + long-press list), cursor-drag gesture, own emoji keyboard | M | All technical-doc-confirmed "fully achievable" — implementation work, not research risk. |
| | **Swappable number-line top row + Grammar pack + pack-crossover wiring (owner decision §0.3)**: number row ⇄ pack-family toggle, Grammar pack authored first, existing packs wired per §2's crossover table | M | Builds on `CustomKeyboardLayout.bodyRows`' existing "arbitrary peripheral sections around a fixed body" generalization (technical doc §5) and the existing `ProductCatalog`/entitlement machinery — no new gating system. |
| | One-tap numpad-flip layer | M | The differentiating feature, distinct from the number-line swap above — flips the *entire* canvas to the numpad, not just the top row. |
| | **Setup wizard for both keyboards (owner decision §0.4)**: extend `OnboardingViewController`/`OnboardingStep`, new `packDisplayBehavior` `Constants` key + `SettingsSync` wiring, Settings re-entry point | M | Evolves the shipped 3-step flow — see §2 for the full LAST-USED/PRIMARY-SELECTED spec. |
| | Wire packs-as-optional-row, live math preview, Clipboard/Snippets/Tape overlay triggers, theme rendering (incl. Glass) | M | Mostly integration of already-shipped, input-agnostic engines — confirmed by technical doc §5's direct code read. |
| | Second extension target scaffolding: bundle ID, Info.plist, entitlements, App Group wiring, `ProductCatalog` gating hookup | S | `StoreManager` needs zero changes (already generic) — this is target/plist plumbing, not new monetization logic. |
| **2 — Prediction decision gate + hardening validation** | **Three-way decision (owner decision §0.6), not KeyboardKit-vs-nothing**: (a) ship the free floor as-is, (b) build whichever OSS candidate cleared all four harness gates (+15pp quality, ≤15MB memory, ≤16ms p95 latency, zero GPL) in Phase 0's offline pass, or (c) trial KeyboardKit Basic ($50/mo) | S (decision) + M (conditional build) | Decision gate, not a build task by default — only (b) or (c) become build work, and only if Phase 0's data supports it. Ship internal/TestFlight cohort on whichever path is chosen; measure real-usage quality vs. the `UITextChecker` baseline before wider rollout regardless of which path won the offline harness. |
| **3 — Hardening + GA gates** | Device-verification pass (latency budget re-check on full device matrix, key-target sizing study), memory ceiling re-profile with full V1 feature set loaded | M | See gates below — this phase can bounce work back to Phase 1 if it fails. |
| | **Parity-spec QA gate re-run (owner decision §0.1)**: the Phase 1 screenshot-diff checklist re-executed against the finished build, including the period/comma and number-line-swap states | S | This is the gate referenced in §0.1/§2 — a build that regresses on parity after Phase 1 blocks GA the same way a latency/memory regression would. |
| | RC kill-switch wiring (mirrors existing `custom_keyboard_drag_reorder_enabled` pattern) + staged TestFlight cohort rollout | S | Reuses the exact kill-switch architecture already shipped for Custom Keyboard drag-reorder (`3a0c1f16`). |
| | **§7 Absolute Definition of Done pass (owner decision §0.8)**: full checklist run, adversarial review to two consecutive clean passes | M | Gates GA independent of the other Phase 3 items passing individually — see §7. |
| | **Swipe legal-gate check-in (owner decision §0.5, decision only, no build)**: confirm whether US 7,706,616 has lapsed (due 2026-12-21) or been extended by a continuation, and check Cerence v. Apple's docket status | S (decision) | Not a Phase-3 build dependency — recorded here so the flagged swipe prototype (kept behind a feature flag per §2 non-goals) has an explicit re-check point tied to the GA hardening cycle rather than being forgotten until someone asks about it. |
| **4 — V2 Group A/B/C (rewritten per §3 — QWERTY-variant + non-QWERTY-Latin + complex-diacritic locales)** | `es`/`it`/`nl`/`pt-PT` (Group A, diacritics only), `de`/`fr` (Group B, real layout-position remap: QWERTZ/AZERTY), `pl` (Group C, AltGr/secondary-layer diacritics) | L | Per-language layout work; lexicon is free via system `UITextChecker` locale coverage where available (§3). **Actual sequencing within this phase depends on the ASC sales-locale data §3 flags as not yet pulled** — this effort estimate assumes all of Group A–C ship in one phase; split further if sales data says otherwise. |
| **5 — V2 Group D (non-Latin script, LTR — the locales v1 silently dropped)** | `ru` (Cyrillic/JCUKEN layout), `hi` (Devanagari layout-vs-transliteration decision spike, then build) | L | Real alternate-script keyboard work, not a QWERTY variant — see §3's explanation of why v1's tiering never surfaced these two already-shipped NumPad locales. |
| **6 — V2 Group E (RTL)** | `ar`, `he` — mirrored layout, RTL `StackView` mode, cursor/overlay RTL audit, Arabic-Indic vs. Western digit decision for the swappable number row | XL | Structural work, not translation — see §3. Gate on Groups A–D architecture proving out first. |
| **7 — V2 Group F (CJK) scoping decision** | `ja`, `ko`, `zh-Hans`, `zh-Hant`, `zh-HK` — explicit staged decision (build full IME support vs. scope out), pending real sales-locale data | S (decision only) | Do not silently drop this — record the decision so it doesn't quietly become a roadmap gap nobody chose. §3 deliberately does not pre-judge this call. |

### Device-verification gates (keyboards live or die on feel)

These are **hard gates**, not soft targets — a keyboard that feels laggy or mis-targets keys gets
uninstalled regardless of feature completeness, per every complaint-bank citation about the native
keyboard's own 2025–2026 latency/lag regressions (evidence bank Theme 1, items 1.3–1.8). NumPad Type
cannot ship with the same failure mode it's positioned against.

- **Typing latency budget:** target **sub-30ms keydown-to-glyph-rendered**, matching the one
  explicit numeric bar found in the competitive-landscape doc's synthesis (Grammarly is called out as
  the *only* keyboard in industry comparisons that misses this target, due to real-time analysis
  overhead — competitive doc, Grammarly profile). Measure on both a min-spec device (oldest
  officially-supported iOS 16 hardware) and a current-generation device — the gap between them is the
  real risk surface, not the current-gen number alone.
- **Key-target sizing research:** before finalizing row geometry, explicitly research/measure against
  Gboard's documented small-touch-target space-bar complaint (competitive doc, Gboard profile) and
  Apple's own Human Interface Guidelines minimum tap-target sizing — this is a named failure mode for
  a *market leader*, not a hypothetical; do not assume "we copied the system keyboard's proportions"
  is sufficient without a measured tap-accuracy pass, especially given NumPad Type's canvas now has to
  fit a persistent number row *and* the full QWERTY grid in the same vertical budget the system
  keyboard gives only to letters.
- **Memory budget table (against the ~50–70MB Jetsam ceiling, technical doc §1):**

| Component | Estimated footprint | Confidence |
|---|---|---|
| Existing NumPad numpad-extension runtime (baseline, already shipping) | Unknown exact figure — needs a real Jetsam-report profile pull as part of Phase 0, not assumed | — |
| `StackView`/`Button`/theme rendering for QWERTY row shapes | Marginal — same rendering primitives as today's numpad, more cells on screen | LOW estimate, verify in Phase 0 |
| `UITextChecker` + `UILexicon` (system APIs, not in-process models) | Minimal direct footprint — these run as system service calls, not loaded dictionaries in your own heap | MED, per technical doc §1's framing that these are the free/lightweight tier |
| Own emoji picker (Unicode data, category/search index) | Low, one-time asset load | LOW estimate |
| *(if pursued later)* naive in-memory n-gram bigram table | **10–60MB** — technical doc §2's own explicit math; this alone can eat most of the remaining headroom in a 50–70MB budget | LOW confidence per the technical doc's own framing — explicitly an estimate to validate, not a fact |
| *(safer later alternative)* small quantized neural model (FUTO ContextLM precedent) | ~1.5M parameters — technical doc §2's cited real-world comparable, meaningfully smaller than the naive bigram table | MED, based on FUTO's public architecture, not independently profiled in NumPad's own runtime |

  **Decision rule:** V1 stays entirely in the "minimal direct footprint" rows (`UITextChecker`/
  `UILexicon` only) — the bigram/neural-model rows are explicitly **out of V1 scope** and only enter
  the roadmap if Phase 2's KeyboardKit trial *also* underperforms expectations and a from-scratch
  prediction layer becomes the remaining option, which is a decision for a future phase, not this plan.

### Kill-switch / rollout strategy

Mirrors the pattern already proven for Custom Keyboard v2's drag-reorder feature (`3a0c1f16`) — reuse
the architecture, don't invent a new one:
1. **Local feature flag** (`FeatureFlags.fullKeyboardEnabled` or equivalent) — DEBUG/TestFlight-only
   visibility during Phases 1–2, matching the existing `FeatureFlags.customKeyboardDragReorderEnabled`
   precedent.
2. **Remote Config kill switch** — a production-side `full_keyboard_enabled` RC key, checked the same
   way `custom_keyboard_drag_reorder_enabled` gates today, so a bad-quality autocorrect regression or
   a device-class-specific crash can be killed server-side without an App Store resubmission cycle.
3. **Staged TestFlight cohort:** internal team → small external TestFlight cohort (target: enough
   volume to get real-usage autocorrect-quality signal, not a statistically rigorous sample — this is
   a qualitative "does it feel broken" gate before GA, matching Phase 2's validation step) → wider
   TestFlight → GA, with each stage requiring the latency/memory gates above to still hold, not just
   the previous stage's approval.
4. **GA is a second, independently-toggleable Settings → Keyboard entry**, not a replacement of the
   existing numpad extension — per the structural decision in §1, this containment is the primary
   mechanism protecting NumPad's existing 4.x rating if NumPad Type stumbles post-launch.

---

## 5. PRICING — monetizing without betraying "no subscription"

### The honest option analysis

| Option | Fit with "no subscription" | Fit with the $11.99 Pro anchor | Verdict |
|---|---|---|---|
| **Included in existing `numpad.pro.lifetime` ($11.99), no new SKU** | Perfect — zero new purchase decision, reinforces "Pro = everything" positioning already established by the moonshot roadmap's monetization doc | Strengthens the anchor: Pro's value proposition grows (every pack + premium themes + custom keyboard + iCloud sync + Kiosk height + **now a full keyboard**) without raising the price, which is exactly the kind of "anchor gets better over time" move that makes $11.99 feel like a bargain in hindsight rather than needing a price increase to justify new scope | **Recommended for V1.** No new pricing surface to design, test, or explain — ships inside a purchase flow that already exists and already converts (however weakly — moonshot §6 bullet 4 flags the 0.7%/$337 baseline honestly). |
| **New standalone non-consumable SKU (à-la-carte, like the 6 packs)** | Still no subscription — consistent with the existing model | Directly competes with the $11.99 anchor's *deliberate* positioning (CLAUDE.md: "the à-la-carte total sitting just under Pro is deliberate — the store anchors on Pro's extras") — a full keyboard priced as its own à-la-carte SKU either has to be priced high enough to not cannibalize Pro (awkward, since it's clearly Pro-tier scope) or low enough to undercut Pro's value story (worse) | **Rejected for V1**, revisit only if usage data shows most buyers want the keyboard *without* wanting the rest of Pro — no evidence for that segmentation exists yet, and manufacturing a new SKU before evidence is exactly the kind of "expensive to fake" mistake moonshot §6 warns against for the revenue bullet generally. |
| **Standalone paid app** | Still no subscription in isolation, but forces the "buy it twice" problem from §1's decision table — the rules doc confirms there is no native entitlement-sharing mechanism for non-consumables across apps | Would need to either duplicate Pro's price point in a second app (bad optics: "why do I have to pay $11.99 again") or discount via a Paid App Bundle (still a new purchase, not a benefit) | **Rejected** — already rejected at the structural-decision level in §1; repeating here only to confirm the pricing analysis doesn't reopen that door. |

### Recommendation

**Gate NumPad Type entirely behind existing `numpad.pro.lifetime`** ($11.99) and the 72-hour early-bird
variant where still applicable — no new SKU, no new price point, no subscription. This is consistent
with `Monetization.isCustomKeyboardEntitled`'s existing pattern (Custom Keyboard is *also* Pro-only,
not its own SKU) and treats NumPad Type as the same tier of feature: a platform capability that
deepens Pro's value, not a standalone product line. Free/à-la-carte-pack users see NumPad Type as a
locked feature behind the same deep-link upsell pattern (`numpad://store-preview?source=...`) used
everywhere else in the app today — zero new gating code paths, reuse `Monetization.isLocked`-style
helpers directly.

**Interaction with the $11.99 anchor:** this makes Pro's pitch materially stronger without raising its
price, which is the single highest-leverage move available given moonshot §6's honest read that
revenue proof (bullet 4) is the gating bullet for the whole acquisition narrative — a bigger, more
differentiated Pro tier at the same price is a direct lever on conversion, whereas a new SKU adds a
purchase-decision fork that the existing 0.7% conversion baseline doesn't obviously support adding.

---

## 6. RISKS, ranked, each with mitigation

### Existential risks (lead with these)

1. **Autocorrect quality below native = uninstall.** This is the single biggest risk to the entire
   project. The complaint-evidence-bank doc exists specifically because the *native* keyboard's
   autocorrect is under sustained, mainstream-press-documented criticism (WSJ, Macworld, MacRumors,
   two public "we fixed it" claims from Apple that press coverage shows didn't hold) — meaning the bar
   NumPad Type has to clear isn't "good," it's "noticeably not worse than a keyboard people are
   already actively frustrated with," while starting from a free-floor engine (`UITextChecker`) that
   the technical doc's own verdict calls **"good enough to not look broken, not competitive with
   Gboard."** If NumPad Type ships with a rougher autocorrect experience than the free system default,
   users don't file a bug report — they turn the extension off and never come back, and per the
   competitive doc's cross-cutting abandonment analysis, that first-impression window is narrow.
   - **Mitigation:** (a) never ship past internal-cohort TestFlight without the Phase 2 real-usage
     validation gate explicitly passing — "does it feel competent" is a qualitative bar, test it as
     one, not just via automated test coverage of the correction logic. (b) Per owner decision §0.6,
     Phase 2 is now a genuine three-way decision, not just a KeyboardKit escape hatch: the OSS
     prediction harness (Phase 0) scores AOSP-dictionary and SymSpell candidates against
     `UITextChecker` *before* any Swift is written, so "is there something better than the free
     floor" gets answered with pre-registered gates (+15pp quality, ≤15MB memory, ≤16ms p95 latency,
     zero GPL) rather than a late, expensive KeyboardKit trial being the only lever — keep the
     KeyboardKit Basic trial ($50/mo) as the fallback if nothing OSS clears the gates, not the first
     move. Don't let sunk-cost thinking on the free-floor path delay switching if either the harness or
     the trial data says so. (c) Lean into the positioning doc's explicit advice: **don't compete on
     "as smart as Gboard/SwiftKey"** — compete on the numbers-first workflow wedge where NumPad has a structural
     advantage no competitor has bothered to build, and be honest in V1 marketing that the number-row/
     numpad-flip/live-math-preview is the reason to switch, not "better autocorrect than Google."
     Setting the *marketing* expectation correctly reduces the review-quality risk from the *product*
     expectation gap.

2. **Secure-field bounce-back friction.** Per the technical doc §1 and the rules doc, the system keyboard
   silently swaps in whenever focus lands in a secure text field (passwords) or a phone-pad field, and
   swaps NumPad Type back out the moment focus leaves — this is a hard, undocumented-to-the-user OS
   behavior that the competitive-landscape doc's cross-cutting abandonment analysis names explicitly
   as "breaks the mental model": *"users experience this as 'my keyboard randomly stopped working'
   rather than understanding it as a deliberate OS security boundary."* For a keyboard whose whole
   pitch is numbers-first (PINs, one-time codes, banking apps — exactly the fields most likely to be
   secure/phone-pad-typed), this isn't an edge case, it's squarely in the target use case. A user
   entering a PIN, having the keyboard silently vanish and reappear as the stock one, and not
   understanding why, is a five-star-review-killer that has nothing to do with NumPad's own code
   quality and everything to do with an OS behavior no third-party vendor can fix.
   - **Mitigation:** (a) **proactive onboarding education** — explain the secure-field swap behavior
     explicitly during first-run setup ("you'll see your normal keyboard for passwords and PINs — that's
     Apple's security design, not a bug") rather than letting users discover it cold and misattribute
     it. (b) **In-app copy audit**: never imply NumPad Type "replaces" the system keyboard for secure
     entry — market it as "for everything else," setting the boundary explicitly rather than letting
     the OS behavior contradict an implied promise. (c) Track this specific complaint pattern in
     TestFlight/review-monitoring explicitly during rollout (§4) — if "keyboard disappeared" reports
     spike, that's a signal the onboarding copy isn't landing, fixable without touching the product.

### Secondary risks

3. **Cerence patent exposure, if scope creeps into V2/V3 swipe — broader than the original Kushler/
   Swype claims (owner decision §0.5).** Mitigation: already structural — swipe is an explicit
   non-goal in V1 (§2) and gated on legal review + litigation outcome before any V2+ commitment
   (technical doc §3; `2026-07-05-oss-swipe-options.md` §5). The dedicated swipe research added a
   concrete, dated re-check point: **US 7,706,616** (Cerence-owned, Zhai/Kristensson/ShapeWriter
   lineage, covers the classical corner/shape-matching decoding approach — not just neural swipe) is
   **ACTIVE and expires 2026-12-21**; the Phase 3 milestone table (§4) now carries an explicit
   "swipe legal-gate check-in" line item tied to that date so this doesn't quietly become a stale
   assumption. The discipline required here is *not* letting "but Gboard/SwiftKey have it" pressure
   pull swipe into scope before both that patent's status *and* Cerence v. Apple's resolution clear —
   and per the swipe doc, "clean-room reimplementation instead of adopting OSS" does **not**
   meaningfully reduce this exposure, so don't treat a from-scratch build as a legal workaround.

4. **Rating contamination — a rough NumPad Type launch drags down NumPad's existing 4.x average.**
   Mitigation: covered structurally in §1/§4 (separate opt-in extension, conservative TestFlight/RC
   staging) — the residual risk is real but is the accepted tradeoff of the extend-in-place decision,
   not something to re-solve here; monitor review sentiment specifically for typing-mode mentions
   during rollout and be willing to pull the RC kill switch fast rather than let a bad cohort ride.

5. **Memory ceiling regression as features accumulate across Phases 1–3.** Mitigation: the memory
   budget table (§4) is a running check, not a one-time Phase 0 pass — re-profile at the end of Phase
   1 (full V1 feature set) and again before GA (Phase 3), not just at the spike stage; a Jetsam kill
   in production is a silent, unreported crash from the user's perspective, exactly the kind of
   "feels broken, can't tell why" failure the whole project is trying to avoid causing.

6. **KeyboardKit/vendor dependency risk if Phase 2's trial leads to adoption.** Mitigation: per owner
   decision §0.6, this is now the *third* option evaluated, behind the free floor and any OSS
   candidate that clears the harness gates — reducing how often this risk should even trigger. If it
   still does: the technical doc's own framing applies — a recurring SaaS cost that never goes away
   and puts NumPad's core typing quality on someone else's pricing/roadmap. Treat any KeyboardKit
   adoption as a *reversible* decision (don't deeply couple UI code to their APIs beyond what's
   needed) and revisit at each tier pricing jump ($50 → $150 → $500/mo) as a fresh build-vs-buy call,
   not an autopilot upgrade.

7. **V2 CJK (Group F) scope ambiguity becoming a silent roadmap gap.** Mitigation: already addressed
   as a named Phase 7 decision point in §4 rather than an implicit omission — the risk isn't the
   technical difficulty, it's stakeholders assuming "multilingual" implicitly includes CJK until told
   otherwise. A related, newly-surfaced version of this same risk (owner decision §0.7): the v1 draft
   of §3 *also* silently dropped `ru` and `hi` — two locales NumPad already ships — because its
   Latin/RTL/CJK tiering had no bucket for non-Latin, non-RTL, non-IME scripts. §3's Group D exists
   specifically so this class of gap gets caught by the doc's own structure next time, not just this
   time.

8. **Marketing copy drifting into disparaging-Apple or competing-platform territory.** Mitigation: the
   rules doc §2/§3 gives clean, specific safe-lane copy examples ("the keyboard with a real number
   pad," "no Full Access required for core typing") — brief marketing against that doc directly before
   any public copy ships, and never name Android/Google Play in App Store metadata (the one
   well-precedented rejection trigger found in research).

9. **Setup wizard's LAST-USED vs. PRIMARY-SELECTED default (owner decision §0.4) picked wrong for a
   given user's habits reads as "the keyboard forgot my setting."** Defaulting to LAST-USED (§2)
   is a judgment call, not a measured one — a user who always wants Finance showing and occasionally
   detours into Grammar may perceive LAST-USED's "reopens on whatever I used last" behavior as broken
   state rather than working as designed. Mitigation: surface the choice explicitly in the wizard
   (§2) rather than only in a buried settings row, so the default is something users actively saw and
   could have changed, not a silent assumption; track wizard completion vs. later manual overrides of
   `packDisplayBehavior` as a signal the default is wrong for a meaningful share of users, and revisit
   the default (not just the option) if that signal shows up post-launch.

10. **Period/comma-on-main-layer default ON (owner decision §0.2) reads as "this keyboard is broken,
    the keys are in the wrong place" instead of "this keyboard fixed something."** The whole point of
    defaulting ON is to make the fix visible, but any layout change a user didn't ask for carries a
    real risk of being misread as a bug rather than an improvement, especially for users who
    muscle-memory-type without looking. Mitigation: the parity-spec workstream (§0.1/§2) exists partly
    to make sure the *rest* of the layout is unmistakably familiar, so this one deliberate change reads
    as a considered addition against a familiar backdrop rather than as one of several unexplained
    differences; call it out explicitly in the TRY IT step of the setup wizard (§2) rather than letting
    users discover it mid-sentence with no explanation.

---

## 7. ABSOLUTE DEFINITION OF DONE (owner decision §0.8)

The owner's mandate, verbatim: *"no mistakes, complete testing, ready for review and minor
cleanup."* This section turns that into a literal, checkable bar. **No phase in §4 counts as done
against this plan until every applicable item below is true for the work that phase shipped** — this
is a gate layered on top of each phase's own task list, not a replacement for it, and it applies
cumulatively (Phase 3's GA gate re-checks Phase 1's work too, not just Phase 3's own additions).

1. **100% of new pure logic is unit-tested.** Every non-UI, non-system-API-dependent function
   introduced by this project — shift/caps state transitions, double-space-period detection, the
   pack-crossover/pack-display-behavior logic, the parity-spec geometry calculations, any offline
   harness scoring code — has unit test coverage at 100%, not a percentage target with an
   acknowledged gap. `OnboardingEnableStep.shouldAutoAdvance`-style pure decision functions (already
   the pattern this codebase uses to keep UIKit-free logic testable) are the template to follow for
   every new decision point this project introduces.
2. **A full XCUITest E2E typing matrix**, including: parity screenshot-diffs (§0.1/§2/§4) against the
   native keyboard; the period/comma on/off switch in both states; the number-line swap (number row ⇄
   pack family, §2); the full setup-wizard flow for both keyboards (enable/disable QWERTY, default
   pack selection, LAST-USED vs. PRIMARY-SELECTED, re-run from Settings); all run on **both iPhone and
   iPad simulators** — not iPhone-only with an assumption iPad behaves the same, given this codebase's
   own documented iPad-specific quirks (the height-constraint iPad-drift bug, the floating
   mini-keyboard heuristic, the ≥700pt side-panel overlay mode all called out in `CLAUDE.md`).
3. **A measured typing-latency budget**, not an estimate — the sub-30ms keydown-to-glyph-rendered
   target from §4's device-verification gates, actually measured on both a min-spec and current-
   generation device for the finished build, with the number recorded, not just "felt fine in
   testing."
4. **A memory profile under the ceiling, with real margin** — the ~50–70MB Jetsam ceiling (technical
   doc §1), profiled with the full shipped feature set loaded (not just the Phase 0 spike's minimal
   canvas), showing headroom rather than a number that merely doesn't exceed the limit on the test
   device used.
5. **A device-verification checklist**, covering the min-spec/current-gen latency split, key-target
   sizing research (§4), and the parity-spec screenshot-diff pass, signed off per device class before
   any TestFlight cohort expands.
6. **Staged TestFlight + RC kill switches** live and tested before wider rollout — the
   `custom_keyboard_drag_reorder_enabled`-pattern local flag plus a Remote Config kill switch, per §4's
   kill-switch/rollout strategy, confirmed to actually disable the feature server-side, not just wired
   and assumed to work.
7. **Adversarial review repeated until two consecutive clean passes** — not one review with issues
   fixed and shipped; a second, independent pass finding nothing new before this counts as reviewed.
8. **Zero known CRITICAL or HIGH severity issues at hand-off.** MEDIUM/LOW may ship with a recorded
   follow-up; CRITICAL/HIGH may not, regardless of schedule pressure.
9. **Docs and localization current** — `CLAUDE.md` and this plan reflect what actually shipped (not
   what was originally planned, where the two diverged during implementation), and every locale this
   phase touched (§3) has its UI strings translated before that locale's build reaches TestFlight, not
   after.

---

## Sources

All findings above are attributed to the seven input documents named at the top of this file
(`technical-feasibility`, `competitive-landscape`, `complaint-evidence-bank`, `rules-and-structure`,
`oss-swipe-options`, `oss-prediction-options`, plus the moonshot roadmap) and the owner decisions
recorded in §0; no new external research was performed for this v2 synthesis beyond what those two
new OSS docs already carried out. Codebase architecture claims (`ProductCatalog` genericity,
`StackView`/`Button` reuse, `CustomKeyboardLayout.bodyRows` generalization, the `OnboardingViewController`
/`OnboardingStep` WOW→ENABLE→TRY IT machine, the `Constants`/`SettingsSync` cross-process pattern, and
the actual 17-locale `.lproj` set) were cross-checked against a `graphify query` pass and direct file
reads over the live repository, not assumed from the research docs alone.
