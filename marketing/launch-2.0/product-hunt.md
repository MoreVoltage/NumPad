# NumPad 2.0 — Product Hunt Launch Kit

Status: DRAFT. All features/pricing per `marketing/appstore/description-2.0.md` (canonical).
App Store link: https://apps.apple.com/us/app/numpad-your-number-keyboard/id1072547160

---

## Listing

**App name line:** NumPad — Your Number Keyboard

**Tagline (≤60 chars, pick one):**

1. `The number pad your iPhone forgot` (33 chars)
2. `Type a number, get an answer` (28 chars)
3. `A real numeric keypad, in every app` (35 chars)

**Short description (≤260 chars — this one is 229):**

> A full numeric keypad in every iOS app — now it computes as you type. Six swappable key
> packs, tax/tip and unit converters, clipboard history, Siri support. $2.99 up front,
> $1.99 packs, $11.99 Pro lifetime. No subscription, ever.

**Topic tags:** iOS, iPad, Productivity, Tech, User Experience

**Links:** App Store URL above · https://morevoltage.com/ · james@morevoltage.com

---

## Maker's first comment (founder voice, ~300 words)

> Hi Product Hunt — I build NumPad alone, under the name More Voltage.
>
> The origin story is dumb in the way true things are: I kept typing prices into a
> spreadsheet on my phone, and every single number meant a round trip through the "123"
> key. Apple gives you a dial pad for phone numbers and a decimal pad for a few blessed
> fields — but the moment an app takes free text, you're hunting digits above QWERTY. So I
> built the keypad iOS forgot: a real 10-key, available in every app, as a keyboard.
>
> 2.0 shipped this week — the biggest update since launch. The headline is live math:
> type "84.50*1.18"
> into any text field and the answer appears in a floating chip before you reach for "=".
> The same engine now answers Siri — "Calculate a tip with NumPad" works the moment the
> app installs, no setup, fully offline. There are six swappable key packs (Finance,
> Symbols & Science, Programmer, Date & Time, Units & Conversion, Cooking & Baking),
> Liquid Glass themes on iOS 26, and a rebuilt drag-and-drop editor so Pro users can
> build their own layout around the keypad.
>
> Money, plainly: NumPad is $2.99 up front, and that buys the whole base app forever —
> the numpad, Math keys, 15 themes, snippets, and clipboard history. Packs are $1.99
> each, one time. Pro is $11.99, one time: every pack, the Glass themes, the custom
> keyboard editor, iCloud sync, and a kiosk-size height for counter-mounted iPads. No
> subscription anywhere. Family Sharing is on for every purchase.
>
> One technical detail I'm fond of: the whole keyboard runs inside Apple's ~50MB memory
> ceiling for keyboard extensions, and the extension links no analytics SDK at all. It
> can't phone home — there's nothing in the binary to phone home with.
>
> Ask me anything. I wrote every line.

---

## Gallery plan (ordered)

Sources: composited slides live in `marketing/app-store/<size>[-<locale>]/` (e.g.
`marketing/app-store/iphone-6.5/`), raw clips in `marketing/video/` (`v1`–`v6.mov`),
new 2.0 captures per `marketing/appstore/screenshot-storyboard.md` (shots 1–10).

