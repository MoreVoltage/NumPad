# App Store Connect — Custom Product Pages Runbook

App: NumPad (`com.morevoltage.NumPad`)
Version context: 1.7.2
Date: 2026-06-18
Spec: `marketing/aso-sales-audit/custom-product-pages-v3.md`

## STOP rule

This runbook prepares and stages everything up to — but **never including** — submission. Do **not** click **Submit for Review** / **Add for Review** on any CPP, the app version, IAPs, or anything else. Creating a CPP, uploading screenshots, and saving promo text are all reversible drafts; submitting is not. When you reach a "Submit" button, stop and hand back to the owner.

Other guardrails (from `asc-upload-checklist.md`): do not delete ASC assets, do not save live pricing, do not overwrite live screenshots from automation without explicit confirmation.

## Prerequisites

1. Stage the reordered screenshots locally first:
   ```bash
   python3 marketing/assemble_cpp_screenshots.py            # all priority locales
   # or, to start with English only:
   python3 marketing/assemble_cpp_screenshots.py --locale en-US
   ```
   Output lands in `marketing/cpp/{cpp_name}/{fastlane_device}/{locale}/` as `NN_<slug>.png`. The `NN` prefix is the exact upload order; upload files in ascending `NN`.

2. Confirm you can sign in to App Store Connect with an account that has the **App Manager** or **Admin** role for NumPad.

3. (Only if you choose to script later) App Store Connect API auth — the repo's Fastfile reads either:
   - `ASC_API_KEY_PATH=/path/to/api_key_info.json`, **or**
   - `ASC_KEY_ID` + `ASC_ISSUER_ID` + `ASC_KEY_CONTENT`

   You do **not** need these for the manual steps below.

## Target CPPs and orders

Screenshots are uploaded per device. Order is by slide number from the canonical set:
`1=01-numbers-without-slowdowns, 2=02-faster-forms, 3=03-tax-and-tip, 4=04-paste-recent-numbers, 5=05-pro-packs-for-work, 6=06-your-numpad-your-style`.

| CPP | Slide order | Promo text (en-US) | Promo chars |
|---|---|---|---|
| `numpad-workflow` (fix existing) | 1, 2, 3, 4, 5, 6 | `Type numbers faster in any app. No subscription.` | 48 |
| `numpad-finance` (new) | 3, 5, 2, 4, 1, 6 | `Tax & tip calculator, currency symbols, and clipboard history — straight from your keyboard.` | 92 |
| `numpad-spreadsheet` (new) | 1, 2, 4, 5, 3, 6 | `A fast number pad for spreadsheets and forms. Reuse recent numbers. No subscription needed.` | 91 |

Device upload slots (each CPP needs all five filled per locale):

| Folder name (under each CPP) | ASC device tab |
|---|---|
| `APP_IPHONE_67` | iPhone 6.9" Display |
| `APP_IPHONE_65` | iPhone 6.5" Display |
| `APP_IPHONE_61` | iPhone 6.1" Display |
| `APP_IPAD_PRO_6GEN_129` | iPad Pro 13" (M4) / 6th-gen 12.9" Display |
| `APP_IPAD_PRO_129` | iPad Pro 12.9" (2nd–5th gen) Display |

Target locales (lead en-US, then per spec localization priority):
- **numpad-workflow & numpad-finance:** en-US, en-GB, en-AU, en-CA, de-DE, fr-FR, then (workflow also) zh-Hans, zh-Hant, then ja, pt-BR, es-MX.
- **numpad-spreadsheet:** en-US, en-GB, en-AU, en-CA, de-DE, fr-FR, zh-Hans, zh-Hant, ja, pt-BR.

(Exact per-CPP locale lists are encoded in `assemble_cpp_screenshots.py` and the spec doc.)

---

## Step 0 — Navigate to Custom Product Pages

1. Sign in to App Store Connect → **Apps** → **NumPad**.
2. Left sidebar: under the version area, open **Custom Product Pages** (sometimes shown under the "App Store" section).
3. You should see any existing CPP (e.g. the `numpad-workflow` page, or a leftover "Test" shell). Do not delete anything.

---

## Step 1 — Fix the shuffled order on `numpad-workflow`

> Goal: make every device set read 1 → 6.

