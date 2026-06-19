# NumPad — Marketing Video: Storyboard & Production Brief

Date: 2026-06-18 · Status: **DRAFT — awaiting sign-off**

This is the sign-off gate before any rendering. It covers both video deliverables,
proposes **three hook concepts** (pick one), and lists the **three creative decisions**
I need from you (hook, voiceover, music).

---

## 1. What we're making and where it runs

| Cut | Length | Format(s) | Where it's used | Apple screen-recording rule |
|---|---|---|---|---|
| **App Store preview** | 15–30s | Portrait `1080×1920` (iPhone 6.5"+), `886×1920` accepted; iPad `1200×1600`; + poster frame | App Store product page ("tap to play"), staged in ASC Media Manager | **Yes** — must be real device/app screen recording, no heavy live-action |
| **Commercial master** | ~45s (30–60s) | `1080×1920` portrait + `1920×1080` landscape master | Paid social, landing page hero, press kit | No — full advertising license, motion graphics OK |
| **Social cut-down** | 15s | `1080×1920` | Paid social (skippable pre-roll, Stories/Reels) | No |
| **Social cut-down** | 6s | `1080×1920` | Bumper ads (YouTube 6s, etc.) | No |

The commercial master is the creative source; the 15s and 6s are cut from it; the
App Store preview is a screen-recording-only sibling that reuses the same beats but
stays within Apple's rules.

## 2. Emotional arc (the spine of every cut)

**Frustration → Relief → Delight → Desire.** First 3 seconds must hook on the *pain*,
not the product. Viewer thinks "ugh, that's me" before NumPad ever appears.

## 3. Hook options — **pick one** (first 0–3s of every cut)

All three are screen-recording-safe so the chosen hook works in the App Store preview too.

> **Hook A — "Mode-Switch Hell" (recommended).** Tight on a real iOS keyboard inside
> Messages/Mail/a checkout form. A thumb jabs the **"123"** key over and over —
> letters→numbers→letters — typing a phone number, fumbling, backspace, backspace.
> Three apps, same fight, fast cuts on the beat. Pure screen. Instantly universal.
> *Why recommended: most relatable, 100% screen-based (Apple-safe), zero ambiguity about the problem.*

> **Hook B — "The Bill."** Restaurant table, splitting a check. Over-the-shoulder of a
> phone: the default keyboard, tip typed wrong, total redone twice while the card
> machine waits. Higher emotional stakes, a touch more cinematic (for the commercial
> we'd keep it phone-screen-led so it still cuts into the ASP preview).

> **Hook C — "Autocorrect Betrayal."** Macro on the cramped number row; a one-time
> passcode / serial gets mangled by autocorrect into a word, the field turns red
> "Invalid code." Single sharp gag. Great for the 6s bumper.

## 4. Commercial master — shot-by-shot (~45s)

VO lines are written to also work as **on-screen kinetic type** if you choose text-only.
Music cue assumes an upbeat, confident electronic/indie bed (~120–125 BPM) with a
clear "drop" at the turn (≈0:08).

| # | t (s) | On-screen action | Copy / VO | Music / SFX |
|---|---|---|---|---|
| 1 | 0.0–3.0 | **HOOK** (chosen A/B/C). Frustrated number entry, mode-switch flailing, a wrong digit, red error. | VO: *"Typing numbers on iPhone shouldn't be this hard."* / Text: **"Numbers. On iPhone. Ugh."** | Sparse, tense ticks; a single error "buzz" |
| 2 | 3.0–5.0 | Hard cut to black. A single key-tap sound. NumPad wordmark snaps in, then dissolves to a phone with the NumPad keyboard sliding up. | VO: *"So we built the number pad it forgot."* / Text: **"Meet NumPad."** | Beat drops — energy in |
| 3 | 5.0–9.0 | **Relief.** Same Messages/Notes context as the hook, now numbers fly in — fast, confident, no mode switch. Keycaps pulse on each tap. | Text: **"A real numpad. In every app."** | Satisfying tap rhythm locked to beat |
| 4 | 9.0–14.0 | Context montage: a checkout card field, a Notes total, a spreadsheet cell — number entry in each, snappy whip-transitions. | VO: *"Forms, checkouts, spreadsheets — wherever numbers live."* | Whooshes on each transition |
| 5 | 14.0–20.0 | **Wow 1 — Tax/Tip.** Long-press the **%** key; the Tax/Tip panel slides in; tip + total compute live; "$97.20" stamps in. | Text: **"Long-press for tax & tip."** | Rising synth; a "ka-ching" confirm |
| 6 | 20.0–26.0 | **Wow 2 — Clipboard history.** Long-press **0**; clipboard panel slides in; a long order number taps into a field in one move. | Text: **"Your recent numbers, one tap away."** | Click-clack; a clean "snap" |
| 7 | 26.0–32.0 | **Wow 3 — Packs & themes.** Programmer/finance pack rows flip through; themes recolor the keyboard in a quick, satisfying cascade. | VO: *"Packs for finance, code, and math. Themes that fit you."* | Montage builds; pitch rises |
| 8 | 32.0–37.0 | **iPad beat.** Pull back to iPad: the keyboard with the side-panel layout, clipboard docked, drag-and-drop a value into a doc. | Text: **"Built for iPad, too."** | Wide, airy swell |
| 9 | 37.0–41.0 | Rapid recap flashes (4 frames): numbers, tax/tip, clipboard, theme. "No subscription" badge stamps. | Text: **"No subscription. Yours forever."** | Final build |
| 10 | 41.0–45.0 | **Brand payoff.** Clean background, app icon lands, wordmark + tagline. Subtle CTA. | Text: **"NumPad. Your number pad."** + *Download on the App Store* | Resolve to a single warm chord; last key-tap |

## 5. Derivative cuts

- **App Store preview (30s):** beats 1, 3, 5, 6, 8, 10 — all from real screen recordings; no live-action; trims the montage and the brand-only frames. Poster frame = beat 3 (numbers flying in) or beat 5 (tax/tip), whichever you prefer.
- **15s social:** hook (2s) → relief (3s) → tax/tip (4s) → clipboard (3s) → brand (3s).
- **6s bumper:** Hook C gag (2s) → one wow (tax/tip, 2s) → brand lockup (2s).

## 6. How I'll produce it (in this environment)

- **Editor:** `ffmpeg` (available in-sandbox) drives the assembly — transitions (`xfade`),
  motion (`zoompan`), titles/kinetic type, audio mixing/ducking, and per-format export.
- **App footage:** the existing `marketing/video/v1–v6.mov` clips are **real device captures**
  and are the screen-recording source for the App Store preview. They're short, silent,
  and low/irregular-fps, so I'll motion-stabilize/retime them and, where a beat needs it,
  generate clean UI animation from the same pixel-accurate assets used for the new iPad
  screenshots (keyboard slide-up, panel slide-in, tap pulses).
- **Motion graphics / titles:** generated frames (device frames, kinetic type, brand lockup).
- **Sound:** tasteful key-tap / confirm SFX designed in-sandbox. **Music:** see decision below.

### One honest constraint on the App Store preview
Apple wants the preview captured from a real device. The existing v1–v6 captures qualify,
but they're low quality. The on-store preview will look best if you (or I, driving an iPad/iOS
Simulator on your Mac) record **fresh, clean** captures at 1080×1920/60fps. Options when you
sign off: **(a)** I build the preview from the existing real captures now (good, not pristine),
**(b)** you record fresh captures from a list of shots I provide, or **(c)** I drive a Simulator
on your Mac to capture them. The **commercial master + cut-downs** I can produce to a high bar
regardless, since Apple's restriction doesn't apply off-store.

## 7. Decisions I need from you (the sign-off)

1. **Hook:** A (recommended), B, or C — or mix (e.g., A for ASP, B opens the commercial).
2. **Voice:** Voiceover + on-screen text, **on-screen text only** (recommended for cost/localization — type localizes cleanly across the 50 store locales; VO would need 50 reads), or VO only.
3. **Music:** Licensed track (budget?) vs. **royalty-free** (recommended). If royalty-free, I can assemble an original, license-safe bed + SFX in-sandbox, or you drop in a chosen track.
4. **App Store preview capture path:** (a) existing real captures now, (b) you record fresh, or (c) I drive your Simulator.

## 8. Asset deliverables (on sign-off)

- `app-store-preview-iphone-65.mp4` (+ `poster-iphone.png`) — staged in ASC Media Manager, **not submitted**
- `app-store-preview-ipad-129.mp4` (+ `poster-ipad.png`)
- `commercial-master-portrait-45s.mp4` and `commercial-master-landscape-45s.mp4`
- `social-15s.mp4`, `social-6s.mp4`
- `marketing/video/README.md` — asset map (which cut goes where) + regeneration commands
