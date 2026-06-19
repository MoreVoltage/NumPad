# Pricing and Packaging Hygiene — Recommendations

Date: 2026-06-18
App: NumPad (`com.morevoltage.NumPad`), version 1.7.2 line
Scope: catalog hygiene + pricing **recommendations** for App Store Connect.

> [!IMPORTANT]
> **This is a recommendation memo only.** It does **not** change any price, does
> **not** submit anything for review, and does **not** call App Store Connect live.
> Every action below is to be performed manually, by a human, in the ASC UI (or via
> the reviewed `marketing/asc/iap_admin.py` helper in dry-run first). Nothing here is
> a live change.

---

## 0. TL;DR

| Item | Recommendation | Live cost | Confirm where |
|---|---|---|---|
| Finance Pack price | Hold at the equivalent of **$1.99 USD** (do not change) | $0 | **Confirm the real live price in ASC** — the `$1.99` in code is a fallback string, not authoritative |
| Family Sharing — Pro Lifetime | Turn **ON** | $0 marginal | ASC > IAP > `numpad.pro.lifetime` |
| Family Sharing — Finance Pack | Turn **ON** | $0 marginal | ASC > IAP > `numpad.pack.finance` |
| 7 legacy draft IAPs | Review, then **delete the ones with no sales history** | $0 | ASC > Monetization > In-App Purchases |
| Per-market pricing | **Hold everywhere now.** Re-evaluate India/MEA + LatAm lower tiers only after page conversion improves and 1.8 funnel analytics ship | $0 (study only) | — |

---

## 1. Finance Pack price reconcile

**Finding.** The codebase shows `$1.99` for the Finance Pack, and v2's analysis
estimated the Finance Pack at ~$1.99. These two numbers agree — but **neither is the
source of truth for what users are actually charged.**

The `$1.99` lives in the StoreKit display layer as a *fallback string*:

- `NumPad/Controllers/StoreViewController.swift:380`
  `price(for: StoreManager.shared.financeProduct, fallback: "$1.99")`
- `NumPad/Controllers/StoreViewController.swift:212-214`
  `return product?.displayPrice ?? fallback`

That fallback is only shown when StoreKit has **not** loaded the live product
(cold launch, offline, or App Store hiccup). The moment `Product.displayPrice`
arrives from Apple, the real ASC price replaces it. So `$1.99` is a placeholder to
avoid an empty cell — it is **not** the configured price and can silently drift from
the live price. (For reference, Pro Lifetime has the same pattern with a `$4.99`
fallback at `StoreViewController.swift:370`.)

**Recommendation.**
1. **Keep the Finance Pack at the equivalent of $1.99 USD.** It is correctly
   positioned as the low-friction entry point in the funnel; v2 confirmed the tier
   is sound and that pricing should hold until conversion improves.
2. **Confirm the actual live USD price in ASC** (Monetization > In-App Purchases >
   `numpad.pack.finance` > Pricing). If the live price is **not** $1.99, the
   recommendation is still "hold the current tier" — but the team should know the
   real number, because the `$1.99` string proves nothing.
3. **Keep the code fallback aligned** with whatever the confirmed live price is, so
   the offline/cold-launch state never misquotes the price. (Code change is out of
   scope for this deliverable — flag for the next app PR if the live price differs.)

> The Apple price-point grid is dense — USD moves in $0.10 steps up to $9.99 — so
> $1.99 is a valid point and there is no tier-rounding problem here. **Verify in ASC.**

---

## 2. Family Sharing — recommend ON for both non-consumables

**Recommendation: turn Family Sharing ON for both non-consumables:**
`numpad.pro.lifetime` and `numpad.pack.finance`. Both are currently **OFF** (per v2).

