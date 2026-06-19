# Custom Product Pages — Actionable Spec v3

Date: 2026-06-18
Supersedes: `custom-product-pages-v2.md`
Status: STAGING ONLY. Nothing in this doc is submitted to App Store Connect. Use the runbook at `marketing/asc/cpp_runbook.md` and the assembly script at `marketing/assemble_cpp_screenshots.py` to prepare assets, then stop before any Submit/Add for Review.

## What changed since v2

- **Fixed the shuffled screenshot order on `numpad-workflow`.** v2 specified an intentional reorder (1-2-4-3-5-6, PPO Treatment A). The live `numpad-workflow` CPP, however, currently has its screenshots in a *shuffled* (out-of-sequence) state on both iPhone and iPad — they do not read in the intended order. v3 restores a clean, deliberate `1→6` sequence so each device set reads coherently top to bottom. See "CPP 1" below for the exact ordered filenames per device.
- **Replaced `numpad-ipad` with `numpad-spreadsheet`.** v2's third CPP was `numpad-ipad`, justified by the absence of iPad-specific screenshots. That gap is now closed: genuine iPad screenshots (13" and 12.9") exist for all 50 locales and are part of the **main app listing**, so a separate iPad-only CPP is redundant. v3 keeps `numpad-finance` (continuity with v2) and adds `numpad-spreadsheet` for the data-entry / spreadsheets audience identified in the brief.
- **Continuity note on `numpad-ipad`:** iPad coverage is now handled by the main listing's genuine iPad screenshots (`APP_IPAD_PRO_6GEN_129_*` and `APP_IPAD_PRO_129_*` in `fastlane/screenshots/{locale}/`). If iPad-device-targeted Search Ads are still desired later, point them at the main listing or at `numpad-workflow` (which carries iPad screenshots), rather than re-creating an iPad-only CPP.

## The six source slides (canonical order)

These are the only screenshots that exist. Every CPP selects and orders from this set. Marketing slugs and the concept each slide sells:

| # | Slug | Concept | Best for |
|---|---|---|---|
| 1 | `01-numbers-without-slowdowns` | Speed hero — fast numeric entry, no lag | Universal opener |
| 2 | `02-faster-forms` | Filling forms faster | Office / data-entry |
| 3 | `03-tax-and-tip` | Tax & tip overlay calculation | Finance / everyday math |
| 4 | `04-paste-recent-numbers` | Clipboard history of recent numbers | Power utility, copy/paste workflows |
| 5 | `05-pro-packs-for-work` | Pro packs (Finance, Symbols, Programmer) | Monetization / pro intent |
| 6 | `06-your-numpad-your-style` | Themes / customization | Visual closer |

Device source directories (host paths) and the deliver device keyword each maps to (mirrors `marketing/setup_fastlane_screenshots.py`):

| Marketing dir prefix | Fastlane / deliver device keyword | Source path (en-US) |
|---|---|---|
| `iphone-6.9` | `APP_IPHONE_67` | `marketing/app-store/iphone-6.9/` |
| `iphone-6.5` | `APP_IPHONE_65` | `marketing/app-store/iphone-6.5/` |
| `iphone-6.1` | `APP_IPHONE_61` | `marketing/app-store/iphone-6.1/` |
| `ipad-13` | `APP_IPAD_PRO_6GEN_129` | `marketing/app-store/ipad-13/` |
| `ipad-12.9` | `APP_IPAD_PRO_129` | `marketing/app-store/ipad-12.9/` |

(`iphone-6.3` is intentionally skipped — no standard deliver device type for that size, matching the existing setup script.)

Localized source dirs append a locale suffix, e.g. `marketing/app-store/iphone-6.9-de-DE/`. The en-US dirs carry no suffix.

---

## CPP 1: `numpad-workflow` (fix the shuffled order)

