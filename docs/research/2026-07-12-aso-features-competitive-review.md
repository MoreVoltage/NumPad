# NumPad Growth Review — ASO, Feature Opportunities, Competitive Landscape

**Date:** 2026-07-12 · **Status:** FOR REVIEW — no implementation plan yet
**Inputs:** three parallel research passes — (1) 2025/26 iOS ASO best practices (22 web sources), (2) competitor landscape in three rings (31 sources), (3) exhaustive inventory of our own docs/plans, feature flags, and memory files.
**Constraint honored throughout:** compete **without over-complicating the existing product** — most recommendations below are packaging, metadata, and surfacing of things we already built, not new engineering.

---

## 0. Executive summary

1. **The direct competitive category is a graveyard, and we're already the deepest product in it.** One live minimalist rival (Numpad 2, $0.99, Sweden, active), one days-old cloner squatting "NumPad Pro" at $4.99-lifetime, and a pile of abandoned apps from 2019–2021. Nobody else has packs, overlays, themes, iPad side panel, App Intents, or a QWERTY page. The win condition is **distribution, not features**.
2. **Our biggest growth lever costs no code: metadata + screenshots.** Apple started indexing screenshot captions (June 2025), Custom Product Pages now serve in *organic* search with assigned keywords (July 2025), and IAP display names are indexed. Our current subtitle spends its 30 characters on low-search-volume benefit copy. A metadata/creative overhaul is the single highest-ROI action available.
3. **The demand signal is spreadsheet/data-entry pain, and no one owns it.** An unresolved Microsoft forum thread since 2023 (Excel on iPad won't show a numeric keypad), Apple's own docs acknowledging the pain, and an entire Amazon best-seller category of $20–40 Bluetooth numpads "for financial accounting." We can own the phrase "number pad for Excel" with keys we already ship (Tab/arrows).
4. **NumPad Type (QWERTY) is validated as genuinely unoccupied ground** — Gboard iOS frozen since May 2022, Fleksy/Typewise exited consumer, Microsoft removed Copilot from SwiftKey. But the category's failure mode is clear: a laggy QWERTY earns 2.8★. Quality bar before GA is non-negotiable.
5. **Monetization upside is mostly already designed in our own docs:** Try-Before-You-Buy pack trials, Ledger Tape Pro, Offer-Code referral loop, B2B kiosk packaging — all in the moonshot roadmap, none built. The competitive research independently confirms the accountant/bookkeeper tape features (Adding Machine 10Key proved the audience, then aged out).
6. **One strategic tension to decide:** we are a $2.99 **paid download** with IAP on top. Every live growth mechanic (trials, referral offer codes, CPP conversion, ASA economics) works better free-with-IAP. This is a decision item, not a recommendation — Pro pricing at $11.99 stays per the standing decision.

---

## 1. Where we stand (observed baseline, read 2026-07-12)

| Fact | Value | Note |
|---|---|---|
| Listing | "NumPad: Your Number Keyboard" (id1072547160) | |
| Subtitle | "Fast numbers, forms & finance" | Benefit copy, weak keyword value |
| Price model | **$2.99 paid** + 6 packs @ $1.99 + Pro $11.99 (+ $5.99 early-bird) | Unusual paid+IAP hybrid |
| Rating | 4.2★ / 231 ratings | 2nd-largest base among true numeric keyboards |
| Category | **Productivity** (#52) | Internal docs say Utilities — mismatch to resolve |
| Version | 2.0.0 live ~5 days | |
| Known copy bug | Description says "WHAT YOU GET FOR FREE" on a paid app | Already queued for 2.0.1 |
| Brand pollution | "NumPad Pro: Number Keyboard" (new, $4.99 lifetime), "NumPad+" (1.3★, dead) squat our name in search | |

---

## 2. ASO — what works in 2025/26

### 2.1 Mechanics that changed recently (facts, sourced in §8)

- **Search surface = 160 chars total:** Name (30) + Subtitle (30) + Keyword field (100). Name weighted highest. Description is NOT indexed on iOS. Never repeat a word across the three fields — each word counts once and permutes across fields.
- **Screenshot captions are indexed since ~June 17, 2025** (Appfigures finding, Apple-confirmed at WWDC25). Caption keywords *stack with* metadata keywords — repetition here is expected. One keyword theme per screenshot, caption top-of-frame, searchable phrasing.
- **Custom Product Pages became an organic surface (July 30, 2025):** assign keywords from your keyword field to a CPP and Apple serves that page in organic search for those terms. Limit raised to 70 CPPs (Oct 2025). Apple's own figure: +156% CVR for CPP-referred users.
- **IAP display names (30 chars × up to 20 promoted IAPs) are indexed** and permute with other metadata. In-App Event name (30) + short description (50) also indexed.
- **Apple Search Ads popularity scores broke Sept 29, 2025** (US keywords with popularity >5 collapsed ~166k→~39k). Long-tail volume data is now hidden; the ground truth is a cheap ASA Discovery/Search Match campaign's search-term report.
- **AI-generated tags (June 2025 beta)** derive from description + screenshots — the un-indexed description now indirectly influences discovery; write it with real feature vocabulary.
- **Featuring Nominations form** (ASC, since Nov 2024) is the formal editorial channel; submit 3–6 weeks before a beat. Editors score: UX, UI, innovation, uniqueness, **accessibility**, **localization**, product-page quality.
- **Cross-localization trick:** the US storefront indexes 9 extra locales — filling **Spanish (Mexico)** metadata (English terms allowed) roughly doubles indexed keyword space in the US without translating anything. en-AU also indexes en-GB. UK indexes only itself.

### 2.2 Ranked ASO actions for NumPad (all zero product-code)

| # | Action | Impact | Effort |
|---|---|---|---|
| 1 | Rebuild first 3 screenshots for 2.0 with keyword-bearing captions ("Number Pad for Spreadsheets", "Tax & Tip in Your Keyboard"), keyboard shown live in Excel/banking/PIN contexts | High | Med |
| 2 | Fill Spanish (MX) locale metadata; then en-GB/en-AU with *non-duplicate* variant keyword sets | High | Low |
| 3 | Audit the 160-char core: move "numeric keypad"/"10 key"-class terms into subtitle + keyword field, zero cross-field repeats, singulars, no spaces | High | Low |
| 4 | Featuring Nomination 3–6 weeks before next beat (and again at QWERTY GA) — one demoable signature story + accessibility/localization/App Intents notes | High-if-hit | Low |
| 5 | 3–5 Custom Product Pages with assigned keywords (tax/tip · Excel/data-entry · programmer · converter); reuse as press-kit and ASA variation URLs | High | Med |
| 6 | $5–10/day ASA Discovery/Search Match for 2 weeks **as keyword research** (post-Sept-2025 ground truth); graduate winners to exact; keep tiny brand-defense on "numpad" (blocks the squatters) | Med-High | Low-Med |
| 7 | Review prompts wired to success moments (completed tax/tip calc, Nth session) within the 3-per-365 cap; **do NOT reset the 4.2★/231 rating** | Med-High | Low |
| 8 | Rename promoted IAP display names as search phrases ("Unit Converter Pack", "Tax & Tip Money Pack") — indexed surface | Med | Low |
| 9 | Tax-season play each Jan–Apr: promo-text swap, tax screenshot to slot 2, In-App Event "Tax Season Toolkit" (indexed 30+50 chars), tax CPP + small ASA push | Med | Low-Med |
| 10 | PPO A/B at 2.0: first-screenshot variants, then icon. **Skip app-preview video** (evidence it's neutral-to-negative for productivity utilities) | Med | Low-Med |

**Validation task before locking metadata:** actual volumes for "number pad" vs "numeric keypad" vs "10 key" vs "keypad" are no longer publicly verifiable — action #6 answers this for ~$100.

### 2.3 Do-not-waste list (myths / banned)

- Keyword density in description (not indexed on iOS — Play Store cargo-culting).
- Repeating keywords across name/subtitle/keyword field (counted once).
- Plurals, "app", "free", spaces after commas in the keyword field.
- Incentivized reviews (Apple terminated 146k accounts in 2024 — expulsion risk).
- Ratings reset at 2.0 (keeps written reviews anyway, nukes 231-rating social proof).
- Keyword-stuffed app name (Guideline 2.3.7 rejection risk).
- Relying on ASA popularity scores (broken since Sept 2025).
- App preview video as a priority asset for this category.

---

## 3. Competitive landscape

### 3.1 Ring 1 — direct (numeric/number keyboards): a graveyard plus two live rivals

| App | Price | Rating | State | What matters to us |
|---|---|---|---|---|
| **Numpad 2** (ALPA AB) | $0.99 one-time | 4.5★/19 | **Active** (updated days ago) | The sharpest rival. Adaptive action key (decimal/tab/space), phone vs calculator layout (hold-"5" toggle), 1.9 MB, "no data collection," settings **without Full Access** as a headline. No monetization headroom at $0.99 — can't fund features. |
| **NumPad Pro: Number Keyboard** | Free + $4.99 lifetime | too few | **New** (v1.0.2, days old) | Fast-shipping cloner; squats "NumPad Pro" in search — collides with our Pro branding. Undercuts our Pro price. |
| Number Pad – Smart Keyboard | $3.99 | 4.3★/7 | Dormant | "10+5" auto-completes calculations; "stays available between cells" spreadsheet pitch — good idea, dead executor. |
| Number Row Keyboard | $1.99 | **2.8★** | Limping | QWERTY+number row with lag/crash reviews — **the cautionary tale for our QWERTY page**. |
| The Math Keyboard / Numboard / NumPad+ / SciKey etc. | $0–0.99 | 1.3–3.4★ | Abandoned 2019–2021 | Proven demand (math/scientific symbol entry), zero live supply. |
| **Symbol Keyboard+** (iSolid) | Free + $2.99–16.99 IAP | **4.5★/1,700+** | Coasting | Largest ratings base in the niche — symbol entry demand is real and monetizable. Our Symbols & Science pack can absorb this via ASO. |
| Adding Machine 10Key | paid | n/a | Old | Named/saveable/emailable **tapes** + audio key confirmation for eyes-free 10-key. The accountant-audience artifact; audience proven, product aged out. |
| Remote KeyPad and NumPad | freemium | n/a ("300k+ downloads" self-claimed) | n/a | People rig up an iPhone as a numpad *for their computer* — demand-intensity evidence. |

**Read:** we already have the deepest product and the 2nd-largest ratings base among true numeric keyboards. Nobody in Ring 1 can fund a feature race. Distribution is the game.

### 3.2 Ring 2 — majors (the feature bar, and why the moat holds)

- **Gboard iOS: last updated May 2022.** Google is pouring AI into Android only. Third-party keyboard competition on iOS is *weakening*.
- **SwiftKey:** Microsoft **removed** Copilot/Compose from the keyboard in 2025 — even Microsoft couldn't make in-keyboard AI stick.
- **Grammarly:** ~$5.99/mo sub; shipped a Liquid Glass redesign that earned press (validates our glass themes as a PR hook, not just a feature).
- **Fleksy:** exited consumer entirely (B2B SDK only, late 2024). **Typewise:** pivoted to B2B customer-service AI.
- **AI newcomers** (CleverType, BossAI, ReplyAI): all subscription, all reply/tone-focused, none touch numeric workflows.

**Moat:** majors optimize for conversation. They will never build tax/tip overlays, conversion keys, programmer packs, result tapes, or spreadsheet tab-flows. The bar they set for our QWERTY page is only: competent autocorrect + glide + clipboard.

### 3.3 Ring 3 — one separation away

- **Calculators** (PCalc $9.99, Soulver $14 one-time, Calcbot free+$2, Calzy $0.99): our live-math chip + result tape + conversion overlay ≈ Calcbot's entire paid tier. These users already pay for number tools — realistic acquisition source. Soulver at $14 proves a ~$15 anchor works for math utilities.
- **Unit converters** (Amount, Units Plus, Convertible): Apple **sherlocked the basics** — iOS Calculator now converts units/currency natively. Their remaining edge is live currency, which we deliberately don't do (offline-only decision stands).
- **Clipboard managers:** Paste is $9.99/yr with visible price-hike grumbling; Yoink $5.99 one-time. Wedge: "clipboard history built into your keyboard, no subscription."
- **Text expanders:** TextExpander ~$40/yr with a *weak* iOS story (expansion only inside its own keyboard). Our snippets + date/time tokens are closer to parity than it looks. Gap to credible casual replacement: **fill-in placeholders + snippet search**.
- **Spreadsheet data entry (the hot one):** Excel on iPad won't auto-show a numeric keypad — Microsoft thread unresolved since Aug 2023; Apple ships a special formula keyboard in Numbers (first-party acknowledgment of the pain); Amazon has a whole Bluetooth-numpad best-seller category marketed for "financial accounting" at $20–40. **People pay real money for hardware to fix what we fix in software.**

### 3.4 Positioning gaps (underserved, no owner)

1. **"Excel/Sheets iPad data entry" keyboard** — tab/next-cell workflows. We already ship Tab/arrow keys. Nobody owns the phrase.
2. **Accountant/bookkeeper 10-key** — eyes-free entry, exportable tape. Our result tape + Kiosk preset is ~70% there.
3. **Math/scientific symbol entry** — every dedicated app is dead; 1,700+ ratings of proven demand at Symbol Keyboard+. Our Symbols & Science pack absorbs this via ASO alone.
4. **Real QWERTY + real numpad in one keyboard** — genuinely unoccupied on iOS. This is NumPad Type.
5. **No-subscription utility bundle** — vs Paste/TextExpander sub fatigue: "keyboard + clipboard + snippets + converter, pay once."

### 3.5 Threats

- **Apple sherlocking** (already ate basic unit conversion; a system numpad layout would hurt — no evidence planned, but it caps how much we bet on any single overlay).
- **Price-floor erosion** — $0.99 / $4.99-lifetime anchors; AI-assisted cloners appear in *days*.
- **Brand-search pollution** — three unrelated "NumPad*" apps, one at 1.3★. (Mitigation: brand-defense ASA ≈ pennies; consider a trademark check.)
- **Full Access distrust** — the category's biggest conversion killer; Numpad 2 now *advertises* working without it. We're mostly fine here already — we should **say so** in the listing.
- **QWERTY quality bar** — sub-stock typing = 2.8★ (observed failure mode).
- **AI-keyboard noise** — "keyboard" head-term discovery keeps getting more expensive; our long-tail turf is defensible.

### 3.6 Steal-worthy features (competitor-observed, tagged by effort)

| Feature | Seen in | Effort | Attracts |
|---|---|---|---|
| "Works without Full Access" as a listing bullet | Numpad 2 | **Zero (copy only)** | Privacy-sensitive |
| Excel-mode *marketing* of existing Tab/arrow keys | MS-thread pain | **Zero (ASO/copy)** | Spreadsheet users |
| Adaptive action key (context-cycles decimal/tab/next) | Numpad 2 | Low | Data entry |
| Phone 1-2-3 vs calculator 7-8-9 layout flip | Numpad 2 | Low | Accountants |
| "Insert result" key on the live-math chip ("10+5" → tap → result typed) | Number Pad Smart Keyboard | Low | Everyday math |
| Symbol favorites/reorder | Symbol Keyboard+ | Low (Custom Keyboard nearly does this) | Science/engineering |
| Named, saved, exportable tapes | Adding Machine 10Key | Med | Accountants (Pro ammo) |
| Audio per-key confirmation, eyes-free 10-key | Adding Machine 10Key | Med | Pro data entry + a11y |
| Spacebar-glide cursor | Gboard | Med | QWERTY page (already on plan) |
| Snippet fill-in placeholders | TextExpander | Med | Support/sales pros |
| iCloud sync of pinned clipboard | Paste | Med-High | Multi-device (Pro ammo; security caveat: ours lives in keychain — deferred for a reason) |
| Live currency in conversion overlay | Amount/Calcbot | Med | Travel/finance (**conflicts with offline-only decision — listed for completeness, not recommended**) |
| Natural-language math ("20% of 150") | Soulver | High | Finance (partial via percent-natural parsing) |
| Liquid Glass as a press hook | Grammarly | Zero (PR angle) | Design press |

---

## 4. Internal feature-opportunity inventory (what our own docs already contain)

### 4.1 In flight — the big bet

- **NumPad Type (QWERTY page)** — flag-gated on `feat/qwerty-glide-and-accuracy`, Pro-gated with **no new SKU** (plan §5). Accuracy stack (lexicon re-ranking, personal dictionary, touch-offset personalization) is **built on branch**. [monetization][acquisition]
- **Remaining before GA:** onboarding QWERTY step, emoji keyboard, overlay/live-math triggers on the QWERTY page, cursor-drag-on-spacebar, Phase-0 prediction harness → engine decision, device gates (latency <30ms, memory vs ~50–70MB Jetsam), full E2E matrix, extension rename copy.
- **Glide typing:** designed, **not built**; dark-flag + legal gate. Patent US 7,706,616 active through **2026-12-21** — i.e., the legal risk window closes in ~5 months. Do not market "coming soon" (standing decision).
- **V2 multilingual (16 locales):** rollout order explicitly gated on the **ASC sales-by-territory report** — not yet pulled.

### 4.2 Shipped-but-hidden / cheap unlocks (code exists today)

- **Conversion overlay GA promotion** — engine + overlay fully built behind `FeatureFlags.conversionOverlay`; the Units/Cooking packs shipped per the 2026-07-03 decision. **Verify the GA promotion actually landed**; if not, it's a config-level unlock of a paid pack's core value. [monetization]
- **Custom Keys → custom packs + macros re-surface** — hidden screen, retained by design for a future re-surface (deferred log). [retention][monetization]
- **Decode-only pack leftovers** (`.scientific/.business/.international/.programmerPlus` glyphs) — fold into sibling packs as **free quality bumps**, per pack-lineup proposal (too thin to be SKUs). [retention]
- **Experimental flags ready to promote when desired:** locale-aware separators, save-snippet-from-keyboard, fast backspace-word-delete. [retention]

### 4.3 Planned with design docs (unbuilt)

- **Long-press secondary functions on Custom Keyboard keys** — full 2-phase design doc; inherits Pro, no new gate. [retention][monetization]
- **Custom Keyboard follow-ups:** token dispatch, per-key color/size, label override, **Keyboard Cards** export/import (`.numpadkbd` AirDrop loop — social/acquisition, no server by design). [acquisition][retention]

### 4.4 Moonshot roadmap (docs-only; competitive research independently validates the bolded ones)

- **Tier 1:** Lucky Digits (delight/share) · Live Tape widget · **Ledger Tape Pro v1 (named multi-tapes + grand total — matches gap #2 and Adding Machine 10Key evidence)** · **Try Before You Buy (time-boxed real-output pack trials — the designed answer to paid-conversion friction)** · **Kiosk/Fleet B2B packaging (sell today's binary via ABM — "no new engineering")**.
- **Tier 2:** The Receipt (shareable tape artifact) · **Offer-Code referral loop ("Gift a Pack")** · Field Conversion Ladder · Ratio solver · Ledger Tape v2 export · Keyboard Cards · Bundles (3rd price anchor, needs Store row) · **CPP + ASA persona funnel (now directly supported by the 2025 CPP organic changes — §2)** · Numeric Workspace API · Spotlight snippets · Pack Foley · Sass Mode.
- **Tier 3 (need spikes first):** Running Tab (Live Activity from extension — spike required) · Ask the Number (on-device FoundationModels behind `=` — spike required: callable from extension?) · Continuity Numpad · Wrist Tally · vertical calculators.
- **B2B:** Product A (Kiosk, sellable today, zero committed customers) vs Product B (SDK, **owner-gated: no engineering until a discovery call lands with stated budget** — standing decision).

### 4.5 Guardrails — already decided NOT to do (do not re-propose)

Mascots · hosted sharing backend · visionOS · standalone Handoff · bespoke StandBy · barcode-scanner replacement · crypto/live-market data · medical dosage framing · "themes/overlays as the moat" claims · generic AI wrapper · Ask-the-Number UI before the spike · dictation (impossible in extension) · inline ghost-text · Genmoji · cloud autocorrect in V1 · standalone $4.99 custom keyboard SKU · **Pro price cuts (STAYS $11.99 — deliberate à-la-carte anchoring)** · live-FX currency (offline-only) · plaintext clipboard iCloud sync · Statistics/Crypto/IP-networking/Roman-numeral packs.

---

## 5. Synthesis — the shortlist, filtered for "don't over-complicate"

Grouped by cost shape. Evidence column shows *why* (competitor/demand/ASO cross-reference).

### Tier A — Zero product code (metadata, config, copy, store ops)

| # | Item | Evidence | Impact | Effort |
|---|---|---|---|---|
| A1 | Metadata overhaul: subtitle + keyword field + no-dup audit (§2.2 #3) | Caption/keyword mechanics; current subtitle wastes 30 chars | High | Low |
| A2 | Screenshot rebuild with indexed captions; Excel/banking/PIN contexts (§2.2 #1) | June-2025 caption indexing; first-3-screenshot conversion | High | Med |
| A3 | ES-MX + en-GB/en-AU cross-localization (§2.2 #2) | Doubles US-indexed keyword space, free | High | Low |
| A4 | 3–5 CPPs with assigned keywords (tax/tip, Excel, programmer, converter) | July-2025 organic CPP serving; +156% CVR (Apple's figure) | High | Med |
| A5 | ASA: 2-week Discovery research burn + permanent brand defense on "numpad" | Popularity data broke Sept 2025; squatters on our name | Med-High | Low |
| A6 | IAP display-name renames as search phrases | IAP names indexed | Med | Low |
| A7 | Featuring nomination cadence (2.0 now; QWERTY GA later) | Formal ASC channel; editors score a11y/localization/App Intents — we have all three | High-if-hit | Low |
| A8 | Review prompts at success moments; no rating reset | 3/365 cap; velocity signal; 231 ratings = social proof | Med-High | Low |
| A9 | "Works without Full Access for core typing" + "No subscription. Pay once." listing bullets | Numpad 2 headlines it; Paste/TextExpander sub fatigue | Med | Zero |
| A10 | Tax-season playbook (Jan–Apr, recurring) | Seasonal query spike + our TaxTip overlay | Med | Low |
| A11 | Fix "WHAT YOU GET FOR FREE" copy (already queued) + resolve Productivity-vs-Utilities category | Paid-app copy mismatch kills trust | Med | Low |
| A12 | Kiosk B2B landing page + quote form (sell existing binary) | Moonshot Tier 1 #5: "no new engineering" | Med (new revenue shape) | Low-Med |

### Tier B — Small product features, high fit (each ≤ a few days, no architectural change)

| # | Item | Evidence | Tag |
|---|---|---|---|
| B1 | "Insert result" key on the live-math preview chip | Number Pad Smart Keyboard's one good idea; extends existing chip | retention |
| B2 | Adaptive action key / "Excel mode" slot preset (decimal↔tab↔next-cell), then market gap #1 hard | MS thread unresolved since 2023; $20–40 hardware pads | acquisition |
| B3 | Calculator-layout flip (7-8-9 top) as a setting | Numpad 2; accountant muscle memory | acquisition |
| B4 | Free pack quality bumps: fold decode-only leftover glyphs into sibling packs | Our own pack-lineup proposal; defuses "thinner than before" | retention |
| B5 | Promote conversion overlay to GA if not already live (verify first) | Paid pack's core value behind a dead flag would be a bug-class miss | monetization |
| B6 | Snippet fill-in placeholders + snippet search | TextExpander's $40/yr weakness; makes "text expander included" credible | acquisition/monetization |
| B7 | Named/exportable tapes (Ledger Tape v1) + optional audio key-confirmation | Gap #2; Adding Machine 10Key audience orphaned; Pro ammo | monetization |
| B8 | Try Before You Buy pack trials (pilot on Units, per moonshot design) | Directly attacks paid+IAP conversion friction | monetization |
| B9 | Offer-Code "Gift a Pack" referral loop | Apple-native, no server, acquisition loop | acquisition |

### Tier C — The bet already in motion (sequence, don't expand)

- **C1 — NumPad Type GA** is the one big thing. Market validation is strong (gap #4, Gboard frozen, majors retreating). The plan's own quality gates (latency, memory, parity) are exactly right — the 2.8★ Number Row Keyboard is what shipping early looks like. No new scope: finish the existing checklist (§4.1).
- **C2 — Glide**: hold behind the dark flag as planned; note the patent window closes 2026-12-21 — a legal check in Q4 could clear GA marketing for early 2027, aligning with a "NumPad Type + glide" featuring beat.
- **C3 — Multilingual V2**: pull the ASC sales-by-territory report (the plan's own explicit data gate) before ordering locales; pairs with the cheap metadata-localization wins in A3.

### Explicitly NOT recommended (would over-complicate)

Subscriptions of any kind · AI/LLM features before the FoundationModels spike · live currency FX · new pack SKUs beyond the six until attach rates prove out (standing decision on Business & Invoicing) · NumPad SDK engineering before a funded discovery call (standing decision) · app preview video · chasing the "keyboard" head term · any Ring-2 feature parity beyond autocorrect/glide/clipboard.

---

## 6. Risks & caveats

- **Source quality:** ASO lift percentages are vendor estimates (Appfigures, SplitMetrics, etc.); mechanics (limits, what's indexed) are fact-grade and corroborated. Competitor ratings/prices read 2026-07-12 from US listings — they drift. "300k downloads" is a developer self-claim. Copied's death is inferred from absence.
- **Keyword volumes are unverifiable post-Sept-2025** — the ASA discovery burn (A5) must precede locking the 160-char metadata (A1). Sequence matters.
- **Paid-download drag:** every conversion mechanic above operates behind a $2.99 gate that no direct competitor except Number Pad Smart ($3.99, dormant) still charges. Tier A/B actions improve funnel top and middle; the gate itself is the untested variable.
- **Sherlocking cap:** don't deepen dependence on any single overlay that Apple could absorb next WWDC; packs + workflow keys (tab/next-cell, tapes) are more defensible than generic conversion.
- **Cloner speed:** the days-old "NumPad Pro" shows ideas get copied in days — features are defensible only in aggregate; brand + ratings base + distribution are not copyable.
- **QWERTY reputational risk:** a bad NumPad Type GA can drag the flagship's 4.2★ down (single listing, shared rating). The device gates in the plan are the mitigation; they need a physical device pass.

---

## 7. Open decisions (numbered — respond by number)

1. **Business model check-in:** stay $2.99-paid + IAP, or study free-with-IAP for acquisition (Try-Before-You-Buy is the designed middle path)? *No change proposed to Pro $11.99 — that decision stands.*
2. **Metadata rewrite scope (A1–A3):** approve subtitle/keyword-field rewrite + ES-MX/en-GB/en-AU cross-localization? (Blocked only by the ASA research burn, ~2 weeks, ~$100–150.)
3. **Screenshot/CPP production (A2, A4):** approve building the new screenshot set + 3–5 CPPs? Which personas first — tax/tip, Excel/data-entry, programmer, converter?
4. **ASA standing budget:** approve ~$5–10/day research burn + ongoing brand-defense campaign?
5. **Category:** keep Productivity or move to Utilities (secondary keeps the other)?
6. **Tier B picks:** which of B1–B9 go into the next release train? (My read of best value-per-complexity: B2 "Excel mode" + B5 verify-conversion-GA + B4 free glyph bumps + B8 trials.)
7. **Kiosk B2B (A12):** green-light the landing page + quote form (marketing-only, no engineering)?
8. **Featuring nomination (A7):** nominate now on 2.0 + In-App Event, or wait for the QWERTY GA beat?
9. **Glide legal check (C2):** schedule patent/legal review for Q4 2026 ahead of the 2026-12-21 expiry?
10. **ASC territory report (C3):** pull sales-by-territory now to unblock the multilingual rollout order?
11. **Brand protection:** any appetite for a trademark screen on "NumPad" given the squatters, or rely on ASA brand defense only?

---

## 8. Key sources (abridged; full URLs in the research transcripts)

- **ASO mechanics:** developer.apple.com (PPO, featuring, review guidelines, IAP reference) · appfigures.com (2025 algorithm/caption indexing) · respectaso.com (ASA popularity break; CPP 2026 guide) · aso.dev (cross-localization; search-term rank) · asomobile.net, apptweak.com, lexogrine.com (field mechanics) · techcrunch.com (AI tags).
- **Competitors:** apps.apple.com listings for Numpad 2 (id6476788277), NumPad Pro (id6764050280), Number Pad Smart (id987232515), Number Row (id1264816696), Math Keyboard (id917470088), Numboard (id1175536307), Symbol Keyboard+ (id1551472227), Adding Machine 10Key (id392883834), Remote KeyPad (id1135331999), Gboard (id1091700242), Grammarly (id1158877342) · fleksy.com · support.microsoft.com (SwiftKey Copilot removal) · pasteapp.io/pricing · textexpander.com · soulver.app.
- **Demand:** techcommunity.microsoft.com (Excel iPad keypad thread) · support.apple.com (Numbers formula keyboard; iOS Calculator conversions) · amazon.com Numeric Keypads best-sellers · discussions.apple.com.
- **Pricing landscape:** adapty.io State of In-App Subscriptions 2025 · revenuecat.com lifetime-subscription guidance.
- **Internal:** docs/plans/ (full-keyboard, moonshot, pack-lineup, secondary-keypress, b2b-validation, 2.0-deferred-log) · marketing/aso-sales-audit/ · NumPad/Libraries/SharedExtensions.swift (FeatureFlags L589, RemoteConfig L1551) · project memory files.
