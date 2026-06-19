# NumPad 1.8.0 — App Store Connect release runbook

Goal: get version **1.8.0 (build 8)** and **all 1.8.0 updates** staged on App Store Connect,
then stop. **Do not click "Submit for Review"** — that's your call.

What's already done in the repo (this session):
- Version bumped to **1.8.0**, build **8**, on **both** targets (app was 1.7.2, keyboard was 1.7.1) — `NumPad.xcodeproj/project.pbxproj`.
- Fastlane `app_version` → 1.8.0 and a new `release_1_8_0` lane added (`fastlane/Fastfile`).
- 1.8.0 **release notes** written for all 50 locales (14 localized + English) — `fastlane/metadata/*/release_notes.txt`.
- New **iPad screenshots** (50 locales) staged in `fastlane/screenshots/` (validator green).
- New **App Store preview** video: `marketing/video/out/app-store-preview-iphone.mp4` (+ `poster-iphone.png`).
- **CPP** package, **pricing/hygiene** memo, and **paywall/localization** changes — see linked runbooks/memos.

Prerequisites (your machine):
- Xcode (the binary cannot be built in the cloud session).
- ASC API key in env: `ASC_API_KEY_PATH=…` **or** `ASC_KEY_ID` + `ASC_ISSUER_ID` + `ASC_KEY_CONTENT`.
- `pod install` done; open `NumPad.xcworkspace` (CocoaPods workspace).

---

## 1. Build the binary → TestFlight (creates build 8 on ASC)
```bash
cd <repo>
pod install
fastlane beta            # or: fastlane release_1_8_0  (build + TestFlight + metadata + screenshots)
```
`release_1_8_0` does steps 1–3 in one shot. To do them separately, use `fastlane beta` here and the deliver lanes below.

## 2. Refresh screenshots on disk (if regenerated)
```bash
python3 marketing/setup_fastlane_screenshots.py --clean
python3 marketing/validate_aso_assets.py        # expect all PASS
```

## 3. Stage 1.8.0 metadata + screenshots (no submit)
```bash
fastlane upload_all      # deliver: creates/updates the 1.8.0 version, uploads 50-locale
                         # metadata (incl. release notes + keywords) + iPhone & iPad screenshots
```
`deliver` is configured with `submit_for_review: false`. It will create the 1.8.0 App Store version if it doesn't exist.

## 4. Attach the build
In ASC → App Store → **1.8.0** → "Build" → select **build 8** (from step 1, once processed).

## 5. Stage the App Store preview video (deliver can't do this)
ASC → App Store → 1.8.0 → the iPhone 6.5"+ display → **Media Manager** → drag in
`marketing/video/out/app-store-preview-iphone.mp4`, set the poster frame
(`marketing/video/out/poster-iphone.png` shows the intended frame).
- It's a rendered preview that faithfully depicts the real UI; if Review prefers captured footage, swap in a Simulator recording using the same timing (`marketing/video/README.md`).
- An **iPad** preview still needs real iPad footage — optional for this release.

## 6. Custom Product Pages
Follow `marketing/asc/cpp_runbook.md`: fix the shuffled `numpad-workflow` order (1→6) and create
`numpad-finance` + `numpad-spreadsheet`. Screenshots staged under `marketing/cpp/…`.

## 7. Catalog hygiene (IAPs)
Per `marketing/aso-sales-audit/pricing-hygiene-recommendations.md`:
```bash
python3 marketing/asc/iap_admin.py            # dry-run: list IAPs + draft audit
python3 marketing/asc/iap_admin.py --apply --family-sharing   # turn ON Family Sharing for both IAPs
```
- Confirm the **Finance Pack** live price in ASC (the code's "$1.99" is only a display fallback).
- Review the 7 legacy draft IAPs; delete only those with no sales history (script requires `--confirm-delete`).

## 8. Final review — then stop
Walk the 1.8.0 version: metadata, release notes, screenshots (iPhone **and** iPad in 1→6 order),
build 8 attached, preview staged, CPPs ready, Family Sharing on. **Leave "Submit for Review" to a human.**

---

### Notes
- Nothing in this repo submits or changes price automatically.
- Keyword refinements (optional) live in `marketing/aso-sales-audit/keyword-update-plan.md`; apply to `fastlane/metadata/<locale>/keywords.txt` before step 3 if you want them this release.
- In-app paywall/localization changes ship **in the binary** (step 1) — make sure the 1.8.0 build you upload includes them.
