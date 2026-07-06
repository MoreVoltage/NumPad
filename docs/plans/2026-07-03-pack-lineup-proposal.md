# NumPad 2.0 — Pack Lineup & Pro Pricing Proposal

Date: 2026-07-03. Branch: `feat/2.0-ux-overhaul`. Research-only — no source changes.
Companions: `2026-06-24-2.0-monetization-and-scope-design.md`, `2026-06-24-2.0-deferred-log.md`,
`2026-06-24-2.0-ux-overhaul-design.md`, `2026-06-24-2.0-ship-checklist.md`,
`marketing/aso-sales-audit/pricing-packaging-analysis-v2.md`, `baseline-metrics.md`.

---

## 1. The problem, stated precisely

2.0 consolidated 12 pack options down to 5 (default + math free; Finance, Symbols & Science,
Programmer, Date & Time sold à la carte at $1.99 each). Pro lifetime is $11.99 and bundles all
packs + premium themes + the Custom Keyboard + iCloud sync.

Before consolidation, the monetization doc's original 9-pack plan priced Pro at $11.99 against
**9 × $1.99 = $17.91** of à la carte packs — buying everything individually cost **$5.92 more**
than Pro. That's a self-evident "just get Pro" nudge.

After the UX-overhaul consolidation, the à la carte total is **4 × $1.99 = $7.96** — Pro now costs
**$4.03 more** than buying every pack individually. The bundle-discount narrative flipped to a
bundle-*premium* narrative. A user who only cares about packs (not the Custom Keyboard, themes, or
iCloud sync) now has a strictly cheaper path than Pro, and the "why not just get Pro" nudge is gone.

That premium isn't unreasonable on its face — $4.03 buys the Custom Keyboard, premium themes,
iCloud sync, and all future packs — but it's an *implicit* subtraction the user has to do
themselves ($11.99 − $7.96). Nothing in the Store UI states it, and the anchor most users will
form is the blunter "$11.99 vs $7.96" comparison. That's the gap this proposal closes, from two
angles: new packs (grows the à la carte side back up) and/or a lower Pro price (shrinks the premium
directly).

---

## 2. Inventory: what's still in code from the 12→5 consolidation

`KeyboardType` (`NumPad/Libraries/Keyboard.swift`) and `PackKeys.symbols(for:)`
(`NumPad/Libraries/SharedExtensions.swift:766`) still carry five **decode-only** cases: `.units`,
`.scientific`, `.business`, `.international`, `.programmerPlus`. They exist purely so a
pre-consolidation user's persisted pack selection doesn't crash on decode — `KeyboardType.packs`
(the picker list) and `ProductCatalog.packProductID(for:)` (the store) both exclude them, and two
tests (`NumPadTests.swift:353` `testLegacyPacksAreNotSelectable`, plus the `PackCatalogTests`
suite) actively assert they stay unselectable and unsold.

**Important nuance the design doc glossed over as "absorbed":** the merge was not a clean 1:1
fold. Diffing the decode-only rows against the packs that supposedly absorbed them shows real,
un-migrated content:

| Decode-only pack | Its keys | Absorbed into | That pack's actual keys | Left behind |
|---|---|---|---|---|
| `.scientific` | `π e √ ^ ² ³ × ÷ ± °` | Symbols & Science | `% = π √ ^ ² ° × ÷ ± ≈` | `e`, `³` |
| `.business` | `$ € £ ¥ ¢ % ‰ ( ) #` | Finance | `$ € £ ¥ ₹ ¢ % ‰ ( )` | `#` |
| `.international` | `€ £ ¥ ₹ ₩ – — … ° №` | Finance | (same as above) | `₩ – — … №` |
| `.programmerPlus` | `0b != == && \|\| => -> { } _` | Programmer | `0x 0b & \| ^ << >> != == { }` | `&& \|\| => -> _` |
| `.units` | `cm m km in ft mi kg lb °C °F` | *(none — dropped entirely)* | — | all of it |

None of this is a live engine — every decode-only row (except `.units`'s underlying
`UnitConverter`, see below) is a static array of literal-text keys; tapping one inserts the label
verbatim. `Date & Time` is the only pack that's genuinely computed (`DateTimeTokens`, live values
at tap time).

