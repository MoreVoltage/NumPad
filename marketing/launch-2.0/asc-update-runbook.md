# ASC Launch-Updates Runbook — NumPad 2.0 publicity

Everything here is staged and dry-run-safe. **The only thing needed from the owner is the
issuer ID** (and, for the In-App Event, two clicks in ASC at the end).

## What's prepared

`marketing/launch-2.0/asc_launch_updates.py` — three stages, dry-run by default, idempotent:

| Stage | What it does | Review needed? |
|---|---|---|
| `promo` | Sets fresh Promotional Text on the LIVE 2.0 version (en-US/GB/CA/AU). Promotional text changes go live without App Review and without a new version. | No |
| `event` | Creates a DRAFT In-App Event "NumPad 2.0 Launch" (MAJOR_UPDATE badge, starts +4 days, runs 14 days, en-US card copy). In-App Events show on the product page, in search results, and are Today-tab eligible — free visibility most utility apps never claim. | Yes — but only when YOU submit it |
| `media` | Attaches the 1080×1920 event card (`marketing/video/out/poster-iphone.png`) to the draft event. | — |

The new promotional text (168 chars):
> NumPad 2.0 is here: math that computes as you type, Siri Shortcuts, Liquid Glass themes, a build-your-own keyboard, and iPad kiosk mode. No subscription.

Event card copy: name "NumPad 2.0: Live Math" · short "Math computes as you type - plus Siri & packs" · long "Type 84.50*1.18 and the answer floats above your cursor. New packs, Siri Shortcuts, Liquid Glass themes."

## Your part (~3 minutes)

```bash
cd /Users/jamespikover/NumPad
export ASC_KEY_ID=5TKV4B55P8
export ASC_API_KEY_PATH=~/.private_keys/AuthKey_5TKV4B55P8.p8
export ASC_ISSUER_ID=<paste issuer ID>          # ASC > Users and Access > Integrations

python3 marketing/launch-2.0/asc_launch_updates.py                    # dry-run everything, eyeball it
python3 marketing/launch-2.0/asc_launch_updates.py --stage promo --apply
python3 marketing/launch-2.0/asc_launch_updates.py --stage event --apply
python3 marketing/launch-2.0/asc_launch_updates.py --stage media --apply
```

Then in ASC: **NumPad → In-App Events → "NumPad 2.0 Launch" → review the draft → Submit.**
(Events need ~24h review lead; the script schedules the start +4 days out, so submitting
within 3 days keeps the schedule. `--start-days N` adjusts.)

Alternatively: paste the issuer ID into this chat and I'll run all of it, pausing before the
one outward-facing step (event submission stays yours either way — it's an ASC UI button).

## Queued for the NEXT version (2.0.1+) — cannot change on a live version

- **Keywords**: apply the en master cluster from `marketing/aso-sales-audit/keyword-update-plan.md`
  (`numpad,number pad,number keyboard,numeric keypad,calculator keyboard,spreadsheet keyboard,forms keyboard,clipboard history,tax tip,finance keyboard,programmer keyboard,pin,otp`), then es-ES, zh-Hans, zh-Hant, he, ar-SA per the same doc.
- **Description fix**: the live description's "WHAT YOU GET FOR FREE" section header reads as
  free-to-download, but the app is a $2.99 paid download — reword to "INCLUDED WITH THE APP"
  (caught during copy-pack fact-checking, see `marketing/launch-2.0/` copy files which already
  use the corrected framing).