**Audience:** General productivity users arriving via App Store Search ("number keyboard", "numeric keypad", "forms keyboard") and broad-match Apple Search Ads.

**Core message:** "The number keyboard iOS should have included."

**The fix:** restore a clean, sequential read. The current live CPP has these slides out of order on both iPhone and iPad. Re-upload so every device set is exactly slides 1, 2, 3, 4, 5, 6 — the natural narrative (speed → forms → tax/tip → clipboard → pro packs → themes). This is the safe, legible default for a broad-audience page; a shuffled set reads as a mistake to a shopper.

> Note: v2 proposed 1-2-4-3-5-6 (a PPO experiment swapping clipboard ahead of tax/tip). Because the page is currently *shuffled* (an error state, not a deliberate experiment), v3's priority is to ship a correct, in-order set first. The 1-2-4-3-5-6 experiment can be run later as a deliberate PPO treatment once the baseline is clean.

### Correct ordered filenames per device (en-US)

**iPhone 6.9" (`APP_IPHONE_67`) — source `marketing/app-store/iphone-6.9/`:**
1. `01-numbers-without-slowdowns-1320x2868.png`
2. `02-faster-forms-1320x2868.png`
3. `03-tax-and-tip-1320x2868.png`
4. `04-paste-recent-numbers-1320x2868.png`
5. `05-pro-packs-for-work-1320x2868.png`
6. `06-your-numpad-your-style-1320x2868.png`

**iPhone 6.5" (`APP_IPHONE_65`) — source `marketing/app-store/iphone-6.5/`:** same six slugs, `*-1290x2796.png`.

**iPhone 6.1" (`APP_IPHONE_61`) — source `marketing/app-store/iphone-6.1/`:** same six slugs, `*-1206x2622.png`.

**iPad 13" (`APP_IPAD_PRO_6GEN_129`) — source `marketing/app-store/ipad-13/`:**
1. `01-numbers-without-slowdowns-2064x2752.png`
2. `02-faster-forms-2064x2752.png`
3. `03-tax-and-tip-2064x2752.png`
4. `04-paste-recent-numbers-2064x2752.png`
5. `05-pro-packs-for-work-2064x2752.png`
6. `06-your-numpad-your-style-2064x2752.png`

**iPad 12.9" (`APP_IPAD_PRO_129`) — source `marketing/app-store/ipad-12.9/`:** same six slugs, `*-2048x2732.png`.

(Localized variants substitute the locale-suffixed source dir; filenames within are identical.)

### Screenshot-order table

| Position | Slide # | Slug |
|---|---|---|
| 1 | 1 | `01-numbers-without-slowdowns` |
| 2 | 2 | `02-faster-forms` |
| 3 | 3 | `03-tax-and-tip` |
| 4 | 4 | `04-paste-recent-numbers` |
| 5 | 5 | `05-pro-packs-for-work` |
| 6 | 6 | `06-your-numpad-your-style` |

### Promotional text (en-US, 48 chars)

```
Type numbers faster in any app. No subscription.
```

### Keyword angle

Broad numeric-entry intent. Cite `keyword-research.csv` rows: `number pad` (row 3, priority 1), `number keyboard` (row 4, priority 1), `numeric keypad` (row 5, priority 1), `forms keyboard` (row 8, workflow, priority 1). This page is the catch-all for the highest-volume generic terms.

### Localization priority

1. en-US (lead)
2. en-GB, en-AU, en-CA (same English copy)
3. de-DE, fr-FR (Europe = 31.6% of revenue, `market-prioritization.csv` row 3)
4. zh-Hans, zh-Hant (Asia Pacific = 9.7%, row 5)
5. ja, pt-BR, es-MX

---

## CPP 2: `numpad-finance` (finance / accounting / bookkeeping)

**Audience:** Accountants, bookkeepers, small-business owners, and anyone doing expense tracking, invoicing, or everyday tax/tip math. Arrives via finance-intent Search Ads and cross-promo from the Finance Pack IAP.

