# NumPad — Next Release Revenue Improvement Prompt

**Created:** 2026-06-18
**Context:** 1.7.2 has been submitted (metadata + screenshots uploaded via Fastlane; awaiting a new build). This document is a ready-to-run prompt for the *next* release cycle, focused on growing revenue. Hand the "PROMPT TO RUN" section to an agent verbatim; the rest is grounding context and rationale.

---

## Where revenue stands today (baseline)

From `pricing-packaging-analysis-v2.md` and the 90-day snapshot:

| Metric | Value |
|---|---|
| Paid app price (US) | $2.99 ($2.54 proceeds) |
| Pro Lifetime IAP (US) | $4.99 ($4.24 proceeds) |
| Finance Pack IAP (US) | ~$1.99 |
| Total revenue (90 days, est.) | ~$837 |
| IAP proceeds (90 days) | $337 |
| **IAP conversions (90 days)** | **5** |
| First-time downloads (90 days) | 180 |
| Revenue per first-time download | ~$4.65 |
| Family Sharing on IAPs | OFF |
| Top territories | US/Canada 42.5%, Europe 31.6% |

**The headline problem:** download volume is low *and* IAP conversion is very low (5 purchases per ~180 downloads). Revenue growth therefore has two independent levers — **(A) get more qualified downloads** (store conversion / discoverability) and **(B) convert more installs into IAP buyers** (paywall, packaging, funnel). The next release should move both.

---

## What already exists (do NOT rebuild these — extend them)

- **Screenshot generator:** `marketing/generate_app_store_screenshots.py` — 6 slides, 50 locales, iPhone (6.9/6.5/6.3/6.1) + iPad (13/12.9). Driven by `LOCALE_TEXT` and a `SLIDES` list.
- **Overlay raw recomposer:** `marketing/recompose_overlay_raws.py` — composites the keyboard onto a neutral "Notes" host for slides 3 & 4; includes the seam-cleanup pass added in 1.7.2.
- **Validator:** `marketing/validate_aso_assets.py` — checks locale counts, IAP char limits (name ≤30, desc ≤45), screenshot counts/sizes.
- **Fastlane lanes:** `upload_metadata`, `upload_screenshots`, `upload_all` (in `fastlane/Fastfile`).
- **Unused video clips:** `marketing/video/v1-rise.mov … v6-packs.mov` — six short captures (rise/typing/clipboard/taxtip/themes/packs). Never assembled or uploaded. **Starting material for the App Store preview video.**
- **ASO research already done:** `keyword-research.csv`, `keyword-update-plan.md`, `market-prioritization.csv`, `pricing-packaging-analysis-v2.md`, `custom-product-pages-v2.md`, `product-page-optimization-plan.md`, `localized-screenshot-plan.md`, `baseline-metrics.md`.
- **Live CPP:** `numpad-workflow` (renamed from "Test") — has iPhone + iPad screenshots, 7 keywords, Option A promo text. **Not yet submitted.**

---

## Known defects to fix next cycle

1. **iPad screenshots use an iPhone mockup.** `render_slide_ipad()` in `generate_app_store_screenshots.py` reuses the single iPhone `marketing/assets/mockup.png`, just rescaled onto a 2064×2752 canvas with repositioned floating keys. The raw captures behind them are also iPhone screenshots. Result: the iPad "13-inch" screenshots show a phone, not an iPad. Needs (a) a real iPad device frame/mockup, and (b) iPad-appropriate raw captures (landscape or portrait iPad, ideally showing the side-panel overlay layout that the app supports on iPad ≥700pt — see CLAUDE.md "iPad ≥700pt wide" behavior).
2. **No App Store preview video** despite 6 clips sitting ready in `marketing/video/`.
3. **CPP screenshot order is shuffled** (ASC reorders on multi-upload) on `numpad-workflow`; iPhone and iPad sets are not in 1→6 order.
4. **Family Sharing is OFF** on both IAPs — turning it on is a discoverability/perceived-value lever (and is expected for non-consumables).

