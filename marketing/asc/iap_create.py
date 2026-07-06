#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
iap_create.py - Create the two missing NumPad 2.0 in-app purchases (draft products).

  ============================================================================
  STAGE-ONLY. Dry-run by default. Nothing is written without --apply.
  ============================================================================
  - Creates ONLY the two products listed below, as NON_CONSUMABLE drafts.
  - Idempotent: a product that already exists (matched by productId) is skipped.
  - NEVER sets prices, NEVER uploads metadata/screenshots, NEVER submits.
    Price, localized name/description, and the required review screenshot stay a
    manual ASC-UI step (same guardrail as iap_admin.py -- no pricing code here).

Creates (all NON_CONSUMABLE; existing ones skipped):
  numpad.pro.lifetime.earlybird   "NumPad Pro (Early Bird)"
  numpad.pack.datetime            "Date & Time Pack"
  numpad.pack.units               "Units & Conversion Pack"
  numpad.pack.cooking             "Cooking & Baking Pack"

After --apply, finish each product in the ASC UI (or via iap_metadata.py):
  - set the price   (early-bird Pro $5.99 ; each pack $1.99)
  - add the localized display name + description
  - upload a review screenshot
  -> then the product becomes Ready to Submit.

Auth (environment variables; never hard-code keys):
  ASC_KEY_ID        10-char App Store Connect API Key ID            (required)
  ASC_ISSUER_ID     Issuer ID (UUID) from Users and Access          (required)
  and ONE of:
  ASC_API_KEY_PATH  path to the AuthKey_XXXXXXXXXX.p8 file           (preferred)
  ASC_KEY_CONTENT   the .p8 private key contents inline

Dependencies:
  pip install pyjwt cryptography requests

Usage:
  python3 marketing/asc/iap_create.py            # dry-run (shows what it would create)
  python3 marketing/asc/iap_create.py --apply    # actually create the draft products
