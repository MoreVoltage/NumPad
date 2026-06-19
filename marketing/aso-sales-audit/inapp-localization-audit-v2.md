# In-App Localization Audit v2

Date: 2026-06-18
Scope: app target + keyboard extension `.lproj` coverage vs. the 50-locale App Store metadata set, with a focus on the paywall/store surface so a localized store listing does not lead to an English in-app paywall.

> Companion to `iap-localization-audit.md` (which covers ASC IAP product names/descriptions). This doc covers the *in-app* bundled `Localizable.strings`, the store/paywall strings the app renders at runtime.

---

## 1. Verified `.lproj` coverage (what actually ships in the bundle)

Directories were enumerated on disk, not trusted from a list. Findings:

### App target — `NumPad/<lang>.lproj/`

18 `.lproj` directories exist. **17 carry a `Localizable.strings`; `zh-HK` does not.**

| Has `Localizable.strings` (17) | Notes |
|---|---|
| Base, en, ar, de, es, fr, he, hi, it, ja, ko, nl, pl, pt-PT, ru, zh-Hans, zh-Hant | `Base` + `en` are the English masters. Each non-English file has 103 keys pre-change (113 after this pass). |

| `.lproj` present but **no** `Localizable.strings` (1) | Contents |
|---|---|
| `zh-HK.lproj` | Only `LaunchScreen.strings` and `Main.strings`, both 1-byte/empty. **No `Localizable.strings`.** A `zh-HK` (Hong Kong) user therefore gets **zero** localized in-app strings from this folder and resolves to `zh-Hant` (see matrix). This is the one in-app gap inside the existing Chinese set. |

So the real count of in-app-localized languages for the runtime string table is **16 non-English** (de, es, fr, ar, he, hi, it, ja, ko, nl, pl, pt-PT, ru, zh-Hans, zh-Hant) **+ en/Base** — i.e. the "~16 languages" figure is accurate, with the caveat that `zh-HK` is a directory but not a working localization for `Localizable.strings`.

### Keyboard extension — `Keyboard/<lang>.lproj/`

16 directories: ar, de, en, es, fr, he, hi, it, ja, ko, nl, pl, pt-PT, ru, zh-Hans, zh-Hant. **No `Base` and no `zh-HK`** here. The keyboard extension surface is mostly chrome (key labels, Full Access prompts) and does not render the paywall, so it is out of scope for this deliverable but listed for completeness.

### Out of scope (third-party / system)

`Pods/SwiftRater/SwiftRater/*.lproj` (31 locales) is a dependency's own bundle and `NumPad/Settings.bundle/en.lproj` is the Settings.app bundle — neither is our paywall surface.

---

## 2. Coverage matrix: 50 store-metadata locales → in-app resolution

Store metadata ships **50 locales** (verified from `fastlane/metadata/<locale>/`):
`ar-SA, bn-BD, ca, cs, da, de-DE, el, en-AU, en-CA, en-GB, en-US, es-ES, es-MX, fi, fr-CA, fr-FR, gu-IN, he, hi, hr, hu, id, it, ja, kn-IN, ko, ml-IN, mr-IN, ms, nl-NL, no, or-IN, pa-IN, pl, pt-BR, pt-PT, ro, ru, sk, sl-SI, sv, ta-IN, te-IN, th, tr, uk, ur-PK, vi, zh-Hans, zh-Hant`.

### How iOS resolves a store locale to an in-app `.lproj`

`.lproj` folders are **language IDs** (Apple, *Language and Locale IDs*). At launch iOS walks the user's ordered preferred languages and picks the best available `.lproj`, with **dialect → base-language fallback**: a region dialect (`en-GB`, `de-DE`, `fr-CA`) falls back to the base language `.lproj` (`en`, `de`, `fr`) when no exact dialect folder exists. Script-tagged Chinese (`zh-Hans`/`zh-Hant`) matches by script; Hong Kong (`zh_HK`) defaults to **Traditional**, so it resolves to `zh-Hant` when no `zh-HK` strings exist. If no language matches at all, the app uses its development region (English).

