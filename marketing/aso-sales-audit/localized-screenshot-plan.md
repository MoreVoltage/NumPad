# Localized Screenshot Plan

Goal: adapt the existing six screenshot concepts to the best-fit languages and territories without changing the underlying product story.

## Current Screenshot Story

The current English master screenshot set already covers the right value props:

1. Numbers without slowdowns
2. Faster forms
3. Tax and tip
4. Paste recent numbers
5. Pro packs for work
6. Your numpad, your style

## Priority Locale Groups

| Priority | Locale Group | Why It Matters | Screenshot Approach |
|---|---|---|---|
| 1 | English master | Largest revenue cluster and search-led acquisition | Keep the current six-screen story as the control set. |
| 1 | Spanish (`es-ES`) | Efficient reuse across Spain and many Latin markets | Localize the six headlines and keep the same ordering. |
| 1 | Simplified Chinese (`zh-Hans`) | Strong APAC fit and high-intent utility keywords | Use concise, benefit-first translations and preserve the same six beats. |
| 1 | Traditional Chinese (`zh-Hant`) | Separate storefront expectations from Simplified Chinese | Mirror the English story with native wording. |
| 1 | Hebrew (`he`) | Already localized and strong fit for numeric workflows | Keep benefit-led copy and avoid English-heavy mixed text. |
| 2 | Portuguese (`pt-PT`) | Existing metadata coverage, lower current priority | Reuse English visual layout with localized captions. |
| 2 | Italian (`it`) | Existing metadata coverage and easy expansion from English master | Treat as a maintenance locale unless traffic grows. |
| 3 | Long-tail locales | Existing repo coverage, but lower revenue priority | Do not spend custom screenshot budget until the top markets move. |

## Recommended Localization Rules

- Keep the first screenshot about speed and the second about forms. Those are the clearest acquisition hooks.
- Keep tax, tip, clipboard, and pro packs in the middle of the sequence so they act as differentiators instead of the opening claim.
- Keep the final screenshot about customization and style so the app feels personal, not just utility-only.
- Use one translated noun phrase per headline and avoid sentence-length copy.
- Use native script for the hero headline when the locale supports it.
- Do not build new locale-specific asset sets for markets without corresponding metadata coverage unless traffic justifies the spend.

## Suggested Copy Direction

These are planning translations, not live ASC changes.

| Theme | English Master | Spanish Direction | Chinese Direction | Hebrew Direction |
|---|---|---|---|---|
| Speed | Numbers without slowdowns | Numeros sin lentitud | 数字输入更快更顺 | בלי האטות בהקלדת מספרים |
| Forms | Faster forms | Formularios mas rapidos | 表单输入更快 | טפסים מהר יותר |
| Tax/Tip | Tax and tip | Impuestos y propina | 税费和小费 | מס וטיפ |
| Clipboard | Paste recent numbers | Pega numeros recientes | 粘贴最近使用的数字 | הדבקת מספרים אחרונים |
| Pro | Pro packs for work | Packs Pro para el trabajo | 专业键盘包 | חבילות פרו לעבודה |
| Style | Your numpad, your style | Tu teclado numerico, tu estilo | 你的数字键盘, 你的风格 | המקשים שלך, הסגנון שלך |

## Production Notes

- Reuse the existing screenshot composition and only swap localized headline text where possible.
- Export the localized sets at the same sizes already present in `marketing/app-store/`.
- Keep the English masters as the fallback for any locale that is not yet proven.
