#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
iap_admin.py - App Store Connect IAP hygiene helper for NumPad.

  ============================================================================
  STAGE-ONLY. UNTESTED AGAINST THE LIVE ACCOUNT. REVIEW + DRY-RUN FIRST.
  ============================================================================
  - Dry-run by default. Nothing is written without --apply.
  - Never deletes anything without BOTH --apply AND --confirm-delete.
  - Never deletes the two intended products (numpad.pro.lifetime,
    numpad.pack.finance) under any circumstances.
  - NEVER submits an app or IAP for review.
  - NEVER changes prices. (There is no pricing code in this file on purpose.)

What it can do:
  --list                List all IAPs for the app, with status + familySharable.
  --audit-drafts        List only draft / not-yet-approved IAPs (cleanup audit).
  --set-family-sharing  Set familySharable=true on the two non-consumables.
                        Requires --apply. Family Sharing is a ONE-WAY door in
                        ASC: once on, it cannot be turned off (you'd have to
                        delete + recreate the product). This tool only ever sets
                        it to TRUE, never false.
  --delete-iap ID       Delete a single draft IAP by product id or ASC resource
                        id. Requires --apply AND --confirm-delete. Refuses the
                        two intended products. Intended only for the 7 legacy
                        draft IAPs after you have confirmed they have NO sales
                        history. Deletion is likely irreversible.

Auth (environment variables; never hard-code keys):
  ASC_KEY_ID        10-char App Store Connect API Key ID            (required)
  ASC_ISSUER_ID     Issuer ID (UUID) from Users and Access          (required)
  and ONE of:
  ASC_API_KEY_PATH  path to the AuthKey_XXXXXXXXXX.p8 file           (preferred)
  ASC_KEY_CONTENT   the .p8 private key contents inline (e.g. CI secret)
  (ASC_API_KEY_PATH wins if both are set.)

Dependencies:
  pip install pyjwt cryptography requests

App: NumPad, bundle id com.morevoltage.NumPad

