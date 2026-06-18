# Custom Product Pages — Actionable Spec v2

Date: 2026-06-16  
Updated: 2026-06-17

## Overview

Three Custom Product Pages, each targeting a distinct acquisition intent. ASC allows up to 35 CPPs; we start with 3 that map to the clearest audience segments in the current data.

Current live state checked 2026-06-17: one "Test" CPP shell exists in ASC and is Ready to Submit. It is not useful for sales as-is. It should be deleted, left out of review, or repurposed as `numpad-workflow` before submission.

## Audience Sizing

| Segment | Evidence | Est. Share of Traffic |
|---|---|---|
| General productivity / forms | Search is #1 source (14 PPV/day avg); "number keyboard" and "numpad" are primary search terms | ~55% |
| Finance / tax / spreadsheet | Finance Pack exists as IAP; tax/tip is a differentiator; Europe + India overindex on finance search terms | ~25% |
| iPad power users | iPad is 28.6% of revenue ($31.41/mo); no iPad-specific screenshots exist today | ~20% |

---

## CPP 1: `numpad-workflow`

**Audience:** General productivity users arriving via App Store Search for "number keyboard", "numeric keypad", "forms keyboard", etc.

**Core Message:** "The number keyboard iOS should have included."

**Traffic Sources:**
- Default for Apple Search Ads broad-match campaigns
- Web referral links from productivity blog posts / review sites
- App Store Search (if set as the search-ads landing page)

### Metadata

| Field | Value |
|---|---|
| Promotional Text | Type numbers faster in any app. No subscription. |
| Screenshots | Slides 1 (invoice/forms), 2 (checkout), 4 (clipboard), 3 (tax/tip), 5 (finance), 6 (themes) |

**Screenshot order rationale:** Lead with the two strongest neutral-context slides (invoice, checkout), then clipboard history as a differentiator, then tax/tip and finance as depth. Themes last as a visual closer.

**Why this order differs from control:** Current order is 1-2-3-4-5-6. This reorders to 1-2-4-3-5-6, putting the clipboard (a universally useful feature) before tax/tip (a niche feature). Matches PPO Treatment A.

### Localization Priority

1. English (US) — launch first
2. English (UK, AU, CA) — same copy
3. German, French, Spanish (MX), Japanese, Portuguese (BR) — top revenue non-English markets

### Success Metrics

| Metric | Target | Measurement |
|---|---|---|
| Conversion rate | ≥1.0% (vs 0.7% baseline) | ASC Analytics, 30-day window |
| First-time downloads | ≥25% lift | Compare CPP vs control page |
| Bounce rate (PPV with no download) | Track only | Baseline not yet established |

---

## CPP 2: `numpad-finance`

**Audience:** Users searching for finance/tax/accounting keyboard functionality — accountants, bookkeepers, small business owners, anyone doing expense tracking.

**Core Message:** "Tax, tip, and finance symbols — built into your keyboard."

**Traffic Sources:**
- Apple Search Ads exact-match campaigns on: "tax calculator keyboard", "finance keyboard", "accounting keyboard", "spreadsheet keyboard"
- Links from finance/accounting tool review pages
- Cross-promotion from Finance Pack IAP description

### Metadata

| Field | Value |
|---|---|
| Promotional Text | Tax & tip calculator, currency symbols, and clipboard history — all from your keyboard. |
| Screenshots | Slides 3 (tax/tip), 5 (finance symbols), 1 (invoice/forms), 2 (checkout), 4 (clipboard), 6 (themes) |

**Screenshot order rationale:** Lead with the tax/tip overlay (the hero feature for this audience), then finance symbols keyboard, then the general-purpose slides. This front-loads the Finance Pack value proposition.

### Localization Priority

1. English (US)
2. English (UK, AU, CA)
3. German, French — Europe is 31.6% of revenue and finance use cases are strong there
4. Japanese, Portuguese (BR), Spanish (MX)

### Success Metrics

| Metric | Target | Measurement |
|---|---|---|
| Conversion rate | ≥1.2% | Finance-intent users should convert higher than general |
| Finance Pack attach rate | ≥5% of downloaders from this page | Track IAP proceeds from users acquired via this CPP |
| Revenue per download | ≥$3.00 | Higher than baseline $1.87 |

---

## CPP 3: `numpad-ipad`

**Audience:** iPad users — the original plan called this "business-ipad" but iPad users broadly are the right target. iPad is 28.6% of revenue with zero iPad-optimized screenshots today.

**Core Message:** "Finally, a real number keyboard for iPad."

**Traffic Sources:**
- Apple Search Ads campaigns filtered to iPad device type
- Web referral links mentioning iPad specifically
- iPad App Store Browse (iPad-specific editorial features)

### Metadata

| Field | Value |
|---|---|
| Promotional Text | Full number keyboard for iPad. Works in every app. No subscription. |
| Screenshots | iPad screenshots only (13" and 12.9"), same 6-slide sequence as control but rendered at iPad aspect ratio |

**Screenshot note:** iPad-rendered screenshots now exist locally for all 50 locales in both 13" and 12.9" sizes. Use the files exported to `fastlane/screenshots/{locale}/APP_IPAD_PRO_6GEN_129_*.png` and `APP_IPAD_PRO_129_*.png`.

### Localization Priority

1. English (US)
2. English (UK, AU, CA)
3. German, Japanese — iPad penetration is highest in these markets

### Success Metrics

| Metric | Target | Measurement |
|---|---|---|
| Conversion rate | ≥1.5% | iPad users who see iPad screenshots should convert significantly higher |
| iPad revenue share | ≥35% (vs current 28.6%) | Shift more iPad traffic through this page |
| Pro Lifetime attach rate | ≥3% | iPad users tend to be higher-value |

---

## Implementation Checklist

### Phase 1: Build (no ASC changes)

- [x] Finalize all 6 screenshot raw images; slides 3 and 4 now use a neutral Notes-style context.
- [x] Generate iPad screenshots at 13" and 12.9" sizes.
- [x] Localize screenshot headlines/sublines for all 50 metadata locales.
- [ ] Write promotional text variants for each CPP in all target locales
- [ ] Document the screenshot order for each CPP

### Phase 2: Create in ASC (requires user confirmation)

- [ ] Delete, leave out, or repurpose the empty "Test" CPP
- [ ] Create `numpad-workflow` CPP in ASC
- [ ] Create `numpad-finance` CPP in ASC
- [ ] Create `numpad-ipad` CPP in ASC
- [ ] Upload screenshots in the specified order for each CPP
- [ ] Set promotional text for each CPP
- [ ] Set localized metadata for each CPP

### Phase 3: Traffic & Measurement

- [ ] Set up Apple Search Ads campaign groups mapping to each CPP
- [ ] Create web referral UTM links pointing to each CPP
- [ ] Baseline 30-day metrics before directing traffic
- [ ] Run for minimum 4 weeks before evaluating

## Dependencies

| Dependency | Status | Blocks |
|---|---|---|
| Slide 3/4 raw screenshot replacement | Complete locally | Upload/review only |
| iPad screenshot generation | Complete locally | Upload/review only |
| Screenshot localization | Complete locally for 50 locales | Upload/review only |
| Apple Search Ads account | Not verified | Phase 3 traffic routing |

## Recommendation

Launch `numpad-workflow` first — it matches the current search-led acquisition mix and requires the least new asset work (same screenshots as control, just reordered). Once that's running, add `numpad-finance` to test whether finance-intent routing improves IAP attach. Add `numpad-ipad` after the refreshed iPad screenshots are uploaded and reviewed in ASC.
