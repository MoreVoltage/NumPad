# Full-Keyboard Competitive Landscape (2024–2026)

Date: 2026-07-05. Research-only, web sources — no source changes, not committed.

**Why this doc exists:** the 2.0 design docs already flag a **full-QWERTY mode** as "a
deliberate later build" (`2026-06-24-2.0-ux-overhaul-design.md`) sitting on top of the
single-canvas/`SpringboardLayout` foundation shipped in 2.0. Before scoping that build, this
surveys the third-party iOS keyboard market: who's in it, why users churn off it, and whether
"numbers/data-entry as a first-class citizen" is a real gap or wishful thinking.

---

## TL;DR — one-liner per competitor

- **Gboard (Google)** — free, ~4.0–4.1★ on ~59K+ iOS ratings; wins on multilingual switching and
  swipe-typing polish; loses on iOS-specific rough edges (landscape layout, cursor/scroll tracking,
  voice-typing requiring the host app) and is the default "why bother switching" benchmark.
- **SwiftKey (Microsoft)** — free with optional IAP; strong ~4.6★ on ~121K iOS ratings; best-in-class
  prediction/learning and 90+ language support, but recent complaints cluster on AI-driven
  autocorrect regressions, forced Bing integration, and shrinking on-screen space from added chrome.
- **Grammarly (Keyboard & Notes)** — subscription, ~$12/mo (or $30 monthly / $20/mo quarterly
  tiers); 4.4–4.6★ on 89K–181K ratings; owns "writing quality" positioning, not typing speed;
  complaints are about price-after-trial and latency from real-time grammar checking, not privacy.
- **Fleksy** — cautionary tale: 4.5★/20M+ users at its peak, **pulled the consumer app from both
  app stores by late 2024** and pivoted entirely to a B2B keyboard SDK (healthcare, productivity
  integrators) — proof that "fast + private" alone isn't a durable consumer business once Gboard/
  SwiftKey commoditized swipe-typing and on-device prediction.
- **Typewise** — freemium, $1.99/mo or $9.49/yr or $25 lifetime; 3.8★ on a small base (839 ratings);
  the clearest **privacy-first positioning already in market** ("does NOT require Full Access,"
  "no typing data transmitted to the cloud") wrapped around a hexagonal-layout error-reduction
  gimmick; reviews split between "can't live without it" and "QWERTY is king," i.e. the layout
  bet, not the privacy claim, is what's contested.