"""

from __future__ import annotations

import argparse
import datetime
import os
import sys
import time
from typing import Any, Dict, List, Optional

BUNDLE_ID = "com.morevoltage.NumPad"
ASC_BASE = "https://api.appstoreconnect.apple.com"
JWT_AUDIENCE = "appstoreconnect-v1"
JWT_LIFETIME_SECONDS = 15 * 60

# The exact products to create. `name` is the internal reference name (not shown to users).
# Idempotent: anything already in ASC is skipped, so the full 2.0 wish-list lives here.
PRODUCTS_TO_CREATE = [
    {"product_id": "numpad.pro.lifetime.earlybird", "name": "NumPad Pro (Early Bird)"},
    {"product_id": "numpad.pack.datetime", "name": "Date & Time Pack"},
    {"product_id": "numpad.pack.units", "name": "Units & Conversion Pack"},
    {"product_id": "numpad.pack.cooking", "name": "Cooking & Baking Pack"},
]
IAP_TYPE = "NON_CONSUMABLE"


def _require_runtime_deps():
    try:
        import jwt  # noqa: F401  (PyJWT)
        import requests  # noqa: F401
    except ImportError as exc:
        sys.exit(
            "Missing dependency: %s\n"
            "Install with: pip install pyjwt cryptography requests" % exc
        )


def _load_private_key() -> str:
    key_path = os.environ.get("ASC_API_KEY_PATH")
    key_content = os.environ.get("ASC_KEY_CONTENT")
    if key_path:
        if not os.path.isfile(key_path):
            sys.exit("ASC_API_KEY_PATH is set but file not found: %s" % key_path)
        with open(key_path, "r", encoding="utf-8") as fh:
            return fh.read()
    if key_content:
        return key_content
    sys.exit("No private key. Set ASC_API_KEY_PATH (path to .p8) or ASC_KEY_CONTENT.")


def _generate_token() -> str:
    import jwt  # PyJWT

    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer_id:
        sys.exit("Set ASC_KEY_ID and ASC_ISSUER_ID environment variables.")
    now = int(time.time())
    payload = {"iss": issuer_id, "iat": now, "exp": now + JWT_LIFETIME_SECONDS, "aud": JWT_AUDIENCE}
    headers = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    token = jwt.encode(payload, _load_private_key(), algorithm="ES256", headers=headers)
    return token.decode("utf-8") if isinstance(token, bytes) else token


def _auth_headers() -> Dict[str, str]:
    return {"Authorization": "Bearer %s" % _generate_token(), "Content-Type": "application/json"}


def _raise_for_api_error(resp) -> None:
    if resp.status_code < 400:
        return
    try:
        errors = resp.json().get("errors", [])
        detail = "; ".join(
            "%s: %s" % (e.get("title", "error"), e.get("detail", "")) for e in errors
        )
    except Exception:
        detail = resp.text[:500]
    sys.exit("API error %s on %s\n  %s" % (resp.status_code, resp.url, detail))


def _get(path: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    import requests

    url = path if path.startswith("http") else ASC_BASE + path
    resp = requests.get(url, headers=_auth_headers(), params=params, timeout=30)
    _raise_for_api_error(resp)
    return resp.json()


def _get_all_pages(path: str, params: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    import requests

    results: List[Dict[str, Any]] = []
    url = path if path.startswith("http") else ASC_BASE + path
    first = True
    while url:
        resp = requests.get(url, headers=_auth_headers(), params=params if first else None, timeout=30)
        _raise_for_api_error(resp)
        body = resp.json()
        results.extend(body.get("data", []))
        url = (body.get("links") or {}).get("next")
        first = False
    return results


def _post(path: str, body: Dict[str, Any]) -> Dict[str, Any]:
    import requests

    url = path if path.startswith("http") else ASC_BASE + path
    resp = requests.post(url, headers=_auth_headers(), json=body, timeout=30)
    _raise_for_api_error(resp)
    return resp.json() if resp.content else {}


def resolve_app_id() -> str:
    body = _get("/v1/apps", params={"filter[bundleId]": BUNDLE_ID, "limit": 200})
    for app in body.get("data", []):
        if app.get("attributes", {}).get("bundleId") == BUNDLE_ID:
            return app["id"]
    sys.exit("No app found for bundle id %s with these credentials." % BUNDLE_ID)


def existing_product_ids(app_id: str) -> set:
    iaps = _get_all_pages("/v1/apps/%s/inAppPurchasesV2" % app_id, params={"limit": 200})
    return {(i.get("attributes", {}) or {}).get("productId") for i in iaps}


def create_one(app_id: str, product: Dict[str, str]) -> None:
    body = {
        "data": {
            "type": "inAppPurchases",
            "attributes": {
                "name": product["name"],
                "productId": product["product_id"],
                "inAppPurchaseType": IAP_TYPE,
            },
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    }
    result = _post("/v2/inAppPurchases", body)
    new_id = (result.get("data") or {}).get("id", "?")
    print("  [DONE] created %s  \"%s\"  resource id=%s" % (product["product_id"], product["name"], new_id))


def main(argv: Optional[List[str]] = None) -> None:
    parser = argparse.ArgumentParser(
        description="Create the two missing NumPad 2.0 IAP drafts. Dry-run by default; never sets prices.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--apply", action="store_true", help="Actually create the products. Without this, dry-run only.")
    args = parser.parse_args(argv)
    _require_runtime_deps()

    print("=" * 76)
    print("iap_create.py  -  STAGE-ONLY  -  %s" % datetime.date.today())
    print("App: NumPad (%s)" % BUNDLE_ID)
    print("Mode: %s" % ("APPLY (writes enabled)" if args.apply else "DRY-RUN (read-only / no writes)"))
    print("=" * 76)

    app_id = resolve_app_id()
    print("Resolved app id: %s" % app_id)
    existing = existing_product_ids(app_id)

    print("\nProducts to create (NON_CONSUMABLE; price + metadata + screenshot done later in ASC UI):")
    print("-" * 76)
    created = 0
    for product in PRODUCTS_TO_CREATE:
        pid = product["product_id"]
        if pid in existing:
            print("  [SKIP] %s already exists." % pid)
            continue
        if not args.apply:
            print("  [DRY]  would create %s  \"%s\"  (%s)" % (pid, product["name"], IAP_TYPE))
            continue
        create_one(app_id, product)
        created += 1
    print("-" * 76)
    if not args.apply:
        print("Dry-run: nothing written. Re-run with --apply to create the drafts.")
    else:
        print("Created %d product(s). Next, per product in ASC: set price + metadata + review screenshot." % created)


if __name__ == "__main__":
    main()
