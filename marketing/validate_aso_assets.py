#!/usr/bin/env python3
"""Validate local App Store metadata, IAP metadata, and screenshot assets."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
METADATA = ROOT / "fastlane" / "metadata"
IAP_METADATA = ROOT / "fastlane" / "iap_metadata"
MARKETING_SCREENSHOTS = ROOT / "marketing" / "app-store"
FASTLANE_SCREENSHOTS = ROOT / "fastlane" / "screenshots"

APP_LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "keywords.txt": 100,
    "promotional_text.txt": 170,
    "description.txt": 4000,
    "release_notes.txt": 4000,
}

IAP_LIMITS = {
    "name.txt": 30,
    "description.txt": 45,
}

MARKETING_DEVICE_SPECS = {
    "iphone-6.9": (1320, 2868),
    "iphone-6.5": (1284, 2778),
    "iphone-6.3": (1206, 2622),
    "iphone-6.1": (1125, 2436),
    "ipad-13": (2064, 2752),
    "ipad-12.9": (2048, 2732),
}

FASTLANE_DEVICE_PREFIXES = {
    "APP_IPHONE_67",
    "APP_IPHONE_65",
    "APP_IPHONE_61",
    "APP_IPAD_PRO_6GEN_129",
    "APP_IPAD_PRO_129",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


def image_size(path: Path) -> tuple[int, int]:
    with Image.open(path) as img:
        return img.size


def locale_suffix(locale: str) -> str:
    return "" if locale == "en-US" else f"-{locale}"


def main() -> int:
    errors: list[str] = []
    metadata_locales = sorted(p.name for p in METADATA.iterdir() if p.is_dir())

    for locale in metadata_locales:
        locale_dir = METADATA / locale
        for filename, limit in APP_LIMITS.items():
            path = locale_dir / filename
            if not path.exists():
                errors.append(f"missing app metadata: {path.relative_to(ROOT)}")
                continue
            length = len(read_text(path))
            if length > limit:
                errors.append(
                    f"app metadata too long: {path.relative_to(ROOT)} has {length}/{limit}"
                )

    for product_dir in sorted(p for p in IAP_METADATA.iterdir() if p.is_dir()):
        iap_locales = sorted(p.name for p in product_dir.iterdir() if p.is_dir())
        if iap_locales != metadata_locales:
            missing = sorted(set(metadata_locales) - set(iap_locales))
            extra = sorted(set(iap_locales) - set(metadata_locales))
            errors.append(
                f"{product_dir.name} locale mismatch; missing={missing}, extra={extra}"
            )

        for locale in iap_locales:
            locale_dir = product_dir / locale
            for filename, limit in IAP_LIMITS.items():
                path = locale_dir / filename
                if not path.exists():
                    errors.append(f"missing IAP metadata: {path.relative_to(ROOT)}")
                    continue
                length = len(read_text(path))
                if length > limit:
                    errors.append(
                        f"IAP metadata too long: {path.relative_to(ROOT)} has {length}/{limit}"
                    )

    for locale in metadata_locales:
        suffix = locale_suffix(locale)
        for device, expected_size in MARKETING_DEVICE_SPECS.items():
            directory = MARKETING_SCREENSHOTS / f"{device}{suffix}"
            pngs = sorted(directory.glob("*.png"))
            if len(pngs) != 6:
                errors.append(
                    f"marketing screenshot count: {directory.relative_to(ROOT)} has {len(pngs)}/6"
                )
                continue
            for png in pngs:
                actual_size = image_size(png)
                if actual_size != expected_size:
                    errors.append(
                        f"marketing screenshot size: {png.relative_to(ROOT)} has {actual_size}, expected {expected_size}"
                    )

    for locale in metadata_locales:
        directory = FASTLANE_SCREENSHOTS / locale
        pngs = sorted(directory.glob("*.png"))
        if len(pngs) != 30:
            errors.append(
                f"fastlane screenshot count: {directory.relative_to(ROOT)} has {len(pngs)}/30"
            )
            continue

        for prefix in FASTLANE_DEVICE_PREFIXES:
            matching = [png for png in pngs if png.name.startswith(prefix + "_")]
            if len(matching) != 6:
                errors.append(
                    f"fastlane screenshot device count: {directory.relative_to(ROOT)} {prefix} has {len(matching)}/6"
                )

    if errors:
        print("FAIL: ASO asset validation found issues")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"PASS: {len(metadata_locales)} app metadata locales")
    print("PASS: IAP metadata locales and character limits")
    print(f"PASS: {len(metadata_locales) * len(MARKETING_DEVICE_SPECS) * 6} marketing screenshots")
    print(f"PASS: {len(metadata_locales) * 30} fastlane screenshots")
    return 0


if __name__ == "__main__":
    sys.exit(main())
