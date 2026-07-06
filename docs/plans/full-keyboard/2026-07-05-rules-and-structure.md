# App Store rules + Apple relations constraints for a full keyboard

Research doc only — no code changes. Covers what App Review requires of a *full* (system-wide,
typing-replacement) keyboard extension, what marketing copy is safe, what off-Store marketing risk
looks like, and whether NumPad should ship a second keyboard extension in the same app or as a
standalone app.

---

## 1. App Review Guidelines for keyboards (4.4.x) — applied to a full keyboard

### 4.4 Extensions (general, applies to the containing app + the extension)

> "Apps hosting or containing extensions must comply with the App Extension Programming Guide...
> and should include some functionality, such as help screens and settings interfaces where
> possible. You should clearly and accurately disclose what extensions are made available in the
> app's marketing text, **and the extensions may not include marketing, advertising, or in-app
> purchases.**"

Implication for a full keyboard: the keyboard extension binary itself can never show a paywall,
upsell banner, or "upgrade to Pro" button — that has to live in the container app, reached only via
a deep link (the same `numpad://store-preview` pattern NumPad already uses for locked keys/packs).
This applies whether the full keyboard is a second extension in NumPad or a new app entirely.

### 4.4.1 Keyboard Extensions — the operative rules

**Must:**
- Provide keyboard input functionality (typed characters)
- Follow Sticker guidelines if it includes images/emoji
- Provide a method for progressing to the next keyboard (the 🌐 globe key)
- **Remain functional without full network access and without requiring full access**
- Collect user activity only to enhance the functionality of *that keyboard extension on that
  device* (i.e., not for cross-app/cross-device profiling or ad targeting)

**Must not:**
- Launch other apps besides Settings
- Repurpose keyboard buttons for other behaviors (e.g., hold-return-to-launch-camera)

The load-bearing phrase for a full keyboard is **"remain functional without full network access
and without requiring full access."** Full Access and network access are opt-in, off by default,
and Apple's review explicitly checks that basic typing (and — this is the part that bites autocorrect
engines — basic *autocorrect/prediction*) works with both switched off. A full keyboard's core value
prop (predictive text, autocorrect, swipe-to-type, etc.) has to ship a fully on-device path as the
**default**, not a degraded "please enable Full Access to use this app" experience. Apple has
rejected/flagged keyboards in the past for functionally gating core typing behind Full Access.

