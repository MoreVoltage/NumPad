# GROK_RESULT — 2.1.0 paywall language + StoreKit wire

**Branch:** `james/rel-2.1.0-paywall-sub`
**Base:** live 2.0.3 `949716e8`
**Version:** 2.1.0 (13)
**Scope:** storefront paywall language flip + StoreKit 2 subscription product IDs. No QWERTY. No ASC create. No submit.

## Changes
- Drop hero reassurance “One-time purchase. No subscription, ever.” → “Pro unlocks every pack and theme. Subscribe, or buy once.”
- Hero CTAs: annual primary / monthly secondary / lifetime tertiary (fallback lifetime primary if sub products unloaded)
- Product IDs: `numpad.pro.sub.monthly`, `numpad.pro.sub.annual` in ProductCatalog + Products.storekit subscription group
- Entitlement: `isProEntitled` = lifetime OR early bird OR `isProSubscriptionActive` OR grandfathered
- Features & Guide Pro footer scrubbed
- UITests assert new reassurance + annual/lifetime CTA labels
- en-US What’s New draft for 2.1.0

## Out of scope
- ASC subscription SKU create (waits James prices + Jessie elevation)
- Search Ads (Shelf)
- Submit / TestFlight / App Store
- QWERTY / feat/2.1 latency worktrees
