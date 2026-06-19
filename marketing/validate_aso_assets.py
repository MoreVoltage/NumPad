#!/usr/bin/env python3
"""Validate local App Store metadata, IAP metadata, and screenshot assets."""
from __future__ import annotations

import json
import shutil
import subprocess
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

    # --- iPad genuineness guard ---
    # The pixel-size checks above pass even for the old "iPhone scaled onto an iPad canvas" bug.
    # Genuine iPad slides require the iPad raws (real iPad-specific UI) + the iPad device frame, so
    # assert those inputs exist whenever iPad marketing output is present.
    if (MARKETING_SCREENSHOTS / "ipad-13").is_dir():
        ipad_raw_dir = ROOT / "marketing" / "raw" / "ipad"
        raws = sorted(ipad_raw_dir.glob("[0-9]*.png")) if ipad_raw_dir.is_dir() else []
        if len(raws) < 6:
            errors.append(
                f"iPad raws: expected >=6 genuine iPad raws in marketing/raw/ipad, found {len(raws)} "
                f"(run marketing/generate_ipad_raws.py)"
            )
        ipad_frame = ROOT / "marketing" / "assets" / "ipad-mockup.png"
        if not ipad_frame.exists():
            errors.append("iPad device frame missing: marketing/assets/ipad-mockup.png")

    # --- Video assets (warn-only: staged previews + commercial, validated when present) ---
    warnings: list[str] = []
    VIDEO_SPECS = {
        "app-store-preview-iphone.mp4": ((1080, 1920), (15, 30)),
        "commercial-master-portrait.mp4": ((1080, 1920), (20, 65)),
        "social-15s.mp4": ((1080, 1920), (10, 20)),
        "social-6s.mp4": ((1080, 1920), (4, 8)),
    }
    video_out = ROOT / "marketing" / "video" / "out"
    ffprobe = shutil.which("ffprobe")
    if video_out.is_dir():
        for name, (dim, (lo, hi)) in VIDEO_SPECS.items():
            path = video_out / name
            if not path.exists():
                warnings.append(f"video missing: marketing/video/out/{name}")
                continue
            if not ffprobe:
                continue
            try:
                probe = subprocess.run(
                    [ffprobe, "-v", "error", "-show_entries",
                     "stream=codec_type,width,height:format=duration", "-of", "json", str(path)],
                    capture_output=True, text=True)
                meta = json.loads(probe.stdout)
                streams = meta.get("streams", [])
                vstreams = [s for s in streams if s.get("codec_type") == "video"]
                has_audio = any(s.get("codec_type") == "audio" for s in streams)
                dur = float(meta.get("format", {}).get("duration", 0))
                if vstreams and (vstreams[0].get("width"), vstreams[0].get("height")) != dim:
                    warnings.append(f"video size: {name} is {vstreams[0].get('width')}x{vstreams[0].get('height')}, expected {dim[0]}x{dim[1]}")
                if not (lo <= dur <= hi):
                    warnings.append(f"video duration: {name} is {dur:.1f}s, expected {lo}-{hi}s")
                if not has_audio:
                    warnings.append(f"video has no audio track: {name}")
            except Exception as exc:
                warnings.append(f"video probe failed for {name}: {exc}")
        if not ffprobe:
            warnings.append("ffprobe not found; skipped video dimension/duration checks")

    if errors:
        print("FAIL: ASO asset validation found issues")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"PASS: {len(metadata_locales)} app metadata locales")
    print("PASS: IAP metadata locales and character limits")
    print(f"PASS: {len(metadata_locales) * len(MARKETING_DEVICE_SPECS) * 6} marketing screenshots")
    print(f"PASS: {len(metadata_locales) * 30} fastlane screenshots")
    if (MARKETING_SCREENSHOTS / "ipad-13").is_dir():
        print("PASS: iPad raws + device frame present (genuine iPad UI)")
    if warnings:
        print(f"WARN: {len(warnings)} video/asset warning(s):")
        for w in warnings:
            print(f"- {w}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
