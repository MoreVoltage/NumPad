# Moonshot Council — Power-User Verticals

Date: 2026-07-03. Lens: **the professions that would pay 10x for a perfect numeric keyboard.**
Read-only research pass — no code changes. Branch `feat/2.0-ux-overhaul`.

Grounding read before ideating:
- `docs/plans/2026-07-03-pack-lineup-proposal.md` — Units & Conversion revival (dormant `UnitConverter`
  + `ConversionView`, gated by `FeatureFlags.conversionOverlay`), Cooking pack, decode-only legacy
  packs, Business & Invoicing candidate reusing `TaxTipMath`.
- `docs/plans/2026-07-03-b2b-validation-brief.md` — kiosk deployment reality: Bluetooth HID scanners
  **suppress the software keyboard entirely** (this rules out any "NumPad replaces the barcode
  scanner" idea outright — noted below); Guided Access/SAM/ASAM do *not* block it; Managed Open In
  and Intune App Protection can, unless deployed via ABM.
- `CLAUDE.md` — current overlay roster (Clipboard History, Snippets, Tax/Tip, Conversion, Result
  Tape, Pack Picker), Custom Keyboard v2 (drag reorder, handedness, three sections), iPad Kiosk
  height preset (Pro-gated, falls back to Tall), iCloud sync (`CloudSync`), the swipe-to-pin/delete
  interaction already shipped on `ClipboardHistoryView`.
- Codebase facts confirmed via `graphify` + targeted reads (not full-file browsing):
  - `TaxTipMath` (`SharedExtensions.swift:611`) — pure, tested tax/tip math, reusable pattern.
  - `UnitConverter` (`SharedExtensions.swift:793`) — linear + affine conversion engine, category-based.
  - `ResultTape` exists as a `Constants` key already (GA per CLAUDE.md) — the "adding-machine tape"
    concept is **already shipped in v1 form**; the ideas below extend it, not invent it.
  - `Keyboard/KeyboardViewController.swift:246-250` — NumPad **already** deep-links from the keyboard
    extension to the container app via the classic responder-chain `openURL:` selector trick
    (`numpad://store-preview`). This is Apple's unsupported-but-universally-shipped pattern (every
    third-party keyboard that deep-links to its own app uses it); it proves the "keyboard → app
    handoff for an action the extension itself can't do" path is *already working in production
    here*, which de-risks any idea below that needs a share sheet / export (the extension can't
    present `UIActivityViewController` reliably, but it can hand off to the app, which can).

Constraints applied to every idea: 50MB extension memory ceiling, no network without Full Access,
no Firebase in the extension, iOS 16 floor (iOS 26 APIs allowed behind `#available`), buildable
incrementally by a small team, no gimmick that dies in a week.

---

## 1. Ledger Tape Pro — for bookkeepers & accountants