- **"Unni" / others** — no iOS keyboard product by that name was found (only near-misses like "Uni
  Keyboard" / "UniChar," which are Unicode-symbol pickers, not general typing keyboards). The
  relevant "others" bucket is actually a cluster of **numeric-only addon keyboards** — NumPad:
  Your Number Keyboard ($2.99+IAP, 4.2★/230 ratings), Number Pad – Smart Keyboard ($3.99, 4.3★/7
  ratings), Calcvier, Calku, Numberie — plus AI-writing entrants like CleverType. None of these
  is a full letters+numbers keyboard; see the gap analysis below.

---

## Detailed profiles

### Gboard
- **Pricing:** free, no IAP found.
- **Rating trend:** ~4.0–4.1★, 59,000+ iOS ratings (JustUseApp's independent review-mining pass
  over 57,771 reviews scored it 66.5/100 on "safety"/trust signals, not a star rating — read that
  as "generally trusted, not glowing").
- **Praise:** most-accurate swipe typing and predictive text; best multilingual switching of the
  majors (language bar + quick switch reduces wrong-language autocorrect); free.
- **Complaints:** landscape orientation gets distorted; small touch-target on space bar causing
  mis-taps; voice typing routes through the Gboard *app* rather than working inline; text field
  doesn't auto-scroll to keep the cursor visible above the keyboard; limited customization vs.
  user requests.
- **Read on numbers:** no calculator, no unit conversion, no numeric-first layout. Apple's own
  Calculator app (not Gboard) picked up unit/currency conversion in iOS 18 — Google hasn't gone
  there on iOS.

### SwiftKey (Microsoft)
- **Pricing:** free with optional theme IAP; some comparison roundups cite a $1.99/mo "Premium"
  tier for AI features.
- **Rating:** ~4.6★, 121,000 iOS ratings — the strongest rating-to-volume ratio of the majors.
- **Praise:** learning/adaptation ("keeps track of your word choices"); best pure typing efficiency
  in head-to-head reviews; 90+ language support cited as unmatched for multilingual users.
- **Complaints:** swipe-typing accuracy regressions ("misses a lot of words"); users explicitly
  naming **Full Access as a privacy concern** in reviews; unwanted forced Bing search integration;
  limited to two active languages at once without more granular control; UI/toolbar redesigns and
  shrinking usable screen space drawing negative feedback. Microsoft's dev-response pattern leans
  on "settings adjustments" and privacy clarifications rather than shipping fixes — a support-load
  signal, not just a UX one.
- **Read on numbers:** no calculator/conversion; number row is the standard shifted-symbol row.

### Grammarly (AI Keyboard & Notes)
- **Pricing:** subscription-first — $12/mo billed annually is the anchor tier; $30/mo and $20/mo
  (quarterly) tiers also cited; 7-day free trial before charge.
- **Rating:** 4.4–4.6★ across 89K–181K ratings depending on source/date — strong for a paid product.
- **Praise:** integrates across WhatsApp/Gmail/social; genuinely differentiated on writing-quality
  checking (grammar/tone) rather than raw typing speed.
- **Complaints:** billing-surprise pattern (steep price after promo ends, "~$144/year" framing in
  reviews); noisy suggestions in specialized/technical writing contexts; higher input latency from
  real-time analysis (only keyboard in the roundups that misses the sub-30ms target the others hit).
- **Read on numbers:** irrelevant to its positioning — it competes on prose quality, not data entry.
  Zero overlap with a numbers-first pitch, which is useful: it proves a **non-typing-speed,
  non-privacy** positioning (workflow specialization) can still command premium pricing.

### Fleksy
- **Pricing (historical):** started paid ($1.99), went free-with-IAP, then the consumer app was
  **removed from both the App Store and Google Play by late 2024**.
- **Rating (historical):** 4.5★ with 20M+ users at peak — a real, well-loved product, not a flop.
- **What happened:** ThingThing (Fleksy's owner) pivoted to a B2B keyboard SDK in 2020 (healthcare,
  productivity integrators), launched a developer platform in 2022, and by 2024 had stopped
  maintaining the consumer app entirely. Some 2026 roundups still cite Fleksy favorably on "fastest
  typing" (147 WPM claims) and "zero data collection," but that reputation is now inherited by
  SDK licensees, not a live consumer app — **treat any current "Fleksy" star rating in aggregator
  articles as stale/inherited, not a live signal.**
- **Lesson for positioning:** "fast + private" as the *entire* value prop wasn't enough to survive
  Gboard/SwiftKey commoditizing swipe-typing and on-device prediction. A workflow-specific wedge
  (Grammarly's writing-quality, or a numbers/data-entry wedge) survives feature-parity pressure in
  a way "we're just a faster/more private version of the same thing" does not.

### Typewise
- **Pricing:** freemium; Typewise PRO $1.99/mo or $9.49/yr; $25 one-time lifetime option.
- **Rating:** 3.8★, 839 ratings — small, engaged base, not mainstream traction.
- **Privacy positioning (already explicit, on the App Store listing itself):** "does NOT require
  'Full Access'" and "none of your typing data is transmitted to the cloud," with an offline mode
  that disables even anonymous usage analytics. This is the **clearest existing privacy-first
  marketing claim found on iOS** for a general keyboard.
  - Note: `Typewise Custom Keyboard` (privacy-forward, ID `1470215025`) and `Typewise Offline
    Keyboard` (ID `1074311276`) appear to be two separate App Store listings under the same brand —
    worth disambiguating in any future direct-comparison audit rather than a red flag.
- **Praise:** "much smarter way to type," gesture controls, larger effective key targets; loyal
  users call the PRO tier "well worth paying for."
- **Complaints:** the hexagonal layout is the product's entire bet, and it's genuinely divisive —
  "requires more vertical reach," "QWERTY is king." Occasional crashes, missing emoji search.
- **Read on numbers:** no calculator or conversion; the innovation is purely the letter-layout
  geometry, not data-entry workflow.

### The "Unni / others" bucket — what's actually there
No iOS keyboard app named "Unni" (or a plausible near-spelling) surfaced in App Store or web
search. The nearest name-matches — **Uni Keyboard** and **UniChar — Unicode Keyboard** — are
Unicode/symbol-picker keyboards (typing special characters, braille, etc.), not general-purpose
typing keyboards, and aren't part of the Gboard/SwiftKey/Grammarly/Fleksy/Typewise competitive set.

The genuinely relevant "others" are two clusters:

1. **AI-writing entrants** (e.g., **CleverType** — $4.99/mo or $39.99/yr, self-reported 4.7★/34K+
   reviews, 1.2M active users): repositioning the Grammarly playbook ("save 2+ hours/week on
   email") rather than competing on typing mechanics. Confirms writing-quality/professional-use
   is a viable premium wedge distinct from speed or privacy.
2. **Numeric-only addon keyboards** — this is the load-bearing finding for the gap analysis below.
   `NumPad: Your Number Keyboard` ($2.99 + $1.99 Finance Pack + $4.99 all-packs lifetime, 4.2★/230
   ratings), `Number Pad – Smart Keyboard` ($3.99, 4.3★/7 ratings, autocompletes expressions like
   "10+5," offline), `Calcvier`, `Calku`, `Numberie Keyboard` all exist **today**, all validate
   real demand for numeric-first typing (spreadsheets, forms, banking, PINs), and **none of them
   is a full keyboard** — every one requires the user to keep the system (or another third-party)
   keyboard installed for letters and manually switch via the globe key when they need to type a
   word. That switching tax is exactly the friction pattern documented below.

---

## Why people abandon third-party keyboards (cross-cutting)

Pulled from Apple Community threads, security writeups, and multi-source 2025–2026 comparison
articles — these recur across every competitor's review section, not just one product:

1. **Full Access is the trust wall.** Full Access lets a keyboard "access, record and transmit
   anything you type" — this exact framing shows up unprompted in SwiftKey reviews, Gboard
   security writeups, and every "should I use a third-party keyboard" explainer. For
   well-known vendors (Google, Microsoft) reviewers extend trust based on brand/audit history;
   for anyone else, Full Access is the first and sometimes only objection raised.
2. **Secure-field bounce-back breaks the mental model.** iOS forces the system keyboard in
   password fields and in apps using cross-platform frameworks (Flutter, Ionic) or custom text
   views that bypass the system keyboard stack, and Safari does the same for web password fields.
   Users experience this as "my keyboard randomly stopped working" rather than understanding it as
   a deliberate OS security boundary — it's an unpredictable, unexplained failure mode baked into
   the platform, not something any third-party vendor can fix.
3. **Global switching friction compounds.** Per-app keyboard state doesn't persist the way users
   expect; every keyboard switch is a manual globe-key tap; iOS point updates periodically break
   third-party extensions until the vendor ships a compatibility patch (documented as far back as
   the iOS 13 Full-Access bug, still cited as a category risk in 2025–2026 writeups).
4. **Multilingual gaps are still unresolved as of iOS 18.** Apple's own multilingual merge feature
   (up to 3 languages in one keyboard) is inconsistently loved — some users find merged languages
   convenient, others find it impossible to unmerge — and third-party keyboards inherit the same
   complexity plus their own language-pack coverage gaps (e.g., Turkish/Japanese needing separate
   keyboards, not auto-detected). Gboard is consistently cited as the *best* of the third parties
   here; SwiftKey claims the broadest raw language count (90+) but "limited to two active
   languages" in practice per reviews.
5. **Feature commoditization removes the reason to switch.** Swipe-typing was Swype/Fleksy's
   entire differentiator until Gboard and SwiftKey both shipped it natively — after that, Swype
   died and Fleksy's consumer app followed by 2024. Apple's Calculator app picking up unit/currency
   conversion in iOS 18 is the same pattern one step earlier: a feature that used to require a
   third-party app is now free, built-in, and requires zero trust decision.

---

## Underserved niches

### Is there a full keyboard that treats numbers/math/data-entry as first-class?

**No.** Across Gboard, SwiftKey, Grammarly, Fleksy, Typewise, and the AI-writing entrants
(CleverType and peers), none ships a calculator, unit converter, or numeric-optimized layout as
part of a full letters+numbers keyboard. One independent comparison pass, when asked directly,
returned: *"No keyboards mentioned focus specifically on numbers, math, or data entry."* The
closest things that exist are:

- **The numeric-only addon apps** (NumPad, Number Pad, Calcvier, Calku, Numberie) — they prove the
  demand (people pay $2–4 plus IAP for a *better* number pad) but require keeping a second keyboard
  installed for text, so they're a workaround, not a full keyboard.
- **Apple's own Calculator app** — picked up 200+ unit/currency conversions in iOS 18 and
  natural-language conversion in Math Notes ("50 m in feet ="), but that's a standalone app, not a
  keyboard extension — it doesn't help you convert a number *while typing in Messages or a form*.
- **This project's own `NumPad` keyboard extension** — already the most complete numbers-first
  *keyboard* (Finance/Symbols/Programmer/Units/Cooking packs, live unit/currency conversion via the
  "=" overlay, Tax/Tip calculator) — but it is explicitly a numeric-only extension today; the
  full-QWERTY mode flagged in the 2.0 design docs is what would turn this from "best numeric addon"
  into "the only full keyboard where numbers are first-class."

### Why that gap is defensible, not just unclaimed

Two structural reasons feature-parity risk is lower here than it looks:

1. **Gboard/SwiftKey's core layout hierarchy fights against it.** Both are built as chat-first
   QWERTY keyboards where digits live on a shifted/secondary layer by design, because their
   billions of mainstream users are typing words, not numbers. Making numbers genuinely first-class
   (persistent number row sized for single-hand entry, an always-reachable calculator/converter,
   PIN/OTP-aware key sizing) means restructuring the *default* layout for a data-entry minority —
   a redesign risk neither vendor has taken even once (Apple didn't put it in Gboard; it went into
   the standalone Calculator app instead). It's easy to bolt on a calculator *icon somewhere*; it's
   a much bigger bet to make numbers the organizing principle of the keyboard's layout, which is
   what actually solves the workflow (spreadsheets, invoicing, forms, tips) that numeric-addon
   reviews describe wanting solved.
2. **The precedent case (Fleksy/Swype) doesn't transfer.** Swipe-typing was a single, cleanly
   copyable *feature* — Gboard shipped an equivalent in one release cycle and the differentiator
   evaporated. A numbers-first full keyboard is a *layout + workflow* bet (persistent calculator,
   unit conversion, tax/tip math, pack-based number formats) stacked on top of a fully compliant
   general keyboard — closer to Typewise's hexagonal-layout bet (which nobody has copied in years,
   because it requires committing to a different default experience for *all* users, not adding a
   toggle) than to a droppable feature checkbox.

### Privacy-first positioning — who owns it today?

- **Typewise owns it most explicitly on iOS right now** — "does NOT require Full Access" and "no
  typing data transmitted to the cloud" are on the App Store listing itself, not just marketing
  copy elsewhere. But Typewise's actual growth engine is the hexagonal layout, and its rating base
  is small (839 ratings) — the privacy claim is present but not what's driving adoption or churn in
  its own reviews.
- **Fleksy claimed "zero data collection"** as a badge in third-party roundups, but the product
  behind that claim no longer exists as a consumer app — the claim is now orphaned marketing
  copy in aggregator articles, not a live product signal.
- **Gboard/SwiftKey structurally cannot fully own this**, even if they wanted to: their AI
  prediction/rewrite features depend on cloud processing by design (this is explicit in
  Microsoft/Google's own architecture — "opting out of the data flow means opting out of the
  features"). Any privacy-first pivot for them means shipping a visibly worse AI experience for
  their mainstream users, which they have no incentive to do.
- **On Android, open-source keyboards (e.g., HeliBoard) already own "no network permission at
  all" as a hard privacy guarantee** and are pulling in developers/sysadmins/technical-writer
  power users specifically on that basis — but there is no iOS equivalent with comparable rigor
  and mainstream packaging; Typewise is the closest but pairs the claim with a divisive layout
  bet rather than a mainstream-compatible one.
- **Nobody today pairs "no Full Access required for core typing" with a numbers/data-entry
  wedge.** That combination — the No Full Access privacy claim only Typewise makes, plus the "not
  even a Gboard threat" layout defensibility only a data-entry-first keyboard has — is open.

---

## Positioning recommendation

Position the future full-keyboard build as **"the keyboard for people who type numbers" —
privacy-first by construction, not by toggle.**

Concretely:
- **Lead with the workflow wedge, not the privacy wedge.** Privacy-first alone (Typewise, and
  historically Fleksy) tops out at a small, engaged-but-niche rating base because "more private" is
  a defensive reason to switch, not an active one — it doesn't show up in a review as "I switched
  *because* of this," it shows up as "I'm *comfortable* using this because of this." Numbers/
  data-entry, forms, invoicing, tips, unit conversion is the active reason ("I switched because
  typing numbers was painful everywhere else") — exactly the demand the numeric-addon apps'
  reviews already surface, just trapped in an addon that can't replace the system keyboard.
- **Make "no Full Access required for core typing" the credibility layer underneath it, stated on
  the App Store listing itself** (following Typewise's precedent) — this defuses the single most
  consistently cited objection to third-party keyboards (Full Access = keylogger risk) without
  requiring the user to trust a brand the way Gboard/SwiftKey get trusted on reputation alone.
  Full Access can still be offered *opt-in* for the specific features that need it (clipboard
  history, haptics/sound — matching this project's existing entitlement model), same as today.
- **Don't compete on swipe-typing, multilingual breadth, or AI writing quality** — those are
  exactly the axes where Gboard, SwiftKey, and Grammarly have deep, funded, structurally-favored
  advantages (cloud AI, 90+ languages, brand trust). Competing there invites the same fate as
  Fleksy: a feature Google ships natively in one release cycle.
- **The moat is the layout + workflow bet, not any single feature** — persistent calculator/
  converter reachability, pack-based number formats, tax/tip math, and a numbers-first default
  layout are each individually copyable, but *all of them organized as the keyboard's core
  identity* is the same kind of commitment Typewise made with hexagons: expensive for Gboard to
  copy because it means deprioritizing their mainstream chat-first users, not because the
  individual features are hard to build.
- **Target the same "spreadsheets, forms, banking, invoicing, tips" use cases the numeric-addon
  apps' reviews already validate** — that's the fastest path to product-market signal, since
  demand is proven; the wedge is turning "addon you switch to" into "keyboard you never have to
  leave," which directly removes the #1 documented abandonment cause (manual switching friction)
  for exactly the audience most likely to care.

---

## Sources

- [Gboard – App Store](https://apps.apple.com/us/app/gboard-the-google-keyboard/id1091700242)
- [Gboard – Ratings & Reviews](https://apps.apple.com/us/app/gboard-the-google-keyboard/id1091700242?see-all=reviews&platform=iphone)
- [Gboard Reviews — JustUseApp](https://justuseapp.com/en/app/1091700242/gboard-the-google-keyboard/reviews)
- [Goodbye GBoard — Medium/Mac O'Clock](https://medium.com/macoclock/the-perfect-iphone-keyboard-a-showdown-1175f1c32cae)
- [Hacker News: iPhone keyboard discussion](https://news.ycombinator.com/item?id=45216413)
- [Microsoft SwiftKey AI Keyboard – App Store](https://apps.apple.com/us/app/microsoft-swiftkey-ai-keyboard/id911813648)
- [Microsoft SwiftKey Reviews — JustUseApp](https://justuseapp.com/en/app/911813648/microsoft-swiftkey-keyboard/reviews)
- [Grammarly: AI Keyboard & Notes – App Store](https://apps.apple.com/us/app/grammarly-ai-keyboard-notes/id1158877342)
- [Grammarly vs. Gboard — CleverType](https://www.clevertype.co/post/grammarly-vs-gboard-which-ai-keyboard-for-ios-and-android-is-best)
- [Fleksy — Wikipedia](https://en.wikipedia.org/wiki/Fleksy)
- [Fleksy Keyboard SDK](https://www.fleksy.com/)
- [Best Fleksy Alternatives 2026 — App Vulture](https://appvulture.com/apps-like/fleksy/)
- [Fleksy, Inc. developer page — App Store](https://apps.apple.com/gd/developer/fleksy-inc/id520337249)
- [Typewise Custom Keyboard – App Store](https://apps.apple.com/us/app/typewise-custom-keyboard/id1470215025)
- [Typewise Offline Keyboard – App Store](https://apps.apple.com/us/app/typewise-offline-keyboard/id1074311276)
- [Typewise iOS review — iGeeksBlog](https://www.igeeksblog.com/typewise-custom-keyboard-ios-app-review/)
- [NumPad: Your Number Keyboard – App Store](https://apps.apple.com/us/app/numpad-your-number-keyboard/id1072547160)
- [Number Pad – Smart Keyboard – App Store](https://apps.apple.com/us/app/number-pad-smart-keyboard/id987232515)
- [Best Keyboard Apps for iOS 2026 — CleverType](https://www.clevertype.co/post/best-keyboard-apps-for-ios-in-complete-comparison)
- [Best Keyboard App for iPhone in 2026 — BossAI](https://bossai.tech/blog/keyboard-app-for-iphone)
- [Here's why you should avoid third-party keyboards — AppleToolBox](https://appletoolbox.com/heres-why-you-should-avoid-third-party-keyboards-on-your-iphone-or-ipad/)
- [Security of Third-Party Keyboard Apps — Zeltser](https://zeltser.com/third-party-keyboards-security)
- [Turn Off Full Access for iPhone Third-Party Keyboards — iDarb](https://idarb.com/2026/04/26/iphone-keyboard-privacy-turn-off-full-access-third-party/)
- [Why does a keyboard app need 'Full Access'? — Softonic](https://en.softonic.com/articles/why-does-a-keyboard-app-need-full-access-to-my-iphone)
- [iOS 13 Full-Access keyboard bug — The Hacker News](https://thehackernews.com/2019/09/ios-13-keyboard-apps.html)
- [Apple: convert units or currency in Calculator](https://support.apple.com/guide/iphone/convert-units-or-currency-iph69d274dde/ios)
- [The Quiet Revolt Against Google's Keyboard — WebProNews](https://www.webpronews.com/the-quiet-revolt-against-googles-keyboard-why-android-power-users-are-defecting-to-open-source-alternatives/)
- [Swype Is Dead. Long Live Swype — Forbes](https://www.forbes.com/sites/anthonykarcz/2018/02/20/swype-is-dead-long-live-swype/)
- [Multiple language keyboards — MacRumors Forums](https://forums.macrumors.com/threads/multiple-language-keyboards.2438621/)
- [How To Use a Bilingual Keyboard iOS 18 — The Mac Observer](https://www.macobserver.com/ios/bilingual-keyboard-ios/)
- [Uni Keyboard – App Store](https://apps.apple.com/us/app/uni-keyboard/id924603370)
- [UniChar — Unicode Keyboard – App Store](https://apps.apple.com/us/app/unichar-unicode-keyboard/id880811847)

*(Aggregator-article numbers — ratings/counts quoted from third-party comparison sites rather than
fetched directly from the App Store — should be treated as directional, not audited; where this
doc fetched an App Store listing directly, that's noted as such above.)*
