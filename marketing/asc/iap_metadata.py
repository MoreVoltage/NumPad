#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
iap_metadata.py - Fill in metadata for the NumPad 2.0 draft IAPs so they reach
READY_TO_SUBMIT: en-US localization (name + description), USA base price, and a review
screenshot. Dry-run by default; nothing is written without --apply.

  ============================================================================
  STAGE-ONLY. Dry-run by default. NEVER submits for review (a human submits).
  ============================================================================
  - Operates ONLY on the four products listed in PRODUCTS below.
  - Idempotent: skips a localization/price/screenshot that is already present.
  - Prices come from the exact USA price point matching the target customerPrice.
  - The review screenshot is an existing en-US app screenshot (reused for all four).

Auth (env vars; never hard-code keys):
  ASC_KEY_ID, ASC_ISSUER_ID, and ONE of ASC_API_KEY_PATH (.p8 path) / ASC_KEY_CONTENT.
Deps: pip install pyjwt cryptography requests

Usage:
  python3 marketing/asc/iap_metadata.py                       # dry-run, all stages
  python3 marketing/asc/iap_metadata.py --stage localizations # dry-run one stage
  python3 marketing/asc/iap_metadata.py --stage prices --apply # write one stage
  python3 marketing/asc/iap_metadata.py --apply               # write all stages
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import os
import sys
import time
from typing import Any, Dict, List, Optional

BUNDLE_ID = "com.morevoltage.NumPad"
ASC_BASE = "https://api.appstoreconnect.apple.com"
JWT_AUDIENCE = "appstoreconnect-v1"
JWT_LIFETIME_SECONDS = 15 * 60

LOCALE = "en-US"
BASE_TERRITORY = "USA"
# An existing en-US app screenshot (1320x2868), reused as each IAP's review screenshot.
SCREENSHOT = "fastlane/screenshots/en-US/APP_IPHONE_67_01.png"

# The MISSING_METADATA products, with the copy + price to apply.
PRODUCTS = [
    {"pid": "numpad.pro.lifetime.earlybird", "name": "NumPad Pro (Early Bird)",
     "desc": "50% off lifetime Pro — every pack & more.", "price": "5.99"},
    {"pid": "numpad.pack.datetime", "name": "Date & Time Pack",
     "desc": "Insert date, time & timestamps in a tap.", "price": "1.99"},
    {"pid": "numpad.pack.symbols", "name": "Symbols & Science Pack",
     "desc": "Symbols & science operators row.", "price": "1.99"},
    {"pid": "numpad.pack.programmer", "name": "Programmer Pack",
     "desc": "Hex, binary & bitwise operators row.", "price": "1.99"},
    {"pid": "numpad.pack.units", "name": "Units & Conversion Pack",
     "desc": "Length, mass & temperature conversions.", "price": "1.99"},
    {"pid": "numpad.pack.cooking", "name": "Cooking & Baking Pack",
     "desc": "Fractions, cups, tsp & ml for recipes.", "price": "1.99"},
    # 2.0 repricing: Pro moves from the legacy $4.99 to $11.99 (owner-decided anchor).
    {"pid": "numpad.pro.lifetime", "name": "All Packs Lifetime",
     "desc": "Every pack & premium theme, forever.", "price": "11.99"},
]


def _require_runtime_deps():
    try:
        import jwt  # noqa: F401
        import requests  # noqa: F401
    except ImportError as exc:
        sys.exit("Missing dependency: %s\nInstall: pip install pyjwt cryptography requests" % exc)


def _load_private_key() -> str:
    key_path = os.environ.get("ASC_API_KEY_PATH")
    key_content = os.environ.get("ASC_KEY_CONTENT")
    if key_path:
        if not os.path.isfile(key_path):
            sys.exit("ASC_API_KEY_PATH set but file not found: %s" % key_path)
        with open(key_path, "r", encoding="utf-8") as fh:
            return fh.read()
    if key_content:
        return key_content
    sys.exit("No private key. Set ASC_API_KEY_PATH (path to .p8) or ASC_KEY_CONTENT.")


def _token() -> str:
    import jwt
    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer_id:
        sys.exit("Set ASC_KEY_ID and ASC_ISSUER_ID environment variables.")
    now = int(time.time())
    payload = {"iss": issuer_id, "iat": now, "exp": now + JWT_LIFETIME_SECONDS, "aud": JWT_AUDIENCE}
    tok = jwt.encode(payload, _load_private_key(), algorithm="ES256", headers={"alg": "ES256", "kid": key_id, "typ": "JWT"})
    return tok.decode("utf-8") if isinstance(tok, bytes) else tok