**Core message:** "Tax, tip, and finance symbols — built into your keyboard."

### Screenshot selection + order

Lead with the finance hero features, then prove general competence:

1. `03-tax-and-tip` — the single most finance-relevant slide; tax/tip overlay is the differentiator this audience searches for. Hero.
2. `05-pro-packs-for-work` — surfaces the Finance Pack (currency symbols) and pro value directly; primes IAP attach.
3. `02-faster-forms` — invoices, expense forms, ledgers: the daily reality of this audience.
4. `04-paste-recent-numbers` — clipboard history of recent numbers maps to reconciling figures across apps.
5. `01-numbers-without-slowdowns` — speed reassurance, kept high enough to anchor the core promise.
6. `06-your-numpad-your-style` — visual closer.

**Why this order:** front-loads tax/tip + pro packs (the finance value proposition) before the general-purpose slides, so a finance-intent shopper sees their use case in the first two frames. Differs from v2's finance order (3-5-1-2-4-6) only in keeping forms (2) ahead of clipboard (4), because forms are more recognizably "accounting" than clipboard.

### Screenshot-order table

| Position | Slide # | Slug |
|---|---|---|
| 1 | 3 | `03-tax-and-tip` |
| 2 | 5 | `05-pro-packs-for-work` |
| 3 | 2 | `02-faster-forms` |
| 4 | 4 | `04-paste-recent-numbers` |
| 5 | 1 | `01-numbers-without-slowdowns` |
| 6 | 6 | `06-your-numpad-your-style` |

### Promotional text (en-US, 92 chars)

```
Tax & tip calculator, currency symbols, and clipboard history — straight from your keyboard.
```

### Keyword angle

Finance/calculation intent. Cite `keyword-research.csv` rows: `calculator keyboard` (row 6, feature, priority 1 — "Tax and tip plus finance use cases"), `tax tip keyboard` (row 10, priority 2), `finance keyboard` (row 11, priority 2 — "Finance pack and currency symbols exist as a monetized feature"). For localized finance terms: `财务` (zh-Hans, row 19), `formularios` + `finanzas`/`impuesto`/`propina` cluster (es from `keyword-update-plan.md` Spanish section).

### Localization priority

1. en-US (lead)
2. en-GB, en-AU, en-CA (same English copy)
3. de-DE, fr-FR (Europe = 31.6% of revenue; finance use cases overindex in Europe per v2 sizing)
4. ja (Asia Pacific, strong finance/utility fit)
5. pt-BR, es-MX (Spanish finance vocabulary already supported in metadata)

### Success metrics (carried from v2)

| Metric | Target |
|---|---|
| Conversion rate | ≥1.2% |
| Finance Pack attach rate | ≥5% of downloaders from this page |
| Revenue per download | ≥$3.00 (vs $1.87 baseline) |

---

## CPP 3: `numpad-spreadsheet` (data entry / spreadsheets)

**Audience:** Heavy data-entry users — people living in Excel, Google Sheets, Numbers, CRMs, and back-office forms on iPhone/iPad. They want a fast, tab-friendly numeric pad and quick reuse of recent values. Arrives via "spreadsheet keyboard" / "forms keyboard" Search Ads.

**Core message:** "Built for spreadsheets and forms — fast numbers, instant reuse."

### Screenshot selection + order

Lead with raw entry speed and forms (the data-entry core), then reuse and depth:

1. `01-numbers-without-slowdowns` — speed is the #1 ask for bulk data entry; the lag-free promise is the hook. Hero.
2. `02-faster-forms` — forms and tabular entry are this audience's literal job. Second to reinforce the spreadsheet/forms fit immediately.
3. `04-paste-recent-numbers` — clipboard history = reusing figures across cells/sheets without retyping; a strong data-entry differentiator.
4. `05-pro-packs-for-work` — "for work" framing + Symbols/Programmer packs appeal to power data users.
5. `03-tax-and-tip` — secondary calculation depth.
6. `06-your-numpad-your-style` — visual closer.

