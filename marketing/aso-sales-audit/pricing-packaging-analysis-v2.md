# Pricing and Packaging Analysis v2

Date: 2026-06-16

## Current Pricing Structure

### App Purchase Price

| Territory | Currency | Price | Proceeds |
|---|---|---|---|
| United States | USD | $2.99 | $2.54 |
| Eurozone | EUR | €2.99 | €2.12 |
| Australia | AUD | $4.99 | $3.86 |
| Albania | USD | $3.99 | $2.83 |
| Armenia | USD | $3.99 | $2.83 |

Base country: United States (USD). Available in 175 countries/regions. Price adjustment: May Adjust Automatically.

### Pro Lifetime IAP (`numpad.pro.lifetime`)

| Territory | Currency | Price | Proceeds |
|---|---|---|---|
| United States | USD | $4.99 | $4.24 |
| Eurozone | EUR | €5.99 | €4.24 |
| Australia | AUD | $7.99 | $6.17 |
| Brazil | BRL | R$29.90 | R$22.21 |
| Albania/Armenia | USD | $5.99 | $4.24 |

Available in 175 countries/regions. Family Sharing: OFF.

### Finance Pack IAP (`numpad.pack.finance`)

Priced lower than Pro Lifetime (exact prices follow the same Apple tier pattern, estimated ~$1.99 USD based on historical pricing tier structure).

Available in 175 countries/regions. Family Sharing: OFF.

## Revenue Analysis

### 90-Day Snapshot

| Metric | Value |
|---|---|
| IAP proceeds | $337 |
| In-app purchases | 5 |
| App price proceeds (est.) | ~$500 (based on downloads × $2.54) |
| Total revenue (est.) | ~$837 |
| First-time downloads | 180 |
| Redownloads | 158 |
| Revenue per first-time download | ~$4.65 |

### 30-Day Territory Sales (App + IAP Combined)

| Rank | Territory | Sales (USD) | Share |
|---|---|---|---|
| 1 | USA and Canada | $46.79 | 42.5% |
| 2 | Europe | $34.77 | 31.6% |
| 3 | Africa, Middle East, India | $11.24 | 10.2% |
| 4 | Asia Pacific | $10.65 | 9.7% |
| 5 | Latin America, Caribbean | $6.66 | 6.0% |

### Device Mix

| Device | Sales (USD) | Share |
|---|---|---|
| iPhone | $72.06 | 65.5% |
| iPad | $31.41 | 28.6% |
| Desktop | $6.64 | 6.0% |

## Pricing Assessment

### Total User Cost

A user who buys the app and Pro Lifetime pays $2.99 + $4.99 = **$7.98 total** (US). This is reasonable for a productivity keyboard utility with lifetime access.

### Price Tier Positioning

The app sits at Apple's ~$2.99 tier for the app purchase and ~$4.99 tier for Pro Lifetime. These are common price points for utility apps:

- $2.99 app price signals "not free, but not expensive" — appropriate for a keyboard that replaces a missing iOS feature.
- $4.99 Pro Lifetime is an accessible upsell — less than 2x the app price, which feels proportional.
- The Finance Pack (est. ~$1.99) is positioned as a low-friction entry point.

### Currency Equivalents

Apple's automatic price adjustment means prices in non-USD currencies roughly match the USD tier after currency conversion and local taxes. The EUR price is €2.99 (app) and €5.99 (Pro), which are the standard Apple tier equivalents.

## Recommendations

### Keep Current Pricing

The current pricing structure is sound. The v1 analysis recommendation to hold pricing until page conversion improves remains correct. Current 0.7% conversion rate means pricing experiments would have very low statistical power.

### Prioritize Before Pricing Changes

1. **Localize all storefront metadata** — this is the highest-leverage change (in progress).
2. **Add iPad screenshots** — captures 28.6% of revenue that currently sees suboptimal assets.
3. **Replace weak screenshots (slides 3-4)** — improve the quality of the conversion funnel.
4. **Test screenshot order via PPO** — find the highest-converting layout.
5. **Only then test pricing** — once page conversion is measurably improved.

### Future Pricing Experiments to Consider

- **Finance Pack price test:** test $0.99 vs $1.99 to see if lower friction increases attach rate.
- **Regional pricing:** consider whether the Pro Lifetime should be priced differently in India, Brazil, or Southeast Asia where purchasing power is lower. Apple's May Adjust Automatically handles currency, but a deliberate lower tier could increase volume.
- **Family Sharing for Pro Lifetime:** enabling this adds perceived value at zero marginal cost. Household value proposition becomes stronger.

### Do Not Change

- Do not introduce a subscription model. The "No subscription" messaging is a competitive differentiator.
- Do not remove the Finance Pack. Even if attach rate is low, it provides a stepping stone in the funnel.
- Do not change pricing simultaneously with metadata changes — isolate variables.