1. Open the `numpad-workflow` CPP. (If the only existing CPP is the empty "Test" shell, you may repurpose it: rename to `numpad-workflow` and treat the steps below as a fresh upload. Do not delete it.)
2. For each locale (start with **en-US**):
   1. Select the locale from the localization dropdown (add the locale if it is not yet present).
   2. For each of the five device tabs, look at the current screenshot order.
   3. Re-order to match `1, 2, 3, 4, 5, 6`. Two ways:
      - **Drag-reorder** the existing images into ascending order, or
      - **Remove and re-add**: delete the existing screenshots for that device (this only affects the draft CPP, not the live app listing) and re-upload from `marketing/cpp/numpad-workflow/<device>/<locale>/` in ascending `NN_` filename order.
   4. Confirm the thumbnails read top-to-bottom: numbers-without-slowdowns → faster-forms → tax-and-tip → paste-recent-numbers → pro-packs-for-work → your-numpad-your-style.
3. Set/confirm **Promotional Text** = `Type numbers faster in any app. No subscription.`
4. Repeat for en-GB, en-AU, en-CA, de-DE, fr-FR, zh-Hans, zh-Hant, ja, pt-BR, es-MX.
5. Save. **Do not submit.**

---

## Step 2 — Create `numpad-finance`

1. In Custom Product Pages, click **(+)** / **Create Custom Product Page**.
2. Name / reference: `numpad-finance`. (This internal name is not shown to users; it appears in the CPP URL and analytics.)
3. Choose to start from the default product page (so non-overridden fields inherit the main listing).
4. For **en-US** first:
   1. Upload screenshots for each device tab from `marketing/cpp/numpad-finance/<device>/en-US/`, in ascending `NN_` order. The resulting order must be: tax-and-tip, pro-packs-for-work, faster-forms, paste-recent-numbers, numbers-without-slowdowns, your-numpad-your-style (slides 3, 5, 2, 4, 1, 6).
   2. Set **Promotional Text** = `Tax & tip calculator, currency symbols, and clipboard history — straight from your keyboard.`
5. Add localizations and repeat the upload + promo text for: en-GB, en-AU, en-CA, de-DE, fr-FR, ja, pt-BR, es-MX. (English locales reuse the English promo text; localized promo text can be added later — leaving a locale's promo blank inherits the default page's value.)
6. Save. **Do not submit.**

---

## Step 3 — Create `numpad-spreadsheet`

1. Custom Product Pages → **Create Custom Product Page**.
2. Name / reference: `numpad-spreadsheet`.
3. Start from the default product page.
4. For **en-US** first:
   1. Upload screenshots for each device tab from `marketing/cpp/numpad-spreadsheet/<device>/en-US/`, in ascending `NN_` order. Resulting order: numbers-without-slowdowns, faster-forms, paste-recent-numbers, pro-packs-for-work, tax-and-tip, your-numpad-your-style (slides 1, 2, 4, 5, 3, 6).
   2. Set **Promotional Text** = `A fast number pad for spreadsheets and forms. Reuse recent numbers. No subscription needed.`
5. Add localizations and repeat for: en-GB, en-AU, en-CA, de-DE, fr-FR, zh-Hans, zh-Hant, ja, pt-BR.
6. Save. **Do not submit.**

---

## Step 4 — Verify (still no submit)

For each of the three CPPs, in each target locale:
- [ ] All five device tabs have exactly six screenshots.
- [ ] Screenshot order matches the table in Step 1/2/3 (read the thumbnails left-to-right / top-to-bottom).
- [ ] Promotional text is set for en-US and is within 170 chars (it is — 48 / 92 / 91).
- [ ] No device tab is missing or has a leftover wrong-aspect-ratio image.
- [ ] `numpad-workflow` no longer looks shuffled in any locale.

Cross-check the staged source folders if a slot looks wrong:
```bash
ls marketing/cpp/numpad-finance/APP_IPHONE_67/en-US/
# 01_03-tax-and-tip.png  02_05-pro-packs-for-work.png  ...
```

---

## Step 5 — STOP

Leave all three CPPs in **draft / ready** state. Notify the app owner that the CPPs are staged and verified, and that the only remaining action is the explicit **Submit for Review** (gated, owner-only). CPPs are reviewed with the next app version; they cannot go live without a submitted, approved version.

## Optional: scripted listing/creation

If you prefer to script the *listing* and *creation* (not submission) of CPPs, see `marketing/asc/cpp_manage.py`. It is **dry-run by default**, requires an explicit `--apply` flag to make any change, **never submits**, and is **untested** — review it line by line before running. Screenshot upload for CPPs via the API is multi-step (reservation + chunked binary upload + commit) and is intentionally **not** implemented there; do screenshot upload through the ASC UI using the staged `marketing/cpp/...` folders.