def _headers() -> Dict[str, str]:
    return {"Authorization": "Bearer %s" % _token(), "Content-Type": "application/json"}


def _err(resp) -> None:
    if resp.status_code < 400:
        return
    try:
        errs = resp.json().get("errors", [])
        detail = "; ".join("%s: %s" % (e.get("title", "error"), e.get("detail", "")) for e in errs)
    except Exception:
        detail = resp.text[:500]
    sys.exit("API error %s on %s\n  %s" % (resp.status_code, resp.url, detail))


def _get(path: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    import requests
    url = path if path.startswith("http") else ASC_BASE + path
    resp = requests.get(url, headers=_headers(), params=params, timeout=30)
    _err(resp)
    return resp.json()


def _get_optional(path: str, params: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, Any]]:
    """GET that returns None on any 4xx/5xx instead of exiting (for existence checks)."""
    import requests
    url = path if path.startswith("http") else ASC_BASE + path
    resp = requests.get(url, headers=_headers(), params=params, timeout=30)
    return resp.json() if resp.status_code < 400 else None


def _get_all(path: str, params: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    import requests
    out: List[Dict[str, Any]] = []
    url = path if path.startswith("http") else ASC_BASE + path
    first = True
    while url:
        resp = requests.get(url, headers=_headers(), params=params if first else None, timeout=30)
        _err(resp)
        body = resp.json()
        out.extend(body.get("data", []))
        url = (body.get("links") or {}).get("next")
        first = False
    return out


def _post(path: str, body: Dict[str, Any]) -> Dict[str, Any]:
    import requests
    url = path if path.startswith("http") else ASC_BASE + path
    resp = requests.post(url, headers=_headers(), json=body, timeout=60)
    _err(resp)
    return resp.json() if resp.content else {}


def _patch(path: str, body: Dict[str, Any]) -> Dict[str, Any]:
    import requests
    url = path if path.startswith("http") else ASC_BASE + path
    resp = requests.patch(url, headers=_headers(), json=body, timeout=60)
    _err(resp)
    return resp.json() if resp.content else {}


def resolve_app_id() -> str:
    for app in _get("/v1/apps", params={"filter[bundleId]": BUNDLE_ID, "limit": 200}).get("data", []):
        if app.get("attributes", {}).get("bundleId") == BUNDLE_ID:
            return app["id"]
    sys.exit("No app found for bundle id %s." % BUNDLE_ID)


def iap_ids(app_id: str) -> Dict[str, str]:
    ids = {}
    for i in _get_all("/v1/apps/%s/inAppPurchasesV2" % app_id, params={"limit": 200}):
        ids[(i.get("attributes") or {}).get("productId")] = i["id"]
    return ids


# --- Stage: localization -----------------------------------------------------

def stage_localization(iap_id: str, name: str, desc: str, apply: bool) -> str:
    locs = _get("/v2/inAppPurchases/%s/inAppPurchaseLocalizations" % iap_id, params={"limit": 50}).get("data", [])
    same_locale = [l for l in locs if (l.get("attributes") or {}).get("locale") == LOCALE]
    if same_locale:
        attrs = same_locale[0].get("attributes") or {}
        if attrs.get("name") == name and attrs.get("description") == desc:
            return "loc  OK (already set)"
        if not apply:
            return "loc  would UPDATE en-US"
        _patch("/v1/inAppPurchaseLocalizations/%s" % same_locale[0]["id"],
               {"data": {"type": "inAppPurchaseLocalizations", "id": same_locale[0]["id"],
                         "attributes": {"name": name, "description": desc}}})
        return "loc  updated en-US"
    if not apply:
        return "loc  would CREATE en-US"
    _post("/v1/inAppPurchaseLocalizations",
          {"data": {"type": "inAppPurchaseLocalizations",
                    "attributes": {"locale": LOCALE, "name": name, "description": desc},
                    "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}}}})
    return "loc  created en-US"


# --- Stage: price ------------------------------------------------------------

def find_price_point(iap_id: str, price: str) -> Optional[str]:
    for p in _get_all("/v2/inAppPurchases/%s/pricePoints" % iap_id,
                      params={"filter[territory]": BASE_TERRITORY, "limit": 200}):
        if (p.get("attributes") or {}).get("customerPrice") == price:
            return p["id"]
    return None


def stage_price(iap_id: str, price: str, apply: bool) -> str:
    pp = find_price_point(iap_id, price)
    if not pp:
        return "price SKIP (no USA price point for %s)" % price
    if not apply:
        return "price would set $%s (USA base)" % price
    body = {
        "data": {
            "type": "inAppPurchasePriceSchedules",
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                "baseTerritory": {"data": {"type": "territories", "id": BASE_TERRITORY}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price}"}]},
            },
        },
        "included": [
            {"type": "inAppPurchasePrices", "id": "${price}",
             "attributes": {"startDate": None},
             "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": pp}}}}
        ],
    }
    _post("/v1/inAppPurchasePriceSchedules", body)
    return "price set $%s (USA base)" % price


