# Gap Closure Status

Date: 2026-06-16
ASC version: 1.7.2 (Prepare for Submission)
Live version: 1.7.1 (Ready for Distribution)

> Current note, 2026-06-17: this file is a historical gap audit. The latest live ASC check and local verification are in `submission-readiness-2026-06-17.md`. Since this audit was written, local metadata/screenshots were expanded to 50 locales, iPad screenshots were generated, slides 3/4 were recomposed into neutral Notes-style contexts, Product Page Optimization Treatment A began running, and local IAP metadata now passes Apple character limits.

## 1. App-Level Pricing

- App price: $2.99 USD (proceeds $2.54)
- Available in 175 countries/regions
- Price adjustment: May Adjust Automatically
- Base country: United States (USD)
- Tax category: App Store software
- Sample territory prices: Australia $4.99 AUD, Austria €2.99, Albania $3.99

## 2. App Information (App-Level Metadata)

All non-English App Information name/subtitle fields in ASC still show English fallback text. The fastlane metadata directories contain translations for 39 locales, but these have never been uploaded to ASC's App Information section.

Current live App Information across all locales:
- Name: "NumPad: Your Number Keyboard" (English fallback everywhere)
- Subtitle: empty in all non-English locales

### Fastlane metadata locales (39)

ar-SA, bn-BD, ca, cs, da, el, es-ES, fi, fr-CA, gu-IN, he, hr, hu, id, it, kn-IN, ko, ml-IN, mr-IN, ms, nl-NL, no, or-IN, pa-IN, pl, pt-PT, ro, ru, sk, sl-SI, sv, ta-IN, te-IN, tr, uk, ur-PK, vi, zh-Hans, zh-Hant

### Missing high-value locales (not in fastlane metadata)

de-DE, fr-FR, ja, hi, pt-BR, es-MX, th, en-GB, en-AU, en-CA

These 10 locales are missing from both app metadata and IAP metadata in the fastlane directory structure. Several of these (de-DE, fr-FR, ja, pt-BR, es-MX, th) already have approved IAP localizations in ASC, meaning ASC has translations that fastlane doesn't track.

## 3. Version-Level Localizations (1.7.2)

ASC shows 45 version-level localizations. All non-English locales inherit English screenshots and have English-only description/keywords/what's new text.

### Screenshots

- iPhone 6.5" (1284x2778): 6 English screenshots uploaded. All other locales inherit from English.
- iPhone 6.9" (1320x2868): 6 English screenshots uploaded.
- iPhone 6.3" (1206x2622): 6 English screenshots uploaded.
- iPhone 6.1" (1125x2436): 6 English screenshots uploaded.
- iPad 13" (2064x2752): 0 screenshots (not generated yet).
- iPad 12.9" (2048x2732): 2 legacy screenshots exist but do not match the current design system. Not the new generated style.

### Screenshot content issues

- Slide 1 (hero): Good. Shows invoice/spreadsheet context — neutral Apple-style host app.
- Slide 2 (checkout): Good. Shows checkout/payment form — neutral context.
- Slide 3 (tax/tip): Problem. Shows NumPad's OWN settings screen with TAX/TIP overlay. Needs replacement with a neutral host app context (e.g., Notes app with totals).
- Slide 4 (clipboard): Problem. Shows NumPad's OWN settings screen with clipboard history overlay. Needs replacement with a neutral host app context (e.g., Notes/spreadsheet paste).
- Slide 5 (finance): Acceptable. Shows finance symbols keyboard.
- Slide 6 (themes): Acceptable. Shows theme gallery.

## 4. In-App Purchases

### Overview

| IAP | Product ID | Status | Family Sharing | Pricing |
|---|---|---|---|---|
| All Packs Lifetime | numpad.pro.lifetime | Approved (Updates Pending Review) | OFF | 175 countries |
| Finance Pack | numpad.pack.finance | Approved (Updates Pending Review) | OFF | 175 countries |

7 legacy draft IAPs exist (Math Pack, MathPack, Pink Keyboard, Programmer Pack, Purple Keyboard, Symbols Pack, Tax Pack) — all in "Submit for Review" status. These are unused.

### Pro Lifetime (`numpad.pro.lifetime`) Localizations

**Approved (11):**

| Locale | Display Name | Description |
|---|---|---|
| English (Australia) | All Packs Lifetime | Unlock all current and future packs and premium themes. |
| English (Canada) | All Packs Lifetime | Unlock all current and future packs and premium themes. |
| English (U.K.) | All Packs Lifetime | Unlock all current and future packs and premium themes. |
| English (U.S.) | All Packs Lifetime Access | Get all current and future packs and themes! |
| French | Accès à vie tous les packs | Tous les packes et thèmes actuels et futurs. |
| German | Alle Packs lebenslang | Alle aktuellen und zukünftigen Packs und Themes. |
| Hindi | सभी पैक लाइफटाइम | सभी current और future packs और premium themes. |
| Japanese | 全パック生涯アクセス | 現在と将来のすべてのパックとテーマ。 |
| Portuguese (Brazil) | Acesso vitalício aos pacotes | Todos os pacotes e temas atuais e futuros. |
| Spanish (Mexico) | Acceso de por vida a packs | Todos los packs y temas actuales y futuros. |
| Thai | ปลดล็อกทุกแพ็กถาวร | ปลดล็อกสัญลักษณ์การเงินและสกุลเงิน |

