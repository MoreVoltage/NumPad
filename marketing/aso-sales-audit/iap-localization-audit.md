# IAP Localization Audit

Scope: `numpad.pro.lifetime` and `numpad.pack.finance`.

## Coverage

- Both IAPs have 39 localized folders each, for a total of 78 localized IAP entries.
- Coverage roughly mirrors the app metadata localization set.
- The repo already has translated names and descriptions for both products in the current supported locales.

## What the Current Copy Is Doing Well

- The lifetime purchase is consistently framed as a one-time unlock.
- The finance pack is consistently framed as a finance-symbol unlock.
- The copy is short enough to fit App Store Connect UI constraints.
- The localized sets are already broad enough to support the main territories the app is seeing in sales.

## Sample Current Copy

| Locale | Product | Name | Description |
|---|---|---|---|
| es-ES | Lifetime | Acceso de por vida a packs | Todos los packs y temas actuales y futuros. |
| es-ES | Finance | Pack Finanzas | Desbloquea símbolos financieros. |
| he | Lifetime | כל החבילות לכל החיים | כל החבילות והערכות הנוכחיות והעתידיות. |
| he | Finance | חבילת פיננסים | פתחו סמלי מטבע ופיננסים. |
| zh-Hans | Lifetime | 所有包终身访问 | 当前和未来的所有键盘包与主题。 |
| zh-Hans | Finance | 金融包 | 解锁货币和金融符号。 |

## Audit Findings

1. The lifetime product is positioned correctly, but some locales could be more explicit about future packs and premium themes.
2. The finance pack description is clear, but it could do more work by naming the actual use cases: spreadsheets, forms, banking, tax, and currency entry.
3. The localization set looks complete enough to support testing, so the main issue is message quality rather than missing translations.

## Recommended Canonical Copy

### `numpad.pro.lifetime`

- Name: Numpad Pro Lifetime
- Description: Unlock all current and future packs and premium themes. No subscription.

### `numpad.pack.finance`

- Name: Finance Pack
- Description: Unlock currency and finance symbols for spreadsheets, forms, banking, and tax entry.

## Locale Guidance

- Keep the lifetime description concept identical across locales even if the wording changes.
- Keep the finance pack description benefit-led, not feature-led.
- Avoid introducing extra marketing language that makes the product sound larger than it is.
- Keep native-script clarity first, then compress for UI length.

## Recommendation

No live ASC IAP changes yet. Tighten the canonical copy first, then use it as the reference for any future localization pass.
