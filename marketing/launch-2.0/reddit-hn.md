# NumPad 2.0 — Show HN + Reddit Drafts

Status: DRAFT. Facts per `marketing/appstore/description-2.0.md` (canonical) with the
paid-download correction: **$2.99 up front**, IAPs on top, no subscription.
Link everywhere: https://apps.apple.com/us/app/numpad-your-number-keyboard/id1072547160

---

## Show HN

**Title (pick one, HN-plain):**

1. `Show HN: NumPad – an iOS number-pad keyboard that computes as you type`
2. `Show HN: I built the numeric keypad iOS never shipped`

**Body:**

> NumPad is a numeric-keypad keyboard extension for iPhone and iPad. It replaces the
> digit-hunting you do on the stock keyboard with a real 3×4 calculator-style pad,
> available in any app that takes text. I've been building it solo for years; 2.0 shipped
> this week and it's the largest update so far, so I'm showing it here.
>
> The new headline feature: type an arithmetic expression into any text field —
> "84.50*1.18", "250-20%" — and a result chip appears above the keyboard before you
> finish. Tap it to insert the answer. There's also a two-step tax+tip calculator behind
> a long-press on "%", clipboard history behind "0", a unit converter behind "=", and six
> swappable key rows for finance, science symbols, programming (hex/bitwise), date/time
> insertion, unit conversion, and cooking fractions.
>
> How it's built: almost entirely UIKit, programmatic layout, no storyboards in the
> extension. The one SwiftUI surface is the custom-layout editor in the container app,
> hosted as an island inside UIKit. The interesting constraint is Apple's ~50MB memory
> ceiling for keyboard extensions — it shapes everything, from vendored dependencies to
> the fact that Firebase isn't linked into the extension target at all. The math engine
> is one shared module: the "=" key, the live preview chip, and the three Siri App
> Intents ("Calculate with NumPad", "Convert units", "Calculate a tip") all call the same
> code, fully offline, and a Siri calculation lands on the same result tape the keyboard
> shows. No analytics of any kind run in the keyboard process — by design, not by
> settings toggle; the SDK isn't in the binary.
>
> Honest limitations: it's iOS-only, and Apple's enable flow for third-party keyboards is
> still clunky (Settings → General → Keyboard, then a Full Access prompt — Full Access is
> optional and only feeds clipboard history, haptics, and key sounds). iOS blocks custom
> keyboards in secure password fields, so NumPad steps aside there. The live preview is
> an arithmetic parser, not a CAS. The Liquid Glass themes need iOS 26 and fall back to a
> translucent color below it. The "Kiosk" iPad height is a size preset, not a Guided
> Access integration.
>
> Pricing, since HN will ask: $2.99 up front for the full base app (numpad, Math keys, 15
> themes, snippets, clipboard history). Six optional packs at $1.99 each, one-time. Pro
> is $11.99 one-time (every pack, Glass themes, layout editor, iCloud sync, kiosk
> height). No subscription. Family Sharing enabled on everything.
>
> Happy to answer anything about keyboard-extension development — it's a strange corner
> of iOS.

**Show HN norms checklist:** post from personal account, no "we're excited", answer
every top-level comment for the first 3–4 hours, don't argue with pricing complaints —
state the reasoning once and move on.

---

## Reddit

### r/iosapps

- **Rules note:** self-promo is the sub's purpose; developers must disclose they're the
  dev. Check current rules for repost frequency (typically one post per major update).