**Prepare for Submission (39):**

Arabic, Bangla, Catalan, Chinese (Simplified), Chinese (Traditional), Croatian, Czech, Danish, Dutch, Finnish, Greek, Gujarati, Hebrew, Hungarian, Indonesian, Italian, Kannada, Korean, Malay, Malayalam, Marathi, Norwegian, Odia, Polish, Portuguese (Portugal), Punjabi, Romanian, Russian, Slovak, Slovenian, Spanish (Spain), Swedish, Tamil, Telugu, Turkish, Ukrainian, Urdu, Vietnamese

**Quality issues:**
- Hindi: mixed Hindi/English in description ("सभी current और future packs और premium themes.")
- Multiple Indic locales have mixed native/English in names (e.g., "ಎಲ್ಲ ಪ್ಯಾಕ್ಸ್ lifetime", "எல்லா packs lifetime", "అన్ని packs lifetime")
- Some descriptions contain "future packs/themes." as English fragments

**IAP promotional image:** 1024x1024 image present, status "Prepare for Submission"

### Finance Pack (`numpad.pack.finance`) Localizations

**Approved (11):**

| Locale | Display Name | Description |
|---|---|---|
| English (Australia) | Finance Pack | Unlock currency and finance symbols. |
| English (Canada) | Finance Pack | Unlock currency and finance symbols. |
| English (U.K.) | Finance Pack | Unlock currency and finance symbols. |
| English (U.S.) | Finance Pack | Unlock specialized financial symbols |
| French | Pack Finance | Débloque les symboles financiers. |
| German | Finanzen-Paket | Währungs- und Finanzsymbole freischalten. |
| Hindi | Finance Pack | मुद्रा और finance symbols अनलॉक करें |
| Japanese | 金融パック | 通貨記号と金融向け記号を解除 |
| Portuguese (Brazil) | Pacote Finanças | Libera símbolos financeiros. |
| Spanish (Mexico) | Pack Finanzas | Desbloquea símbolos financieros. |
| Thai | แพ็กการเงิน | ปลดล็อกสัญลักษณ์การเงินและสกุลเงิน |

**Prepare for Submission (39):**

Same set as Pro Lifetime.

**Quality issues:**
- Hindi: display name still English "Finance Pack", description mixed ("मुद्रा और finance symbols अनलॉक करें")
- Bangla: display name still English "Finance Pack", description mixed ("currency ও finance symbols আনলক করুন।")

## 5. Custom Product Pages

One CPP exists in ASC: "Test" — completely empty shell with no content, no metadata, no screenshots. Not usable.

Plan calls for 3 CPPs: numpad-workflow, numpad-finance, numpad-power (see custom-product-pages-plan.md).

## 6. Product Page Optimization

No active tests. PPO is available in the ASC sidebar. Plan calls for Treatment A first (see product-page-optimization-plan.md).

## 7. Gap Summary

### Critical gaps (blocking higher conversion)

1. **No localized app name/subtitle in ASC.** All 39 translated fastlane locales still show English fallback in App Information. 10 additional high-value locales (de-DE, fr-FR, ja, etc.) have no fastlane metadata at all.
2. **No localized screenshots.** Every non-English locale inherits English screenshots. Headlines, sublines, and footer text are English-only.
3. **No iPad screenshots in new design.** iPad 13" has zero screenshots. iPad 12.9" has 2 legacy screenshots not matching current design system.
4. **Weak middle screenshots.** Slides 3 and 4 show NumPad's own UI as the host app context instead of neutral Apple-style contexts.

### Important gaps (reducing IAP revenue)

5. **IAP localization quality.** Hindi and Bangla have mixed native/English text in approved copy. Multiple Indic locales have similar issues in pending copy. 39 locales are pending review but translations exist.
6. **10 high-value locale gap.** de-DE, fr-FR, ja, hi, pt-BR, es-MX, th, en-GB, en-AU, en-CA missing from fastlane metadata entirely despite being key revenue markets.
7. **No Custom Product Pages.** Only an empty "Test" CPP exists. No audience-targeted pages for workflow, finance, or iPad users.

### Lower priority gaps

8. **7 legacy draft IAPs** sitting in "Submit for Review." These are obsolete and should be cleaned up eventually.
9. **Family Sharing** is OFF for both IAPs. Worth considering enabling for Pro Lifetime.
10. **No PPO tests running.** Should wait until screenshot and metadata improvements are in place.

## 8. Task Dependency Order

1. Write gap-closure-status.md (this file) — DONE
2. Generate iPad screenshots (13" and 12.9") — extends generate_app_store_screenshots.py
3. Replace weak middle screenshot contexts (slides 3, 4) — new raw images needed
4. Localize screenshots for all supported ASC locales — depends on #2, #3
5. Localize app name/subtitle for all locales — create missing fastlane dirs, push to ASC
6. Finish IAP localization & submission readiness — fix mixed-language issues, prepare submission checklist
7. Pricing analysis v2 — capture full territory pricing matrix
8. Custom Product Pages — define 3 actionable CPPs
9. Verification & final summary — end-to-end check
