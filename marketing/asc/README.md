# marketing/asc — App Store Connect API helpers (STAGE-ONLY)

This folder holds scripts that talk to the **App Store Connect API**. Everything here
is for **staging, inspection, and recommendation work only**.

> [!WARNING]
> All scripts in this folder are **stage-only** and default to **dry-run**.
> They are **untested against the live account**. Review the code and run a dry-run
> first. Nothing here should ever submit an app or IAP for review, change prices,
> or delete a product with sales history.

App: **NumPad** — bundle id `com.morevoltage.NumPad`.

## Scripts

| Script | Purpose | Default mode |
|---|---|---|
| `iap_admin.py` | List IAPs + status, set Family Sharing on the two non-consumables, audit draft IAPs | **dry-run** (no writes without `--apply`; no deletes without `--confirm-delete`) |

## Authentication

The scripts use the **App Store Connect API** with an **ES256-signed JWT** built from an
App Store Connect API key (Issuer ID + Key ID + the `.p8` private key). Tokens are
short-lived (Apple caps validity at 20 minutes).

Provide credentials through **environment variables** (never hard-code or commit keys):

**Option A — point at the `.p8` file:**

```bash
export ASC_KEY_ID="ABC123DE45"          # the 10-char Key ID
export ASC_ISSUER_ID="6f0e1d2c-..."     # the Issuer ID (UUID) from Users and Access > Integrations
export ASC_API_KEY_PATH="/secure/path/AuthKey_ABC123DE45.p8"
```

**Option B — pass the key contents inline (e.g. CI secret):**

```bash
export ASC_KEY_ID="ABC123DE45"
export ASC_ISSUER_ID="6f0e1d2c-..."
export ASC_KEY_CONTENT="$(cat /secure/path/AuthKey_ABC123DE45.p8)"
```

`ASC_API_KEY_PATH` takes precedence if both it and `ASC_KEY_CONTENT` are set.

Get these from **App Store Connect > Users and Access > Integrations > App Store Connect API**.
The API key needs at least **App Manager** role to read/modify IAPs.

### Dependencies

```bash
pip install pyjwt cryptography requests
```

(`cryptography` is required for ES256 signing.)

## Safety rules (inherited from the audit folder)

- Do **not** submit the app or any IAP for review without explicit user confirmation.
- Do **not** change public ASC pricing, availability, metadata, or IAP ordering without explicit user confirmation.
- Do **not** delete ASC products without saving local copies and confirming immediately before deletion — and **never** delete a product with sales history.
- Do **not** put private ASC credentials in reports, logs, or commits.
- Family Sharing, once enabled on a product, **cannot be turned off** without deleting and recreating the product. Treat `--set-family-sharing` as a one-way door.

## Pricing

Pricing is **not** managed by any script here. See
`../aso-sales-audit/pricing-hygiene-recommendations.md` for the current pricing
recommendation memo. All price decisions are manual, in the ASC UI, after review.