**Revival cost is low, and asymmetric across candidates:**
- Re-selecting a decode-only pack (add to `KeyboardType.packs`, `ProductCatalog.packProductID`,
  `RemoteConfigManager.configureDefaults()`'s `packs_enabled` CSV, a `PacksViewController.PackOption`
  case, a `Products.storekit` + ASC product) is a few hours of plumbing — the pattern is
  copy-paste from the existing 4 packs and the tests already scaffold what "selectable" looks like.
- But three of the five (`.scientific`, `.business`/`.international`, `.programmerPlus`) are
  **too thin to be their own $1.99 SKU** — 4-5 leftover glyphs each, no distinct engine, largely
  redundant with a pack the user may already own. Reviving them *as new packs* would read as
  padding the catalog with near-duplicates, which cuts against restoring trust in the value story.
  Section 4 recommends folding these small leftovers back into their sibling packs as a **free
  quality bump** (no new SKU) instead.
- `.units` (Units & Conversion) is the one with real standalone merit — see below.

**`.units` is the one genuinely worth reviving, and it's cheaper than it looks:**
`UnitConverter` (`SharedExtensions.swift:716`) is a complete, tested, offline conversion engine
(length/mass/temperature, linear + affine) that already exists **independently** of the dead pack
row — it backs the `ConversionView` overlay (`Keyboard/Views/ConversionView.swift`), which is
**fully built and wired** to the `=` key (`KeyboardViewController.swift:386`,
`ConversionViewDelegate` at line 834) but sits behind `FeatureFlags.conversionOverlay`, off by
default (never promoted to GA in the Phase-3 pass — see the deferred log). Reviving Units &
Conversion properly means: (a) re-selecting the pack row (cheap, per above) **and** (b) promoting
`conversionOverlay` from experimental to GA and pairing it with the pack, so the key row isn't just
`cm`/`in` as literal text — it actually converts. That's a half-step, not a from-scratch build: the
hard part (the math + the overlay UI) is done and tested; the work is wiring + polish + gating.

---

## 3. Competitive scan (light)

- **This app's own live 1.7.x listing** (`apps.apple.com/us/app/numpad-your-number-keyboard`,
  developer "More Voltage") still advertises the pre-2.0 model: $2.99 app, $4.99 "All Packs
  Lifetime," Finance $1.99 standalone, 17 themes, "no subscription." Useful mainly as a reminder of
  the *before* anchor: at $4.99, Pro was priced under a single pack-and-a-half, an obviously good
  deal. The 2.0 repricing to $11.99 is a large jump from that anchor even before the packs math above.
- **Direct numpad-style competitors** (Remote KeyPad and NumPad — 300K+ downloads since 2016;
  NumPad+; Numpad by ALPA AB) are mostly free-with-a-Pro-unlock or one-time-purchase utilities with
  **no per-domain pack catalog** — they don't sell "Finance" vs "Programmer" separately. NumPad's
  à la carte pack model is comparatively unusual for this category, which cuts both ways: it's a
  differentiator, but there's no established competitor price anchor to lean on for "$1.99/pack" —
  the anchor has to come from Apple's own tier ladder and from general keyboard-app IAP norms.
- **General third-party keyboard apps** (SwiftKey, Kika, KeyPro, CleverType) skew **subscription**
  ($1.99–$12/month) for themes/AI features — the opposite of NumPad's stated "no subscription"
  differentiator (explicitly called out as a "do not change" in
  `pricing-packaging-analysis-v2.md`). One competitor, Fleksy, offers lifetime access at a flat
  $4.99 — a useful low-anchor data point for what "buy once" utility keyboards tend to charge.
  Nothing in this space suggests $11.99 is out of line for a lifetime-unlock non-consumable; the
  issue is internal (the à la carte math), not external positioning.
- **Adjacent niche apps** (unit converters, scientific calculators) are typically standalone
  free/freemium apps, not keyboard extensions — confirms Units & Conversion has real standalone
  search demand (people do look for "unit converter" as its own category) but no direct
  keyboard-extension competitor to benchmark price against.

