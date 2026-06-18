# Raw Screenshot Replacements Needed

## Current Problems

Slides 3 and 4 show NumPad's own settings screen as the "host app" behind the keyboard. This looks self-referential and breaks the illusion that NumPad works naturally in any app.

## Required Replacement Screenshots

All raw screenshots must be 1320x2868 RGBA PNGs taken on iPhone 15 Pro Max (or equivalent 6.9" Simulator).

### 03-taxtip.png (replace)

Capture NumPad's keyboard active in **Apple Notes** or **Safari** with a form showing dollar amounts/totals. The TAX/TIP overlay should be visible (long-press the % key). The host app behind the keyboard should be clearly a neutral Apple app, not NumPad's settings.

Suggested context: Apple Notes with a few lines like:
```
Dinner total: $80.00
Tax (8.5%):
Tip (20%):
```
Then show NumPad keyboard with the TAX/TIP popup open.

### 04-clipboard.png (replace)

Capture NumPad's keyboard active in **Apple Notes** or **a form/spreadsheet** showing the clipboard history popup. The host app should be clearly a neutral app.

Suggested context: Apple Notes or Safari with a form, showing NumPad keyboard with the Clipboard History sheet open (containing sample numbers like "1,249.99", "555-867-5309").

## How to Capture

1. Open Simulator with iPhone 15 Pro Max (iOS 17+)
2. Build and install NumPad
3. Open Notes (or Safari to a form page)
4. Switch to NumPad keyboard
5. Trigger the relevant overlay (long-press % for TAX/TIP, tap clipboard for history)
6. Take simulator screenshot (Cmd+S in Simulator)
7. The screenshot will be 1320x2868 at 3x scale

## After Capturing

Run `python3 marketing/generate_app_store_screenshots.py` to regenerate all sizes including iPad.