- **Suggested flair:** `Paid` (or the sub's dev/promo flair if present)
- **Titles:**
  1. `I make NumPad, a real number-pad keyboard for iOS — 2.0 just shipped with live math that computes as you type`
  2. `NumPad 2.0: numeric keypad keyboard with compute-as-you-type, six key packs, no subscription`
- **Body:**

> Dev here — I've built NumPad solo for years and 2.0 shipped this week.
>
> The short version: it's a full numeric keypad that lives in every app as a keyboard.
> New in 2.0: type "84.50*1.18" in any text field and the answer floats up before you hit
> equals. Long-press "%" for tax+tip, "0" for clipboard history, "=" for a unit
> converter. Six swappable key packs (Finance, Symbols & Science, Programmer, Date &
> Time, Units, Cooking). Siri works out of the box: "Calculate a tip with NumPad."
>
> Pricing: $2.99 up front (that's the whole base app — numpad, Math keys, 15 themes,
> snippets, clipboard history). Packs $1.99 each one-time, Pro $11.99 one-time. No
> subscription, Family Sharing on everything.
>
> Privacy, because it's a keyboard: the extension contains zero analytics code. Full
> Access is optional and only used for clipboard history, haptics, and key sounds.
>
> [App Store link] — happy to answer questions or take feature requests here.

### r/apple

- **Rules note:** r/apple does **not** allow standalone self-promo posts — they belong
  in the daily discussion thread or the periodic self-promo megathread. Check the
  sidebar/pinned posts on launch day and post there; a standalone post will be removed.
- **Suggested flair:** none (comment in megathread)
- **Titles (for the megathread comment, first line):**
  1. `NumPad 2.0 — my numeric-keypad keyboard now computes math as you type (App Intents + Liquid Glass)`
  2. `Shipped: a number-pad keyboard that adopts App Intents, Liquid Glass, and stays subscription-free`
- **Body (platform-tech angle, shorter):**

> Solo dev. NumPad is a numeric-keypad keyboard extension; 2.0 shipped this week and it's
> my attempt to adopt the current platform stack properly: three zero-setup App Intents
> (Siri answers "Calculate a tip with NumPad" offline, with the same engine as the
> keyboard's "=" key), real Liquid Glass theme material on iOS 26 with a graceful
> fallback, and iPad-specific UI (overlays dock as a side panel instead of covering your
> document). $2.99 up front, optional one-time IAPs, no subscription, and the keyboard
> extension ships with no analytics SDK at all. [link]

### r/iphone

- **Rules note:** promo posts are restricted — historically limited to designated days/
  flair ("Promotion" flair, check the sub's current policy before posting). If in doubt,
  wait for the promo day.
- **Suggested flair:** `Promotion` (or current equivalent)
- **Titles:**
  1. `Typing numbers on iPhone always annoyed me, so I built a real number-pad keyboard — 2.0 is out`
  2. `My number-pad keyboard for iPhone now does math while you type`
- **Body:** reuse the r/iosapps body, trim the pack list to one line, lead with the
  "123-key round trip" pain instead of the dev intro.

### r/ipad

- **Rules note:** check self-promo policy (generally tolerated for dev posts with
  disclosure; avoid link-only posts).
- **Suggested flair:** `App` / `Discussion`
- **Titles:**
  1. `I built my keyboard app around the iPad this year: side-panel overlays, pointer hover, drag-and-drop, and a kiosk-size height`
  2. `NumPad 2.0 on iPad — the numeric keypad with a converter that docks beside your document`
- **Body:**

> Dev here. NumPad is a numeric-keypad keyboard, and the 2.0 work treated iPad as its own
> platform instead of a stretched phone: on wide iPads the clipboard/snippets/converter
> overlays open as a 360pt side panel so they never cover your work, keys respond to
> pointer hover, and you can drag a clipboard entry straight into the host app. There are
> four keyboard heights — Small, Default, Tall, and a Pro Kiosk size for iPads mounted at
> a counter or front desk. $2.99 up front, one-time IAPs, no subscription. [link]
>
> If you use an iPad for data entry, I'd genuinely like to hear what's missing.

### Niche: r/smallbusiness

- **Rules note:** self-promotion is banned outside the designated promo thread
  ("Promote your business" weekly thread). Post there, or write a genuine discussion
  post and mention the app only if asked. Lead with the workflow, not the product.
- **Suggested flair:** none (weekly promo thread)
- **Titles (promo-thread comment):**
  1. `For anyone entering prices/inventory counts on an iPhone all day`
  2. `Made a tool for the "typing numbers into forms on a phone" problem`
- **Body:**

> If part of your day is punching prices, quantities, or invoice numbers into a phone —
> POS backends, banking apps, inventory counts — the stock iPhone keyboard makes you
> mode-switch for every digit. I build NumPad, a keyboard that's a real 10-key: it also
> computes as you type ("84.50*1.18" shows the answer before you hit equals), keeps
> clipboard history one tap away, and has a tax+tip calculator behind the "%" key. On an
> iPad at a counter, there's a kiosk-size height so it's tappable from arm's length.
> $2.99, one-time IAPs for extras, no subscription. [link]

### Niche: r/Bookkeeping

- **Rules note:** small practitioner sub; no formal promo thread, but blatant ads get
  removed. Disclose you're the dev, frame as "tool for a pain you have," engage in
  comments.
- **Suggested flair:** none / `Software`
- **Titles:**
  1. `Entering figures on your phone between clients — what do you use?` (discussion-first; mention app in body)
  2. `I built a 10-key keyboard for iPhone because phone data entry was killing me`
- **Body:**

> Dev disclosure up front: I make NumPad. If you ever key figures into a phone — bank
> feeds, receipt amounts, a quick reconciliation on the go — the iOS keyboard's number
> row is the bottleneck. NumPad puts a calculator-style keypad in every app, computes
> expressions as you type (handy for quick "amount × rate" checks without leaving the
> field), keeps your recent copied numbers behind a long-press, and inserts today's date
> with one tap from the Date & Time pack. One-time pricing, no subscription. [link] —
> and if there's a key your workflow needs that I don't have, tell me; the Pro tier lets
> you build your own layout, but I also just add good ideas.

### Niche: r/Accounting

- **Rules note:** large sub, **hostile to self-promo** — direct app posts are usually
  removed and mocked. Only viable as an honest comment when someone asks for tools, or
  skip entirely. Recommendation: skip the standalone post; keep the r/Bookkeeping draft
  as the practitioner play.
