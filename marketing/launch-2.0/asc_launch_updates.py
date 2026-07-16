#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
asc_launch_updates.py - Post-launch App Store Connect updates for NumPad 2.0 publicity:

  Stage "promo"  - refresh Promotional Text on the LIVE (READY_FOR_SALE) version's English
                   localizations. Promotional text updates do NOT require a new version or
                   App Review.
  Stage "event"  - create a DRAFT In-App Event ("NumPad 2.0 Launch", MAJOR_UPDATE badge)
                   with en-US localization. In-App Events are free App Store visibility
                   (search, Today-tab eligibility) most small apps never use.
  Stage "media"  - attach the 1080x1920 event card image to the event localization
                   (reuses marketing/video/out/poster-iphone.png).

  ============================================================================
  STAGE-ONLY. Dry-run by default. NEVER submits for review (a human submits the
  event from ASC > NumPad > In-App Events after eyeballing the draft).
  ============================================================================

Auth (env vars; never hard-code keys):
  ASC_KEY_ID, ASC_ISSUER_ID, and ASC_API_KEY_PATH (.p8 path).
Deps: pip install pyjwt cryptography requests

Usage:
  python3 marketing/launch-2.0/asc_launch_updates.py                    # dry-run, all stages
  python3 marketing/launch-2.0/asc_launch_updates.py --stage promo --apply
  python3 marketing/launch-2.0/asc_launch_updates.py --stage event --apply
  python3 marketing/launch-2.0/asc_launch_updates.py --stage media --apply
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

# --- Content -----------------------------------------------------------------

# <=170 chars. Applied to every English locale that exists on the live version.
PROMO_TEXT = ("NumPad 2.0 is here: math that computes as you type, Siri Shortcuts, "
              "Liquid Glass themes, a build-your-own keyboard, and iPad kiosk mode. "
              "No subscription.")

PROMO_LOCALES = {"en-US", "en-GB", "en-CA", "en-AU"}

EVENT = {
    "referenceName": "NumPad 2.0 Launch",
    "badge": "MAJOR_UPDATE",
    # No deepLink: ASC rejects a bare scheme ("numpad://") as not a valid URL, and the app
    # defines no dedicated event landing route — the card opening the app/product page is fine.
    "purchaseRequirement": "NO_COST_ASSOCIATED",
    "primaryLocale": "en-US",
    "purpose": "ATTRACT_NEW_USERS",
}

EVENT_LOCALIZATION = {
    "locale": "en-US",
    # name <=30, shortDescription <=50, longDescription <=120 (ASC hard limits)
    "name": "NumPad 2.0: Live Math",
    "shortDescription": "Math computes as you type - plus Siri & packs",
    "longDescription": ("Type 84.50*1.18 and the answer floats above your cursor. "
                        "New packs, Siri Shortcuts, Liquid Glass themes."),
}

# In-App Event media specs: the event CARD is landscape 1920x1080; the event DETAILS page
# takes portrait 1080x1920. Both attach to the same en-US localization.
EVENT_ASSETS = [
    ("marketing/launch-2.0/event-card-1920x1080.png", "EVENT_CARD"),
    ("marketing/video/out/poster-iphone.png", "EVENT_DETAILS_PAGE"),
]

# Scheduling: events need App Review lead time; default start is +4 days, 14-day run.
DEFAULT_START_DAYS = 4
DEFAULT_DURATION_DAYS = 14


def _require_runtime_deps():
    try:
        import jwt  # noqa: F401
        import requests  # noqa: F401
    except ImportError as exc:
        sys.exit("Missing dependency: %s\nInstall: pip install pyjwt cryptography requests" % exc)


def _load_private_key() -> str:
    key_path = os.environ.get("ASC_API_KEY_PATH")
    if not key_path:
        sys.exit("ASC_API_KEY_PATH not set (path to the .p8 key)")
    if not os.path.isfile(os.path.expanduser(key_path)):
        sys.exit("ASC_API_KEY_PATH set but file not found: %s" % key_path)
    with open(os.path.expanduser(key_path), "r", encoding="utf-8") as fh:
        return fh.read()


def _token() -> str:
    import jwt
    key_id = os.environ.get("ASC_KEY_ID") or sys.exit("ASC_KEY_ID not set")
    issuer = os.environ.get("ASC_ISSUER_ID") or sys.exit("ASC_ISSUER_ID not set")
    now = int(time.time())
    payload = {"iss": issuer, "iat": now, "exp": now + JWT_LIFETIME_SECONDS, "aud": JWT_AUDIENCE}
    return jwt.encode(payload, _load_private_key(), algorithm="ES256", headers={"kid": key_id})


def _headers() -> Dict[str, str]:
    return {"Authorization": "Bearer %s" % _token(), "Content-Type": "application/json"}


