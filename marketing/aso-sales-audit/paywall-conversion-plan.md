# Paywall / IAP Conversion Plan — Release 1.8

Date: 2026-06-18 · Scope: in-app upsell funnel (the biggest revenue lever given **5 IAPs / 180 first-time downloads** over 90 days ≈ ~2.8% download→paid).

## 1. The funnel today (and its blind spots)

Upsell is **reactive only**: tapping a locked key or pack deep-links to the store
(`numpad://store-preview?source=…`), and `store_viewed` is logged app-side with a `source`.
There is **no proactive first-run upsell**, the hero copy is generic regardless of entry point,
and the funnel can't see initiation, cancellation, or per-source conversion.

Known constraint: the **keyboard extension does not link Firebase** (deliberate — no keystroke
tracking, faster cold start). So the lock-tap signal is the deep link itself; it surfaces in the
app as `store_viewed{source}`. All new events are therefore logged **app-side**.

Entry points (`source`): `key_lock`, `pack_picker` (keyboard), `packs` (Packs screen),
`home` (settings row), `deep_link` (fallback), and new `first_run`.

## 2. What changed in this release (code)

| Change | Mechanism | File |
|---|---|---|
| **Context-aware paywall hero** — headline + pitch adapt to entry point (locked key vs locked pack vs first run), plus a "what's included" checklist and a "One-time purchase. No subscription, ever." reassurance | Higher conversion (clearer value at the moment of intent) | `NumPad/Controllers/StoreViewController.swift` (`makeHeroHeader`, `makeBenefitRow`, `heroCopy`) |
| **One-time first-run upsell** — shown once after the keyboard is enabled, skippable, only if Pro isn't owned; `source = first_run` | Higher conversion (proactive look at Pro for users who never hit a lock) | `NumPad/Controllers/Base/ViewController.swift` (`presentFirstRunUpsellIfNeeded`), flag `Constants.firstRunUpsellShown` |
| **Full purchase funnel events** — `purchase_initiated`, `purchase_completed`, `purchase_cancelled`, `paywall_dismissed`, each with `source` (+ `product_id`) | Measurement (per-surface conversion + cancel rate) | `StoreViewController.swift` (`buy`, `viewWillDisappear`) |

Lock-chip moment is improved indirectly: the chip already deep-links with the right `source`,
and the store now *answers* that source ("Unlock every key" / "Unlock every pack").

No price changes were made (per ground rules) — see §6 and the D5 pricing memo.

## 3. Analytics events after this release

| Event | Attributes | When | Status |
|---|---|---|---|
| `store_viewed` | `source` | Paywall appears | existing |
| `purchase_initiated` | `product_id`, `source` | User taps a product to buy | **new** |
| `purchase_completed` | `product_id`, `source` | Purchase verified (funnel, source-attributed) | **new** |
| `purchase_succeeded` | `product_id` | Entitlement applied (product-level) | existing |
| `purchase_cancelled` | `product_id`, `source` | User cancelled the sheet | **new** |
| `purchase_failed` | `product_id`, `source` | Error/verification failure (now carries source) | updated |
| `paywall_dismissed` | `source`, `purchased` | Paywall closed | **new** |
| `restore_completed` | `pro`, `finance` | Restore finished | existing |

## 4. How we'll measure it

Per-`source` funnel in Firebase/analytics:

```
store_viewed → purchase_initiated → purchase_completed
            (view→initiate rate)  (initiate→complete rate)
```

- **Paywall view→purchase rate**, segmented by `source` — isolates which surface converts
  (e.g., `first_run` vs `key_lock` vs `pack_picker`).
- **Cancel rate** = `purchase_cancelled / purchase_initiated` — flags price/value friction.
- **First-run efficacy** = `purchase_completed{source=first_run} / store_viewed{source=first_run}`.
- **Attach rate** = paying users / first-time downloads (the headline number to move from ~2.8%).
- Guardrail: **uninstall / first-session length** shouldn't regress from the first-run upsell.

## 5. Expected impact (hypotheses to validate, not promises)

Revenue mechanism = **higher conversion** (download→paid) and modestly **higher ARPU** (clearer Pro framing pulls some Finance-only buyers to Pro). Effort = **S–M** (shipped here, no new SKUs).

- First-run upsell typically converts a low-but-real share of new users who would otherwise
  never see a lock. Plausible range: **+0.5–2.0 pp** of download→paid. At 180 first-time
  downloads/90d that's roughly **+1 to +4 incremental purchases/90d** — small in absolute terms
  but a large relative move on a base of 5, and it compounds as installs grow.
- Context-aware hero + value checklist: incremental lift on existing `store_viewed` traffic;
  measure as view→purchase rate change vs the 1.7.2 baseline.
- The real win is **instrumentation**: today we can't see initiate/cancel/per-source. After 1.8
  we can, which is the prerequisite for any pricing test having statistical meaning.

## 6. Bundling & pricing (recommend, don't change)

- Keep the two-tier ladder: **Finance Pack** (low-friction entry) → **Pro** (everything, forever).
  The new hero leans on "everything + no subscription," which is the strongest frame for Pro.
- Consider **upgrade pricing** for Finance→Pro buyers (so the $1.99 isn't "wasted") — this is an
  ASC catalog change, deferred to the D5 pricing memo.
- Do **not** introduce a subscription (the "no subscription" line is a differentiator and is now
  reinforced on the paywall).
- Finance Pack price reconcile + per-market pricing recommendations live in the D5 memo.

## 7. Rollout & guardrails

- `Monetization.paywallEnabled` already gates all of this; the DEBUG section can simulate states.
- First-run upsell is **once per install**, never over onboarding, never when Pro is owned.
- Watch cancel rate and uninstall after release; if first-run hurts retention, gate it behind
  Remote Config (the RC plumbing already exists via `RemoteConfigManager`).
