#!/usr/bin/env python3
"""
Copy generated App Store screenshots from marketing/app-store/
into fastlane/screenshots/{locale}/ with fastlane deliver naming.

Fastlane screenshot naming: {DEVICE_TYPE}_{order}.png

Usage:
    python3 marketing/setup_fastlane_screenshots.py
    python3 marketing/setup_fastlane_screenshots.py --clean   # remove existing first
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "marketing" / "app-store"
DST = ROOT / "fastlane" / "screenshots"

# Marketing dir suffix → fastlane locale code
LOCALE_MAP: dict[str, str] = {
    "": "en-US",
    "-ar-SA": "ar-SA",
    "-bn-BD": "bn-BD",
    "-ca": "ca",
    "-cs": "cs",
    "-da": "da",
    "-de-DE": "de-DE",
    "-el": "el",
    "-en-AU": "en-AU",
    "-en-CA": "en-CA",
    "-en-GB": "en-GB",
    "-es-ES": "es-ES",
    "-es-MX": "es-MX",
    "-fi": "fi",
    "-fr-CA": "fr-CA",
    "-fr-FR": "fr-FR",
    "-gu-IN": "gu-IN",
    "-he": "he",
    "-hi": "hi",
    "-hr": "hr",
    "-hu": "hu",
    "-id": "id",
    "-it": "it",
    "-ja": "ja",
    "-kn-IN": "kn-IN",
    "-ko": "ko",
    "-ml-IN": "ml-IN",
    "-mr-IN": "mr-IN",
    "-ms": "ms",
    "-nl-NL": "nl-NL",
    "-no": "no",
    "-or-IN": "or-IN",
    "-pa-IN": "pa-IN",
    "-pl": "pl",
    "-pt-BR": "pt-BR",
    "-pt-PT": "pt-PT",
    "-ro": "ro",
    "-ru": "ru",
    "-sk": "sk",
    "-sl-SI": "sl-SI",
    "-sv": "sv",
    "-ta-IN": "ta-IN",
    "-te-IN": "te-IN",
    "-th": "th",
    "-tr": "tr",
    "-uk": "uk",
    "-ur-PK": "ur-PK",
    "-vi": "vi",
    "-zh-Hans": "zh-Hans",
    "-zh-Hant": "zh-Hant",
}

# Marketing dir prefix → fastlane device keyword
# See: https://docs.fastlane.tools/actions/deliver/#available-screenshot-types
DEVICE_MAP: dict[str, str] = {
    "iphone-6.9": "APP_IPHONE_67",
    "iphone-6.5": "APP_IPHONE_65",
    "iphone-6.1": "APP_IPHONE_61",
    "ipad-13": "APP_IPAD_PRO_6GEN_129",
    "ipad-12.9": "APP_IPAD_PRO_129",
}
# Skip iphone-6.3 — no standard deliver device type for that size.


def main() -> None:
    clean = "--clean" in sys.argv

    if clean and DST.exists():
        print("Cleaning fastlane/screenshots/...")
        shutil.rmtree(DST, ignore_errors=True)

    total = 0

    for locale_suffix, fl_locale in sorted(LOCALE_MAP.items()):
        locale_dir = DST / fl_locale
        locale_dir.mkdir(parents=True, exist_ok=True)
        locale_count = 0

        for device_prefix, device_kw in sorted(DEVICE_MAP.items()):
            src_dir = SRC / f"{device_prefix}{locale_suffix}"
            if not src_dir.is_dir():
                continue

            pngs = sorted(src_dir.glob("*.png"))
            for order, img in enumerate(pngs, start=1):
                dst_name = f"{device_kw}_{order:02d}.png"
                shutil.copy2(img, locale_dir / dst_name)
                locale_count += 1

        total += locale_count
        print(f"  {fl_locale}: {locale_count} screenshots")

    print(f"\nDone. Copied {total} screenshots to fastlane/screenshots/")
    print("\nTo upload metadata only:")
    print("  fastlane upload_metadata")
    print("\nTo upload screenshots only:")
    print("  fastlane upload_screenshots")
    print("\nTo upload app metadata + screenshots:")
    print("  fastlane upload_all")


if __name__ == "__main__":
    main()
