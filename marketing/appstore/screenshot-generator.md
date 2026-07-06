# App Store Screenshot Generator — Location & Regen Instructions

## Location

The screenshot generator project lives **outside this repo**, on DevVault (1.5TB volume):

```
/Volumes/DevVault/Projects/numpad-shots-gen
```

It is intentionally kept out of the NumPad repo to avoid committing large raw/intermediate
render assets. Only the final 30 PNGs delivered to App Store Connect are committed here, in:

```
fastlane/screenshots/en-US/
```

## Generator project layout

```
numpad-shots-gen/
├── assets/         # source images/backgrounds used to compose the marketing frames
├── raw-backup/     # backup of raw (unframed) device captures
└── output/         # final composed PNGs, one per App Store device size/slot
```

`output/` contains the 30 files matching the current fastlane set:
- `APP_IPAD_PRO_129_01..06.png`
- `APP_IPAD_PRO_6GEN_129_01..06.png`
- `APP_IPHONE_61_01..06.png`
- `APP_IPHONE_65_01..06.png`
- `APP_IPHONE_67_01..06.png`

## Regenerating screenshots

1. On a machine with the DevVault volume mounted, open the generator project:
   ```bash
   cd /Volumes/DevVault/Projects/numpad-shots-gen
   ```
2. Update source captures in `raw-backup/` and/or composition assets in `assets/` as needed
   (new copy, new pack/theme content, updated 2.0 UI, etc).
3. Run the generation pipeline for the project (see the project's own README/scripts for the
   current entry point — the pipeline renders each device size + slot into `output/`).
4. Verify the regenerated files in `output/`:
   ```bash
   for f in output/*.png; do sips -g pixelWidth -g pixelHeight "$f"; done
   ```
   Expected dimensions (must match exactly, no letterboxing):
   - iPad Pro 12.9": 2048×2732
   - iPad Pro 12.9" (6th gen): 2064×2752
   - iPhone 6.1": 1125×2436
   - iPhone 6.5": 1284×2778
   - iPhone 6.7": 1320×2868
5. Copy the 30 finished PNGs into this repo, overwriting the existing set:
   ```bash
   cp /Volumes/DevVault/Projects/numpad-shots-gen/output/*.png \
      /Users/jamespikover/NumPad/fastlane/screenshots/en-US/
   ```
6. From the NumPad repo, stage and commit **only** the screenshot PNGs:
   ```bash
   git add fastlane/screenshots/en-US/*.png
   git commit -m "chore: refresh App Store screenshots"
   ```

## Notes

- Do not commit the generator project itself into NumPad — it stays on DevVault.
- Keep this note updated if the generator's entry point/script name changes.