| # | Asset | What it shows / caption |
|---|-------|--------------------------|
| 1 | **GIF (new capture — storyboard shot 1):** `gif-live-math.gif` | Live math preview computing `84.50*1.18` as you type; the result chip appears, tap inserts `99.71`. Caption: "Finish typing, the answer's already there." |
| 2 | `iphone-6.5/01-numbers-without-slowdowns-1284x2778.png` | Hero: the full numpad inside Messages. Caption: "A real 10-key, in every app that takes text." |
| 3 | **GIF from `video/v4-taxtip.mov`:** long-press "%" → tax + tip panel computes live | Caption: "Long-press % for tax and tip. Tip is figured on the pre-tax amount, like it should be." |
| 4 | `iphone-6.5/05-pro-packs-for-work-1284x2778.png` | The six packs. Caption: "Finance, Symbols & Science, Programmer, Date & Time, Units, Cooking — $1.99 each, once." |
| 5 | **GIF from `video/v3-clipboard.mov`:** long-press "0" → clipboard history, tap to paste | Caption: "Your recent numbers, one tap away. Stored on-device." |
| 6 | **GIF (new capture — storyboard shot 4):** custom keyboard editor, chip mid-drag into Column 1, live preview updating | Caption: "Pro: build your own keyboard around the keypad. Drag keys in, watch it preview live." |
| 7 | Screenshot from `ipad-13/` set (side-panel overlay shot) | iPad: overlays open as a 360pt side panel instead of covering your work. Caption: "On iPad, the converter docks beside your document — and there's a Kiosk-size height for counters." |
| 8 | **GIF from `video/v5-themes.mov`** or `iphone-6.5/06-your-numpad-your-style-1284x2778.png` | Theme cascade ending on Liquid Glass. Caption: "17 themes. Two of them are real iOS 26 Liquid Glass." |

Video slot (top of gallery): trim `marketing/video/out/_master_v.mp4` to ~30s per the
commercial storyboard's beats 1, 3, 5, 6, 8, 10.

---

## Launch-day checklist

- [ ] Schedule launch for 12:01 AM PT (PH day boundary); confirm listing draft the day before
- [ ] First comment (above) pasted within 5 minutes of going live
- [ ] Gallery uploaded in the order above; verify GIFs autoplay under 3MB each
- [ ] App Store link resolves to the 2.0 listing (promotional text updated in ASC)
- [ ] X launch thread post 1 goes out linking the PH page (see `social-calendar.md`)
- [ ] LinkedIn founder post live by 9 AM PT
- [ ] Reply to every comment same-day; use snippets below for the predictable ones
- [ ] Do NOT ask for upvotes anywhere public (PH delists for it); "we're live today" is fine
- [ ] Log conversion: PH-day downloads vs. baseline (App Store Connect → Metrics)
- [ ] End of day: thank-you comment with anything learned; note top questions for FAQ

---

## Prewritten reply snippets

**"Why paid?"**
> $2.99 is the whole base app, forever — the numpad, Math keys, 15 themes, snippets,
> clipboard history. No subscription, no ads, no analytics in the keyboard, no trial
> clock. The specialty packs are $1.99 once and Pro is $11.99 once. I'm one person;
> up-front pricing is how this stays maintained without renting itself to you.

**"Privacy — it's a keyboard?!"**
> Fair reflex. The keyboard extension links zero analytics SDKs — not "we anonymize,"
> there is literally no analytics code in that binary. Full Access is optional and used
> only for clipboard history, haptics, and key-click sounds, all on-device. And iOS
> itself blocks third-party keyboards in secure password fields, so NumPad never even
> sees those.

**"Android version?"**
> No, and honestly not planned. I'm a solo developer and NumPad is deeply iOS-native —
> UIKit, App Intents, Liquid Glass. A port would be a second full-time product. If that
> changes I'll say so, but I'd rather be plain about it than string you along.

**"Why no subscription?"**
> Because a number pad shouldn't rent itself to you. Packs and Pro are non-consumable
> one-time purchases, Family Sharing enabled — buy once, share with up to five family
> members. The trade-off is honest: big updates like 2.0 have to earn new customers
> instead of billing old ones. I'm fine with that.

**"How is this different from the built-in keyboard's number row?"**
> The built-in row gives you digits in a single cramped line, and only after a mode
> switch in most apps. NumPad is a full 3×4 keypad — calculator layout, big targets —
> plus things a number row can't do: it computes expressions as you type, long-press "%"
> is a tax/tip calculator, "0" holds clipboard history, "=" opens a unit converter, and
> the top row swaps for finance/programmer/date/unit/cooking keys. Different tool, same
> slot.
