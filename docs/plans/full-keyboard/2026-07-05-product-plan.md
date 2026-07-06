# NumPad Type — Master Product Plan (working name)

**Date:** 2026-07-05. Planning doc only — no code changes, not committed.
**Inputs:** `2026-07-05-{technical-feasibility,competitive-landscape,complaint-evidence-bank,rules-and-structure}.md`
(this directory) and `docs/plans/moonshot/2026-07-03-roadmap.md`. Cross-checked against the live
`ProductCatalog`/`Monetization` architecture in `NumPad/Libraries/SharedExtensions.swift` (generic
over `ProductCatalog.allProductIDs` — confirmed via `graphify query`, not assumed).

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

### V1 feature list

**Parity baseline (per technical-feasibility §4/§6):**
- Full QWERTY letter layout + shifted symbol/number layer, matching system key geometry and spacing
  as closely as `UIInputViewController`'s canvas allows
- Shift/caps-lock logic, self-implemented against `UITextInputTraits.autocapitalizationType`
  (no keystroke-level OS assist exists — technical doc §4)
- Double-space → period, self-implemented buffer/detect/swap (no API assist exists)
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

**NumPad integrations that make this a "NumPad Type," not a QWERTY clone:**
- **Persistent number row** — a `1234567890` row always visible above/adjacent to QWERTY, not
  behind a `123` shift tap. This is the single most-cited, most durable complaint in the evidence
  bank (Theme 5 — outlived two full Apple autocorrect rewrites, still the top reader reaction as of
  the Apr 2026 iOS 27 rumor coverage) and the positioning doc's literal one-line pitch: *"the keyboard
  for people who type numbers."*
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

### V1 explicit non-goals (set expectations up front)

1. **Dictation is impossible, categorically, not "not yet."** No app extension type has ever had
   microphone access since iOS 8; this is Apple privacy policy, not a technical gap that a future iOS
   release could close (technical doc §1). Do not put a mic icon in the UI, even disabled — it invites
   "why doesn't this work" support load for a feature that structurally cannot exist.
2. **Swipe-to-type is deferred, not rejected — pending legal review of Cerence v. Apple.** The suit is
   active, unresolved, and filed against the single most defensible target in the industry (Apple
   itself) in Sept 2025 (technical doc §3). Treat as a separate, explicitly-gated V2+ decision, not a
   V1 requirement — building it now risks a full rebuild or worse if the legal read changes, and per
   the competitive doc, swipe is exactly the axis (per Fleksy's collapse) where NumPad has no
   structural advantage over Gboard/SwiftKey anyway. Do not market "swipe coming soon."
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

## 3. V2 — multilingual rollout

### Locale-by-locale strategy, tied to the engine path's actual locale support

`UITextChecker` and `UILexicon` are both system APIs — their language coverage tracks whatever
language packs the *user's device* already has installed system-wide, not something NumPad ships or
maintains per-locale. This means the free-floor engine's language coverage is **effectively free** to
extend: the work is the *keyboard layout* (QWERTY variants, AZERTY, QWERTZ, diacritics, dead keys)
and *UI localization*, not a from-scratch prediction model per language. This materially changes the
V2 cost model versus a KeyboardKit/Fleksy path, where each additional language is a metered SaaS
line-item (KeyboardKit Silver's "5 languages" vs. Gold's "75+" tiers, technical doc §2) — reinforcing
the recommendation to stay on the free floor into V2 rather than buying language coverage.

**Locale sequencing, tied to NumPad's existing 16 localized languages** (per the localization
commits already in the repo — `34b7a308`, `c561edc3` — the app is already carrying translation debt
across this locale set, so V2 sequencing should track it rather than open a second, unrelated locale
list):

1. **Tier 1 (launch alongside V1 stabilization, Latin-script, no layout surgery):** Spanish, French,
   German, Italian, Portuguese, Dutch — QWERTY/QWERTZ/AZERTY variants only, diacritic dead-key
   handling, existing NumPad UI strings already translated. Lowest engineering risk, largest
   addressable overlap with the existing install base's device-language settings.
2. **Tier 2 (layout + lexicon complexity, still Latin/near-Latin script):** Turkish (technical doc §4
   flags Turkish explicitly as needing its own keyboard, not auto-detected — a real layout-variant
   task), Polish, Swedish/Norwegian/Danish (diacritic-heavy but Latin), Vietnamese (diacritic stacking
   is a genuinely harder input method, likely needs its own dead-key/tone-mark state machine).
