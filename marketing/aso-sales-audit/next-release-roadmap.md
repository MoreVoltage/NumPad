# NumPad 1.8 — Revenue Roadmap & Status

Date: 2026-06-18. Builds on the 1.7.2 ASO/sales audit. Everything below is **staged or
implemented in the repo**; nothing was submitted to App Store review, no prices changed,
no purchases made.

## Baseline (from the audit)
90 days: 65K impressions · 0.7% page conversion · 180 first-time downloads · 5 IAPs · $337 IAP proceeds.
US+Canada 42.5% & Europe 31.6% of revenue · iPad 28.6% of revenue · Family Sharing OFF.

## What shipped this pass

| # | Deliverable | Revenue mechanism | Effort | How we measure it | Status |
|---|---|---|---|---|---|
| 1 | **Genuine iPad screenshots** (50 locales × 13"/12.9") replacing the iPhone-in-an-iPad-frame bug | Higher **conversion** on iPad search/browse (28.6% of revenue saw wrong assets) | M | iPad product-page conversion & iPad revenue share vs 1.7.2 | ✅ Done, validated |
| 2 | **Marketing video** v1 — commercial master (31s), App Store preview (19s), 15s/6s cut-downs, poster, original music/SFX | Higher **conversion** (poster→play→install) + brand/paid-social reach | L | ASC "with preview" conversion; preview play rate; social CTR | ✅ v1 built · ⏳ VO + real-context re-capture pending |
| 3 | **Paywall/IAP** — context-aware value hero, one-time first-run upsell, full funnel analytics | Higher **conversion** (download→paid) + some **ARPU** | S–M | New per-source funnel: `purchase_initiated/completed/cancelled`, `paywall_dismissed`; attach rate | ✅ Implemented (build in Xcode) |
| 4 | **CPPs** — workflow order fixed (1→6), new `numpad-finance` + `numpad-spreadsheet` w/ tailored shots, promo, keywords | Higher **conversion** via audience-matched pages + Finance attach | M | Per-CPP conversion vs control; Finance Pack attach from finance CPP | ✅ Staged (assets + runbook + dry-run script) |
| 5 | **Pricing & hygiene** — Family Sharing ON (both IAPs), legacy-IAP cleanup, per-market pricing recs, Finance price reconcile | **ARPU** (perceived value; pricing later) | S | Attach rate post-Family-Sharing; per-market proceeds when a test runs | ✅ Recommended (scripts + memo) |
| 6 | **In-app localization** — 10 new paywall strings × 16 languages; RC `price_copy` default fixed so localized pitch wins | Higher **conversion** in non-English markets (closes the localized-store → English-paywall leak) | M | Conversion & attach by locale (esp. DE/FR/JA/ES/zh) | ✅ Done (top markets) · ⏳ 26 long-tail locales optional |

## Prioritized roadmap

### Quick wins — ship with 1.8 (low effort, high certainty)
1. **iPad screenshots** (D1) — already validated; upload via `fastlane upload_screenshots`.
2. **Paywall + analytics + localization** (D3/D6) — build in Xcode, smoke-test, ship in the 1.8 binary. The analytics are the prerequisite for everything in "larger investments".
3. **Family Sharing ON** for both IAPs (D5) — two toggles in ASC; zero-cost perceived-value bump. (One-way door — can't be disabled later.)
4. **Fix the shuffled `numpad-workflow` CPP order** (D4) — pure win, no new assets.
5. **App Store preview (existing-capture cut)** staged in Media Manager (D2) — a preview at all beats none.

### Larger investments — sequence after 1.8 ships
6. **Video re-capture + VO** (D2) — record real-context footage (Notes/checkout/spreadsheet) on the Simulator per the storyboard, add the voiceover read; re-run the pipeline. Biggest lift to the spot's quality.
7. **Launch `numpad-finance` + `numpad-spreadsheet` CPPs** with matching Apple Search Ads groups (D4).
8. **Pricing tests** (D5) — only once 1.8's funnel analytics have data; first candidate is a lower India Pro tier.
9. **Long-tail in-app localization** (D6) — add the 26 store locales that still hit an English paywall, by revenue order (tr → Nordics → CEE → …).

## What needs you (decisions & handoffs)
- [ ] **Build & smoke-test in Xcode** — D3/D6 are Swift; verify the paywall hero, first-run upsell, and new events on device/simulator (no Swift toolchain in this environment to compile).
- [ ] **Run ASC steps with your API key** (stage only, **stop before Submit**): `fastlane upload_screenshots` / `upload_metadata`; create the 2 CPPs + fix order (`marketing/asc/cpp_runbook.md`); Family Sharing + legacy-IAP audit (`marketing/asc/iap_admin.py`, dry-run first); confirm Finance Pack's **live** price; stage the video preview.
- [ ] **Voiceover** — record the read (script in `commercial-storyboard.md`) or keep text-only; one mix step documented in `video/README.md`.
- [ ] **Simulator re-capture** (your choice) — say the word and I'll drive it / hand you the shot list.
- [ ] **Translation review** — 16 localized paywall strings (`paywall-strings-localization.csv`); double-check ar/he and the idiomatic "Make NumPad yours".
- [ ] **Pricing** — recommendation is hold now; approve when you want to test.

## Verification summary (this pass)
- `marketing/validate_aso_assets.py` → PASS (50 locales, 1800 marketing + 1500 fastlane screenshots, **iPad raws + frame present**).
- iPad slides visually confirmed genuine iPad UI across Latin/CJK/RTL/Indic locales.
- All Python compiles; edited Swift is brace-balanced (compile in Xcode to confirm).
- Video: master 30.8s, preview 18.6s, 15s, 6s — all 1080×1920 with audio.
- 16 `.lproj` each carry the 10 new paywall keys with native translations.
- No ASC submissions, no price changes, no purchases.
