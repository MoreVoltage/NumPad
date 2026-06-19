#!/usr/bin/env python3
"""
App Store Connect — Custom Product Page (CPP) management helper.

!!! UNTESTED. REVIEW BEFORE USE. !!!
This script has NOT been run against a live App Store Connect account. The ASC
API surface for Custom Product Pages (appCustomProductPages and related
resources) can change and may differ from what is encoded here. Treat every
request body below as a draft to verify against the current Apple docs:
  https://developer.apple.com/documentation/appstoreconnectapi

SAFETY MODEL
  - DRY-RUN BY DEFAULT. With no flags it only LISTS existing CPPs (read-only
    GET) and prints what a create would do. It writes nothing.
  - Mutations (creating CPPs / localizations / setting promo text) require the
    explicit --apply flag AND will still refuse anything submission-related.
  - There is NO submit capability in this script, by design. It cannot add a
    CPP, version, or IAP to review. Submission stays a manual, human action
    (see marketing/asc/cpp_runbook.md).
  - Screenshot binary upload is intentionally NOT implemented (it is a
    multi-step reserve/upload/commit flow). Use the ASC UI with the staged
    folders from marketing/assemble_cpp_screenshots.py.

AUTH (same env vars the repo Fastfile uses):
  - ASC_API_KEY_PATH=/path/to/api_key_info.json   (a JSON file with key_id,
    issuer_id, and key/key_content), OR
  - ASC_KEY_ID + ASC_ISSUER_ID + ASC_KEY_CONTENT  (PEM string for the .p8)
App id: com.morevoltage.NumPad

USAGE
  python3 marketing/asc/cpp_manage.py                 # list CPPs (read-only)
  python3 marketing/asc/cpp_manage.py --list          # explicit list
  python3 marketing/asc/cpp_manage.py --plan          # show create plan, no writes
  python3 marketing/asc/cpp_manage.py --apply --create-missing   # create CPPs (GUARDED)

Requires: pip install pyjwt cryptography requests   (only needed for live calls)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

APP_BUNDLE_ID = "com.morevoltage.NumPad"
ASC_BASE = "https://api.appstoreconnect.apple.com/v1"
PROMO_LIMIT = 170

# Mirror of the CPP definitions in custom-product-pages-v3.md /
# assemble_cpp_screenshots.py. Names are the internal reference names.
CPPS: dict[str, dict] = {
    "numpad-workflow": {
        "order": [1, 2, 3, 4, 5, 6],
        "promo": "Type numbers faster in any app. No subscription.",
    },
    "numpad-finance": {
        "order": [3, 5, 2, 4, 1, 6],
        "promo": ("Tax & tip calculator, currency symbols, and clipboard "
                  "history — straight from your keyboard."),
    },
    "numpad-spreadsheet": {
        "order": [1, 2, 4, 5, 3, 6],
        "promo": ("A fast number pad for spreadsheets and forms. Reuse "
                  "recent numbers. No subscription needed."),
    },
}


# --------------------------------------------------------------------------
# Auth
# --------------------------------------------------------------------------
def _load_key() -> dict:
    """Return {'key_id', 'issuer_id', 'private_key'} from env, or exit."""
    path = os.environ.get("ASC_API_KEY_PATH", "").strip()
    if path:
        data = json.loads(Path(path).read_text())
        # api_key_info.json conventionally has key_id, issuer_id, key (PEM).
        key = data.get("key") or data.get("key_content") or ""
        return {
            "key_id": data["key_id"],
            "issuer_id": data["issuer_id"],
            "private_key": key,
        }
    key_id = os.environ.get("ASC_KEY_ID", "").strip()
    issuer_id = os.environ.get("ASC_ISSUER_ID", "").strip()
    key_content = os.environ.get("ASC_KEY_CONTENT", "").strip()
    if key_id and issuer_id and key_content:
        # Allow literal "\n" in the env var.
        return {
            "key_id": key_id,
            "issuer_id": issuer_id,
            "private_key": key_content.replace("\\n", "\n"),
        }
    sys.exit("ERROR: set ASC_API_KEY_PATH or ASC_KEY_ID+ASC_ISSUER_ID+ASC_KEY_CONTENT.")


def _make_token(creds: dict) -> str:
    try:
        import jwt  # PyJWT
    except ImportError:
        sys.exit("ERROR: PyJWT not installed. Run: pip install pyjwt cryptography")
    now = int(time.time())
    payload = {"iss": creds["issuer_id"], "iat": now, "exp": now + 1200,
               "aud": "appstoreconnect-v1"}
    headers = {"kid": creds["key_id"], "typ": "JWT"}
    return jwt.encode(payload, creds["private_key"], algorithm="ES256", headers=headers)


def _session(token: str):
    try:
        import requests
    except ImportError:
        sys.exit("ERROR: requests not installed. Run: pip install requests")
    s = requests.Session()
    s.headers.update({"Authorization": f"Bearer {token}",
                      "Content-Type": "application/json"})
    return s


# --------------------------------------------------------------------------
# Read-only helpers
# --------------------------------------------------------------------------
def get_app_id(s) -> str:
    r = s.get(f"{ASC_BASE}/apps",
              params={"filter[bundleId]": APP_BUNDLE_ID, "limit": 1})
    r.raise_for_status()
    data = r.json().get("data", [])
    if not data:
        sys.exit(f"ERROR: app {APP_BUNDLE_ID} not found for this API key.")
    return data[0]["id"]


def list_cpps(s, app_id: str) -> list[dict]:
    # NOTE: verify this relationship/endpoint name against current ASC docs.
    r = s.get(f"{ASC_BASE}/apps/{app_id}/appCustomProductPages",
              params={"limit": 200})
    r.raise_for_status()
    return r.json().get("data", [])


# --------------------------------------------------------------------------
# Guarded mutation (create only; never submit)
# --------------------------------------------------------------------------
def create_cpp(s, app_id: str, name: str, apply: bool) -> None:
    """Create one CPP shell. Refuses unless apply=True. Never submits."""
    body = {
        "data": {
            "type": "appCustomProductPages",
            "attributes": {"name": name, "visible": True},
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
            },
        }
    }
    if not apply:
        print(f"  [DRY-RUN] would POST appCustomProductPages name={name!r}")
        print(f"            body={json.dumps(body)}")
        return
    # Final hard stop: this path NEVER touches any submit/review endpoint.
    r = s.post(f"{ASC_BASE}/appCustomProductPages", data=json.dumps(body))
    if r.status_code >= 300:
        print(f"  ERROR creating {name}: {r.status_code} {r.text}")
        return
    new_id = r.json().get("data", {}).get("id")
    print(f"  CREATED {name} -> id={new_id} (DRAFT, not submitted)")
    print( "    Next: add localizations + screenshots via the ASC UI using")
    print(f"    marketing/cpp/{name}/<device>/<locale>/ (see runbook).")


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
def verify_promos() -> None:
    bad = [(n, len(c["promo"])) for n, c in CPPS.items() if len(c["promo"]) > PROMO_LIMIT]
    if bad:
        for n, ln in bad:
            print(f"  FAIL {n}: {ln} > {PROMO_LIMIT}")
        sys.exit("ERROR: promo text over limit; fix before any apply.")


def cmd_plan() -> None:
    print("Planned CPPs (no network, no writes):")
    for name, cfg in CPPS.items():
        print(f"  - {name}: order={cfg['order']}, promo[{len(cfg['promo'])}] = {cfg['promo']!r}")
    print("\nScreenshots are NOT uploaded by this script. Stage them with")
    print("  python3 marketing/assemble_cpp_screenshots.py")
    print("and upload via the ASC UI (see marketing/asc/cpp_runbook.md).")


def main() -> None:
    ap = argparse.ArgumentParser(
        description="ASC Custom Product Page helper (dry-run by default; never submits).")
    ap.add_argument("--list", action="store_true", help="List existing CPPs (read-only).")
    ap.add_argument("--plan", action="store_true", help="Print create plan; no network.")
    ap.add_argument("--apply", action="store_true",
                    help="Permit mutations. Without this, all writes are dry-run.")
    ap.add_argument("--create-missing", action="store_true",
                    help="Create any CPP from CPPS that does not already exist by name.")
    args = ap.parse_args()

    verify_promos()

    # Pure-offline plan view.
    if args.plan or (not args.list and not args.create_missing and not args.apply):
        cmd_plan()
        if not (args.list or args.create_missing):
            print("\n(Default action is offline --plan. Use --list to query ASC,")
            print(" or --apply --create-missing to create drafts. This tool never submits.)")
            return

    creds = _load_key()
    token = _make_token(creds)
    s = _session(token)
    app_id = get_app_id(s)
    print(f"App {APP_BUNDLE_ID} -> id={app_id}")

    existing = list_cpps(s, app_id)
    existing_names = {c.get("attributes", {}).get("name") for c in existing}
    print(f"Existing CPPs ({len(existing)}):")
    for c in existing:
        attrs = c.get("attributes", {})
        print(f"  - id={c.get('id')} name={attrs.get('name')!r} visible={attrs.get('visible')}")

    if args.create_missing:
        if not args.apply:
            print("\n--apply not set: showing dry-run create plan only.")
        print("\nCreate-missing:")
        for name, _cfg in CPPS.items():
            if name in existing_names:
                print(f"  skip {name} (already exists)")
                continue
            create_cpp(s, app_id, name, apply=args.apply)

    print("\nDone. This tool never submits anything. Submit manually per the runbook.")


if __name__ == "__main__":
    main()
