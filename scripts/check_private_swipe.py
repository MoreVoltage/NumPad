#!/usr/bin/env python3
"""Fail closed before distribution; private swipe is local development only.

Run as the LAST build phase on both app and keyboard targets:
  python3 "$SRCROOT/scripts/check_private_swipe.py" --build-env --product "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
Also run on a finished .xcarchive before any export/upload:
  python3 scripts/check_private_swipe.py --archive /path/to/NumPad.xcarchive
"""
import argparse
import os
from pathlib import Path
import plistlib
import sys

PRIVATE_FLAG = "NUMPAD_PRIVATE_SWIPE"
PRIVATE_IDS = {"com.morevoltage.NumPad.PrivateSwipe", "com.morevoltage.NumPad.PrivateSwipe.Keyboard"}
FORBIDDEN_BINARY_MARKERS = (b"QwertyGlideDecoder", b"QwertyGlideGestureRecognizer", b"QwertyGlideCapture",
                            b"QwertyGlidePath", b"QwertyGlideInsertion", b"QwertySwipeCalibration",
                            b"numpad.private-swipe.calibration", b"Glide Typing (Private)")


def check_environment(env):
    conditions = env.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "").split()
    other_flags = env.get("OTHER_SWIFT_FLAGS", "")
    private = PRIVATE_FLAG in conditions or PRIVATE_FLAG in other_flags
    identifier = env.get("PRODUCT_BUNDLE_IDENTIFIER", "")
    config = env.get("CONFIGURATION", "")
    archive = env.get("ACTION", "") == "install" or env.get("DEPLOYMENT_LOCATION") == "YES"
    if archive and (private or identifier in PRIVATE_IDS or config != "Release"):
        raise ValueError("Archives must use production Release. Private swipe builds cannot be archived or distributed.")
    if private:
        if config != "PrivateSwipe" or "DEBUG" not in conditions or identifier not in PRIVATE_IDS:
            raise ValueError("Private swipe requires PrivateSwipe + DEBUG + isolated private bundle identity.")
    elif identifier in PRIVATE_IDS or config == "PrivateSwipe":
        raise ValueError("Private build identity/configuration requires the explicit DEBUG + NUMPAD_PRIVATE_SWIPE conditions.")
    return private


def check_product(product):
    product = Path(product)
    if not product.is_dir():
        raise ValueError(f"Missing built product: {product}")
    bundles = [product] + sorted(product.rglob("*.appex")) + sorted(product.rglob("*.framework"))
    for bundle in bundles:
        info_path = bundle / "Info.plist"
        if not info_path.is_file():
            raise ValueError(f"Missing product Info.plist: {bundle}")
        with info_path.open("rb") as handle:
            info = plistlib.load(handle)
        identity = info.get("CFBundleIdentifier", "")
        if "privateswipe" in identity.lower() or "private-swipe" in identity.lower():
            raise ValueError(f"Private bundle cannot be distributed: {identity}")
        executable_name = info.get("CFBundleExecutable")
        if not executable_name:
            raise ValueError(f"Missing executable declaration: {bundle}")
        executable = bundle / executable_name
        if not executable.is_file():
            raise ValueError(f"Missing executable: {executable}")
        data = executable.read_bytes()
        for marker in FORBIDDEN_BINARY_MARKERS:
            if marker in data:
                raise ValueError(f"Private swipe implementation found in {executable}: {marker.decode()}")
    for path in product.rglob("*"):
        if path.is_file() and any(token in path.name.lower() for token in ("glide", "swipe")):
            raise ValueError(f"Swipe-specific resource in production product: {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-env", action="store_true")
    parser.add_argument("--product", type=Path)
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    if not (args.build_env or args.product or args.archive):
        parser.error("Specify --build-env, --product, or --archive")
    try:
        private = check_environment(os.environ) if args.build_env else False
        if args.product and not private:
            check_product(args.product)
        if args.archive:
            applications = args.archive / "Products" / "Applications"
            apps = list(applications.glob("*.app"))
            if not apps:
                raise ValueError("Archive contains no application product")
            for app in apps:
                check_product(app)
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        print(f"error: Private swipe distribution guard: {error}", file=sys.stderr)
        return 1
    print("Private swipe distribution guard passed (local private build)." if private else
          "Private swipe distribution guard passed (production swipe exclusion).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
