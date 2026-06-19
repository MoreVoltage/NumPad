# App Store Marketing Assets

Generated assets for the NumPad App Store listing.

- `marketing/app-store/iphone-6.9/` contains six primary iPhone screenshots at `1320x2868`.
- `marketing/app-store/iphone-6.5/`, `iphone-6.3/`, and `iphone-6.1/` contain scaled alternates for older App Store screenshot slots.
- `marketing/app-store/ipad-13/` and `ipad-12.9/` contain six iPad screenshots at `2064x2752` and `2048x2732`.
- `marketing/iap/promo-pro-1024.png` and `marketing/iap/promo-finance-1024.png` are 1024px in-app purchase promotional images.

Regenerate the screenshots with:

```bash
python3 marketing/generate_app_store_screenshots.py                 # en only (iPhone + iPad)
python3 marketing/generate_app_store_screenshots.py --all-locales   # all 50 locales
python3 marketing/generate_app_store_screenshots.py --all-locales --ipad-only   # iPad slides only (fast refresh)
```

## iPad screenshots (genuine iPad UI)

iPhone raws are real Simulator captures. iPad raws are **rendered** from the app's
actual iPad layout — the NumPad keyboard with the iPad-specific 360pt trailing
side-panel (clipboard / tax-tip / snippets), correct theme colours, key glyphs and
pack rows — so the iPad screenshots show real iPad UI rather than a scaled iPhone.

- `marketing/raw/ipad/*.png` — the six locale-independent iPad raws (`2048x2732`).
- The iPad device frame is generated to `marketing/assets/ipad-mockup.png` on demand.
- `render_slide_ipad()` composites the raw into the iPad frame with an iPad-appropriate
  layout (centred portrait device, headline above, footer below).

Regenerate the iPad raws (after any keyboard UI change) with:

```bash
python3 marketing/generate_ipad_raws.py            # writes marketing/raw/ipad/*.png
python3 marketing/generate_ipad_raws.py --sheet     # + a contact sheet for review
```

Then regenerate the composed slides (`--ipad-only` is enough if only iPad changed).

Regenerate the in-app purchase promo images with:

```bash
python3 marketing/generate_iap_promos.py
```
