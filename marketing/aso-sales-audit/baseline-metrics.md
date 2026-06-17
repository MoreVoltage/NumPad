# NumPad ASO Baseline Metrics

Date captured: 2026-06-16
ASC version reviewed: 1.7.2
Metric windows: last 30 days, last 90 days

## Current ASC State

- App metadata localizations: 39 locale directories in `fastlane/metadata`.
- IAP localizations: 78 locale directories in `fastlane/iap_metadata`.
- Default iPhone screenshots: six English master screenshots are already generated under `marketing/app-store/iphone-6.1`, `iphone-6.3`, `iphone-6.5`, and `iphone-6.9`.
- IAP promo images: `marketing/iap/promo-pro-1024.png` and `marketing/iap/promo-finance-1024.png`.
- App Analytics d90 is available.
- App Analytics d30 is currently unavailable in the logged-in ASC session for this app.

## Acquisition Baseline

| Window | Impressions | Product Page Views | Conversion Rate | First-Time Downloads | Total Downloads | Notes |
|---|---:|---:|---:|---:|---:|---|
| Last 30 days | n/a | n/a | n/a | n/a | n/a | App Analytics d30 returned "This app is currently unavailable for Analytics." Use Trends sales as the fallback proxy. |
| Last 90 days | 65K | 3.32K | 0.7% | 180 | 338 | Total downloads is derived from 180 first-time downloads + 158 redownloads. |

## Acquisition Source Mix

App Store Connect Product Pages, 90-day daily average:

| Source Type | Product Page Views (Unique Devices) / Day |
|---|---:|
| App Store Search | 14 |
| App Store Browse | 6 |
| App Referrer | 2 |
| Web Referrer | 2 |
| Institutional Purchase | n/a |
| Unavailable | n/a |

## Monetization Baseline

| Window | IAP Proceeds | Paying Users | Sales | Download-to-Paid | Proceeds / Paying User | Proceeds / Download | Notes |
|---|---:|---:|---:|---:|---:|---:|---|
| Last 30 days | n/a | n/a | $110 sales proxy | n/a | n/a | n/a | Trends sales page is available, but App Analytics d30 is blocked for this app. |
| Last 90 days | $337 | 2 daily average | 5 in-app purchases | n/a | $67.40 | $1.87 | Proceeds per download uses 90-day proceeds divided by 180 first-time downloads. |

## 30-Day Territory Sales Proxy

Source: App Store Connect Trends, 2026-05-16 to 2026-06-15, Sales view.

| Rank | Territory | Sales (USD) | Share of Sales | Notes |
|---:|---|---:|---:|---|
| 1 | USA and Canada | $46.79 | 42.5% | Largest revenue cluster and the primary English optimization target. |
| 2 | Europe | $34.77 | 31.6% | Strong secondary market; good candidate for localized screenshots and keyword refinement. |
| 3 | Africa, the Middle East, and India | $11.24 | 10.2% | Good fit for multilingual localization already present in repo. |
| 4 | Asia Pacific | $10.65 | 9.7% | Strong enough to justify Simplified/Traditional Chinese plus other high-fit locales. |
| 5 | Latin America and the Caribbean | $6.66 | 6.0% | Lower revenue today, but Spanish reuse makes it efficient to support. |

## Top Territories By Revenue

| Rank | Territory | Sales (USD) | Notes |
|---:|---|---:|---|
| 1 | USA and Canada | $46.79 | Core market. |
| 2 | Europe | $34.77 | Best secondary market. |
| 3 | Africa, the Middle East, and India | $11.24 | Strong localization upside. |
| 4 | Asia Pacific | $10.65 | Localization upside, especially Chinese. |
| 5 | Latin America and the Caribbean | $6.66 | Efficient Spanish coverage. |

## Device Mix

| Device | Sales (USD) | Share | Notes |
|---|---:|---:|---|
| iPhone | $72.06 | 65.5% | Primary optimization surface for screenshots and CPPs. |
| iPad | $31.41 | 28.6% | Secondary surface; keep parity with iPhone messaging. |
| Desktop | $6.64 | 6.0% | Low share, but still present in ASC. |

## Immediate Interpretation

- Strongest acquisition market: USA and Canada, with search as the dominant product page source.
- Strongest monetization markets: USA and Canada, then Europe.
- High-impression, low-conversion opportunity: overall App Analytics conversion remains at 0.7% over 90 days.
- High-download, low-paid-conversion opportunity: paying users are sparse relative to acquisition volume, so the conversion funnel deserves the first optimization pass.
- Data gaps: 30-day App Analytics is unavailable for this app in the current session, so Trends sales is the only live 30-day proxy captured here.
