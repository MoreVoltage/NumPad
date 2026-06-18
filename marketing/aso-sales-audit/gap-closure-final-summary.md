# Gap Closure Final Summary

Date: 2026-06-16 (updated)  
Current update: 2026-06-17
App: NumPad 1.7.2 (Prepare for Submission)

## Completed Tasks

### 1. Audit & Status Document
- Created `gap-closure-status.md` with full ASC state audit
- Captured pricing, metadata, screenshots, IAPs, CPPs across all 175 territories

### 2. iPad Screenshot Generation (code + execution)
- Added `render_slide_ipad()` to `generate_app_store_screenshots.py`
- Targets: 13" (2064x2752) master → resize to 12.9" (2048x2732)
- Handles iPad 0.75 aspect ratio with proportional scaling
- **Executed** — iPad screenshots generated for all 50 locales

### 3. App Name/Subtitle Localization
- Created 10 new high-value locale directories: de-DE, fr-FR, ja, hi, pt-BR, es-MX, th, en-GB, en-AU, en-CA
- Each has 6 files: name, subtitle, description, keywords, promotional_text, release_notes
- All within ASC character limits (name ≤30, subtitle ≤30, keywords ≤100)
- Total app metadata locales: 49

### 4. IAP Localization & Submission Readiness
- Fixed mixed Hindi/English in both IAPs (fully native Hindi now)
- Fixed mixed native/English in 11 Indic locales for both IAPs
- Created IAP metadata for 10 new locales (both IAPs)
- Total IAP locales: 49 each
- Created `iap-submission-checklist.md`

### 5. Pricing Analysis v2
- Captured territory pricing from ASC (app: $2.99 USD, Pro: $4.99 USD)
- Wrote `pricing-packaging-analysis-v2.md` with revenue analysis and recommendations
- Recommendation: hold pricing, prioritize metadata/screenshot improvements first

### 6. Custom Product Pages v2
- Wrote `custom-product-pages-v2.md` with 3 actionable CPPs:
  - `numpad-workflow` — general productivity (launch first)
  - `numpad-finance` — finance/tax users (improves IAP attach)
  - `numpad-ipad` — iPad users (28.6% of revenue with no iPad assets today)
- Each has: audience, traffic sources, metadata, screenshot order, localization priority, success metrics
- Implementation checklist with dependencies

### 7. Keyword Limit Fixes
- Fixed es-ES keywords.txt (was 127 chars → now 96)
- Fixed pt-PT keywords.txt (was 115 chars → now 98)

### 8. Localized Screenshot Generation (50 locales × 6 slides × 6 sizes)
- Added `LOCALE_TEXT` dictionary with translations for all 50 metadata locales
- Added `--locale XX` and `--all-locales` CLI flags to generator
- Added `generate_locale()` function and `get_slide_text()` locale fallback helper
- **Generated 1,800 screenshot PNGs** across `marketing/app-store/` directories
- Output directories: `iphone-6.9-{locale}`, `iphone-6.5-{locale}`, etc.

### 9. Indic Locale Description Retranslation
- Rewrote 33 files (description.txt, promotional_text.txt, release_notes.txt) for 11 locales:
  bn-BD, gu-IN, id, kn-IN, ml-IN, mr-IN, or-IN, pa-IN, ta-IN, te-IN, ur-PK
- All now fully native script — no English words except brand names (NumPad, iPhone, PIN, Numbers, Sheets, Excel, Pro)

## 2026-06-17 Additional Local Fixes

- Added `marketing/recompose_overlay_raws.py`.
- Replaced slides 3 and 4 raw contexts with neutral Notes-style host screens.
- Preserved previous settings-screen captures as `marketing/raw/03-taxtip-settings.png` and `marketing/raw/04-clipboard-settings.png`.
- Added missing `en-US` IAP metadata for both intended products.
- Shortened all local IAP descriptions to pass Apple’s 45-character description limit.
- Added `marketing/validate_aso_assets.py`.
- Generated `marketing/aso-sales-audit/iap-localization-upload-table.csv`.
- Rebuilt `fastlane/screenshots/` with 1,500 PNGs.
- Verified local assets with:

```bash
python3 marketing/validate_aso_assets.py
```

## Remaining Tasks (Require Manual Action or Explicit ASC Confirmation)

### A. Upload App Metadata and Screenshots to ASC
**Status:** Pending user confirmation (per safety constraints)
**Scope:** Upload app metadata and screenshots for 50 locales.
**Methods:**
- `fastlane upload_metadata`
- `fastlane upload_screenshots`
- `fastlane upload_all`
- Manual ASC upload — for selective updates
**Requires:** User confirmation before any ASC-visible changes

### B. Update IAP Localizations in ASC
**Status:** Pending manual/API upload
**Scope:** Update `numpad.pro.lifetime` and `numpad.pack.finance` localizable information from `marketing/aso-sales-audit/iap-localization-upload-table.csv`.
**Important:** Current Fastlane lanes do not upload `fastlane/iap_metadata`.

### C. Create or Fix CPPs in ASC
**Status:** Pending user confirmation
**Scope:** Repurpose or leave out the current `Test` CPP; create 3 Custom Product Pages per `custom-product-pages-v2.md`
**Launch order:** numpad-workflow → numpad-finance → numpad-ipad
**Requires:** User confirmation before creation

### D. Submit 1.7.2
**Status:** Pending — do after A, B, C
**Requires:** User confirmation

## Deliverables Created

| File | Purpose |
|---|---|
| `aso-sales-audit/gap-closure-status.md` | Full ASC state audit |
| `aso-sales-audit/iap-submission-checklist.md` | Pre-submission checklist for IAP metadata |
| `aso-sales-audit/pricing-packaging-analysis-v2.md` | Territory pricing analysis |
| `aso-sales-audit/custom-product-pages-v2.md` | Actionable CPP spec (3 pages) |
| `aso-sales-audit/gap-closure-final-summary.md` | This file |
| `marketing/raw/README-replacements.md` | Specs for replacement raw screenshots |
| `marketing/generate_app_store_screenshots.py` | Generator with locale + iPad support |
| `marketing/app-store/` | 1,800 localized screenshots (50 locales × 6 slides × 6 sizes) |
| `marketing/assets/mockup.png` | Phone mockup for screenshot compositing |
| `fastlane/metadata/{50 locales}/` | App metadata (name, subtitle, description, keywords, promo, release notes) |
| `fastlane/iap_metadata/numpad.pro.lifetime/{50 locales}/` | Pro IAP metadata |
| `fastlane/iap_metadata/numpad.pack.finance/{50 locales}/` | Finance Pack IAP metadata |
| `marketing/validate_aso_assets.py` | Local verification for metadata and screenshots |
| `marketing/aso-sales-audit/submission-readiness-2026-06-17.md` | Current live ASC/readiness status |