**Pitch.** Small-business bookkeepers still buy $60-150 physical 10-key printing calculators in
2026 for one reason: the paper tape is an audit trail — every entry visible, subtotal-able,
correctable, and keepable as proof of work. NumPad already ships a GA Result Tape (a running log of
computed results). Ledger Tape Pro turns that from a scratch pad into the digital equivalent of the
adding-machine tape: **named, persistent tapes** (one per client, one per register-close), a
**subtotal key** and a **grand-total key** that behave exactly like a real 10-key's `⊂T⊃`/`＊`, a
**strike-last-line correction** (matches the physical machine's "if you fat-finger it, X out the
line, don't erase it" convention — audit trails value corrections, not silent edits), and a
**"Send Tape"** action that uses the *already-shipped* `openURL:` responder-chain handoff to open the
container app with the tape's text pre-loaded into a share sheet (Mail/Notes/Files/AirDrop) — the
extension itself never touches the network or a file system, it just hands a URL-encoded blob to an
app that already knows how to receive `numpad://` routes.

**Wow moment.** You close out a client's books entirely inside the numeric keyboard, tap "Send
Tape," and a clean line-by-line tape with subtotals is sitting in Mail before you've switched apps.

**Effort:** M — extends existing `ResultTape` model (persistence + naming + subtotal/grand-total
math is straightforward `Constants`/`@UserDefault` work) and existing overlay UI (`ResultTapeView`
already exists); the export step reuses a deep-link pattern the codebase already ships, not a new
one.

**Risk:** Low-medium. The one real unknown is URL length limits on the `openURL:` selector trick for
a multi-line tape payload — mitigated by capping tape length or passing a compact token the app
re-expands from `UserDefaults.group` (the tape is already in the shared app group; the URL only
needs to carry a tape ID, not the content).

**Wow-per-effort: 9/10.**

**First shippable slice:** persistent, named, multi-tape Result Tape with a Grand Total key —
no export yet. Ships value (audit-trail-style multi-tape bookkeeping) before the deep-link/export
piece is built, and validates the "does a bookkeeper actually use named tapes" question before
investing in export plumbing.

---

## 2. Field Conversion Ladder — for field engineers & tradespeople

**Pitch.** The pack-lineup proposal already flags Units & Conversion as worth reviving because the
engine (`UnitConverter`) and overlay (`ConversionView`) exist and just need GA promotion. This
moonshot pushes one step further for the audience that actually lives in unit chains: HVAC techs,
electricians, plumbers, and site engineers who don't convert length-to-length, they convert
**across domains** mid-calculation — a pressure reading in psi that needs to become bar for a
European spec sheet, or an Ohm's-law solve (`V=IR`, `P=VI`) where they know two of four values and
want the rest instantly. Add `.pressure` (psi/bar/kPa/atm/mmHg), `.torque` (ft-lb/N·m), `.flow`
(gpm/L-min), and an **Ohm's Law solver mode** (enter any two of V/I/R/P, get the other two) to
`UnitConverter` — all pure linear/algebraic math, all offline, same category-based pattern already
used for length/mass/temperature. Long-pressing "=" already opens `ConversionView`; this just widens
its category list and adds one non-linear solver mode using the same delegate contract.

**Wow moment.** On a job site with no signal, you type a reading, long-press "=", and see it already
converted to the three other units your spec sheets, your supplier, and your customer each use —
without opening a separate app or doing the math on a napkin.

**Effort:** M — no new subsystem, new `UnitConverter.Category` cases plus one solver mode reusing the
existing overlay UI and `ConversionViewDelegate` contract that Units & Conversion revival is already
scoped to promote to GA.

**Risk:** Low. Pure arithmetic, no network, no new architecture; the only judgment call is category
scope creep (resist adding every trade's pet unit — ship the four with the broadest cross-trade
overlap first).

**Wow-per-effort: 8/10.**

**First shippable slice:** add `.pressure` as a fifth `UnitConverter.Category` riding the Units &
Conversion pack that's already scoped to ship — proves the "widen categories" playbook cheaply
before building the Ohm's Law solver (a genuinely different UI: two-known-two-unknown, not a simple
pair conversion).

---

## 3. Position & Risk Calculator — for active traders

**Pitch.** Every serious day/swing trader either mental-maths position sizing (error-prone under
time pressure) or tabs out to a browser calculator (babypips.com, Van Tharp Institute, and a dozen
clones exist purely for this one formula) mid-trade. The formula is fixed and simple: `Position Size
= (Account × Risk%) / |Entry − Stop|`, plus the derived R-multiple and dollar-risk. This is exactly
the `TaxTipMath`-shaped problem NumPad already solved once (pure function, small overlay, delegate
pattern) — a new `PositionSizeMath` struct and a new overlay (`PositionSizeView`, structurally a
sibling of `TaxTipView`) bound to a long-press on a Finance-pack key. Entirely offline — no live
prices needed, which is exactly why the pack-lineup doc rejected "Crypto & Trading" (thin, needs a
live feed) but this idea doesn't: risk sizing needs only numbers the trader already knows and types.

**Wow moment.** You type your stop-loss distance, glance at a panel that's already showing "227
shares, $198 at risk, 1R defined" — sized and logged before your next candle closes, without ever
leaving the ticket-entry field for a separate app.

**Effort:** M — one new pure-math module (small, testable, same shape as `TaxTipMath`) and one new
overlay view cloned from the existing `TaxTipView` pattern; no new pack infrastructure, no new
gating primitives.

**Risk:** Medium — narrower audience than the other four ideas, and "audience size" here is a bet on
whether active traders adopt a niche numeric keyboard at all (unlike accountants/engineers, they're
not naturally numpad-first typists on mobile — most position sizing happens on desktop platforms).
Worth prototyping cheaply before marketing spend, not before the code — the code risk is low, the
demand risk is the real unknown.

**Wow-per-effort: 7/10.**

**First shippable slice:** static 4-field position-size overlay (account, risk %, entry, stop →
shares + $ risk + R) with no persistence and no new pack — bound to a long-press on an existing
Finance-pack key, so it ships as a value-add to a pack that already exists rather than requiring a
new SKU decision up front.

---

## 4. Cycle-Count Tally — for warehouse & inventory ops

