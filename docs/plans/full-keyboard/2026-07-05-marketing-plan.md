# NumPad Type — Two-Track Marketing Plan

Status: DRAFT, planning doc only — no code/config changes, not submitted anywhere, not committed.
Date: 2026-07-05. Working name for the product: **NumPad Type** (per
`2026-07-05-product-plan.md`), shipping as a second, independently-toggleable keyboard extension
inside the existing **NumPad** app (Option A — no standalone app, no new SKU, gated behind
existing `numpad.pro.lifetime`).

Sources this plan is built from (read in full before using this doc):
- `2026-07-05-complaint-evidence-bank.md` — every citation below is item-numbered against this
  doc (e.g. "1.3", "2.2"). Do not cite anything not in that bank; do not upgrade a 🟡 item to a
  🟢 claim.
- `2026-07-05-rules-and-structure.md` — the App Review / trademark / off-Store-featuring-risk
  constraints Track A and Track B are each built to survive.
- `2026-07-05-competitive-landscape.md` — the "numbers-first, privacy-by-construction, don't
  compete on AI-smart-autocorrect" positioning both tracks inherit.
- `marketing/appstore/description-2.0.md` — voice/format continuity for Track A (same
  above-the-fold structure, same restrained claims discipline, same "PRIVACY, THE WAY A KEYBOARD
  SHOULD WORK" register).

**The one-sentence version of this whole plan:** Track A is the calm answer; Track B is the loud
question it's answering. They never swap words, and they never promise something the other track's
evidence contradicts.

---

## 0. Why two tracks, and how they coexist without contradicting each other

Apple reviews App Store metadata (Track A). Nobody reviews a tweet (Track B) — but a tweet can
still cost NumPad an App Review relationship if it's reckless, per the rules doc's finding that
Apple has, in practice, applied review-queue pressure to developers who fought it publicly
(Eleftheriou, Basecamp/HEY), even with no written rule saying it will.

So the split isn't "spicy vs. safe," it's **where the citation lives**:

- **Track A never cites a complaint.** It only ever describes what NumPad Type itself does, in its
  own aspirational voice. If the words "autocorrect," "lag," "bug," or "broken" appear anywhere in
  Track A copy, that's a bug in this plan, not a feature.
- **Track B never invents a complaint.** Every claim about "the keyboard people are frustrated
  with" is a citation to something a named outlet, forum user, or Apple's own release notes already
  said publicly, dated and linked. Track B doesn't get to say anything about the native keyboard
  that the evidence bank doesn't already say.

### Voice matrix

| Dimension | Track A — App Store | Track B — Social / PR / Web |
|---|---|---|
| Reader's mental state | Cold, browsing the Store, hasn't decided anything | Warm — arrived via a shared post, already annoyed at *something* |
| Register | Calm, confident, aspirational | Urgent, citation-dense, culturally fluent |
| How Apple/the native keyboard is mentioned | Never named negatively; feature-forward only, no comparison language | Named directly, but only by quoting *others'* dated, sourced words |
| What claims are allowed | Only verified facts about NumPad Type's own shipped features | Only citations already in the evidence bank, scored 🟢/🟡, never 🔴 |
| Approval gate before publishing | App Review Guidelines checklist (rules doc §2) | Evidence-bank sourcing tier + the DO-NOT list (§below) |
| Failure mode if the line is crossed | Rejected submission, trademark/2.3.1 risk, review-relationship risk | Cheapened brand, lost editorial credibility — no App Review exposure since it's off-Store |
| Shared floor (applies to both, no exceptions) | Same banned-claims list: no unverifiable superlatives, no naming Android/Google Play, no fabricated screenshots, no mocking named individuals |

**The connective rule:** anyone who clicks from a Track B post into the App Store must land on
Track A copy that reads like a calm resolution to the noise they just read — not a continuation of
the complaint, and not a claim the product can't back up. Concretely: Track A must **never** claim
best-in-class autocorrect, because the product plan's own risk #1 is explicit that the V1 free-floor
engine (`UITextChecker`) is "good enough to not look broken, not competitive with Gboard." Track B
is allowed to talk about the *native* keyboard's documented problems; neither track is allowed to
claim NumPad Type solves autocorrect better than anyone. The number pad — not smarter autocorrect —
is the promise both tracks make, in different registers.

---

## TRACK A — APP STORE

**Ground rule for everything below:** purely aspirational, zero disparagement of Apple or the
native keyboard, no Android/competing-platform mentions, no unverifiable superlatives, matches the
existing `description-2.0.md` voice. Every line here should be able to sit next to "PRIVACY, THE WAY
A KEYBOARD SHOULD WORK" from the shipped 2.0 description without a tone seam.

Structural note: because NumPad Type ships as a second extension *inside* the existing NumPad app
(rules doc §4, product plan §1) rather than a new listing, "the app" doesn't get renamed — the work
below is (a) options for what to *call the feature* in copy and in-app UI, and (b) an updated
App Store subtitle/description/keywords for the existing NumPad listing now that it includes a full
keyboard, not a second listing's metadata.

### A1. Feature name options

| Option | Read |
|---|---|
| **NumPad Type** *(recommended — keep the working name)* | Reads naturally in a sentence ("Try NumPad Type"), doesn't imply a separate product, extends the existing brand instead of fragmenting it. |
| "Full Keyboard by NumPad" | Clear but generic — sounds like a category descriptor, not a name; weaker for word-of-mouth. |
| "NumPad: Type Mode" | Frames it as a mode toggle rather than a keyboard in its own right — undersells that it's a second, independently-enabled Settings entry. |

**Existing extension's name:** the product plan (§1) proposes renaming today's numpad extension to
**"NumPad Numbers"** once "NumPad Type" ships, purely for Settings → Keyboard clarity between the two
entries — this is a structural label, not a rebrand of the app itself, so it doesn't change any copy
above. Confirm this rename before GA copy (A6, screenshot captions) goes final, since "your numpad"
references throughout this doc describe the *feature* continuing to work, not a specific Settings
label — they hold either way, but the actual Settings-list string should match whatever this doc and
the product plan finally agree on.

### A2. App subtitle options (Apple's 30-character field)

The current listing's subtitle isn't in the description doc's history, so these are net-new
options once NumPad Type ships, sized to Apple's 30-character subtitle limit:

| # | Subtitle | Chars | Notes |
|---|---|---|---|
| 1 | **"A keyboard with a real numpad"** | 29 | *Primary recommendation.* Directly operationalizes the brief's "the keyboard that finally has a real number pad" line inside the hard 30-char limit. |
| 2 | "Typing you can actually trust" | 29 | Leans on the privacy-first angle; pairs well with the description body doing the "no Full Access" explanation. |
| 3 | "Type numbers like they matter" | 29 | More playful; foregrounds the numbers-first identity over the keyboard-replacement framing. |
| 4 | "Real numbers. Real keyboard." | 28 | Punchier, two-beat structure; slightly more "ad copy," less descriptive. |
| 5 | "Typing that stays on-device" | 27 | Privacy-first, but doesn't mention numbers at all — best held as an A/B challenger, not primary, since numbers-first is the documented defensible wedge (competitive-landscape doc), not privacy alone. |
| 6 | "A keyboard. And a numpad." | 25 | Simplest, most literal; safest fallback if 1–4 test poorly. |

### A3. Description opening — 3 lines above the fold

Matches the existing above-the-fold format and length (`description-2.0.md`'s "Type a number, get
an answer..." block):

```
NumPad now types more than numbers. NumPad Type is a full keyboard — every letter, every
number — built around the numpad you already trust, and its core typing works before you
ever have to grant it Full Access.
```

Why this framing and not others: it leads with the *product* fact (full keyboard, numpad-centered),
not a comparison; "before you ever have to grant it Full Access" is a specific, truthful,
4.4.1-compliant claim (rules doc's own "Safe" example list includes almost this exact line) rather
than an unverifiable trust claim like "the keyboard you can trust."

### A4. Keyword strategy (≤100 chars, comma-separated, Apple convention)

```
numpad,keyboard,custom keyboard,number pad,type faster,privacy keyboard,numeric keyboard,calculator,typing app
```
Character count: 110 — over budget; trim to fit. Recommended trimmed set:

```
numpad,keyboard,custom keyboard,number pad,type faster,privacy keyboard,numeric keyboard,calculator
```
Character count: 99.

Rules for this field, enforced against the rules doc:
- **No competitor brand names** (no "gboard," "swiftkey," "grammarly") — not explicitly a numbered
  guideline violation, but it's the well-precedented trademark-in-metadata risk category the rules
  doc flags, and it's an easy no-upside line to just not cross.
- **No superlatives** ("#1," "smartest," "best") — keyword or not, 2.3.1 treats misleading marketing
  the same everywhere in metadata.
- Existing 2.0 keywords (`calculator,finance,programmer,unit converter,tip calculator,ipad`) stay on
  the numpad-side packs; this set is additive for the new full-keyboard surface, not a replacement —
  reconcile into one ≤100-char field with whoever owns the ASC submission, since the two lists
  combined will overflow the limit and need real prioritization, not just concatenation.

### A5. Screenshot storyboard — 6 shots

Every shot shows a real, working NumPad Type screen — no mockups of a "before" state, no depiction
of the native keyboard at all (positive-only, per the aspirational brief).

| # | Shot | Headline overlay | What it proves |
|---|---|---|---|
| 1 | Hero: NumPad Type open in a Messages composer, full QWERTY + numpad visible | **"A keyboard with a real numpad."** | The core pitch, first thing seen. |
| 2 | Live Math Preview firing mid-sentence inside the full keyboard (reuses the 2.0 feature, now inside NumPad Type) | **"Do the math without leaving the sentence."** | Continuity with NumPad's existing signature feature — this isn't a bolt-on, it's the same product. |
| 3 | Onboarding/settings screen showing core typing enabled with Full Access still off | **"Typing you can trust. No Full Access required to start."** | The 4.4.1-safe privacy claim, shown as a real in-app state, not just asserted. |
| 4 | Close-up on the persistent number row/numpad zone with a subtle "always here" callout | **"A number row that's always there."** | Numbers-first identity, purely forward-looking, no "iPhone never had this" framing. |
| 5 | Theme picker / custom keyboard editor showing NumPad Type alongside the existing Liquid Glass themes | **"Make it yours."** | Ties into the existing Pro customization story instead of introducing a separate one. |
| 6 | iPad screen: NumPad Type at full width with a side-panel overlay open | **"Full keyboard. Full-size, on iPad too."** | Extends the existing "designed for iPad" pillar from `description-2.0.md`. |

### A6. What's-New voice

Same list format as the shipped 2.0 entry; leads with the feature, no "why" beyond the feature
itself:

```
NumPad Type is here — a full keyboard, built around the numpad.

• A whole keyboard: NumPad Type adds full QWERTY typing, letters and numbers together, as
  a second keyboard you can enable right alongside your existing NumPad numpad
• Core typing works immediately — no Full Access required to start
• Live Math Preview, the same one you already use, now built into every screen you type on
• Enable it independently from Settings → Keyboard — your numpad keeps working exactly as
  it does today either way
```

---

## TRACK B — SOCIAL / PR / WEB

**Ground rule for everything below:** every factual claim about the native keyboard is a citation
to a named, dated, linked source in the evidence bank — never an invented or paraphrased-past-truth
claim. 🟢 items can be quoted/stated directly. 🟡 items get paraphrased with a "reportedly" /
"per [outlet]" hedge, never presented as a verified statistic. 🔴 items (meme-fail compilations,
unverifiable engagement) are not used as primary sources anywhere in Track B.

### B1. The narrative arc

1. **Everyone's felt it.** Open with the shared, low-friction feeling — typing on an iPhone has
   been visibly imperfect for years, and it's not just you (Theme 1 press + Theme 2 forums).
2. **Here are the receipts.** Don't assert it — show it: WSJ's own source admitting the two
   dictionaries fight each other (1.1), a slow-motion video of the phone typing the wrong letter
   (1.3/3.3), a 1,627-point Hacker News thread with a public countdown clock (2.2/3.4), and Apple's
   own release notes quietly admitting the bug was real (1.8/4.4).
3. **Here's the fix.** Cut from receipts to product: NumPad Type, demoed live — specifically the
   Live Math Preview working inside a full keyboard, in Messages, in real time.
4. **And it also solves the other gap — the one iPhone's had since 2007.** Pivot from "typing
   quality" to "the missing number row," the more durable of the two complaints per the evidence
   bank's own read (Theme 5; item 5.3 shows it outliving *two* separate autocorrect rewrites).
5. **Press/creator amplification.** Hand the receipts-thread + demo + history-post package to the
   journalists and creators who already covered this exact story, so the pitch is "here's the fix to
   the thing you already wrote about," not a cold intro.

### B2. Ten post concepts, mapped to evidence-bank items

| # | Platform | Hook line | Cited source (evidence bank) | Tone guardrail |
|---|---|---|---|---|
| 1 | X/Twitter (thread opener) | "The guy who invented iPhone autocorrect just told the Wall Street Journal it fights itself." | 1.1 — WSJ (Joanna Stern/Ken Kocienda), via 9to5Mac recap (WSJ is paywalled) | Quote the reported admission directly; don't speculate about Kocienda's current opinions beyond what's quoted; link the free recap, not just the paywalled original. |
| 2 | TikTok/Reels (repost + react) | "Watch someone type 'thumbs up' correctly. Watch the iPhone type something else." | 1.3/3.3 — Macworld slow-motion video / original creator video | Repost with credit to the original creator; don't reenact it as our own "discovery"; caption factually, no mockery of Apple engineers. |
| 3 | X (launch-week receipts thread) | "1,627 people upvoted a countdown clock demanding Apple fix the keyboard. The clock ran out." | 2.2 — Hacker News thread (verified via HN API) + 3.4 — ios-countdown.win | Use the HN point/comment count exactly as verified; label the countdown site as an independent developer's project, not ours; no "Apple is dying" framing. |
| 4 | X/Threads | "Apple's iOS 26.4 patch notes quietly admitted the typing bug was real." | 1.8/4.4 — MacRumors on Apple's own release notes | Quote the release-note language verbatim ("improved keyboard accuracy when typing quickly"); frame as Apple's own words, not our interpretation. |
| 5 | LinkedIn / owned blog (long-form) | "SlashGear's verdict: the iPhone keyboard has major flaws — and the number row people have asked for 'for years now' still isn't native." | 1.9/5.2 — SlashGear (Adnan Ahmed) | Attribute the "years now" phrase directly to SlashGear; don't imply SlashGear endorses NumPad Type — cite them, don't co-brand with them. |
| 6 | X or Reddit (history angle) | "People have been asking for a number row since at least 2022. We went and looked." | 5.1 — MacRumors Forums thread, Oct 2022 | Forum quotes are 🟡 — paraphrase, attribute to "a MacRumors Forums thread," not to named handles, and don't present the thread as a formal survey. |
| 7 | Instagram carousel / X | "Even Craig Federighi joked about this on stage." | 3.5 — WWDC 2023 Federighi "ducking" line, via NPR/CBS coverage | Reference the joke as Apple's own on-record admission-in-comedy-form; link the NPR/CBS coverage, not just a meme clip; never caricature Federighi personally. |
| 8 | TikTok/YouTube Shorts (launch-week demo, our own product) | "Everyone's talking about fixing autocorrect. We just gave the keyboard a number pad, too." | 1.10 — MacRumors on the iOS 27 keyboard-overhaul rumor (context for "why now") | Demo only real, working NumPad Type functionality — no mockups; don't claim to have "fixed" autocorrect — the claim is the number pad, not autocorrect superiority. |
| 9 | X / owned blog (history post) | "The iPhone has never had a dedicated number row. Not once. Since 2007." | 5.1 / 5.5 / 2.4 — the evergreen number-row complaint theme | Keep it historical and factual (a release-year fact plus a documented, durable request), not a claim about Apple's competence or intent. |
| 10 | Press-amplification / X (mid-week) | "Two years after Apple said they fixed autocorrect, one roundup found eight sources saying it's still broken." | 4.3 — Michael Tsai's Nov 2025 roundup | Attribute clearly to Tsai's aggregation; don't claim the eight sources agree beyond what's quoted; this is the master "we said we fixed it twice" post — save for mid-week amplification, not day one. |

### B3. Launch-week sequence

| Day | Beat | Concept(s) used |
|---|---|---|
| T-3 | **Teaser.** No citations, no claims — just "something's coming for the number row iPhone's never had." Builds curiosity without spending any receipts yet. | — |
| Day 1 | **Receipts thread.** Open with #3 (HN countdown clock), continue into #1 (WSJ/Kocienda) and #4 (iOS 26.4 patch notes) as replies in the same thread — the full "we said we fixed it, twice" arc lives here. | #3, #1, #4 |
| Day 2 | **Demo video.** Cut straight to product: Live Math Preview working inside the full keyboard, live, in Messages. This is the pivot from complaint to fix. | #8 |
| Day 3 | **Number-pad-since-2007 history post.** Pivot from typing-quality to the number-row gap — the more durable complaint per the evidence bank. | #9 (supported by #6) |
| Day 4 | **Press/creator pitch.** Send the one-liners below to the journalists who already covered this exact beat (SlashGear's Adnan Ahmed, Macworld's Filipe Espósito, MacRumors, 9to5Mac) and to the creators behind the wrong-letter video (#2) and Michael Tsai (#10) as a possible follow-up mention — the pitch is "the fix to the story you already wrote," with the thread/demo/history-post package as ready-made assets. | #2, #5, #10 (as press assets) |
| Day 5+ | **Sustain.** Rotate #6, #7 as supporting content; monitor App Store review sentiment and Track A funnel metrics per the KPIs below; be ready to pause the sequence if any citation gets challenged rather than defend it publicly. | #6, #7 |

### B4. Press-pitch one-liner variants

1. **News-hook angle:** "Apple's own iOS 26.4 release notes just admitted the keyboard bug was
   real — five months after it went viral. Here's the fix nobody expected: a real number pad."
2. **Consumer-benefit angle:** "The most-requested iPhone keyboard feature isn't smarter
   autocorrect — it's a number row. NumPad Type finally ships one, and core typing works before you
   grant it any special access."
3. **Category/trend angle:** "While Apple tests another AI-driven autocorrect overhaul for iOS 27,
   one indie keyboard skipped the AI race and shipped the thing MacRumors forum threads have asked
   for since 2022: a real number pad."
4. **Privacy angle:** "Every third-party keyboard asks for Full Access on day one. NumPad Type's
   core typing — number pad included — works without it."

### B5. DO-NOT list (explicit, non-negotiable)

- **No mocking named individuals** — Apple employees, journalists, forum users. Reference their
  statements/actions factually and respectfully (Federighi's joke, Kocienda's admission); never
  caricature them or speculate about their competence or intent.
- **No fabricated or mocked-up screenshots.** Every screenshot/video is either a real, working
  NumPad Type build, or a real cited screenshot of press/forum/social content with source credit.
  Never stage a fake Apple UI bug for effect, even as a joke.
- **No "Apple is dying" / "Apple doesn't care" / company-competence framing.** Stick to specific,
  dated, sourced incidents. Don't extrapolate a single patch note or forum thread into a claim about
  Apple's culture, trajectory, or intent — the evidence bank's own sourcing notes make the same
  discipline explicit ("nothing in this document editorializes about Apple's intent or competence").
- **No naming or depicting Android/Google/other platforms** in anything that touches App Store
  metadata (Track A) — 2.3.10's clearest, most-precedented rejection trigger. (Off-Store Track B
  content isn't reviewed, but keep this discipline everywhere anyway — it's not the brand NumPad Type
  is building.)
- **No unverifiable superlatives**, on either track ("smartest autocorrect," "best keyboard ever").
  The product plan's own risk assessment concedes the V1 autocorrect engine isn't competitive with
  Gboard — don't write a check the product can't cash.
- **No presenting 🟡-rated numbers as verified statistics.** Reddit thread counts, X
  likes/retweets, and similar unverifiable engagement figures always get a "reportedly" / "per
  [outlet]" hedge. Never use a 🔴-rated item (meme-fail compilations, unverifiable virality claims) as
  a primary citation anywhere.
- **No implying Apple endorsement or affiliation** — no Apple logo use, no "Apple-approved," nothing
  that reads as Apple partnering with or blessing NumPad Type.
- **No pointed anti-Apple content timed near an active App Store submission window.** Per the rules
  doc §3, keep the review-relationship surface clean while anything is pending review — Track B's
  loudest weeks should not coincide with Track A's most sensitive review windows.
- **No copy reuse across tracks.** If a sentence could appear in both an App Store screenshot and a
  tweet, rewrite one of them — the separation is the whole point.

---

## 3 measurable launch KPIs

1. **Pro-conversion lift attributable to NumPad Type.** Extend the existing
   `numpad://store-preview?source=` deep-link attribution pattern with a new
   `source=full_keyboard_lock` value (reusing `StoreViewController`'s existing `source`-logging
   convention). Target: a measurable lift in Pro conversion rate over the documented ~0.7%
   baseline (product plan §5/moonshot §6) within 60 days of GA, isolated specifically to users who
   arrived via the NumPad Type lock screen.
2. **Extension activation rate.** % of eligible users (Pro-entitled, once NumPad Type is visible to
   them) who actually enable "NumPad Type" under Settings → Keyboard within 30 days — tracked as its
   own funnel step, separate from purchase, since owning Pro and turning the keyboard on are two
   different user decisions.
3. **Track B narrative reach.** Two components, tracked together but reported separately from
   Track A's App Store metrics: (a) count of earned-media/creator pickups referencing NumPad Type
   within 14 days of the launch-week sequence, and (b) one hard engagement threshold on the Day 1
   receipts thread itself (impressions/reposts). This is the proxy for whether "everyone's felt it,
   here are the receipts, here's the fix" actually traveled — not blended into Track A's numbers,
   since a viral Track B moment and a converting Track A listing are different jobs.

**Guardrail, not a KPI:** per product-plan risk #4 (rating contamination), monitor NumPad's existing
App Store rating specifically for reviews mentioning "keyboard"/"typing"/"autocorrect" in the 30
days post-launch. This isn't a success metric — it's a trip-wire. If sentiment on that slice moves
negative, that's the signal to pull the Remote Config kill switch (`full_keyboard_enabled`) before
it drags down NumPad's existing 4.x average, independent of how the three KPIs above are trending.