Sources: [App Review Guidelines §4.4](https://developer.apple.com/app-store/review/guidelines/),
[App Extension Programming Guide: Custom Keyboard](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html)

### What the sandbox actually blocks without Full Access

Per Apple's Custom Keyboard programming guide, a keyboard with `RequestsOpenAccess = false`
(default) has:
- No network access, no shared container with the containing app
- No microphone (no dictation), no Location Services, no Address Book, no Camera Roll
- No `UIPasteboard`, no audio (no keyboard click sound), no iCloud/Game Center/IAP

Apple's own framing: *"If you build a keyboard without open access, the system ensures that
keystrokes cannot be sent back to you or anywhere else... a nonnetworked keyboard gives you a head
start in meeting Apple's data privacy guidelines."* — i.e., the *free/default* tier of a full
keyboard is architecturally incapable of phoning home even if you wanted it to. Any cloud-assisted
autocorrect/ML has to be an **explicit, disclosed, opt-in** feature gated behind the user granting
Full Access, and even then it cannot be the only way core typing works.

### Data-collection limits once Full Access is granted

Even with Full Access, Apple's programming guide (Table 8-2, "responsibilities of an open-access
keyboard") imposes real limits, and 4.4.1's "collect user activity only to enhance ... on the iOS
device" is the App Review–enforced version of the same principle:

| Data | Rule |
|---|---|
| Keystrokes / voice data | "Do not store received keystroke or voice data except to provide services that are obvious to the user." |
| Autocorrect lexicon | "Consider the autocorrect lexicon to be private user data. Do not send it to your servers for any purpose that is not obvious to the user." |
| Network/trending data | "Do not associate the user's identity with their use of trending or other network-based information, for any reason that is not obvious to the user." |
| Address Book / Location | Only for the obvious, disclosed purpose; no background location use. |

Practical read: a full keyboard **can** ship a server-assisted autocorrect/next-word-prediction
model (this is exactly what Gboard on iOS does — it's a live precedent of a full keyboard with
network + Full Access on the App Store), but only as an opt-in enhancement, never as the only path
to functional typing, and never repurposed for analytics/ad-tech on what the user types.

### Privacy Nutrition Label implications

- If the keyboard sends *anything* keystroke-derived to a server (even for autocorrect quality),
  the App Privacy questions in App Store Connect will require disclosing **User Content** (and
  likely **Usage Data** / **Diagnostics**) as collected, and — if tied to an account or device ID —
  as **linked to the user's identity**. That renders on the product page as a much scarier privacy
  label than an on-device-only keyboard's "Data Not Collected."
- This creates a direct product tension: the more "smart"/cloud-assisted the autocorrect, the worse
  the privacy label looks next to competitors marketing "keystrokes never leave your device." Most
  successful third-party keyboards (Fleksy, Typewise) lead marketing with the *opposite* claim —
  on-device-only processing — specifically to keep the nutrition label clean and address the
  well-known "third-party keyboards can see everything you type" trust problem.
- An App Privacy Manifest (`PrivacyInfo.xcprivacy`) is also required declaring any "required-reason"
  API usage and tracking domains; inaccurate manifests are themselves groundsfor rejection separate
  from 4.4.1.

Sources: [Custom Keyboard security tables](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html),
[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/),
[Security of Third-Party Keyboard Apps](https://zeltser.com/third-party-keyboards-security)

---

## 2. Marketing rules — App Store copy that mentions/compares to Apple or native features

### The two guidelines that actually govern this

**2.3.1 (Hidden Features and Misleading Marketing):** bars marketing "in a misleading way, such as
by promoting content or services that it does not actually offer... whether within or outside of
the App Store" — this is the catch-all for *false* claims, not comparative claims per se.

**2.3.10 (Platform References):** *"Make sure your app is focused on the experience of the Apple
platforms it supports, and don't include names, icons, or imagery of **other mobile platforms or
alternative app marketplaces** in your app or metadata, unless there is specific, approved
interactive functionality... Don't include irrelevant information."*

The key nuance: **2.3.10 is about competing platforms (Android, Google Play, Amazon, etc.), not
about Apple's own native features.** Apple is the platform NumPad ships on — referencing "the
built-in keyboard," "the default iPhone keyboard," or "the stock keyboard's autocorrect" is not a
"competing platform" reference in the 2.3.10 sense, because you're describing an in-scope, on-device
comparison relevant to your own app's core function (this is exactly why every third-party keyboard's
listing talks about autocorrect, prediction, themes, etc. relative to the system default). It is
**mentioning Android/Google Play/other marketplaces** in metadata that is the well-documented,
frequently-cited rejection trigger — real-world guidance repeatedly warns against phrases like "the
best Android alternative" or naming Android/WhatsApp/PayPal/Windows in App Store copy.

**Apple trademark rules (separate from App Review, but reviewers do check for implied affiliation):**
third parties **may** use Apple product names (iPhone, iPad, Apple Watch, etc.) in a "referential
phrase" to describe compatibility, but may not use them in a way that suggests endorsement or
affiliation, and may not use the Apple logo. Nothing in the trademark guidelines bars *describing*
a native feature (e.g., "the default keyboard") — the restriction is about implying Apple endorses
or made your product.

### What's safe vs. what risks rejection

**Safe (feature-forward, own-app-focused):**
- "The keyboard with a real number pad."
- "Autocorrect you can trust." / "Your keystrokes stay on your device."
- "Faster typing than the system keyboard." (factual, own-experience comparison, no naming of Apple
  negatively, no logo use)
- "Works instantly — no Full Access required for core typing." (specific, truthful, matches 4.4.1)

**Risky (invites 2.3.1 misleading-marketing or trademark-implied-affiliation scrutiny):**
- Anything that names "Apple" or "iPhone" alongside disparaging language ("unlike Apple's broken
  autocorrect") — not explicitly banned by a numbered guideline, but it's the kind of "irrelevant to
  your app's own experience" copy 2.3.10's closing line ("don't include irrelevant information") and
  2.3.1's misleading-marketing catch-all get invoked for in practice, and it reads as inviting a
  trademark-referential-use objection since it's not describing *compatibility*.
- Any unverifiable superlative ("#1 keyboard," "smartest autocorrect ever") without proof — flagged
  under 2.3.1 as misleading if reviewers ask for substantiation.
- Naming/depicting Android, Google, Samsung, Google Play, or "the best Android alternative" — this
  is the one with the clearest, most repeated precedent of real rejections.

Net: comparisons to Apple's *own* native keyboard, framed as feature claims about your app, are
low-risk and are what the entire third-party keyboard category already does. Comparisons to *other
platforms* (Android etc.) are the actual, well-precedented danger zone.

Sources: [App Review Guidelines §2.3](https://developer.apple.com/app-store/review/guidelines/),
[Apple Copyright and Trademark Guidelines for Third Parties](https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html),
[App Store Rejection Reasons 2026](https://twinr.dev/blogs/apple-app-store-rejection-reasons-2025/)

---

## 3. Off-App-Store marketing (social, PR, web) — no Apple approval, but featuring risk

No App Review guideline applies off-Store — Apple does not review a landing page, a tweet, a press
release, or an ad. The constraints there are ordinary trademark/advertising law (don't use the Apple
logo, don't imply endorsement, don't make false comparative claims that invite an FTC/Lanham Act
complaint), not App Review.

The real question the owner is asking is **editorial-featuring risk**: does publicly punching at
Apple hurt your odds of being featured (Today tab, "App of the Day," category features)?

**What the research surfaced:**
- There is no documented, explicit Apple policy tying editorial featuring to how a developer talks
  about Apple in public marketing. Featuring criteria as documented (design quality, innovation,
  use of new APIs, "does not add value" crackdowns) are about the *app*, not the developer's public
  rhetoric.
- There is, however, a real and repeatedly-observed pattern of developers who **fought Apple
  publicly and paid a price in App Store outcomes** — the clearest is Kosta Eleftheriou, who publicly
  and aggressively called out App Store scams and Apple's handling of them, sued Apple, and reported
  his own apps being targeted/rejected during that period (settled 2022). Basecamp's HEY also had a
  public standoff with Apple (Phil Schiller responded directly, "You download the app and it doesn't
  work") that resulted in update rejections until they changed their IAP posture. Neither case is a
  clean "featuring was denied because of the tweets" precedent — the visible leverage Apple used in
  both was App Review (holding updates, alleging guideline violations), not featuring — but it shows
  Apple has, in practice, applied review pressure that tracked with public friction, even without a
  written rule saying it will.
- "Sherlocking" discourse (Apple shipping a free first-party feature that guts a paid indie app) is
  the more common form of Apple-vs-developer public conflict, and developers who've been sherlocked
  and spoken out (e.g., in various indie-dev blog posts) don't report featuring retaliation — but
  they also aren't a good analogy for "anti-Apple" marketing since they didn't provoke the conflict.

**Practical takeaway:** there's no rule against anti-Apple marketing off-Store, and no evidence
Apple has an anti-featuring blacklist for critics — but the one lever Apple demonstrably has used
against public critics is App Review discretion on your *other* submissions (holding updates,
scrutinizing borderline guideline calls more closely), which is a much higher-leverage risk for a
small indie shop shipping a Pro-gated keyboard than "will Apple feature us." The safer posture: keep
the app's own App Review surface (the 4.4.1 items in §1, the metadata in §2) unambiguously clean if
the marketing plan involves any pointed Apple criticism, since that's the channel Apple actually
controls and has used before.

Sources: [Developers v. Apple (TidBITS)](https://tidbits.com/2020/08/13/developers-v-apple-outlining-complaints-about-the-app-store/),
[A developer's guide to Apple, sherlocking, and antitrust (Astropad)](https://astropad.com/apple-antitrust/),
[Apple settles lawsuit with developer over App Store rejections (TechCrunch)](https://techcrunch.com/2022/09/01/apple-settles-lawsuit-with-developer-over-app-store-rejections-and-scams/)

---

## 4. Structural: one app with two keyboard extensions, vs. a standalone second app

### Option A — Two keyboard extensions in one containing app

**Technically supported by Apple's own docs.** The Custom Keyboard programming guide's multi-language
guidance says explicitly: *"To support more than one language in your custom keyboard, you have two
options: Create one keyboard per language, each as a separate target that you add to a common
containing app... or create a single multilingual keyboard."* This confirms one containing app can
host N keyboard extension targets — each gets its own bundle ID (a suffix of the container's), each
shows as an independent entry under Settings → General → Keyboard → Keyboards, and each can be
enabled/disabled independently by the user.

**No explicit App Review prohibition was found against a second, functionally-distinct keyboard
extension in the same app.** But nothing about bundling reduces the compliance bar — **each**
extension independently has to satisfy all of 4.4.1 on its own: its own working-without-network/
Full-Access path, its own 🌐 next-keyboard key, no ads/marketing/IAP inside *that* extension's UI.
Two keyboards in one app means two independent 4.4.1 surfaces for review to check, not one shared
pass. The upside is entirely on the business side: one App Store listing, one entitlement graph
(NumPad Pro can gate the second keyboard the same way it gates packs today), one privacy label to
maintain, one review queue. This is the structurally simpler option and matches how NumPad already
gates features via `Monetization` flags read by a `#if canImport` shared layer.

Watch item: `4.3(a)` (duplicate-bundle-ID spam) is about *duplicate apps*, not duplicate extension
targets inside one app, so it doesn't apply here — but it's worth keeping the two keyboards visibly
differentiated in the app's own UI/marketing (per 4.4's "clearly and accurately disclose what
extensions are made available") so reviewers don't read it as one extension awkwardly split in two
for no product reason.

### Option B — Standalone second app for the full keyboard

**Cross-promotion between your own apps:** there's no guideline barring an app from mentioning or
linking to your other apps in its own marketing text or in-app UI (this is standard practice — see
any developer's "More from us" section). The one governed channel is **push notifications**: 4.5.4
requires explicit opt-in consent language and an opt-out mechanism before push can be used for
promotional/marketing purposes, which would include using NumPad's push (if it has any) to market a
new standalone keyboard app.

**IAP entitlements do NOT carry over.** In-app purchases are scoped to the app (bundle ID) they were
purchased in. A user who bought `numpad.pro.lifetime` in NumPad has **no entitlement** in a new,
separate app — Apple's StoreKit has no cross-app non-consumable sharing mechanism. The only
documented cross-app sharing case is **auto-renewable subscriptions**, and even then each app needs
its *own* equivalent subscription product configured — Apple doesn't let you point two apps at one
shared subscription entitlement, you configure parallel ones. Since NumPad's monetization is
non-consumable (not subscription), there is **no** path to "NumPad Pro owners get the new keyboard
free" other than manual server-side logic you build yourself (e.g., receipt validation across apps
via your own backend) — which is real engineering, not something App Review/StoreKit gives you.

**Paid App Bundles:** Apple does support bundling up to 10 paid apps at a discounted combined price
(must be priced below the sum of individual prices, floor = highest individual app price), and
`Complete My Bundle` credits a customer who already owns one app in the bundle so they only pay the
delta for the rest. This is the only Apple-native mechanism to soften "you have to buy it again" —
it's a **discount**, not a free unlock, and both apps must be paid (can't mix a paid app with a
free+subscription app in the same bundle). As of WWDC 2026 Apple also expanded bundling to let
*different developers* partner on subscription bundles, which isn't relevant here since NumPad and a
same-developer second app aren't a subscription bundle case.

**Bottom line on B:** a standalone second app is viable but forces a real monetization decision —
either eat the "buy it twice" friction (softened only by a paid bundle discount), or move to a
cross-app subscription model so the entitlement can be configured (in parallel, not shared) across
both apps, or build custom receipt-sharing logic yourself.

Sources: [Custom Keyboard multi-language guidance](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html),
[App and Game Bundles](https://developer.apple.com/app-store/app-bundles/),
[In-App Purchase Family Sharing / cross-app subscription config](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/turn-on-family-sharing-for-in-app-purchases/),
[App Review Guidelines §4.5.4 Push Notifications](https://developer.apple.com/app-store/review/guidelines/)

---

## The 6 hardest constraints

1. **Zero-network + zero-Full-Access baseline is non-negotiable for core typing (4.4.1).** A full
   keyboard's autocorrect/prediction must ship a fully on-device path as the *default* — any
   cloud/ML-assisted autocorrect can only be an optional, disclosed enhancement behind a Full Access
   opt-in, never the only way basic typing/autocorrect works.
2. **Even with Full Access granted, keystroke and lexicon data still can't be stored/transmitted
   beyond what's "obvious to the user" and only to improve that device's keyboard** — this rules out
   telemetry/analytics/ad-tech on typed content and means any server-assisted smart features get an
   unavoidably scarier Privacy Nutrition Label than an on-device-only competitor.
3. **The keyboard extension binary itself can never contain ads, marketing, or IAP UI (4.4/4.4.1)** —
   all paywall/upsell has to live in the container app and be reached only via deep link, whether the
   full keyboard is a second extension in NumPad or its own app.
4. **Marketing copy can reference Apple's own native keyboard as a feature comparison (safe), but
   can't name competing platforms (Android/Google Play) in metadata (2.3.10) and can't pair "Apple"
   with disparaging claims without risking a 2.3.1 misleading-marketing read or a trademark
   implied-affiliation objection** — feature-forward copy ("real number pad," "autocorrect you can
   trust") is the safe lane; comparative-negative Apple-naming copy is the risky one.
5. **IAP entitlements are hard-scoped to a single app/bundle ID — a standalone second app cannot
   honor existing NumPad Pro purchases.** The only Apple-native softening lever is a discounted paid
   App Bundle (still a new purchase) or parallel-configured cross-app subscriptions; free carry-over
   requires custom receipt-sharing you'd have to build yourself.
6. **Two keyboard extensions can technically live in one containing app (each its own Settings entry,
   no explicit rule against it) but bundling doesn't share the compliance bar — each extension must
   independently clear all of 4.4.1 on its own,** doubling review surface rather than halving it;
   and off-Store anti-Apple marketing has no formal review rule but is the one arena where Apple has
   historically applied App Review discretion against public critics (Eleftheriou, Basecamp/HEY), so
   it's a reputational/review-relationship risk, not a written-rule risk.