> Important: a buyer's App Store storefront/region is not the same thing as their device language. The matrix below assumes the common case where device language tracks the territory's primary language; a German speaker with an English phone sees English regardless. The point of the matrix is: *for a user whose device language matches the localized store listing, does the in-app paywall also localize?*

### Matrix

Legend — Resolves: the in-app `.lproj` iOS will load. Result: ✅ localized in-app · ⚠️ localized but via a different dialect's wording · ❌ falls back to English.

| Store locale | Resolves to in-app `.lproj` | Result |
|---|---|---|
| en-US / en-GB / en-AU / en-CA | en | ✅ (English master) |
| de-DE | de | ✅ |
| es-ES | es | ✅ |
| es-MX | es | ⚠️ Spanish, but European-Spanish wording (no `es-MX.lproj`) |
| fr-FR | fr | ✅ |
| fr-CA | fr | ⚠️ French, but France wording (no `fr-CA.lproj`) |
| it | it | ✅ |
| nl-NL | nl | ✅ |
| pl | pl | ✅ |
| ru | ru | ✅ |
| pt-PT | pt-PT | ✅ |
| pt-BR | pt-PT | ⚠️ Nearest-Portuguese match; **European** wording shown to Brazilian users (no base `pt` and no `pt-BR.lproj`). Acceptable but not ideal. |
| ja | ja | ✅ |
| ko | ko | ✅ |
| zh-Hans | zh-Hans | ✅ |
| zh-Hant | zh-Hant | ✅ |
| (zh-HK storefront / HK device) | zh-Hant | ⚠️ Resolves to Traditional; the empty `zh-HK.lproj` is skipped for strings. Fine for HK (Traditional is correct), but note the dedicated folder does nothing. |
| ar-SA | ar | ✅ |
| he | he | ✅ |
| hi | hi | ✅ |
| **ca** (Catalan) | — | ❌ English |
| **cs** (Czech) | — | ❌ English |
| **da** (Danish) | — | ❌ English |
| **el** (Greek) | — | ❌ English |
| **fi** (Finnish) | — | ❌ English |
| **hr** (Croatian) | — | ❌ English |
| **hu** (Hungarian) | — | ❌ English |
| **id** (Indonesian) | — | ❌ English |
| **ms** (Malay) | — | ❌ English |
| **no** (Norwegian) | — | ❌ English |
| **ro** (Romanian) | — | ❌ English |
| **sk** (Slovak) | — | ❌ English |
| **sl-SI** (Slovenian) | — | ❌ English |
| **sv** (Swedish) | — | ❌ English |
| **th** (Thai) | — | ❌ English |
| **tr** (Turkish) | — | ❌ English |
| **uk** (Ukrainian) | — | ❌ English |
| **vi** (Vietnamese) | — | ❌ English |
| **bn-BD** (Bengali) | — | ❌ English |
| **gu-IN** (Gujarati) | — | ❌ English |
| **kn-IN** (Kannada) | — | ❌ English |
| **ml-IN** (Malayalam) | — | ❌ English |
| **mr-IN** (Marathi) | — | ❌ English |
| **or-IN** (Odia) | — | ❌ English |
| **pa-IN** (Punjabi) | — | ❌ English |
| **ta-IN** (Tamil) | — | ❌ English |
| **te-IN** (Telugu) | — | ❌ English |
| **ur-PK** (Urdu) | — | ❌ English |

### Summary

- **20 of 50** store locales get a fully localized in-app paywall today (✅).
- **4** are "soft" localized via a sibling dialect (⚠️): `es-MX`→es, `fr-CA`→fr, `pt-BR`→pt-PT, plus HK→zh-Hant. These read fine but in the wrong regional flavor; low priority.
- **26 of 50** store locales currently hit an **English in-app paywall** (❌) despite a localized store listing. This is the exact "localized store → English paywall" leak this deliverable targets.

---

## 3. Which in-app languages to ADD next (ordered by revenue)

