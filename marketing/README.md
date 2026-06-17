# App Store Marketing Assets

Generated assets for the NumPad App Store listing.

- `marketing/app-store/iphone-6.9/` contains six primary iPhone screenshots at `1320x2868`.
- `marketing/app-store/iphone-6.5/`, `iphone-6.3/`, and `iphone-6.1/` contain scaled alternates for older App Store screenshot slots.
- `marketing/iap/promo-pro-1024.png` and `marketing/iap/promo-finance-1024.png` are 1024px in-app purchase promotional images.

Regenerate the screenshots with:

```bash
python3 marketing/generate_app_store_screenshots.py
```

Regenerate the in-app purchase promo images with:

```bash
python3 marketing/generate_iap_promos.py
```