def _get(path: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    import requests
    r = requests.get(ASC_BASE + path, headers=_headers(), params=params or {}, timeout=60)
    if r.status_code >= 400:
        sys.exit("GET %s failed (%d): %s" % (path, r.status_code, r.text[:500]))
    return r.json()


def _post(path: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    import requests
    r = requests.post(ASC_BASE + path, headers=_headers(), json=payload, timeout=60)
    if r.status_code >= 400:
        sys.exit("POST %s failed (%d): %s" % (path, r.status_code, r.text[:800]))
    return r.json()


def _patch(path: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    import requests
    r = requests.patch(ASC_BASE + path, headers=_headers(), json=payload, timeout=60)
    if r.status_code >= 400:
        sys.exit("PATCH %s failed (%d): %s" % (path, r.status_code, r.text[:800]))
    return r.json() if r.text else {}


def resolve_app_id() -> str:
    data = _get("/v1/apps", {"filter[bundleId]": BUNDLE_ID})["data"]
    if not data:
        sys.exit("No app found for bundle id %s" % BUNDLE_ID)
    return data[0]["id"]


# --- Stage: promo ------------------------------------------------------------

def stage_promo(app_id: str, apply: bool) -> None:
    assert len(PROMO_TEXT) <= 170, "PROMO_TEXT is %d chars (limit 170)" % len(PROMO_TEXT)
    versions = _get("/v1/apps/%s/appStoreVersions" % app_id,
                    {"filter[appStoreState]": "READY_FOR_SALE", "limit": 1})["data"]
    if not versions:
        sys.exit("No READY_FOR_SALE version found - is 2.0 live?")
    vid = versions[0]["id"]
    vstr = versions[0]["attributes"]["versionString"]
    print("Live version: %s (%s)" % (vstr, vid))

    locs = _get("/v1/appStoreVersions/%s/appStoreVersionLocalizations" % vid,
                {"limit": 200})["data"]
    targets = [l for l in locs if l["attributes"]["locale"] in PROMO_LOCALES]
    for loc in targets:
        locale = loc["attributes"]["locale"]
        current = (loc["attributes"].get("promotionalText") or "").strip()
        if current == PROMO_TEXT:
            print("  %s: already current - skip" % locale)
            continue
        print("  %s: %s -> %r" % (locale, "UPDATE" if apply else "would update", PROMO_TEXT))
        if apply:
            _patch("/v1/appStoreVersionLocalizations/%s" % loc["id"], {
                "data": {"type": "appStoreVersionLocalizations", "id": loc["id"],
                         "attributes": {"promotionalText": PROMO_TEXT}}})
    print("promo stage done (%d locales considered)." % len(targets))


# --- Stage: event ------------------------------------------------------------

def _iso(dt: datetime.datetime) -> str:
    return dt.replace(microsecond=0).isoformat() + "Z"


def stage_event(app_id: str, apply: bool, start_days: int, duration_days: int) -> Optional[str]:
    for field, limit in (("name", 30), ("shortDescription", 50), ("longDescription", 120)):
        val = EVENT_LOCALIZATION[field]
        assert len(val) <= limit, "%s is %d chars (limit %d): %r" % (field, len(val), limit, val)

    existing = _get("/v1/apps/%s/appEvents" % app_id, {"limit": 50})["data"]
    for ev in existing:
        if ev["attributes"]["referenceName"] == EVENT["referenceName"]:
            print("Event %r already exists (%s, state=%s) - reusing." % (
                EVENT["referenceName"], ev["id"], ev["attributes"].get("eventState")))
            return ev["id"]

    now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
    start = now + datetime.timedelta(days=start_days)
    end = start + datetime.timedelta(days=duration_days)
    schedule = {
        "publishStart": _iso(start - datetime.timedelta(days=1)),
        "eventStart": _iso(start),
        "eventEnd": _iso(end),
    }
    # The API requires an explicit territories list inside each schedule entry — "all
    # territories" is expressed by listing them all (fetched live; ~175 ids like "USA").
    territories = [t["id"] for t in _get("/v1/territories", {"limit": 200})["data"]]
    attributes = dict(EVENT)
    attributes["territorySchedules"] = [dict(schedule, territories=territories)]
    payload = {"data": {"type": "appEvents", "attributes": attributes,
                        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}
    print("Event plan: %s [%s] %s -> %s (%d territories)" % (
        EVENT["referenceName"], EVENT["badge"], _iso(start), _iso(end), len(territories)))
    if not apply:
        print("  (dry-run: event + en-US localization would be created as DRAFT)")
        return None

    event_id = _post("/v1/appEvents", payload)["data"]["id"]
    print("  created appEvent %s" % event_id)
    loc_payload = {"data": {"type": "appEventLocalizations",
                            "attributes": EVENT_LOCALIZATION,
                            "relationships": {"appEvent": {"data": {"type": "appEvents",
                                                                    "id": event_id}}}}}
    loc_id = _post("/v1/appEventLocalizations", loc_payload)["data"]["id"]
    print("  created en-US localization %s" % loc_id)
    print("event stage done. Event is a DRAFT - review + submit it in ASC by hand.")
    return event_id


# --- Stage: media ------------------------------------------------------------

def _delete(path: str) -> None:
    import requests
    r = requests.delete(ASC_BASE + path, headers=_headers(), timeout=60)
    if r.status_code >= 400:
        sys.exit("DELETE %s failed (%d): %s" % (path, r.status_code, r.text[:300]))


def stage_media(app_id: str, apply: bool) -> None:
    events = _get("/v1/apps/%s/appEvents" % app_id, {"limit": 50})["data"]
    event = next((e for e in events
                  if e["attributes"]["referenceName"] == EVENT["referenceName"]), None)
    if event is None:
        sys.exit("Event %r not found - run --stage event --apply first." % EVENT["referenceName"])
    locs = _get("/v1/appEvents/%s/localizations" % event["id"], {"limit": 10})["data"]
    loc = next((l for l in locs if l["attributes"]["locale"] == "en-US"), None)
    if loc is None:
        sys.exit("en-US localization missing on event %s" % event["id"])

    import requests
    shots = _get("/v1/appEventLocalizations/%s/appEventScreenshots" % loc["id"],
                 {"limit": 10})["data"]
    # Clear out FAILED / never-committed reservations so re-runs are self-healing.
    healthy_types = set()
    for s in shots:
        state = (s["attributes"].get("assetDeliveryState") or {}).get("state", "")
        atype = s["attributes"].get("appEventAssetType", "")
        if state in ("COMPLETE", "UPLOAD_COMPLETE"):
            healthy_types.add(atype)
        else:
            print("  removing %s asset %s (state=%s)" % (atype, s["id"], state))
            if apply:
                _delete("/v1/appEventScreenshots/%s" % s["id"])

    for path, asset_type in EVENT_ASSETS:
        if asset_type in healthy_types:
            print("  %s already attached - skip." % asset_type)
            continue
        if not os.path.isfile(path):
            sys.exit("Asset not found: %s" % path)
        size = os.path.getsize(path)
        print("  %s %s -> %s (%d bytes)" % (
            "uploading" if apply else "would upload", path, asset_type, size))
        if not apply:
            continue
        reserve = _post("/v1/appEventScreenshots", {
            "data": {"type": "appEventScreenshots",
                     "attributes": {"fileName": os.path.basename(path), "fileSize": size,
                                    "appEventAssetType": asset_type},
                     "relationships": {"appEventLocalization": {
                         "data": {"type": "appEventLocalizations", "id": loc["id"]}}}}})
        asset = reserve["data"]
        with open(path, "rb") as fh:
            blob = fh.read()
        for op in asset["attributes"]["uploadOperations"]:
            chunk = blob[op["offset"]:op["offset"] + op["length"]]
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            r = requests.request(op["method"], op["url"], data=chunk, headers=headers, timeout=120)
            if r.status_code >= 400:
                sys.exit("chunk upload failed (%d): %s" % (r.status_code, r.text[:300]))
        # Commit with `uploaded` only: the API rejects a sourceFileChecksum attribute here
        # (422 on that pointer), and accepts the commit without it.
        _patch("/v1/appEventScreenshots/%s" % asset["id"], {
            "data": {"type": "appEventScreenshots", "id": asset["id"],
                     "attributes": {"uploaded": True}}})
        # Poll until Apple validates the image (FAILED here = wrong dimensions etc.).
        for _ in range(12):
            time.sleep(5)
            state = (_get("/v1/appEventScreenshots/%s" % asset["id"])["data"]["attributes"]
                     .get("assetDeliveryState") or {}).get("state", "")
            if state in ("COMPLETE", "UPLOAD_COMPLETE"):
                print("  %s validated (%s)" % (asset_type, state))
                break
            if state == "FAILED":
                sys.exit("  %s FAILED validation - check dimensions/spec." % asset_type)
        else:
            print("  %s still processing - check ASC later." % asset_type)
    print("media stage done.")


# --- Main ----------------------------------------------------------------------

def main() -> None:
    _require_runtime_deps()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", choices=["promo", "event", "media"], default=None,
                        help="run one stage (default: all, in order)")
    parser.add_argument("--apply", action="store_true", help="actually write (default dry-run)")
    parser.add_argument("--start-days", type=int, default=DEFAULT_START_DAYS)
    parser.add_argument("--duration-days", type=int, default=DEFAULT_DURATION_DAYS)
    args = parser.parse_args()

    app_id = resolve_app_id()
    print("App: %s (%s)%s" % (BUNDLE_ID, app_id, "" if args.apply else "  [DRY-RUN]"))
    if args.stage in (None, "promo"):
        stage_promo(app_id, args.apply)
    if args.stage in (None, "event"):
        stage_event(app_id, args.apply, args.start_days, args.duration_days)
    if args.stage in (None, "media"):
        stage_media(app_id, args.apply)


if __name__ == "__main__":
    main()