**Pitch.** The B2B brief is explicit that a connected Bluetooth HID scanner suppresses the software
keyboard entirely — so this idea is deliberately **not** "NumPad replaces the scanner." It targets
the adjacent, still-huge reality: manual cycle counts and spot-checks on iPads with no scanner
attached (small warehouses, retail backrooms, restaurant walk-ins doing inventory) where a worker
keys quantities into a spreadsheet or inventory app field by field, tab-to-next, and has no way to
glance backward to catch a fat-fingered entry until the whole count is wrong. Add a **Tally** overlay
(same overlay+delegate shape as Clipboard History) that mirrors every committed entry (digits + the
Tab/Return that advances to the next field, using the *already-shipped* "repurpose next key" slot
mechanism) into a visible running list with a live sum, and reuses the **exact swipe-to-flag
interaction already shipped** on `ClipboardHistoryView` to mark a line "recount" instead of
pin/delete. Pairs naturally with the already-Pro-gated iPad Kiosk height preset (large touch targets,
warehouse iPad-on-a-cart use case it was already built for).

**Wow moment.** Halfway through a 200-line stockroom count, you glance up and the last six entries
are still sitting right above the keys — you catch the "45" that should've been "450" before you've
moved three shelves further down the aisle, instead of after the whole sheet is submitted.

**Effort:** L — new persistent-during-session list model, new overlay UI, and the swipe-flag
interaction, even though it's copying an established pattern rather than inventing one; genuinely
more moving parts than the other four ideas.

**Risk:** Medium — needs real warehouse-floor UX validation (does "glance backward" actually change
behavior, or do people ignore the tally under time pressure?), and it sits close enough to the
scanner-suppression constraint that marketing copy must be precise about "manual count companion,"
not "replaces your scanner," to avoid a wave of disappointed reviews from people who read "warehouse"
and assume scanning.

**Wow-per-effort: 6/10.**

**First shippable slice:** session-only (not persisted across keyboard dismiss/reopen), no swipe-flag
yet — just prove that typing digits + the next-key advance builds a visible, summed running list
above the keys. Cheapest possible test of "is the glance-backward workflow actually useful" before
investing in persistence and the swipe gesture.

---

## 5. Ratio & Proportion Solver — cross-vertical (broad, deliberately unbranded by profession)

**Pitch.** A huge set of professions solve the exact same "three of four numbers, cross-multiply for
the fourth" problem daily — pharmacy techs and nurses scaling concentrations, bartenders scaling
cocktail ratios for batch service, photographers diluting chemistry, gardeners mixing fertilizer
ratios, and the Cooking pack's own audience scaling a recipe from 4 servings to 11. Rather than
building a medical-flavored feature (which this brief is explicitly told to avoid — no dosage
claims), ship it as a **generic ratio solver**: `A : B :: C : ?` — type any three, the overlay
solves the fourth via simple cross-multiplication, entirely offline, no domain framing in the UI or
copy at all. The generality *is* the safety: nurses/pharmacy techs can self-select into a tool
marketed as "Ratio & Proportion," with zero medical claim exposure, while bartenders and
photographers get equal, honest value from the identical feature. Reuses the same
overlay+delegate shape as `TaxTipView`/`ConversionView` — no new architecture.

**Wow moment.** Type three numbers into an A:B::C:? layout and the fourth appears before you've
finished reaching for a calculator app — one tool, framed generically enough that four unrelated
professions each think "this is built for me."

**Effort:** S-M — smallest of the five: one pure function (cross-multiplication, already simpler
than `TaxTipMath`), one small overlay, no new pack, no new gating.

**Risk:** Low on the engineering side; the only discipline required is marketing restraint — never
let App Store copy, screenshots, or in-app hints drift toward "dosage," "medication," or any
health claim, ever. Keep it strictly "ratio and proportion math," the same register as a scientific
calculator.

**Wow-per-effort: 8/10.**

**First shippable slice:** single ratio-solve overlay (four fields, three filled solves the fourth),
bound to a long-press on an existing key (e.g., the Cooking pack's fraction row, since recipe-scaling
is its most natural first home) — no saved/favorite ratios yet.

---

## Summary table

| # | Idea | Vertical | Effort | Risk | Wow/Effort |
|---|---|---|---|---|---|
| 1 | Ledger Tape Pro | Bookkeepers/accountants | M | Low-med | 9 |
| 2 | Field Conversion Ladder | Field engineers/trades | M | Low | 8 |
| 3 | Position & Risk Calculator | Active traders | M | Medium | 7 |
| 4 | Cycle-Count Tally | Warehouse/inventory ops | L | Medium | 6 |
| 5 | Ratio & Proportion Solver | Cross-vertical (nurses/bartenders/photographers/cooks) | S-M | Low | 8 |

## Explicitly rejected direction

**"NumPad as a barcode-scanner companion"** was considered for the warehouse vertical and dropped —
the B2B brief already establishes that a connected Bluetooth HID scanner suppresses the software
keyboard at the OS level, so any idea premised on NumPad co-existing on-screen with an active
scanner is a platform dead end, not an engineering problem to solve around. Cycle-Count Tally (#4)
is the honest adjacent alternative: manual-entry counting, not scan-assisted counting.
