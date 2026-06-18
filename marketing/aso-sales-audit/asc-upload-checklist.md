# App Store Connect Upload Checklist

Version: 1.7.2  
Updated: 2026-06-17

## Local Source of Truth

- App metadata: `fastlane/metadata/{locale}/`
- Fastlane screenshots: `fastlane/screenshots/{locale}/`
- Marketing screenshot masters: `marketing/app-store/`
- IAP metadata: `fastlane/iap_metadata/{product_id}/{locale}/`
- IAP upload CSV: `marketing/aso-sales-audit/iap-localization-upload-table.csv`
- Current readiness note: `marketing/aso-sales-audit/submission-readiness-2026-06-17.md`

## Verified Locally

- [x] 50 app metadata locales.
- [x] App metadata character limits pass: name <=30, subtitle <=30, keywords <=100, promo <=170.
- [x] 50 IAP metadata locales for `numpad.pro.lifetime`.
- [x] 50 IAP metadata locales for `numpad.pack.finance`.
- [x] IAP character limits pass: display name <=30, description <=45.
- [x] 1,800 generated marketing screenshots: 50 locales × 6 slides × 6 generated sizes.
- [x] 1,500 Fastlane screenshots: 50 locales × 30 files.
- [x] Slides 3 and 4 no longer use the NumPad settings screen as the host context.

Run:

```bash
python3 marketing/validate_aso_assets.py
```

Expected:

```text
PASS: 50 app metadata locales
PASS: IAP metadata locales and character limits
PASS: 1800 marketing screenshots
PASS: 1500 fastlane screenshots
```

## Prepare Fastlane Screenshots

```bash
python3 marketing/generate_app_store_screenshots.py --all-locales
bash marketing/setup_fastlane_screenshots.sh --clean
python3 marketing/validate_aso_assets.py
```

## Upload App Metadata and Screenshots

Authentication options already supported by `fastlane/Fastfile`:

```bash
export ASC_API_KEY_PATH=/path/to/api_key_info.json
```

or:

```bash
export ASC_KEY_ID=your_key_id
export ASC_ISSUER_ID=your_issuer_id
export ASC_KEY_CONTENT="-----BEGIN EC PRIVATE KEY-----\n...\n-----END EC PRIVATE KEY-----"
```

Upload metadata only:

```bash
fastlane upload_metadata
```

Upload screenshots only:

```bash
fastlane upload_screenshots
```

Upload both:

```bash
fastlane upload_all
```

## Important IAP Caveat

The current Fastlane lanes upload app metadata and screenshots. They do **not** upload the local files under `fastlane/iap_metadata`.

Before submission, update the two intended IAPs in ASC using `marketing/aso-sales-audit/iap-localization-upload-table.csv` as the source of truth:

- `numpad.pro.lifetime`
- `numpad.pack.finance`

Then submit only those two IAP updates with version 1.7.2.

## ASC Manual Checks Before Add for Review

- [ ] Version 1.7.2 has the refreshed iPhone screenshots in every intended locale.
- [ ] Version 1.7.2 has the refreshed iPad screenshots in every intended locale.
- [ ] App Information name/subtitle are localized as intended.
- [ ] IAP localizations in ASC match the local upload CSV.
- [ ] Only `numpad.pro.lifetime` and `numpad.pack.finance` are selected/submitted.
- [ ] The 7 legacy draft IAPs are not submitted.
- [ ] The `Test` Custom Product Page is either repurposed with real content or left out of review.
- [ ] App Review sign-in fields are correct and not misleading.
- [ ] Updated production build is attached.

## Safety Constraints

The following require explicit confirmation before execution:

- Submit the app.
- Submit IAPs.
- Submit CPPs.
- Save live pricing.
- Delete ASC assets.
- Overwrite live screenshots/metadata from this machine.