# --- Stage: review screenshot ------------------------------------------------

def stage_screenshot(iap_id: str, path: str, apply: bool) -> str:
    if not os.path.isfile(path):
        return "shot SKIP (file missing: %s)" % path
    existing = _get_optional("/v2/inAppPurchases/%s/appStoreReviewScreenshot" % iap_id)
    if existing and existing.get("data"):
        return "shot OK (already present)"
    if not apply:
        return "shot would upload %s" % os.path.basename(path)

    import requests
    data = open(path, "rb").read()
    md5 = hashlib.md5(data).hexdigest()
    res = _post("/v1/inAppPurchaseAppStoreReviewScreenshots",
                {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots",
                          "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
                          "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}}}})
    sid = res["data"]["id"]
    for op in (res["data"]["attributes"].get("uploadOperations") or []):
        hdrs = {h["name"]: h["value"] for h in (op.get("requestHeaders") or [])}
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        r = requests.request(op.get("method", "PUT"), op["url"], headers=hdrs, data=chunk, timeout=120)
        if r.status_code >= 400:
            sys.exit("screenshot upload chunk failed: %s %s" % (r.status_code, r.text[:200]))
    _patch("/v1/inAppPurchaseAppStoreReviewScreenshots/%s" % sid,
           {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots", "id": sid,
                     "attributes": {"uploaded": True, "sourceFileChecksum": md5}}})
    return "shot uploaded (%s)" % os.path.basename(path)


# --- Stage: availability -----------------------------------------------------

def all_territory_ids() -> List[str]:
    return [t["id"] for t in _get_all("/v1/territories", params={"limit": 200})]


def stage_availability(iap_id: str, territory_ids: List[str], apply: bool) -> str:
    existing = _get_optional("/v2/inAppPurchases/%s/inAppPurchaseAvailability" % iap_id)
    if existing and existing.get("data"):
        return "avail OK (already set)"
    if not apply:
        return "avail would set (all %d territories + new)" % len(territory_ids)
    body = {
        "data": {
            "type": "inAppPurchaseAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territory_ids]},
            },
        }
    }
    _post("/v1/inAppPurchaseAvailabilities", body)
    return "avail set (%d territories)" % len(territory_ids)


# --- CLI ---------------------------------------------------------------------

def main(argv: Optional[List[str]] = None) -> None:
    p = argparse.ArgumentParser(description="Fill NumPad 2.0 IAP metadata. Dry-run by default; never submits.")
    p.add_argument("--apply", action="store_true", help="Perform writes. Without this, dry-run only.")
    p.add_argument("--stage", choices=["all", "localizations", "prices", "screenshots", "availability"], default="all")
    args = p.parse_args(argv)
    _require_runtime_deps()

    print("=" * 84)
    print("iap_metadata.py  -  STAGE-ONLY  -  %s" % datetime.date.today())
    print("App: NumPad (%s)   Stage: %s   Mode: %s"
          % (BUNDLE_ID, args.stage, "APPLY" if args.apply else "DRY-RUN"))
    print("=" * 84)

    app_id = resolve_app_id()
    ids = iap_ids(app_id)
    do_loc = args.stage in ("all", "localizations")
    do_price = args.stage in ("all", "prices")
    do_shot = args.stage in ("all", "screenshots")
    do_avail = args.stage in ("all", "availability")
    territory_ids = all_territory_ids() if do_avail else []

    for prod in PRODUCTS:
        pid = prod["pid"]
        iap_id = ids.get(pid)
        print("\n%s" % pid)
        if not iap_id:
            print("  [ERR] not found in this app.")
            continue
        if do_loc:
            print("  " + stage_localization(iap_id, prod["name"], prod["desc"], args.apply))
        if do_price:
            print("  " + stage_price(iap_id, prod["price"], args.apply))
        if do_shot:
            print("  " + stage_screenshot(iap_id, SCREENSHOT, args.apply))
        if do_avail:
            print("  " + stage_availability(iap_id, territory_ids, args.apply))

    print("\n" + ("Applied." if args.apply else "Dry-run only. Re-run with --apply to write."))
    print("Then check states with: python3 marketing/asc/iap_admin.py --list")


if __name__ == "__main__":
    main()
