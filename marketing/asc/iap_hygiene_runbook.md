# App Store Connect — IAP Hygiene Runbook

App: NumPad (`com.morevoltage.NumPad`)
Version context: 1.7.2 line
Date: 2026-06-18
Recommendation memo: `marketing/aso-sales-audit/pricing-hygiene-recommendations.md`
Helper: `marketing/asc/iap_admin.py` (STAGE-ONLY, UNTESTED — review + dry-run first)

## STOP rule

This runbook covers **catalog hygiene only**: enabling Family Sharing on the two
non-consumables and deleting the 7 legacy **draft** IAPs after verification. It does
**not** submit anything, and it does **not** change any price.

- Do **not** click **Submit for Review** / **Add for Review** on any IAP, the app
  version, or anything else.
- Do **not** change prices (US or regional). Pricing recommendations are hold-only; see
  the memo. There is intentionally no pricing path in the helper.
- Do **not** delete any product with sales history, and never delete the two intended
  products (`numpad.pro.lifetime`, `numpad.pack.finance`).
- Family Sharing is a **one-way door**: once ON it cannot be turned OFF without deleting
  and recreating the product. Only turn it on when you're sure (you are — see memo §2).

Other guardrails (from the audit folder): save local copies before any deletion, don't
overwrite live pricing/metadata from automation, keep ASC credentials out of reports.

## Prerequisites

1. App Store Connect account with **App Manager** (or Admin) role for NumPad.
2. (Only if using the helper) App Store Connect API key + env vars set — see
   `README.md` in this folder. Install deps: `pip install pyjwt cryptography requests`.
3. Read the memo: `marketing/aso-sales-audit/pricing-hygiene-recommendations.md`.

---

## Part A — Confirm the Finance Pack live price (memo §1)

The `$1.99` in the app is a display **fallback** (`StoreViewController.swift:380`), not
the configured price.

1. ASC > **Monetization > In-App Purchases** > `numpad.pack.finance` > **Pricing**.
2. Note the actual current USD price and base-country price point.
3. Recommendation: **hold** the current tier regardless. If the live price is not
   $1.99, record the real number and flag the code fallback for alignment in the next
   app PR (out of scope here — do not edit Swift in this pass).

No change is made in this step.

---

## Part B — Audit the catalog (read-only)

Either via UI or the helper (dry-run, reads only):

```bash
# Dry-run is the default. These commands make NO changes.
python3 marketing/asc/iap_admin.py --list           # all IAPs + status + familyShare
python3 marketing/asc/iap_admin.py --audit-drafts   # just the draft cleanup candidates
```

Confirm:
- The two intended products appear and are approved.
- Exactly the expected legacy **drafts** show up in `--audit-drafts` (submission-readiness
  reported **7**).
- Note each draft's `familySharable` and state.

---

## Part C — Enable Family Sharing on the two non-consumables (memo §2)

This is a metadata change; no new build required. It is irreversible (one-way door).

**UI path (recommended for the confirmation surface):**
1. ASC > Monetization > In-App Purchases > `numpad.pro.lifetime` > **Family Sharing** >
   turn **on** > **Save**.
2. Repeat for `numpad.pack.finance`.

**Helper path (after dry-run):**
```bash
# 1) Dry-run first — shows exactly what it would PATCH, changes nothing:
python3 marketing/asc/iap_admin.py --set-family-sharing

# 2) Apply (only after reviewing the dry-run output):
python3 marketing/asc/iap_admin.py --set-family-sharing --apply
```
The helper only ever sets `familySharable=true` (never false) and only on the two
intended products.

Verify with `--list` (or in the UI) that both now show Family Sharing = true.

---

## Part D — Delete the 7 legacy draft IAPs (memo §3)

Do this **after** 1.7.2 + the two real IAP updates are through review, not during an
active submission window.

For **each** draft candidate:
1. **Confirm zero sales history.** Check the product's page / Sales and Trends in ASC.
   If it has any history, **do not delete it** — stop and leave it in place.
2. **Confirm no build references its product id.** The only live ids are
   `numpad.pro.lifetime` and `numpad.pack.finance` (`StoreManager.swift:19-22`); any
   other id is safe from a code standpoint, but verify.
3. Delete **one at a time**.

**UI path (recommended):** open the draft IAP > Delete > confirm.

**Helper path (double interlock):**
```bash
# Dry-run (default) — shows the candidate, deletes nothing:
python3 marketing/asc/iap_admin.py --delete-iap <product_id_or_resource_id>

# Actual delete — requires BOTH flags, refuses the two intended products:
python3 marketing/asc/iap_admin.py --delete-iap <id> --apply --confirm-delete
```
Deletion is likely irreversible. When in doubt, leave the draft in place.

---

## Part E — Pricing (memo §4) — NO ACTION NOW

All prices **hold**. Do not run any regional price test until:
1. Page conversion measurably improves (current ~0.7% has no statistical power), and
2. **1.8 funnel analytics ship** (the prerequisite for measuring a price test).

When both are true, the first candidate is a **deliberate lower India tier on Pro
Lifetime**, run as a single isolated change, measured on India **total proceeds**
(units x per-unit), not per-unit price. See memo §4–§5. This is out of scope for this
runbook and for the helper.

---

## Done / hand-back

After Parts C and D (if performed): the catalog has Family Sharing on both
non-consumables and only the two intended IAPs remaining. Stop here. Do not submit
anything. Report status to the owner.
