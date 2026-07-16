# Featuring + CPP Pack — refresh (2026-07-12)

Companion to `docs/research/2026-07-12-aso-features-competitive-review.md`. **This does not replace existing
work** — it points at what's already ready and adds only what the new competitive research sharpens.

## What already exists and is strong (verified 2026-07-12 — reuse, don't rewrite)
- **Featuring nomination** → `marketing/launch-2.0/featuring-submission.md` is form-ready (nomination "NumPad 2.0 — Live Math in a keyboard", angles: platform-tech adoption / no-subscription / privacy). Solid as-is; one addition below.
- **CPP plan** → `marketing/aso-sales-audit/custom-product-pages-v2.md` already specs 3 CPPs (`numpad-workflow`, `numpad-finance`, `numpad-ipad`) with screenshot orders, localization priority, and success metrics. Screenshots/localization are done locally; only the promo text + ASC creation remain. Sharpened promo copy below.
- **Screenshot storyboard** → `marketing/appstore/screenshot-storyboard.md` (captions live there — remember Apple indexes caption text since June 2025, so keep keywords in them).

## DONE in this pass
- **Description "FREE" fix (was queued for 2.0.1):** `WHAT YOU GET FOR FREE` → **`WHAT'S INCLUDED`** in `fastlane/metadata/{en-US,en-GB,en-AU,en-CA}/description.txt` and `marketing/appstore/description-2.0.md`. On a **paid** app, "for free" was misleading; "What's Included" pairs correctly with the existing "WHAT PRO ADDS" section.
  - **Follow-up (owner localization pass):** the non-English `fastlane/metadata/*/description.txt` files still carry the *translated* equivalent of "for free" — apply the same reframe when the machine-translation review runs (already an owner-gated item).

---

## Sharpened CPP promotional text (≤170 chars; drop-in replacements for the v2 spec)
Rationale: the v2 promo lines predate the competitive research. These lead with the **unowned Excel/spreadsheet
data-entry gap** and carry the two differentiators the research validated — **no subscription** and **works
without Full Access**. Character counts noted; all under Apple's 170 limit.

**CPP 1 — `numpad-workflow`** (general / search-led)
> Fast numbers for spreadsheets, forms & data entry — a real number pad in every app. No subscription, and it works without Full Access. *(126)*

**CPP 2 — `numpad-finance`** (tax / finance / accounting)
> Tax & tip calculator, currency keys, and a unit converter — built into your number keyboard. One-time purchase, never a subscription. *(131)*

**CPP 3 — `numpad-ipad`** (iPad — directly answers the unresolved "Excel on iPad has no numeric keypad" pain)
> A real number pad for iPad — fast data entry for spreadsheets and forms, right in every app. One-time purchase, no subscription. *(126)*

**Screenshot caption guidance (indexed):** ensure each CPP's first 1–2 captions carry its target keywords, e.g. workflow → "Number Pad for Spreadsheets"; finance → "Tax & Tip in Your Keyboard"; iPad → "A Real Number Pad for iPad". Edit in `screenshot-storyboard.md` if not already present.

---

## Featuring pitch — one addition (accessibility angle)
Apple scores **accessibility** as one of its 7 featuring criteria, and NumPad genuinely qualifies (verified in
code). Add this bullet to `featuring-submission.md` under "Why feature it":

> - **Accessibility:** overlay keys expose VoiceOver labels and custom actions (e.g. the "%" key's "Show tax and tip calculator" action), the keypad scales with Dynamic Type, and Reduce Motion is honored on the live-math chip and onboarding — accessibility depth beyond the category norm.

(Optional freshening: the pitch leads on "Live Math," which is the right *editorial/tech* angle for Apple. Keep it — but if an editor asks for the user story, the one-liner is "the number pad iPhone forgot, now with a calculator built into the keys.")

---

## Owner action checklist (App Store Connect)
1. **Description:** on the next metadata push (fastlane deliver or manual), the "What's Included" fix ships. No action beyond a normal metadata submit.
2. **Featuring:** review `featuring-submission.md` (+ the accessibility bullet above), then submit via ASC → Featuring Nominations. Timing: it's already live-since-July-7, so submit now for the current editorial window; re-nominate at QWERTY GA.
3. **CPPs:** create the 3 CPPs per `custom-product-pages-v2.md`, using the **sharpened promo text above**. Recommended order (from the v2 doc): `numpad-workflow` first, then `numpad-finance`, then `numpad-ipad`. Delete/repurpose the stale "Test" CPP shell first.
4. **Pair with ads:** once created, each CPP URL can back a matching Search Ads ad group and any press/referral link (the review's Tier-A A5/A4 pairing).

## Not changed (deliberately)
- Featuring nomination core copy (already strong; only added the a11y bullet as a suggestion).
- CPP screenshot orders / localization priorities (the v2 spec's choices are sound).
- Pricing language (Pro stays $11.99 one-time; standing decision).