3. **Tier 3 (RTL — structural work, not just translation):** Arabic, Hebrew. RTL requires: mirrored
   key layout, right-to-left text insertion/cursor behavior via `UITextDocumentProxy`, RTL-aware
   punctuation/number handling (Arabic-Indic digit variants are a real decision point — does the
   persistent number row show Western or Arabic-Indic digits per locale, and is that configurable),
   and RTL-aware UI chrome for every overlay (Clipboard/Snippets/Tape/Conversion panels). This is the
   most expensive tier per locale and should not be scheduled until Tiers 1–2 have validated the
   underlying V2 architecture (layout-switching, per-locale UITextChecker routing) on lower-risk
   languages first.
4. **Tier 4 (CJK — likely out of scope for the QWERTY-typing product, real scoping call):** Chinese
   (Pinyin/Zhuyin input), Japanese (Kana/Kanji conversion), Korean (Hangul composition) all require
   full IME (input method editor) architectures — a categorically different engineering problem from
   "add another QWERTY variant," closer to a new product than a V2 locale add. **Recommend explicitly
   scoping CJK out of NumPad Type's roadmap** unless a later dedicated spec argues otherwise; the
   numbers/data-entry positioning (§1/§6) doesn't obviously carry into IME markets the way it does into
   Latin-script/RTL markets, and the engineering cost is an order of magnitude higher per locale.

### Autocorrect-lexicon sourcing per language

- **Tier 1/2 (system `UITextChecker` covers the language):** no NumPad-side lexicon work — the system
  spell-checker already has the dictionary if the device's language pack is installed. Verify per
  language in Phase 0-equivalent spikes before assuming coverage (some minority-script or
  low-resource languages may have thin system dictionaries even where `UITextChecker` technically
  supports the locale).
- **Where system coverage is thin or absent:** fall back to the open-source options surveyed in the
  technical doc §2 — Hunspell ships dictionaries for dozens of languages already (it's the engine
  behind macOS/Chrome/LibreOffice spell-check), with the tri-license caveat (GPL/LGPL/MPL) flagged for
  legal review before bundling into NumPad's closed-source paid app. SymSpell's frequency-dictionary
  approach is portable to additional languages if a suitable frequency corpus exists, but doesn't ship
  one beyond English out of the box — treat as a build task per language, not a drop-in.
- **RTL languages specifically:** confirm `UITextChecker` locale coverage for Arabic/Hebrew before
  committing engineering time to the RTL layout work in Tier 3 — if system coverage is thin, the
  lexicon-sourcing cost compounds with the RTL structural cost, which should factor into whether Tier
  3 is worth prioritizing ahead of Tier 4 CJK scoping-out, or whether both should be deprioritized
  relative to a KeyboardKit Silver ($150/mo, 5 languages, technical doc §2) trial once V2 is underway.

### RTL — summary of what's structurally new

Beyond the lexicon question above: mirrored key geometry (not just mirrored text direction), a
right-to-left-aware `StackView` layout mode, cursor/selection behavior sanity-checked against
`UITextDocumentProxy` in an RTL host context, and every existing overlay (Clipboard, Snippets, Tape,
Conversion, Tax/Tip) re-verified for RTL chrome — this is real UI engineering, not a translation pass,
and should get its own phase gate rather than being folded into "just another locale."

---

## 4. MILESTONES, effort estimates, device-verification gates, memory budget, rollout strategy

### Effort key: S = <1wk, M = 1–3wk, L = 3–6wk, XL = 6wk+

