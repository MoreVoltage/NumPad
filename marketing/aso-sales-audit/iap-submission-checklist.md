# IAP Submission Readiness Checklist

Updated: 2026-06-17

## Intended Products

Submit only these two IAP updates with version 1.7.2:

| Product | Product ID | Live ASC Status Checked | Local Metadata |
|---|---|---|---|
| All Packs Lifetime | `numpad.pro.lifetime` | Approved | 50 locales |
| Finance Pack | `numpad.pack.finance` | Approved | 50 locales |

Do not submit the 7 legacy draft IAPs currently visible in ASC:

- `numpad.pack.math`
- `com.morevoltage.numpad.MathPack`
- `03`
- `numpad.pack.programmer`
- `02`
- `numpad.pack.symbols`
- `numpad.pack.tax`

## Local Fixes Applied

- Added missing `en-US` IAP metadata for both intended products.
- Corrected over-limit descriptions in Arabic, German, English variants, Spanish (Spain), Hebrew, Kannada, Portuguese (Portugal), Tamil, and Telugu where needed.
- Regenerated `marketing/aso-sales-audit/iap-localization-upload-table.csv`.
- Verified all local IAP display names are <=30 characters.
- Verified all local IAP descriptions are <=45 characters.

## Source of Truth

Use this CSV for manual ASC entry, App Store Connect API upload work, or a future Fastlane/Spaceship lane:

```text
marketing/aso-sales-audit/iap-localization-upload-table.csv
```

The current Fastlane lanes do not upload `fastlane/iap_metadata`.

## Required ASC Steps

- [ ] Open `numpad.pro.lifetime` in ASC.
- [ ] Update localizable information from `iap-localization-upload-table.csv`.
- [ ] Verify promotional image is still present and 1024×1024.
- [ ] Verify Review Information screenshot/notes are present.
- [ ] Click Submit for Review for this IAP update when ready.
- [ ] Open `numpad.pack.finance` in ASC.
- [ ] Update localizable information from `iap-localization-upload-table.csv`.
- [ ] Verify promotional image is still present and 1024×1024.
- [ ] Verify Review Information screenshot/notes are present.
- [ ] Click Submit for Review for this IAP update when ready.
- [ ] Include only these two intended IAPs in the 1.7.2 review submission.

## Optional Business Decision

Family Sharing is currently off. Consider enabling it for `numpad.pro.lifetime` if the goal is stronger household/business value perception, but treat it as a pricing/entitlement decision rather than a cleanup requirement.