Net: no competitor data forces a specific number. The lever is internal consistency between Pro and
the sum of packs, not external price matching.

---

## 4. Candidate packs — scored

Scored 1–5 (5 = best) on: **Audience** (how many users plausibly want it), **Frequency** (how often
someone who wants it actually uses it), **Effort** (5 = cheapest/lowest engineering risk, reusing
existing engines; 1 = a real new subsystem), **Bundle** (how much it strengthens "just get Pro"
adjacency — e.g., pairs naturally with a pack most Pro buyers already want).

| # | Candidate | Audience | Frequency | Effort | Bundle | Notes |
|---|---|---|---|---|---|---|
| 1 | **Units & Conversion** (revived + real conversion, not static text) | 4 | 3 | 4 | 3 | Engine + overlay UI already built (`UnitConverter`, `ConversionView`), just gated off. Broad, generic appeal (travel/DIY/fitness/students). Was previously judged "weakest pack" *as a static row* — pairing it with the real overlay changes that verdict. |
| 2 | **Cooking & Baking Measures** (fractions `½ ⅓ ¼ ⅔ ¾ ⅛`, volume units `tsp tbsp cup ml g oz`, a cups↔ml/g overlay) | 4 | 3 | 4 | 2 | New `UnitConverter.Category.volume` (same linear-factor pattern as length/mass — a few hours) + a static fraction row (same `PackKeys` pattern as Finance/Programmer). Reaches a demographic (home cooks) the app doesn't currently market to at all — real ASO/CPP diversification value per the marketing docs' keyword/CPP strategy, not just a feature. |
| 3 | **Business & Invoicing** (markup/margin %, discount-chain math reusing `TaxTipMath`, Net-30/due-date math reusing the `DateTimeTokens` pattern, leftover `#`/`₩`/em-dash glyphs from the old Business/International rows) | 3 | 3 | 4 | 4 | Narrower audience than Finance, but the *pairing* is the point: a freelancer/small-seller who wants Finance very plausibly also wants this — strengthens "get both, or just get Pro" rather than standing alone. Reuses two existing engines (`TaxTipMath`, `DateTimeTokens`'s token-wrapping pattern), no new subsystem. |
| 4 | Date & Time **power tokens** (business-day math, countdown/duration, week number, quarter, timezone shift) | 3 | 3 | 5 | 2 | Cheapest possible build (same `keyToken`/`value(for:)` pure-function pattern, zero new UI) — but Date & Time is already one of the 4 sold packs, so this is a **free enrichment to strengthen an existing SKU**, not a new one. Recommend shipping it as a quality bump, not counted toward the "new packs" total. |
| 5 | Statistics/Data (`σ μ x̄ %CI n=` + a running mean/stdev calculator) | 2 | 2 | 2 | 1 | Needs a genuinely new stateful engine (running dataset, not single-expression eval like `Calculator`) — real build effort for a narrow (students/analysts) audience. |
| 6 | Crypto & Trading (`₿ Ξ` glyphs, bps, ATH/ATL shorthand) | 2 | 1 | 4 | 1 | Cheap (symbol row) but thin and trend-chasing — no live price feed is realistic offline/in-extension, so it's static glyphs only, which is a weak value prop and fights the "no fads, useful utility" brand. |
| 7 | IP/Networking (dotted-decimal, CIDR, subnet helpers) | 1 | 2 | 3 | 1 | Cannibalizes the already-small Programmer buyer base rather than growing it — better as a free enrichment to Programmer (like the leftover `.programmerPlus` glyphs) than its own SKU. |
| 8 | Roman Numerals | 1 | 1 | 5 | 1 | Real but rare one-off need (engraving, sequels/monarchs) — almost no *repeat* daily use once satisfied. Better as a small free token (e.g., inside Date & Time, "this year in numerals") than a paid pack. |

---

## 5. Recommended lineup

**Ship as new à la carte packs (2, deliberately not more in one pass):**
1. **Units & Conversion** — $1.99. Revive the pack row *and* promote `conversionOverlay` to GA so
   it's a real converter, not a static symbol row. This directly answers the deferred log's own
   "weakest pack" verdict by fixing the actual weakness (no live conversion) rather than
   re-shipping the same static row.
2. **Cooking & Baking Measures** — $1.99. New audience, cheap build (extends the same
   `UnitConverter` work from #1 with a `.volume` category), strong ASO/marketing diversification.

**Good next-wave 3rd pack, not required for this pass:**
3. **Business & Invoicing** — $1.99. Ship once the first two prove the "add a pack" playbook
   still converts; its main value is the Finance-adjacency pairing (item 3 in the score table), so
   it's more valuable in a *following* release when there's attach-rate signal to justify it, than
   a same-quarter fire-and-forget bundle-stuffer.

**Fold quietly into existing packs as free quality bumps (no new SKU):**
- `.scientific`'s leftover `e`, `³` → Symbols & Science.
- `.business`/`.international`'s leftover `#`, `₩`, `–`, `—`, `…`, `№` → Finance (or reserve the
  distinctive ones for the new Business & Invoicing pack instead, if #3 ships — don't duplicate).
- `.programmerPlus`'s leftover `&& || => -> _` → Programmer.
- Date & Time power tokens (item 4) → Date & Time.

These are genuine value-adds for existing owners at zero marginal SKU cost, which also quietly
defuses "I paid for this pack and it's thinner than before" resentment from anyone who remembers
the pre-consolidation packs.

**Do not build (for now):** Statistics, Crypto, IP/Networking, Roman Numerals — thin, niche, fad-risk,
or cannibalizing an existing pack's audience rather than growing the total. Revisit only if a
specific user request or attach-rate data changes the calculus.

**Pro-only, unchanged:** Custom Keyboard, premium themes, iCloud sync, custom-keys pack row — these
remain Pro's non-pack differentiators and are the right place to keep exclusivity (per the existing
`2026-06-24-2.0-monetization-and-scope-design.md` decision — no reason to revisit).

---

## 6. Pricing call: reduce Pro to **$8.99**, and ship the two packs — do both

### The math that should drive the number

| Scenario | À la carte sum | Pro | Pro vs sum |
|---|---:|---:|---:|
| Pre-consolidation plan (9 packs) | $17.91 | $11.99 | Pro **saves $5.92** (33%) |
| **Current (4 packs)** | **$7.96** | **$11.99** | Pro **costs $4.03 more** |
| + 2 new packs (6 packs), Pro unchanged | $11.94 | $11.99 | Pro costs $0.05 more (a wash) |
| + 2 new packs (6 packs), **Pro → $8.99** | $11.94 | $8.99 | Pro **saves $2.95** (25%) |
| + 3rd pack later (7 packs), Pro at $8.99 | $13.93 | $8.99 | Pro **saves $4.94** (35%) |

Two single-lever fixes were on the table (per the task framing) and neither alone is as good as
both together:
- **New packs alone** (6 packs, Pro held at $11.99) only gets to a wash ($11.99 vs $11.94) — not a
  discount, just parity. Someone who wants all 6 packs is indifferent; someone who wants 2-3 is
  still better off buying à la carte. The core complaint isn't resolved.
- **Price cut alone** (Pro → $8.99 or $7.99, packs held at 4) fixes the ratio today but leaves the
  catalog thin — it's a purely defensive move that doesn't grow total addressable IAP revenue, and
  at $337/90-days on 180 downloads (`baseline-metrics.md`), this app needs *more things to sell*
  more than it needs to protect margin on a catalog few people are buying from yet (5 IAPs sold in
  90 days total, across the *old* pricing).

**Why $8.99 and not $7.99:** $7.99 lands almost exactly on today's $7.96 pack sum — it would make
Pro priced at *parity* with "buy everything," which erases Pro's premium entirely and gives a
Pro-curious user no reason to prefer Pro over packs even before the new packs ship (there'd be
zero premium for the Custom Keyboard, themes, and iCloud sync during the gap between this decision
and the new packs shipping). $8.99 keeps a small, defensible $1.03 premium over today's 4-pack sum
immediately, and becomes a real 25%+ discount once the 2 new packs land — it's the number that
works in both the "before" and "after" states, not just the end state.

**Why not hold at $11.99 and wait for packs to catch up:** the two new packs are genuinely new
engineering (Units needs the conversion-overlay promotion; Cooking needs a new `UnitConverter`
category) — there will be a real gap between "we decided to fix this" and "6 packs are live and
reviewed in App Store Connect." Holding Pro at $11.99 through that gap leaves the exact problem
this proposal exists to fix, unfixed, for however long that build+ASC-review window is. A price cut
is a same-day fix; new packs are a multi-week one. Do the cheap fix now and the structural fix on
its normal schedule.

**Grandfathering:** unaffected either way — existing Pro owners keep their entitlement regardless
of list price; a price *decrease* has no grandfathering implications (unlike the 1.7→2.0 increase,
which needed the grandfather-detection plumbing). New buyers simply see $8.99.

---

## 7. Implementation touchpoints (for whichever gets planned next)

- **Units & Conversion revival + GA conversion overlay:**
  `NumPad/Libraries/Keyboard.swift` (`KeyboardType.packs` += `.units`), `SharedExtensions.swift`
  (`ProductCatalog.packProductID` += `numpad.pack.units`, `RemoteConfigManager.configureDefaults()`
  `packs_enabled` CSV, flip `FeatureFlags.conversionOverlay` default from experimental to GA — same
  promotion pattern already used for Cursor Controls/Smart Pack Defaulting/Result Tape in Phase 3),
  `PacksViewController.PackOption` (+ case), `Keyboard/Libraries/Item.swift` (pack row already
  renders — just needs the overlay actually invoked from it), `NumPad/Products.storekit` + ASC
  (new $1.99 IAP), `NumPadTests.swift` (`testLegacyPacksAreNotSelectable` needs `.units` removed
  from `legacyDecodeOnlyPacks`, new coverage for the live-conversion path).
- **Cooking & Baking Measures:** `UnitConverter.Category` (+ `.volume`, tsp/tbsp/cup/ml/g factors),
  new `PackKeys`/`KeyboardType` case, same Store/picker/product wiring as above.
- **Business & Invoicing (later):** reuses `TaxTipMath` (margin/markup) and the `DateTimeTokens`
  token-wrapping pattern (due-date math) — same wiring pattern again.
- **Pro price cut:** ASC-only (owner-gated) — reprice `numpad.pro.lifetime` to $8.99, update
  `NumPad/Products.storekit` to match for simulator testing, refresh Store-screen copy/screenshots
  that show "$11.99," refresh any marketing copy in `marketing/aso-sales-audit/` that cites $11.99.
- **Leftover-glyph enrichment (Scientific/Business/International/ProgrammerPlus remnants):** pure
  `PackKeys.symbols(for:)` array edits to the *existing* Symbols & Science / Finance / Programmer
  cases — no gating changes, no new tests beyond updating the "expected keys" assertions in
  `PackCatalogTests.swift`.

## 8. Risks / owner-gated

- **ASC:** create `numpad.pack.units` (and later `.cooking`/`.business2` or similar) at $1.99;
  reprice `numpad.pro.lifetime` to $8.99 (existing owners unaffected); update the 49-locale IAP
  metadata pass for the new SKUs.
- **Copy/localization:** any Store-screen or paywall copy that states "$11.99" or lists "4 packs"
  needs updating in English plus the existing localization passes flagged as outstanding in the
  deferred log.
- **Attach-rate signal is thin:** 5 IAPs sold in the last measured 90-day window (pre-2.0 pricing)
  means there isn't yet real 2.0 attach-rate data to validate any of this against — treat the
  $8.99 number and the 2-pack lineup as the best-reasoned starting point, not a locked-forever
  price; revisit once 2.0 has a real conversion funnel running (the analytics scaffolding for that
  already shipped per `next-release-roadmap.md`).
- **Device/App Review:** new IAPs need the standard review-screenshot + description treatment;
  no new capability/entitlement risk beyond what's already tracked for 2.0.