**Why.**
- **Perceived value, zero marginal cost.** Family Sharing lets up to six members of
  an Apple Family group use a non-consumable the buyer already paid for. For a
  one-time "lifetime" unlock this is a pure perceived-value boost — the buyer feels
  they're equipping the household, not just one device. There is **no per-share fee
  and no revenue given up**: Apple does not discount or split the single purchase.
  It is upside on the conversion decision at no marginal cost.
- **It strengthens the existing "lifetime, no subscription" story.** NumPad's
  differentiator is a one-time purchase. "Buy once, the whole family gets it" is the
  natural extension of that message and reads as generous rather than restrictive.
- **It removes a small objection.** A shared family iPad / a partner's iPhone can use
  the unlock without re-buying, which is exactly the kind of friction that quietly
  suppresses utility-app purchases.

**Critical caveat — this is a one-way door.**
Per Apple: once Family Sharing is enabled on a product, **it cannot be turned off.**
The only way to "undo" it afterward is to **delete the IAP and create a new one**,
which loses the product's history and would require re-submission and re-localization.
So this is a deliberate, irreversible choice — but it is the right one here, because
there is no scenario where we'd want to *remove* household value from a lifetime
unlock. Enabling it is safe to commit to; disabling later is not an option, and we
don't want it to be.

**How (manual, recommended path).**
ASC > Monetization > In-App Purchases > select product > **Family Sharing** section >
turn on > Save. Do this for both products. (The `iap_admin.py --set-family-sharing`
path can do the same via API, but **dry-run and review it first** — see §6.)

This does **not** require a new app binary; it's a metadata change on the IAP. It can
ship independently of 1.8.

---

## 3. Legacy IAP cleanup

**Finding.** Submission-readiness (2026-06-17) reports **7 legacy draft IAP products**
sitting in `Submit for Review` status alongside the two intended products
(`numpad.pro.lifetime`, `numpad.pack.finance`). They are explicitly **not** to be
included with the 1.7.2 submission.

