#!/usr/bin/env python3
"""
Assemble Custom Product Page (CPP) screenshot sets by copying and reordering
the existing six marketing slides into per-CPP, per-device, per-locale folders
with fastlane deliver-style ordered names.

This stages assets only. It NEVER touches fastlane/screenshots/, the screenshot
generators, or App Store Connect. Re-running is idempotent: each destination
folder is rebuilt from scratch each run, so output is deterministic.

Source:      marketing/app-store/{device_prefix}{locale_suffix}/NN-<slug>-*.png
Destination: marketing/cpp/{cpp_name}/{fastlane_device}/{locale}/NN_<slug>.png
             (NN = 1-based position in that CPP's order)

Usage:
    python3 marketing/assemble_cpp_screenshots.py                 # default locales
    python3 marketing/assemble_cpp_screenshots.py --locale en-US  # one locale
    python3 marketing/assemble_cpp_screenshots.py --all           # all priority locales
    python3 marketing/assemble_cpp_screenshots.py --dry-run       # report only, no copy

Promotional texts for each CPP are defined here and verified <= 170 chars
(App Store promotional-text limit) at startup; the script aborts if any exceed it.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "marketing" / "app-store"
DST_ROOT = ROOT / "marketing" / "cpp"

PROMO_LIMIT = 170

# The six canonical slides, keyed by slide number -> marketing slug.
SLIDES: dict[int, str] = {
    1: "01-numbers-without-slowdowns",
    2: "02-faster-forms",
    3: "03-tax-and-tip",
    4: "04-paste-recent-numbers",
    5: "05-pro-packs-for-work",
    6: "06-your-numpad-your-style",
}

# Marketing dir prefix -> fastlane / deliver device keyword.
# Mirrors marketing/setup_fastlane_screenshots.py exactly.
# iphone-6.3 is intentionally omitted (no standard deliver device type).
DEVICE_MAP: dict[str, str] = {
    "iphone-6.9": "APP_IPHONE_67",
    "iphone-6.5": "APP_IPHONE_65",
    "iphone-6.1": "APP_IPHONE_61",
    "ipad-13": "APP_IPAD_PRO_6GEN_129",
    "ipad-12.9": "APP_IPAD_PRO_129",
}

# Marketing locale -> source dir suffix. "" suffix == en-US (no suffix on disk).
def locale_suffix(locale: str) -> str:
    return "" if locale == "en-US" else f"-{locale}"


# Per-CPP screenshot order (slide numbers, in display order) + metadata.
# See marketing/aso-sales-audit/custom-product-pages-v3.md for rationale.
CPPS: dict[str, dict] = {
    "numpad-workflow": {
        "order": [1, 2, 3, 4, 5, 6],
        "promo": "Type numbers faster in any app. No subscription.",
        "locales": ["en-US", "en-GB", "en-AU", "en-CA",
                    "de-DE", "fr-FR", "zh-Hans", "zh-Hant",
                    "ja", "pt-BR", "es-MX"],
    },
    "numpad-finance": {
        "order": [3, 5, 2, 4, 1, 6],
        "promo": ("Tax & tip calculator, currency symbols, and clipboard "
                  "history — straight from your keyboard."),
        "locales": ["en-US", "en-GB", "en-AU", "en-CA",
                    "de-DE", "fr-FR", "ja", "pt-BR", "es-MX"],
    },
    "numpad-spreadsheet": {
        "order": [1, 2, 4, 5, 3, 6],
        "promo": ("A fast number pad for spreadsheets and forms. Reuse "
                  "recent numbers. No subscription needed."),
        "locales": ["en-US", "en-GB", "en-AU", "en-CA",
                    "de-DE", "fr-FR", "zh-Hans", "zh-Hant",
                    "ja", "pt-BR"],
    },
}


def verify_promos() -> None:
    """Abort if any promotional text exceeds the App Store limit."""
    print(f"Promotional text check (limit {PROMO_LIMIT} chars):")
    ok = True
    for name, cfg in CPPS.items():
        n = len(cfg["promo"])
        flag = "OK " if n <= PROMO_LIMIT else "FAIL"
        if n > PROMO_LIMIT:
            ok = False
        print(f"  [{flag}] {name}: {n} chars")
    if not ok:
        sys.exit("ERROR: one or more promotional texts exceed the limit. Fix CPPS before running.")
    print()


def find_source(src_dir: Path, slug: str) -> Path | None:
    """Find the single PNG in src_dir whose filename starts with the slug."""
    if not src_dir.is_dir():
        return None
    matches = sorted(src_dir.glob(f"{slug}-*.png"))
    if not matches:
        # Fall back to any png containing the slug (defensive).
        matches = sorted(src_dir.glob(f"{slug}*.png"))
    return matches[0] if matches else None


def assemble(cpp_names: list[str], locales: list[str] | None, dry_run: bool) -> None:
    grand_total = 0
    per_locale_totals: dict[str, int] = {}

    for cpp_name in cpp_names:
        cfg = CPPS[cpp_name]
        order = cfg["order"]
        target_locales = locales if locales is not None else cfg["locales"]
        print(f"== {cpp_name} (order {order}) ==")

        for locale in target_locales:
            if locale not in cfg["locales"] and locales is None:
                continue
            suffix = locale_suffix(locale)
            locale_count = 0

            for device_prefix, device_kw in DEVICE_MAP.items():
                src_dir = SRC / f"{device_prefix}{suffix}"
                if not src_dir.is_dir():
                    print(f"  WARN missing source dir: {src_dir.relative_to(ROOT)}")
                    continue

                dst_dir = DST_ROOT / cpp_name / device_kw / locale
                # Idempotent: clear and rebuild this exact leaf folder.
                if not dry_run:
                    if dst_dir.exists():
                        shutil.rmtree(dst_dir)
                    dst_dir.mkdir(parents=True, exist_ok=True)

                for position, slide_no in enumerate(order, start=1):
                    slug = SLIDES[slide_no]
                    src = find_source(src_dir, slug)
                    if src is None:
                        print(f"  WARN no source for slide {slide_no} ({slug}) in {src_dir.name}")
                        continue
                    dst_name = f"{position:02d}_{slug}.png"
                    if not dry_run:
                        shutil.copy2(src, dst_dir / dst_name)
                    locale_count += 1

            grand_total += locale_count
            per_locale_totals[locale] = per_locale_totals.get(locale, 0) + locale_count
            verb = "would copy" if dry_run else "copied"
            print(f"  {locale}: {verb} {locale_count} screenshots")
        print()

    print("Per-locale totals:")
    for locale in sorted(per_locale_totals):
        print(f"  {locale}: {per_locale_totals[locale]}")
    verb = "Would copy" if dry_run else "Copied"
    print(f"\n{verb} {grand_total} screenshots total into {DST_ROOT.relative_to(ROOT)}/")
    if dry_run:
        print("(dry-run: no files written)")


def main() -> None:
    ap = argparse.ArgumentParser(description="Assemble CPP screenshot sets (staging only).")
    ap.add_argument("--locale", help="Stage a single locale (e.g. en-US). "
                                      "Applied to every CPP that has it.")
    ap.add_argument("--all", action="store_true",
                    help="Stage every locale listed per CPP (default behavior).")
    ap.add_argument("--cpp", help="Limit to one CPP by name.")
    ap.add_argument("--dry-run", action="store_true", help="Report counts without copying.")
    args = ap.parse_args()

    verify_promos()

    if args.cpp:
        if args.cpp not in CPPS:
            sys.exit(f"Unknown CPP '{args.cpp}'. Known: {', '.join(CPPS)}")
        cpp_names = [args.cpp]
    else:
        cpp_names = list(CPPS)

    if args.locale:
        locales = [args.locale]
    else:
        # --all and default both mean "each CPP's own locale list".
        locales = None

    assemble(cpp_names, locales, args.dry_run)


if __name__ == "__main__":
    main()