API endpoints used (App Store Connect API, base https://api.appstoreconnect.apple.com):
  GET   /v1/apps?filter[bundleId]=com.morevoltage.NumPad     -> resolve app id
  GET   /v1/apps/{appId}/inAppPurchasesV2                    -> list IAPs
  PATCH /v2/inAppPurchases/{iapId}  body familySharable=true -> enable Family Sharing
  DELETE /v2/inAppPurchases/{iapId}                          -> delete a draft IAP
NOTE: Apple revises these resources over time; if an attribute/endpoint name has
changed, this script will surface the API error rather than guessing. Treat the
endpoint list above as "verify against current Apple docs."
"""

from __future__ import annotations

import argparse
import datetime
import os
import sys
import time
from typing import Any, Dict, List, Optional

# --- Constants ---------------------------------------------------------------

BUNDLE_ID = "com.morevoltage.NumPad"
ASC_BASE = "https://api.appstoreconnect.apple.com"

# The two products that are REAL and intended. Never delete these. Family
# Sharing is set ON for exactly these.
INTENDED_PRODUCT_IDS = ("numpad.pro.lifetime", "numpad.pack.finance")

# JWT audience required by App Store Connect.
JWT_AUDIENCE = "appstoreconnect-v1"
# Apple caps token validity at 20 minutes; stay safely under that.
JWT_LIFETIME_SECONDS = 15 * 60

# Statuses that count as "approved / live-ready" vs "draft-ish". Apple has used
# several state strings over time; treat anything not clearly approved as draft.
APPROVED_STATES = {"APPROVED", "READY_TO_SUBMIT", "DEVELOPER_ACTION_NEEDED_APPROVED"}


# --- Lazy imports (so --help works without deps installed) -------------------

def _require_runtime_deps():
    try:
        import jwt  # noqa: F401  (PyJWT)
        import requests  # noqa: F401
    except ImportError as exc:
        sys.exit(
            "Missing dependency: %s\n"
            "Install with: pip install pyjwt cryptography requests" % exc
        )


# --- Auth --------------------------------------------------------------------

def _load_private_key() -> str:
    """Read the .p8 private key contents from env (path preferred)."""
    key_path = os.environ.get("ASC_API_KEY_PATH")
    key_content = os.environ.get("ASC_KEY_CONTENT")
    if key_path:
        if not os.path.isfile(key_path):
            sys.exit("ASC_API_KEY_PATH is set but file not found: %s" % key_path)
        with open(key_path, "r", encoding="utf-8") as fh:
            return fh.read()
    if key_content:
        return key_content
    sys.exit(
        "No private key. Set ASC_API_KEY_PATH (path to .p8) or ASC_KEY_CONTENT "
        "(inline .p8 contents)."
    )


def _generate_token() -> str:
    """Build a short-lived ES256 JWT for the App Store Connect API."""
    import jwt  # PyJWT

    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer_id:
        sys.exit("Set ASC_KEY_ID and ASC_ISSUER_ID environment variables.")

    private_key = _load_private_key()
    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + JWT_LIFETIME_SECONDS,
        "aud": JWT_AUDIENCE,
    }
    headers = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)
    # PyJWT >= 2 returns str; older returns bytes.
    if isinstance(token, bytes):
        token = token.decode("utf-8")
    return token


def _auth_headers() -> Dict[str, str]:
    return {
        "Authorization": "Bearer %s" % _generate_token(),
        "Content-Type": "application/json",
    }


# --- HTTP helpers ------------------------------------------------------------

def _get(path: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    import requests

    url = path if path.startswith("http") else ASC_BASE + path
    resp = requests.get(url, headers=_auth_headers(), params=params, timeout=30)
    _raise_for_api_error(resp)
    return resp.json()


def _get_all_pages(path: str, params: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    """Follow ASC cursor pagination, returning the concatenated `data` arrays."""
    import requests

    results: List[Dict[str, Any]] = []
    url = path if path.startswith("http") else ASC_BASE + path
    first = True
    while url:
        resp = requests.get(
            url, headers=_auth_headers(), params=params if first else None, timeout=30
        )
        _raise_for_api_error(resp)
        body = resp.json()
        results.extend(body.get("data", []))
        url = (body.get("links") or {}).get("next")
        first = False
    return results


def _patch(path: str, body: Dict[str, Any]) -> Dict[str, Any]:
    import requests

    url = path if path.startswith("http") else ASC_BASE + path
    resp = requests.patch(url, headers=_auth_headers(), json=body, timeout=30)
    _raise_for_api_error(resp)
    return resp.json() if resp.content else {}


def _delete(path: str) -> None:
    import requests

    url = path if path.startswith("http") else ASC_BASE + path
    resp = requests.delete(url, headers=_auth_headers(), timeout=30)
    _raise_for_api_error(resp)


def _raise_for_api_error(resp) -> None:
    if resp.status_code < 400:
        return
    detail = ""
    try:
        payload = resp.json()
        errors = payload.get("errors", [])
        detail = "; ".join(
            "%s: %s" % (e.get("title", "error"), e.get("detail", "")) for e in errors
        )
    except Exception:
        detail = resp.text[:500]
    sys.exit("API error %s on %s\n  %s" % (resp.status_code, resp.url, detail))


# --- Domain logic ------------------------------------------------------------

def resolve_app_id() -> str:
    """Resolve the ASC app resource id from the bundle id."""
    body = _get("/v1/apps", params={"filter[bundleId]": BUNDLE_ID, "limit": 200})
    data = body.get("data", [])
    for app in data:
        if app.get("attributes", {}).get("bundleId") == BUNDLE_ID:
            return app["id"]
    if data:
        # Filter returned something but bundle id didn't match exactly; be strict.
        sys.exit(
            "Bundle id filter returned apps but none matched %s exactly. "
            "Refusing to guess." % BUNDLE_ID
        )
    sys.exit("No app found for bundle id %s with these credentials." % BUNDLE_ID)


def fetch_iaps(app_id: str) -> List[Dict[str, Any]]:
    """List all in-app purchases for the app (v2 relationship)."""
    return _get_all_pages(
        "/v1/apps/%s/inAppPurchasesV2" % app_id,
        params={"limit": 200},
    )


def _iap_fields(iap: Dict[str, Any]) -> Dict[str, Any]:
    attrs = iap.get("attributes", {}) or {}
    return {
        "id": iap.get("id", "?"),
        "product_id": attrs.get("productId", "?"),
        "name": attrs.get("name", ""),
        "type": attrs.get("inAppPurchaseType", attrs.get("type", "?")),
        "state": attrs.get("state", attrs.get("status", "?")),
        "family_sharable": attrs.get("familySharable", None),
    }


def _is_draft(fields: Dict[str, Any]) -> bool:
    state = str(fields.get("state", "")).upper()
    return state not in APPROVED_STATES


def print_iap_table(iaps: List[Dict[str, Any]], title: str) -> None:
    rows = [_iap_fields(i) for i in iaps]
    print("\n%s (%d)" % (title, len(rows)))
    print("-" * 96)
    print(
        "%-26s %-30s %-16s %-22s %s"
        % ("product_id", "name", "type", "state", "familyShare")
    )
    print("-" * 96)
    for r in sorted(rows, key=lambda x: str(x["product_id"])):
        fs = r["family_sharable"]
        fs_str = "true" if fs is True else ("false" if fs is False else "?")
        print(
            "%-26s %-30s %-16s %-22s %s"
            % (
                str(r["product_id"])[:26],
                str(r["name"])[:30],
                str(r["type"])[:16],
                str(r["state"])[:22],
                fs_str,
            )
        )
    print("-" * 96)


# --- Actions -----------------------------------------------------------------

def action_list(app_id: str) -> None:
    iaps = fetch_iaps(app_id)
    print_iap_table(iaps, "All in-app purchases")


def action_audit_drafts(app_id: str) -> None:
    iaps = fetch_iaps(app_id)
    drafts = [i for i in iaps if _is_draft(_iap_fields(i))]
    print_iap_table(drafts, "DRAFT / not-approved in-app purchases (cleanup audit)")
    print(
        "\nReview: intended products are %s.\n"
        "Anything else here is a candidate for deletion ONLY after you confirm it\n"
        "has NO sales history. This command made no changes." % (INTENDED_PRODUCT_IDS,)
    )


def action_set_family_sharing(app_id: str, apply_changes: bool) -> None:
    iaps = fetch_iaps(app_id)
    by_product = {_iap_fields(i)["product_id"]: i for i in iaps}

    print("\nFamily Sharing -> set TRUE on the two non-consumables")
    print("-" * 96)
    for pid in INTENDED_PRODUCT_IDS:
        iap = by_product.get(pid)
        if not iap:
            print("  [SKIP] %s not found in this account." % pid)
            continue
        fields = _iap_fields(iap)
        current = fields["family_sharable"]
        iap_id = fields["id"]
        if current is True:
            print("  [OK]   %s already familySharable=true; nothing to do." % pid)
            continue

        if not apply_changes:
            print(
                "  [DRY]  would PATCH /v2/inAppPurchases/%s familySharable=true  (%s)"
                % (iap_id, pid)
            )
            continue

        body = {
            "data": {
                "type": "inAppPurchases",
                "id": iap_id,
                "attributes": {"familySharable": True},
            }
        }
        _patch("/v2/inAppPurchases/%s" % iap_id, body)
        print("  [DONE] %s familySharable set to true." % pid)
    print("-" * 96)
    if not apply_changes:
        print("Dry-run: no changes written. Re-run with --apply to make changes.")
    else:
        print(
            "Reminder: Family Sharing CANNOT be turned off later without deleting\n"
            "and recreating the product. This tool never sets it to false."
        )


def action_delete_iap(
    app_id: str, target: str, apply_changes: bool, confirm_delete: bool
) -> None:
    if target in INTENDED_PRODUCT_IDS:
        sys.exit(
            "REFUSED: %s is an intended product and will never be deleted by this "
            "tool." % target
        )

    iaps = fetch_iaps(app_id)
    match = None
    for i in iaps:
        f = _iap_fields(i)
        if target in (f["product_id"], f["id"]):
            match = i
            break
    if not match:
        sys.exit("No IAP found matching '%s' (by product id or resource id)." % target)

    f = _iap_fields(match)
    if f["product_id"] in INTENDED_PRODUCT_IDS:
        sys.exit("REFUSED: resolved to intended product %s." % f["product_id"])

    print("\nDelete candidate:")
    print(
        "  product_id=%s  id=%s  state=%s  name=%s"
        % (f["product_id"], f["id"], f["state"], f["name"])
    )

    if not _is_draft(f):
        print(
            "  [WARN] This product is in an APPROVED-like state (%s), not a draft."
            % f["state"]
        )
        print("  This tool is intended for the legacy DRAFT IAP cleanup only.")

    if not (apply_changes and confirm_delete):
        print(
            "\n[DRY] would DELETE /v2/inAppPurchases/%s\n"
            "No deletion performed. Deletion requires BOTH --apply AND "
            "--confirm-delete.\n"
            "Confirm this product has NO sales history before deleting; deletion is "
            "likely irreversible." % f["id"]
        )
        return

    _delete("/v2/inAppPurchases/%s" % f["id"])
    print("[DONE] Deleted IAP %s (%s)." % (f["id"], f["product_id"]))


# --- CLI ---------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description=(
            "App Store Connect IAP hygiene helper for NumPad. STAGE-ONLY, "
            "UNTESTED, dry-run by default. Never submits, never changes prices."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    actions = p.add_mutually_exclusive_group(required=True)
    actions.add_argument("--list", action="store_true", help="List all IAPs with status.")
    actions.add_argument(
        "--audit-drafts", action="store_true", help="List draft/not-approved IAPs."
    )
    actions.add_argument(
        "--set-family-sharing",
        action="store_true",
        help="Set familySharable=true on the two non-consumables (needs --apply).",
    )
    actions.add_argument(
        "--delete-iap",
        metavar="ID",
        help="Delete a draft IAP by product id or resource id "
        "(needs --apply AND --confirm-delete).",
    )

    p.add_argument(
        "--apply",
        action="store_true",
        help="Actually perform writes. Without this, all write actions are dry-run.",
    )
    p.add_argument(
        "--confirm-delete",
        action="store_true",
        help="Required (with --apply) to actually delete. Safety interlock.",
    )
    return p


def main(argv: Optional[List[str]] = None) -> None:
    args = build_parser().parse_args(argv)
    _require_runtime_deps()

    print("=" * 76)
    print("iap_admin.py  -  STAGE-ONLY / UNTESTED  -  %s" % datetime.date.today())
    print("App: NumPad (%s)" % BUNDLE_ID)
    print("Mode: %s" % ("APPLY (writes enabled)" if args.apply else "DRY-RUN (read-only / no writes)"))
    print("=" * 76)

    app_id = resolve_app_id()
    print("Resolved app id: %s" % app_id)

    if args.list:
        action_list(app_id)
    elif args.audit_drafts:
        action_audit_drafts(app_id)
    elif args.set_family_sharing:
        action_set_family_sharing(app_id, apply_changes=args.apply)
    elif args.delete_iap:
        action_delete_iap(
            app_id,
            target=args.delete_iap,
            apply_changes=args.apply,
            confirm_delete=args.confirm_delete,
        )


if __name__ == "__main__":
    main()