**Why clean them up.** Stray draft IAPs clutter the Monetization tab, make the catalog
harder to reason about, raise the chance of *accidentally* attaching the wrong product
to a submission, and can confuse future API automation (e.g. a "set Family Sharing on
all non-consumables" loop would have to know to skip them).

**Risks — read before deleting.**
- **Never delete a product that has sales history.** Deletion is destructive and you
  lose the record. A product with even one historical transaction should be left in
  place (or kept as a record), not deleted.
- **Never delete a product a current or in-flight build references** by product ID.
  StoreKit lookups for that ID would start returning nothing and the app would fall
  back to the placeholder price (see §1) or hide the row.
- **Deleting an *approved* product is different from deleting a *draft*.** These 7 are
  drafts in `Submit for Review`, which is the low-risk case — but still verify each
  one individually.
- Deletion in ASC may be **irreversible**; you cannot reliably "undo" a deleted IAP.

**Safe procedure (recommended).**
1. **Audit first, change nothing.** Run `iap_admin.py --audit-drafts` (dry-run; it only
   reads) to list every draft IAP with its product ID, status, name, and
   `familySharable` flag. Cross-check against the two intended product IDs.
2. **Confirm zero sales history** for each draft candidate. Drafts in `Submit for
   Review` that were never released will have none, but verify in ASC
   (Sales and Trends / the product's own page) — do not assume.
3. **Confirm no build references the product ID.** Grep the app for the ID
   (the only live IDs are `numpad.pro.lifetime` and `numpad.pack.finance`, defined in
   `NumPad/Libraries/StoreManager.swift:19-22` — anything else is safe from a code
   standpoint).
4. **Delete only verified-safe drafts, one at a time, in the ASC UI.** Prefer the UI
   for this. If using the helper, deletion requires **both** `--apply` and
   `--confirm-delete`, and the script still refuses to delete the two intended
   products — but the UI gives you a clearer confirmation surface for a destructive,
   likely-irreversible action.
5. **Do not delete during an active submission window.** Wait until 1.7.2 (and the two
   real IAP updates) are through review, so you're not mutating the catalog mid-review.

Net: cleaning up the 7 drafts is **good hygiene with low risk** as long as each is
confirmed to have no sales history and no code reference. When in doubt, leave it.

---

## 4. Per-market pricing recommendation table

Base prices today (from v2): **App $2.99**, **Pro Lifetime $4.99**, **Finance Pack ~$1.99**
(confirm Finance in ASC per §1). Apple "May Adjust Automatically" is **on**, so non-USD
prices already track the USD tier after FX + local tax.

The question is **not** currency conversion (Apple handles that) — it's whether to set a
**deliberately lower local tier** in lower-purchasing-power markets to trade ARPU for
volume. Apple now offers very low "alternate" price points specifically for emerging
markets (India, Indonesia, Mexico, Turkey, etc.), so a lower tier is mechanically
possible. The recommendation weighs that option against each cluster's current revenue
share.

Revenue shares are 30-day, app + IAP combined, from v2 / `market-prioritization.csv`:
USA+Canada 42.5%, Europe 31.6%, Africa/MEA/India 10.2%, Asia Pacific 9.7%, LatAm 6.0%.

| Cluster | Rev share (30d) | App $2.99 | Pro $4.99 | Finance ~$1.99 | Rationale |
|---|---|---|---|---|---|
| **US (+Canada)** | 42.5% | **Hold** | **Hold** | **Hold** | Largest revenue cluster and the price anchor. Search is the main acquisition channel; fix the listing/funnel, not the price. No PPP case to discount the home market. |
| **Europe** | 31.6% | **Hold** | **Hold** | **Hold** | Second-largest cluster; comparable purchasing power to the US. Auto-adjust already sets the standard EUR equivalents (€2.99 / €5.99). Leave it. |
| **India / MEA** | 10.2% | **Hold now; candidate for a localized lower tier later** | **Hold now; strongest lower-tier candidate later** | **Hold** | Apple's auto-converted INR price runs well above local purchasing power (often cited at 2–3x affordable), and Apple provides emerging-market price points precisely for this. A deliberately lower **India** tier on the **Pro Lifetime** is the highest-potential volume play in the whole table — but only after conversion is fixed (see gate below). Finance is already cheap enough to leave. |
| **Asia Pacific** | 9.7% | **Hold** | **Hold (revisit per-country later)** | **Hold** | Mixed cluster: high-PPP markets (JP, AU, KR, SG) sit fine at the standard tier — AU is already at a higher local tier (v2). Lower-PPP APAC markets (e.g. ID, PH, VN) are secondary lower-tier candidates *after* India, not before. Don't blanket-cut the cluster. |
| **LatAm** | 6.0% | **Hold now; secondary lower-tier candidate later** | **Hold now; secondary candidate later** | **Hold** | Smallest cluster and lower PPP (Brazil already has a local BRL tier per v2). A lower tier could lift volume, but at 6.0% of revenue the absolute upside is small — sequence it **after** India/MEA. |

**Reading the table.** Recommendation is **hold every price in every market right now.**
The only markets with a real case for a *deliberate* lower tier are **India/MEA** (best
candidate, driven by the documented PPP gap) and then **LatAm** and **low-PPP APAC** as
secondary candidates. None of these should move yet.

### Gate — why "hold now" and not "cut now"

Per v2, **do not run any price test until page conversion measurably improves.** Current
conversion is ~0.7%; at that rate a pricing experiment has almost no statistical power and
you can't tell a price effect from noise. The ordered prerequisites (also from v2 /
submission-readiness) are:

1. Localize storefront metadata (in progress) — highest-leverage change.
2. Add iPad screenshots (captures ~28.6% of revenue currently on weak assets).
3. Replace weak screenshots (slides 3–4) and PPO-test screenshot order.
4. **Then, and only then,** test pricing — and isolate the variable (don't change price
   and metadata at the same time).

**1.8's new funnel analytics are the explicit prerequisite for any price test.** Without
per-step funnel instrumentation (impression -> product page -> paywall view -> purchase),
a regional price change is unmeasurable: you won't know whether a lower India tier lifted
*attach rate* or just moved noise. So the sequence is: ship 1.8 funnel analytics -> fix
conversion -> *then* run a single, isolated regional price test (start with India Pro
Lifetime). Until that exists, this stays a **hold**.

---

## 5. Effort, revenue mechanism, and how to measure

| Recommendation | Effort | Revenue mechanism | How to measure |
|---|---|---|---|
| **Confirm Finance Pack live price; hold tier** (§1) | Trivial (one ASC read) | Neutral — prevents misquoting price in offline/cold-launch state | Compare live ASC price vs. the code fallback; align them. No revenue test — this is hygiene. |
| **Family Sharing ON, both IAPs** (§2) | Low (2 metadata toggles, no binary) | **ARPU / conversion** — higher perceived value lifts purchase intent; no revenue is split | Watch IAP **conversion rate** (paywall view -> purchase) and overall **attach rate** before/after, once 1.8 funnel analytics exist. Effect is on the *decision*, so look at conversion, not redemptions. |
| **Delete the 7 legacy drafts** (§3) | Low (audit + per-product UI deletes) | Neutral — operational risk reduction, not revenue | Success = clean catalog, no accidental wrong-product submission, audit script lists only the 2 intended IAPs. No revenue metric. |
| **Per-market: hold now** (§4) | None now (study only) | n/a yet | n/a — gated on conversion + 1.8 analytics. |
| **Later: India Pro Lifetime lower tier** (§4, gated) | Medium (regional price set + monitoring; FX/tax-free since it's a fixed local tier) | **Volume over ARPU** — lower price, lower per-unit proceeds, bet on enough extra units to grow total India revenue | Per-storefront, after 1.8: **India units sold** and **India total proceeds** (not per-unit). Win condition = `new_units x new_proceeds_per_unit > old_units x old_proceeds_per_unit` for India. Run as an isolated change with a clean before/after window. |
| **Later: LatAm / low-PPP APAC lower tiers** (§4, gated) | Medium each | Volume over ARPU (same as above) | Same per-storefront unit-and-proceeds comparison; sequence after India so you only move one variable at a time. |

**Two distinct levers, stated plainly:**
- **Family Sharing** is an **ARPU/conversion** lever — it makes the *same* price feel
  worth more, lifting how many people buy. Zero revenue given up.
- **Regional lower tiers** are a **volume** lever — you accept *less per sale* in a
  market to (hopefully) get *enough more sales* that total market revenue rises. This is
  a real bet and must be measured on total per-market proceeds, not per-unit price.

---

## 6. Tooling

The helper `marketing/asc/iap_admin.py` (see `marketing/asc/README.md`) supports the
read-only and low-risk actions above:

- `--list` — list all IAPs with status (and `familySharable`) — **dry-run / read-only**.
- `--audit-drafts` — list draft IAPs for the §3 cleanup audit — **read-only**.
- `--set-family-sharing` — set `familySharable=true` on the two non-consumables —
  **requires `--apply`**; refuses to run without it.
- Deletion of a draft — **requires both `--apply` and `--confirm-delete`**, refuses to
  touch the two intended products, and **never** submits anything.

> [!WARNING]
> `iap_admin.py` is **untested against the live account.** Review it and run a dry-run
> (`--list` / `--audit-drafts`) before any `--apply`. It never submits for review and
> never changes prices.

---

## 7. What this memo does NOT do

- It does **not** change any price (US or regional).
- It does **not** enable Family Sharing — it recommends it; a human applies it.
- It does **not** delete any IAP — it gives the safe procedure.
- It does **not** submit anything for review or call ASC live.
- It does **not** modify Swift, generators, or Fastlane.

All live actions are manual, human-confirmed, and gated as described above.