Cross-referenced with `market-prioritization.csv`. That file ranks by **revenue cluster**, not single locales: USA/Canada (42.5%), Europe (31.6%), Africa/Middle East/India (10.2%), Asia Pacific / Chinese (9.7%), then LATAM Spanish (6.0%). The English and Chinese clusters are already covered in-app, so the incremental revenue from *new* in-app languages comes from the European tail and the India scripts that currently fall back to English.

Recommended add order (highest revenue-per-effort first):

1. **tr (Turkish)** — large single-language market, high utility-app fit, currently ❌. Priority-3 in the CSV's "Nordics and Central Europe / Multiple" line but the biggest single non-covered European-adjacent market.
2. **sv (Swedish), da (Danish), no (Norwegian), fi (Finnish)** — the Nordic block called out explicitly in the CSV (priority 3, "maintain before expanded"). High ARPU markets; small strings file; reuse one creative concept. Add as a group.
3. **cs (Czech), hu (Hungarian), ro (Romanian), sk (Slovak), hr (Croatian), sl-SI (Slovenian)** — Central/Eastern Europe block (priority 3). Lower individual revenue; batch after the Nordics.
4. **el (Greek), id (Indonesian), ms (Malay), vi (Vietnamese), th (Thai), uk (Ukrainian)** — emerging/AP + EU tail; add opportunistically.
5. **India scripts** (hi already covered; ta-IN, te-IN, mr-IN, bn-BD, gu-IN, kn-IN, ml-IN, pa-IN, or-IN) and **ur-PK** — the MENA-IN cluster is 10.2% of revenue but is spread across many scripts and `hi` already captures the largest slice. Add the top one or two (likely `ta`/`te`) only if India in-app conversion data justifies the translation cost; otherwise leave on English.
6. **ca (Catalan)** — lowest priority; Catalan users are comfortable in `es`, which is already localized.

Quick wins that are *not* new languages (do these first, near-zero effort):
- **`pt-BR`**: add a `pt-BR.lproj/Localizable.strings` (copy of pt-PT with Brazilian wording) so Brazil — a large market — gets native rather than European Portuguese. Currently ⚠️.
- **`zh-HK`**: either delete the empty `zh-HK.lproj` (let HK resolve to `zh-Hant` cleanly) or populate it. Today it is dead weight.

---

## 4. Pack / feature names ARE localized (confirmed)

Pack and feature names use `NSLocalizedString` and are translated in each non-English file. Samples:

- `de.lproj/Localizable.strings`: `"Finance" = "Finanzen";`, `"Symbols" = "Symbole";`, `"Programmer" = "Programmierer";`, `"Math" = "Mathematik";`, `"Finance Pack" = "Finanz-Paket";`, `"Custom Pack" = "Eigenes Paket";`
- `ja.lproj/Localizable.strings`: `"Finance" = "金融";`, `"Symbols" = "記号";`, `"Programmer" = "プログラマー";`, `"Math" = "数学";`, `"Finance Pack" = "ファイナンスパック";`, `"Custom Pack" = "カスタムパック";`

The store row strings (`NumPad Pro`, `Everything, forever`, `All keyboard packs, all premium themes, and every future pack.`, `Finance Pack`, `Currency symbols and finance keys.`, `Restore Purchases`, etc.) are likewise translated in all 16 non-English files. After this pass, the 10 new context-aware paywall hero/benefit strings are translated in all 15 files that carry a `Localizable.strings` (every non-English app-target locale except `zh-HK`, which has no such file).

---

## 5. RemoteConfig `priceCopy` hero line is English-only by default — recommended fix (no Swift change here)

### The defect

`NumPad/Libraries/SharedExtensions.swift` (~line 992) sets the Remote Config **default**:

```swift
"price_copy": "Unlock Pro to access premium themes and packs" as NSObject,
```

and exposes it (~line 1005) as:

```swift
var priceCopy: String { rc["price_copy"].stringValue }
```

`StoreViewController.heroCopy(for:)` (`NumPad/Controllers/StoreViewController.swift`, ~lines 199–202) consumes it for the default/settings entry point:

```swift
let rcCopy = RemoteConfigManager.shared.priceCopy
let subtitle = rcCopy.isEmpty
    ? NSLocalizedString("All keyboard packs, all premium themes, and every future pack.", comment: "...")
    : rcCopy
```

The intent is "use the localized bundled string unless Remote Config overrides it." But the RC **default value is a non-empty English literal**, so `rcCopy.isEmpty` is **never true** in the common case — even when no per-locale RC value has been published. Result: the default-source paywall subtitle renders the **English** `"Unlock Pro to access premium themes and packs"` to every locale, shadowing the perfectly good localized `NSLocalizedString` fallback. (The three context-aware entry points — `key_lock`, `pack_picker`, `first_run` — are unaffected; they use `NSLocalizedString` directly. Only the default/settings hero is hit.)

### Recommended fix (describe only — do not change Swift in this deliverable)

Prefer the localized bundled string and treat the RC default as "unset." Any one of these is sufficient; option A is the smallest, safest change:

- **Option A (preferred): make the RC default empty.** In `configureDefaults()` change the `price_copy` default to `""`. Then `rcCopy.isEmpty` is true unless a *real* per-locale value is published in the Remote Config console, so the localized `NSLocalizedString` fallback shows by default and an explicit RC value can still override per region/experiment. No call-site change needed.
- **Option B: sentinel check at the call site.** Keep the English default but treat it as a sentinel: `let useRC = !rcCopy.isEmpty && rcCopy != RemoteConfigManager.englishPriceCopyDefault`. More code; brittle if the default text ever changes.
- **Option C: gate on localization availability.** Only use `rcCopy` when the device's preferred language has no bundled localization. Most complex; not recommended.

Either way, if marketing wants to keep running price-copy experiments via Remote Config, they should publish **per-locale** `price_copy` values (Remote Config supports conditions on device language/region); otherwise the bundled localized strings are the correct default. Recommend Option A plus a short note in the RC console that `price_copy` must be set per-locale or left empty.

---

## 6. What changed in this pass

- Added 10 context-aware paywall strings (hero titles + benefit bullets) to **15** app-target `Localizable.strings` files: de, es, fr, ar, he, hi, it, ja, ko, nl, pl, pt-PT, ru, zh-Hans, zh-Hant — appended under a `/* Paywall */` comment, English keys preserved on the left.
- `zh-HK` intentionally **not** edited: it has no `Localizable.strings` and the deliverable constraint is to append to existing files only. HK users already resolve to `zh-Hant`.
- en.lproj, Base.lproj, Swift, and generators were not touched.
- Translator-review CSV: `paywall-strings-localization.csv` (same folder).
- Validation: see §7.

---

## 7. Validation

`plutil` is unavailable in the build/CI shell used here, so a Python parser was used as the authoritative check (each non-comment line must match `"key" = "value";` with balanced quotes; all 10 expected keys must be present). On a macOS machine, `plutil -lint NumPad/*.lproj/Localizable.strings` is the recommended confirming step before commit.

Result: **all 15 edited files pass** — 113 keys each (103 prior + 10 new), 0 malformed lines, em-dashes preserved (en-dashes/colons that crept into the German and Spanish drafts were corrected to `—`), and all 10 new paywall keys present in every file.

### Low-confidence items for human review

- `"Make NumPad yours"` is adapted idiomatically rather than translated literally in every language (e.g. de "Mach NumPad zu deinem", fr "Personnalisez NumPad", es "Haz NumPad a tu medida"). Flagged for ar/he/hi specifically in the CSV — verify the imperative tone reads as natural marketing copy, not a literal "make … yours."
- ar/he are RTL: keys remain English (required for `NSLocalizedString`); values are native RTL with the Latin "NumPad Pro" as an LTR island, which the OS bidi algorithm handles. Confirm rendering on-device.
- Pack-name lists in K1/K6/K8 reuse each file's existing pack-name translations; confirm they still match if pack names are ever renamed.