**Why this order:** speed (1) and forms (2) up front match the exact search intent; clipboard (4) in position 3 is the spreadsheet-specific superpower (reuse recent numbers), deliberately ahead of pro packs and tax/tip which are secondary for this audience.

### Screenshot-order table

| Position | Slide # | Slug |
|---|---|---|
| 1 | 1 | `01-numbers-without-slowdowns` |
| 2 | 2 | `02-faster-forms` |
| 3 | 4 | `04-paste-recent-numbers` |
| 4 | 5 | `05-pro-packs-for-work` |
| 5 | 3 | `03-tax-and-tip` |
| 6 | 6 | `06-your-numpad-your-style` |

### Promotional text (en-US, 91 chars)

```
A fast number pad for spreadsheets and forms. Reuse recent numbers. No subscription needed.
```

### Keyword angle

Workflow / spreadsheet intent. Cite `keyword-research.csv` rows: `spreadsheet keyboard` (row 7, workflow, priority 1 — "Existing screenshots mention forms and work"), `forms keyboard` (row 8, workflow, priority 1), `clipboard history` (row 9, feature, priority 2 — "Long-press clipboard overlay is a real feature"), `numeric keypad` (row 5, priority 1). Localized: `表单` (zh-Hans forms, row 17), `formularios` (es-ES forms, row 14); Spanish `hojas de calculo`/`excel` and Chinese `表格`/`Excel` clusters from `keyword-update-plan.md`.

### Localization priority

1. en-US (lead)
2. en-GB, en-AU, en-CA (same English copy)
3. de-DE, fr-FR (Europe = 31.6% of revenue)
4. zh-Hans, zh-Hant (Asia Pacific = 9.7%; spreadsheet/Excel intent strong, per keyword plan)
5. ja, pt-BR

### Success metrics

| Metric | Target |
|---|---|
| Conversion rate | ≥1.1% (vs 0.7% baseline) |
| First-time downloads | ≥20% lift vs control for data-entry Search Ads |
| Symbols/Programmer pack attach | track only |

---

## Consolidated per-CPP order matrix

Positions are slide numbers (1–6) from the canonical set.

| Position | numpad-workflow | numpad-finance | numpad-spreadsheet |
|---|---|---|---|
| 1 | 1 | 3 | 1 |
| 2 | 2 | 5 | 2 |
| 3 | 3 | 2 | 4 |
| 4 | 4 | 4 | 5 |
| 5 | 5 | 1 | 3 |
| 6 | 6 | 6 | 6 |

## Promotional text lengths (App Store limit 170)

| CPP | Chars | Within limit |
|---|---|---|
| numpad-workflow | 48 | yes |
| numpad-finance | 92 | yes |
| numpad-spreadsheet | 91 | yes |

(Lengths verified programmatically by `marketing/assemble_cpp_screenshots.py`, which asserts each promo string is ≤170 chars and prints the count.)

## Assets & assembly

- Run `python3 marketing/assemble_cpp_screenshots.py` to stage reordered screenshots into `marketing/cpp/{cpp_name}/{fastlane_device}/{locale}/` with `NN_<slug>.png` deliver-style ordering. Idempotent; re-run safely.
- Default locale set: en-US + the union of the per-CPP localization priorities above. Use `--locale en-US` to stage a single locale, `--all` for the full set.
- The script never touches `fastlane/screenshots/`, the generators, or ASC.

## Handoff

Manual ASC steps to create the two new CPPs, fix the `numpad-workflow` order, upload screenshots, and set promo text in all target locales — stopping before Submit — are in `marketing/asc/cpp_runbook.md`. An optional, dry-run-by-default ASC API helper is at `marketing/asc/cpp_manage.py` (untested; must be reviewed before use).
