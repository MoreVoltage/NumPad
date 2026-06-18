# Submission Readiness — 2026-06-17

App: NumPad  
Version: 1.7.2  
ASC status checked in Chrome: Prepare for Submission

## Live ASC Status Checked

- Product Page Optimization: `Treatment A - Speed and Forms` is approved and running.
- Version 1.7.2: English (U.S.) has 6 of 10 iPhone screenshots and 6 of 10 iPad screenshots visible in ASC.
- Pricing and Availability: 175 countries or regions, United States base country, automatic price adjustment, tax category `App Store software`.
- In-App Purchases: intended products are approved:
  - `numpad.pro.lifetime`
  - `numpad.pack.finance`
- In-App Purchases: 7 legacy draft products remain in `Submit for Review`; do not include them with 1.7.2.
- Custom Product Pages: one page named `Test` exists and is ready to submit, but it is not production-useful as-is.
- App Review Information: `Sign-in required` is checked even though the notes say the app itself does not require login. Verify this before app submission.

## Local Fixes Applied

- Added missing `en-US` IAP metadata for both intended IAP products.
- Shortened all local IAP descriptions to satisfy Apple limits: display name <=30 characters, description <=45 characters.
- Generated `marketing/aso-sales-audit/iap-localization-upload-table.csv` with 100 rows for manual/App Store Connect API upload review.
- Replaced the weak slide 3 and 4 raw screenshot contexts with neutral Notes-style host screens while preserving the keyboard overlays.
- Saved the prior settings-screen captures as:
  - `marketing/raw/03-taxtip-settings.png`
  - `marketing/raw/04-clipboard-settings.png`
- Added `marketing/recompose_overlay_raws.py` so the neutral raw screenshots are reproducible.
- Regenerated all localized App Store screenshots: 50 locales × 6 slides × 6 generated device sizes = 1,800 PNGs.
- Rebuilt Fastlane screenshot exports: 50 locales × 30 Fastlane screenshots = 1,500 PNGs.
- Replaced the stale 11-locale shell screenshot helper with a wrapper around the 50-locale Python mapper.
- Added `marketing/validate_aso_assets.py` for one-command local validation.

## Verification Run

```bash
python3 marketing/validate_aso_assets.py
```

Result:

```text
PASS: 50 app metadata locales
PASS: IAP metadata locales and character limits
PASS: 1800 marketing screenshots
PASS: 1500 fastlane screenshots
```

## Remaining Manual or Confirmation-Gated Work

1. Upload the refreshed app metadata and screenshots to ASC.

   ```bash
   fastlane upload_metadata
   fastlane upload_screenshots
   ```

   Or upload both:

   ```bash
   fastlane upload_all
   ```

   This is an ASC-visible change and should be run only when you are ready to overwrite the current version metadata/screenshots.

2. Update IAP localizations in ASC for both intended products.

   The current Fastfile uploads app metadata/screenshots, not the files under `fastlane/iap_metadata`. Use `marketing/aso-sales-audit/iap-localization-upload-table.csv` as the source of truth for manual entry, App Store Connect API work, or a future Spaceship lane.

3. Submit only these two IAP updates with 1.7.2:

   - `numpad.pro.lifetime`
   - `numpad.pack.finance`

   Do not submit the 7 legacy draft IAPs.

4. Fix or remove the `Test` Custom Product Page.

   Best next action: repurpose it as `numpad-workflow` with localized screenshots/promotional text, or leave it out of review until it has real content. Do not submit an empty/test CPP.

5. Verify App Review Information.

   If the app itself does not require login, consider unchecking `Sign-in required` and keeping sandbox purchase instructions in Review Notes. Do not leave ambiguous login fields if they are only for StoreKit testing.

6. Attach the updated iOS build when ready.

   This readiness pass intentionally excludes the updated build. The app should not be submitted until the production build is attached and the two real IAP updates are included.

7. Decide whether to enable Apple School Manager volume purchase discount.

   Pricing is globally sane today. A business/education discount could help bulk buyers, but it reduces per-seat proceeds; treat it as a deliberate business decision rather than a default cleanup item.

## Sales Confidence Notes

- Highest-confidence sales improvements now available: localized app metadata, localized screenshots, iPad screenshots, cleaner middle screenshots, and corrected IAP localizations.
- Medium-confidence improvement: a real `numpad-workflow` Custom Product Page for Search Ads/referrals.
- Lower-confidence/experimental improvement: regional manual pricing changes. Current automatic pricing is reasonable and avoids tax/FX maintenance risk.