---

## PROMPT TO RUN (give this to the agent verbatim)

> You are helping improve revenue for **NumPad**, an iOS custom-keyboard app (paid app + two non-consumable IAPs: `numpad.pro.lifetime` and `numpad.pack.finance`). The previous release (1.7.2) shipped 50-locale metadata, refreshed screenshots, and fixed broken IAP localizations. Now plan and execute revenue-focused improvements for the **next** release.
>
> **Constraints & ground rules:**
> - Work in the connected `NumPad` repo. Reuse and extend the existing tooling in `marketing/` (screenshot generator, recompose script, validator, Fastlane lanes) — do not rebuild from scratch.
> - Read the existing ASO research in `marketing/aso-sales-audit/` first (especially `pricing-packaging-analysis-v2.md`, `keyword-update-plan.md`, `market-prioritization.csv`, `product-page-optimization-plan.md`) and build on its conclusions rather than redoing the analysis.
> - For any App Store Connect changes, **stage everything but stop before the final "Submit for Review"** — leave that click to the user. Never change pricing, execute purchases, or submit on the user's behalf without explicit confirmation.
> - Verify every asset with `marketing/validate_aso_assets.py` (and a fresh visual check of regenerated images) before declaring done.
> - Ask clarifying questions up front on anything that's a business decision (price changes, which markets, paywall aggressiveness, video voiceover/music).
>
> **Deliverables, in priority order (revenue impact first):**
>
> **1. Real iPad screenshots (conversion on iPad search/browse).**
> The current iPad screenshots show an iPhone. Produce genuine iPad assets: source or build an iPad device-frame mockup, capture iPad raw screenshots that show the app's iPad-specific UI (the side-panel overlay layout on iPad ≥700pt — clipboard/snippets/tax-tip as a 360pt trailing panel, pointer hover, drag-and-drop), and update `render_slide_ipad()` to use the iPad frame and an iPad-appropriate composition. Regenerate iPad 13"/12.9" for all 50 locales and validate sizes (2064×2752 / 2048×2732).
>
> **2. A real commercial-style marketing video (single biggest untapped conversion asset).**
> This is NOT just stitching together the existing screen-capture clips. The clips in `marketing/video/` (`v1-rise` … `v6-packs`) are too short, too basic, and too literal — they're raw UI captures, not advertising. Replace them with a proper **commercial**: the kind of polished, TV-ad-style spot that makes a viewer stop scrolling, tap the poster frame to watch, and feel they want the app by the end.
>
> Build it in two layers:
> - **(a) The App Store preview cut** — Apple's on-store video. Must be screen-recording-based per Apple's rules (real device footage of the app in use, no heavy live-action that the guidelines reject), 15–30s, portrait, in the accepted formats (e.g. 886×1920 / 1080×1920 for iPhone 6.5"+, plus an iPad cut and poster frame). This is what actually uploads to App Store Connect.
> - **(b) The full commercial** — a longer (~30–60s), higher-production "advertising" cut for paid social, the web landing page, and the press kit, where Apple's screen-recording restriction doesn't apply. This is where it should feel like a real ad.
>
> **Creative brief for the commercial — treat this as advertising, not a feature tour:**
> - **Open on a relatable pain, not the product.** The first 3 seconds must hook: someone fighting the default iOS keyboard to type numbers — fumbling a total at a restaurant, mistyping a code, switching keyboard modes repeatedly. The viewer should think "ugh, that's me" before they ever see NumPad.
> - **Turn on the product as the resolution.** NumPad appears and the friction disappears — fast, confident number entry. Show it *in real contexts* (a notes app, a checkout field, a spreadsheet), not in the app's own settings.
> - **Build to the "wow" moments:** the tax/tip long-press, clipboard history, packs and themes — paced like an ad with momentum, each beat earning the next.
> - **Emotional arc + payoff:** frustration → relief → delight → desire. End on a clean, memorable brand moment (logo, tagline, "Your number pad.") and an implicit CTA to download.
> - **Production values:** motion graphics / kinetic typography, snappy transitions on the beat, a soundtrack with energy, tasteful sound design (key taps, satisfying confirms), device frames that look premium. Reference the feel of a polished Apple/SaaS product spot — confident, clean, fast. It should NOT look like a tutorial.
> - **Storyboard first, then produce.** Before rendering anything, deliver a shot-by-shot storyboard / script (scene, on-screen action, copy/VO line, duration, music cue) and get sign-off. Propose 2–3 hook concepts for the open and let the user pick. Confirm whether to use voiceover, on-screen text only, or both, and whether there's a budget for licensed music vs. royalty-free.
> - Capture fresh, clean screen recordings as needed (the existing clips can be source material but most will likely need re-shooting at higher quality and longer duration).
> - Deliver: the App Store preview cut (+ poster frame, staged in Media Manager, not submitted), the full commercial master, and a couple of cut-downs (e.g. 6s and 15s) for paid social. Document the assets and where each is used.
>
> **3. Paywall / IAP-conversion improvements (the biggest revenue lever given 5 conversions / 180 downloads).**
> Analyze the in-app upsell funnel using the deep-link attribution already in place (`numpad://store-preview?source=…`, logged as `store_viewed`). Propose and, where it's a code change, implement concrete improvements: clearer value framing on the paywall, a better lock-chip moment, a first-run or contextual upsell, possibly bundling. Quantify expected impact and define the analytics events needed to measure it. Treat any actual price change as a user decision — present options, don't act.
>
> **4. Store-listing conversion (copy + screenshots A/B via CPPs).**
> Using `product-page-optimization-plan.md` and the existing `numpad-workflow` CPP, propose 1–2 additional audience-targeted Custom Product Pages (e.g. finance/accounting, data-entry/spreadsheets) with tailored screenshots, keywords, and promo text drawn from `keyword-research.csv`. Fix the shuffled screenshot order on the existing CPP (put both iPhone and iPad sets in 1→6 order). Stage in ASC, don't submit.
>
> **5. Packaging / catalog hygiene that affects revenue.**
> Turn on **Family Sharing** for both non-consumable IAPs (expected for this product type; improves perceived value). Review whether the 7 legacy draft IAPs should be deleted to declutter. Reconcile Finance Pack's exact price (the analysis estimates ~$1.99 but it wasn't confirmed). Present a pricing recommendation per top market (US, Europe, then the India/MEA and APAC tiers from `market-prioritization.csv`) — recommend, don't change.
>
> **6. Localization depth for top revenue markets.**
> US/Canada + Europe are 74% of sales. Verify the app's *in-app* paywall and pack names are localized (not just store metadata), since a localized store listing that leads to an English paywall leaks conversions. Spot-check the highest-value non-English markets.
>
> **For each deliverable:** state the expected revenue mechanism (more installs vs. higher conversion vs. higher ARPU), the effort, and how you'll measure it. Produce a short prioritized roadmap at the end (quick wins vs. larger investments) and update the validator if you add new asset types. End with a verification pass.

---

## Suggested sequencing for the next cycle

**Quick wins (do first, low effort / clear upside):**
- Turn on Family Sharing for both IAPs.
- Fix CPP screenshot ordering.
- Confirm Finance Pack price.
- Assemble the preview video from existing clips.

**Medium (real asset work):**
- Genuine iPad screenshots + iPad mockup.
- 1–2 new targeted CPPs.

**Larger (code + measurement):**
- Paywall/upsell funnel improvements with proper analytics instrumentation.
- In-app paywall localization for top markets.

---

## Measurement note

Before shipping the next release, capture a clean **baseline** (downloads, IAP conversion rate, ARPU, per-territory) so each change is attributable. `baseline-metrics.md` exists — refresh it at cycle start and again ~30 days post-release. The single metric to move: **IAP conversions per 100 first-time downloads** (currently ~2.8). Doubling that roughly doubles IAP revenue independent of download growth.