| Phase | Workstream | Effort | Notes |
|---|---|---|---|
| **0 — Spikes (gate before any UI work)** | Text-Replacement lexicon spike (register a real shortcut, call `requestSupplementaryLexicon`, confirm it surfaces) | S | Technical doc §1 flags this MED, not HIGH — do not build UI around it unconfirmed. |
| | Memory spike: instantiate `UITextChecker` + basic QWERTY canvas in a throwaway extension target, profile against the ~50–70MB ceiling | S | Establishes the *remaining* headroom baseline before any prediction-layer decision (technical doc §1/§2). |
| | Typing-latency baseline spike: measure keydown→glyph-rendered latency on the throwaway canvas across an old (min-spec, e.g. iPhone SE-class) and new device | S | See device-verification gates below — this number gates go/no-go on the whole project, not just a nice-to-have metric. |
| **1 — V1 core QWERTY** | Layout + `StackView` extension for QWERTY row shapes, shift/caps state machine, double-space-period | L | Reuses `StackView`/`Button` press-and-haptics plumbing per technical doc §5; new row-shape logic is the actual new work. |
| | `UITextChecker` integration (guesses + completions), in-bounds key-press callout bubble | M | Free-floor engine per §2 recommendation. |
| | Globe key (tap + long-press list), cursor-drag gesture, own emoji keyboard | M | All technical-doc-confirmed "fully achievable" — implementation work, not research risk. |
| | Persistent number row + one-tap numpad-flip layer | M | The differentiating feature — builds on `CustomKeyboardLayout.bodyRows`' existing "arbitrary peripheral sections around a fixed body" generalization (technical doc §5) rather than a fresh layout engine. |
| | Wire packs-as-optional-row, live math preview, Clipboard/Snippets/Tape overlay triggers, theme rendering (incl. Glass) | M | Mostly integration of already-shipped, input-agnostic engines — confirmed by technical doc §5's direct code read. |
| | Second extension target scaffolding: bundle ID, Info.plist, entitlements, App Group wiring, `ProductCatalog` gating hookup | S | `StoreManager` needs zero changes (already generic) — this is target/plist plumbing, not new monetization logic. |
| **2 — Free-floor validation, paid-engine decision gate** | Ship free-floor build to internal/TestFlight cohort; measure real-usage autocorrect quality vs. `UITextChecker` baseline | S | Decision gate, not a build task — go/no-go on KeyboardKit Basic trial. |
| | *(conditional)* KeyboardKit Basic ($50/mo) trial integration if free floor underperforms | M | Only if Phase 2's measurement says so — don't pre-build the integration speculatively. |
| **3 — Hardening + GA gates** | Device-verification pass (latency budget re-check on full device matrix, key-target sizing study), memory ceiling re-profile with full V1 feature set loaded | M | See gates below — this phase can bounce work back to Phase 1 if it fails. |
| | RC kill-switch wiring (mirrors existing `custom_keyboard_drag_reorder_enabled` pattern) + staged TestFlight cohort rollout | S | Reuses the exact kill-switch architecture already shipped for Custom Keyboard drag-reorder (`3a0c1f16`). |
| **4 — V2 Tier 1 (Latin multilingual)** | Spanish/French/German/Italian/Portuguese/Dutch layout variants + dead-key handling | L | Per-language layout work; lexicon is free via system `UITextChecker` locale coverage. |
| **5 — V2 Tier 2 (layout complexity)** | Turkish, Polish, Nordic languages, Vietnamese | L | Turkish and Vietnamese specifically carry real input-method complexity beyond "another QWERTY variant." |
| **6 — V2 Tier 3 (RTL)** | Arabic, Hebrew — mirrored layout, RTL `StackView` mode, cursor/overlay RTL audit | XL | Structural work, not translation — see §3. Gate on Tiers 1–2 architecture proving out first. |
| **7 — V2 Tier 4 scoping decision** | CJK — explicit scope-out recommendation pending a dedicated future spec | S (decision only) | Do not silently drop this — record the decision so it doesn't quietly become a roadmap gap nobody chose. |

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
     one, not just via automated test coverage of the correction logic. (b) Keep the KeyboardKit
     Basic trial ($50/mo) as a fast, cheap escape hatch already scoped into Phase 2 rather than a
     hypothetical — don't let sunk-cost thinking on the free-floor path delay switching if the trial
     data says so. (c) Lean into the positioning doc's explicit advice: **don't compete on "as smart
     as Gboard/SwiftKey"** — compete on the numbers-first workflow wedge where NumPad has a structural
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

3. **Cerence v. Apple swipe-patent exposure, if scope creeps into V2/V3 swipe.** Mitigation: already
   structural — swipe is an explicit non-goal in V1 (§2) and gated on legal review + litigation
   outcome before any V2+ commitment (technical doc §3); the discipline required here is *not*
   letting "but Gboard/SwiftKey have it" pressure pull swipe into scope before that gate clears.

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

6. **KeyboardKit/vendor dependency risk if Phase 2's trial leads to adoption.** Mitigation: the
   technical doc's own framing — a recurring SaaS cost that never goes away and puts NumPad's core
   typing quality on someone else's pricing/roadmap. Treat any KeyboardKit adoption as a *reversible*
   decision (don't deeply couple UI code to their APIs beyond what's needed) and revisit at each tier
   pricing jump ($50 → $150 → $500/mo) as a fresh build-vs-buy call, not an autopilot upgrade.

7. **V2 CJK scope ambiguity becoming a silent roadmap gap.** Mitigation: already addressed as a named
   Phase 7 decision point in §4 rather than an implicit omission — the risk isn't the technical
   difficulty, it's stakeholders assuming "multilingual" implicitly includes CJK until told otherwise.

8. **Marketing copy drifting into disparaging-Apple or competing-platform territory.** Mitigation: the
   rules doc §2/§3 gives clean, specific safe-lane copy examples ("the keyboard with a real number
   pad," "no Full Access required for core typing") — brief marketing against that doc directly before
   any public copy ships, and never name Android/Google Play in App Store metadata (the one
   well-precedented rejection trigger found in research).

---

## Sources

All findings above are attributed to the five input documents named at the top of this file; no new
external research was performed for this synthesis. Codebase architecture claims (`ProductCatalog`
genericity, `StackView`/`Button` reuse, `CustomKeyboardLayout.bodyRows` generalization) were
cross-checked against a `graphify query` pass over the live repository, not assumed from the research
docs alone.
