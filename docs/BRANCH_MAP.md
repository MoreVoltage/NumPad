# NumPad Branch & Worktree Map

_Audit date: 2026-11-20 · read-only (git log / diff / grep only — nothing checked out, stashed, reset or deleted)._
_Reference point **LIVE = `478430f5`** (App Store **2.1.1 build 15**). 2.1.0 live was `11296b01`._

"Behind / ahead" = commits in LIVE not in the branch / commits in the branch not in LIVE.
"Dirty" = `git status --porcelain` line count for the worktree (contents not inspected or touched).

---

## 0. TL;DR

- **The shipped app line is tiny:** `master (a1cdef7c, 2.0)` → `949716e8` 2.0.3 What's New → `fec4ea6b..11296b01` 2.1.0 paywall copy → `478430f5` 2.1.1. Only **7 commits past `master`**. `master` itself is stale (still 2.0); nothing was ever merged back.
- **Everything else (~200 commits) is a single long unshipped chain** that forks from `master` at `a1cdef7c`:
  `full-keyboard-v1 → qwerty-typing-v2 → qwerty-glide → grok/usability → codex/remediate → codex/keyboard-studio-ux → … → excellence-pass → 2.1 (latency, emoji) → 2.1-ux-owner-polish`, with side leaves `codex/keyboard-calibration` and `rel-2.1.1-home-shell-settings`.
- **⚠ STUDIO-ROOT FLAG:** every branch at or after **`919876c3` "replace phone settings list with Keyboard Studio tabs"** (in `codex/keyboard-studio-ux`) makes `StudioTabBarController` the **iPhone root, replacing the classic `HomeViewController`**. That is 16 refs — 14 local branches/detached worktrees + 2 remote-only (list in §3a, marked 🟥 in §2). Only `rel-2.1.1-home-shell-settings` / `key/opus-home-shell-harden` reverse it (`ea86df25`).
- **⚠ QWERTY FLAG:** every branch at or after `feat/full-keyboard-v1` (`47646ab2`) contains the QWERTY "NumPad Type" page + autocorrect stack + dark Glide decoder (marked 🟧). LIVE contains **zero** QWERTY/glide/emoji/calibration files.
- **⚠ SUBSCRIPTION FLAG:** `numpad.pro.sub.monthly` / `numpad.pro.sub.annual` exist **only in `fec4ea6b`** (an ancestor of LIVE) and were stripped by `11296b01`. **No branch tip carries subscription product IDs or a populated `subscriptionGroups`.** LIVE and `codex/update-notifications` still carry *dormant* plumbing (`Monetization.isProSubscriptionActive`, `proSubscriptionActive` key, `StoreManager` writes it) — harmless with no SKUs, but note it.
- **Glide:** present (dark) on all QWERTY branches; local flag OFF by default and "forced off in App Store builds"; RC mirror `qwertyGlideRemoteEnabled` defaults `true`. `codex/keyboard-calibration` also adds a `DEBUG && NUMPAD_PRIVATE_SWIPE` private swipe-training path with its own app group.
- **Real fixes that never reached LIVE (salvage candidates):** rating-prompt never fires (`6e62fb78`), "WHAT YOU GET FOR FREE" still in en-AU/GB/CA paid-app descriptions (`28640521`), first-run Pro upsell default (`154ded03`), the 2.0.1 onboarding rev-3 + hardening sweep (`feat/onboarding-2`, 31 commits, 0 patch-equivalent in LIVE — includes the proSale re-lock work; `proSale` doesn't appear anywhere in LIVE), opt-in update notifications (`codex/update-notifications`).

---

## 1. Topology

```
a1cdef7c master (2.0)  ──┬── 949716e8 2.0.3 ── fec4ea6b(subs!) ── … ── 11296b01 2.1.0 ── 478430f5 2.1.1 = LIVE
                         │                                              ├── codex/update-notifications (+9)
                         │                                              └── origin/codex/remove-keyboard-whats-new (+3, ⊂ update-notifications' first 3)
                         ├── feat/onboarding-2 (+31, 2.0.1 b14)
                         ├── origin/feat/growth-quickwins (+2)
                         ├── james/ipad-app-store-sim-screenshots (+4)
                         ├── james/mor-158-paywall… (+1)
                         ├── james/mor-161-simulator… (+1)
                         └── feat/full-keyboard-v1 (+18)  🟧 QWERTY starts
                               ├── origin/wip/stash-numpad (+17, stash-commit snapshot)
                               └── feat/qwerty-typing-v2 (+35) ── feat/qwerty-glide-and-accuracy (+5)
                                     └── origin/grok/usability-qwerty-ipad-kiosk (+20) ── codex/remediate-qwerty-ipad-kiosk (+33)
                                           └── codex/keyboard-studio-ux (+36)  🟥 919876c3 Studio tabs = iPhone root
                                                 └── grok/usability-qwerty-ipad-kiosk local (+3 docs)
                                                       ├── james/rel-2.1.1-home-shell-settings = key/opus-home-shell-harden (+7, restores classic Home)
                                                       └── codex/ipad-keyboard-width-preview = buzz/numpad-revenue-sprint (+12)
                                                             └── feat/excellence-pass (+12, 2.0.2)
                                                                   └── 237f8372 "open 2.1" (+2) ── feat/2.1-latency (+2)
                                                                         └── feat/2.1-emoji (+15) ──┬── feat/2.1-emoji-family-root (+1) ── feat/2.1 (merge) ── feat/2.1-2111-copy (+2) ── feat/2.1-ux-owner-polish (+2)
                                                                                                      └── origin/codex/qwerty-typing-reliability (+4) ── 44579547 (+3) ── origin/codex/keyboard-calibration (+3)
```

---

## 2. Local branches & worktrees

Legend: 🟥 Studio tab bar is the iPhone root (classic Home replaced) · 🟧 contains QWERTY/NumPad Type (+ dark Glide) · 💲 subscription SKUs · ✅ ancestor of LIVE (fully merged)

### 2a. Live line & active work

| Branch | Worktree path | Tip / date | Merge-base w/ LIVE | Behind / Ahead | Dirty | Contents | Rec. |
|---|---|---|---|---|---|---|---|
| `james/rel-2.1.1-bugfix` | `.worktrees/rel-2.1.1-bugfix` | `478430f5` 2026-09-27 | `478430f5` | 0 / 0 | 1 | **= LIVE 2.1.1 (15).** Version stamp + release notes over 2.1.0. | **Keep** (release reference). Consider tagging `v2.1.1`. |
| `key/opus-branch-map` | `.worktrees/opus-branch-map` | `478430f5` 2026-09-27 | `478430f5` | 0 / 0 (+this doc) | 0 | This audit. | Keep until reviewed, then archive. |
| `key/opus-converter-clip-fix` | `.worktrees/opus-converter-fix` | `478430f5` 2026-09-27 | `478430f5` | 0 / 0 | 0 | Empty so far (parallel task branch off LIVE). | Keep (active). |
| `james/rel-2.1.0-paywall-sub` | `.worktrees/rel-2.1.0-paywall-sub` | `11296b01` 2026-09-05 | `11296b01` | 1 / 0 ✅ | 2 | 2.1.0 as shipped. Its history includes `fec4ea6b` 💲 (sub IDs added) then `11296b01` (stripped). Tip is clean of SKUs. | **Archive** (fully merged); tag `v2.1.0` first. Check the 2 dirty files before removing worktree. |
| `james/rel-2.0.3-whats-new-notif` | `.worktrees/rel-2.0.3` | `949716e8` 2026-09-01 | `949716e8` | 6 / 0 ✅ | 7 | 2.0.3: What's New sheet, keyboard chip, one local notification. | **Archive** (merged); 7 dirty files — owner should glance first. |
| `master` | (main checkout is on another branch) | `a1cdef7c` 2026-07-06 | `a1cdef7c` | 7 / 0 ✅ | — | 2.0 merge. **Stale: 7 commits behind LIVE.** | **Keep**; owner should fast-forward to `478430f5` (not done here). |

### 2b. Post-LIVE side branches (fork from 2.1.0)

| Branch | Worktree path | Tip / date | Merge-base | B / A | Dirty | Contents | Rec. |
|---|---|---|---|---|---|---|---|
| `codex/update-notifications` | `~/NumPad-notifications` | `7c4e8bff` 2026-09-08 | `11296b01` | 1 / 9 | 0 | Removes persistent What's New promo from keyboard then restores it with independent dismissal; fixes keyboard-selection persistence + purchase/onboarding interruptions; **adds explicit opt-in update push notifications via FirebaseMessaging 11.15.0** (new pod, APNs entitlement, Settings opt-in, routing); docs. No QWERTY, no Studio, no sub SKUs (dormant `isProSubscriptionActive` plumbing only, same as LIVE). 33 files / +2195. | **Salvage** — best-positioned branch: 1 behind LIVE, classic Home. Take `9fa9150f` (persistence/interruptions fix) first as a bugfix; notifications (`56dbc44c..5c427dd6`) only as a deliberate feature decision (needs APNs + device checks per its own doc). |
| *(remote only)* `origin/codex/remove-keyboard-whats-new` | — | `49a8c023` 2026-09-08 | `11296b01` | 1 / 3 | — | Exactly the first 3 commits of `codex/update-notifications`. | **Archive** (subsumed). |

### 2c. Off-`master` small branches (never reached LIVE)

| Branch | Worktree path | Tip / date | Merge-base | B / A | Dirty | Contents | Rec. |
|---|---|---|---|---|---|---|---|
| `james/mor-158-paywall-lock-tap-pro-first-run-off-early-bird-not-the-hero` | `.worktrees/mor-158-paywall` | `154ded03` 2026-09-01 | `a1cdef7c` | 7 / 1 | 3 | **Paywall:** default first-run Pro upsell off, keep lock-tap paywall; new `KeyboardEnablementTracker`; +100 lines tests. LIVE still defaults RC `first_run_upsell_enabled: true`. | **Salvage `154ded03`** if the decision still stands — will conflict with `11296b01`'s rewrite of `StoreViewController+Hero.swift`; re-apply by hand on LIVE. |
| `james/mor-161-simulator-app-store-preview-live-math-pack-swap` | `.worktrees/mor-161-preview` | `ff9040b0` 2026-09-01 | `a1cdef7c` | 7 / 1 | 5 | **Screenshots/preview:** UITest capture route + script + committed 250 KB mp4 for an App Store preview (live math chip + Finance pack swap). | **Salvage** only if the preview video is still wanted (marketing tooling, no app code). Else archive. |
| `james/ipad-app-store-sim-screenshots` | `.worktrees/ipad-app-store-shots` | `ea7c37a7` 2026-09-01 | `a1cdef7c` | 7 / 4 | 3 | **Screenshots:** iPad App Store slides from iPad Simulator (bigger device, distinct themes, recaptures). Marketing assets only. | **Keep/salvage** if these slides are what's in ASC; otherwise archive. Assets-only, low conflict. |
| `feat/onboarding-2` | (no worktree) | `57b81ae8` 2026-07-18 | `a1cdef7c` | 7 / 31 | — | **Onboarding rev 3** (WOW → packs showcase → ENABLE → TRY IT, Math-crown finish, replay route `numpad://debug/onboarding?fresh=1`); free-pack claim (shelved behind `free_pack_enabled=false`); packs accordion + **timed-sale scaffolding (proSale)**; full-app hardening sweep `63f6f8e9` (25 files); 2.0.1 build 14 + fastlane lanes + 50-locale notes. **`git cherry`: 0 of 31 patches are in LIVE.** | **Salvage-specific-commits.** Highest-value unshipped non-QWERTY work. Start with `63f6f8e9` (hardening) and the onboarding rev-3 series; skip free-pack claim + version bumps. Expect conflicts — LIVE's onboarding is the 2.0 version. |
| *(remote only)* `origin/feat/growth-quickwins` | — | `3c8832f4` 2026-07-16 | `a1cdef7c` | 7 / 2 | — | 2.0 copy pass, demo-recording UITests, launch marketing; ignores 297 MB captures. | **Archive** unless copy pass is still wanted (check vs LIVE metadata). |

### 2d. The QWERTY / Studio chain (all 🟧; 🟥 from `codex/keyboard-studio-ux` on)

Each row is an ancestor of the row below unless noted, so intermediate tips are fully contained in the leaves.

| Branch | Worktree path | Tip / date | Merge-base | B / A | Dirty | Flags | Contents | Rec. |
|---|---|---|---|---|---|---|---|---|
| `feat/full-keyboard-v1` | — | `edd85780` 2026-07-10 | `a1cdef7c` | 7 / 18 | — | 🟧 | QWERTY pure-logic core, autocorrect (UITextChecker + lexicon), suggestion bar, Grammar pack, numpad flip; briefly a 2nd extension target then folded into the numpad extension as a page; Pro gate + kill switches. | **Archive** (contained in all later). |
| *(remote)* `origin/wip/stash-numpad` | — | `5550431e` 2026-07-12 | `a1cdef7c` | 7 / 35 | — | 🟧 | A pushed `git stash` (index/WIP commits) on top of early glide work: "demo-recording pbxproj ref + featuring-pitch edit". | **Archive.** |
| `feat/qwerty-typing-v2` | — | `5553dc5d` 2026-07-21 | `a1cdef7c` | 7 / 53 | — | 🟧 Glide | Frequency lexicon (en_50k), personal dictionary, touch personalization, **dark glide decoder** (SHARK2-lineage), spatial scoring, typo repair, offline eval harness (engines failed gates). | **Archive** (contained). |
| `feat/qwerty-glide-and-accuracy` | — | `d9606559` 2026-07-23 | `a1cdef7c` | 7 / 58 | — | 🟧 | +suggestion-bar hitTest fix, autocap fix, realistic-typing E2E, usability/iPad/kiosk spec. (origin copy `8901c067` is older, 36 ahead.) | **Archive** (contained). |
| *(remote)* `origin/grok/usability-qwerty-ipad-kiosk` | — | `7f77d816` 2026-07-23 | `a1cdef7c` | 7 / 78 | — | 🟧 | Keyboard profiles (versioned, migrate), QWERTY prefs/quality policies, **iPad kiosk readiness shell**, iPad dashboard, kiosk session reset, long-press alternates. | **Archive** (contained). |
| `codex/remediate-qwerty-ipad-kiosk` | `~/.codex/worktrees/NumPad/codex-remediate-qwerty-ipad-kiosk` | `0f584a2c` 2026-07-26 | `a1cdef7c` | 7 / 111 | 0 | 🟧 | 33 hardening commits: transactional profiles, kiosk session semantics, adaptive iPad geometry, personalization epochs, managed-profile provisioning. | **Archive** (contained); worktree clean → safe to remove later. |
| `codex/keyboard-studio-ux` | `~/NumPad-studio` | `54d74c19` 2026-07-30 | `a1cdef7c` | 7 / 147 | 0 | 🟧🟥 | **Keyboard Studio:** design system, truthful live previews, **`919876c3` replaces iPhone settings list with Studio tab bar** (`StudioTabBarController`, Keyboard/Features/Help tabs), adaptive **iPad Studio** with anchored keyboard dock, iPad height onboarding + **Pro-gated Kiosk mode**, localization. | **Archive** (contained). The iPad Studio half is the salvageable idea; the iPhone root swap is the thing to avoid. |
| `grok/usability-qwerty-ipad-kiosk` (**main checkout**) | `~/NumPad` | `3a3ed78a` 2026-07-30 | `a1cdef7c` | 7 / 150 | **48** | 🟧🟥 | Studio + 2 docs (iPad width spec/plan) + `.gitignore` worktrees. | **Keep for now** — the main checkout has **48 uncommitted entries**; owner must triage them before anything else. Branch itself is contained in later tips. |
| `codex/ipad-keyboard-width-preview` | `.worktrees/ipad-keyboard-width-preview` | `543605dd` 2026-07-30 | `a1cdef7c` | 7 / 162 | 1 | 🟧🟥 | iPad: 5 numpad widths, full-keyboard composition, simplified layout controls, truthful iPad preview. | **Archive** (contained). |
| `buzz/numpad-revenue-sprint` | `.worktrees/numpad-revenue-sprint` | `543605dd` (same SHA) | `a1cdef7c` | 7 / 162 | 0 | 🟧🟥 | Identical pointer to `codex/ipad-keyboard-width-preview`; no own commits. | **Archive** (duplicate pointer). |
| `feat/excellence-pass` | `.worktrees/excellence-pass` | `a176249b` 2026-08-03 | `a1cdef7c` | 7 / 174 | 2 | 🟧🟥 | 2.0.2 prep: **`6e62fb78` rating-prompt fix**, customer-truth blockers, §4.4 keyboard Store block, Early Bird open-to-all then reverted to pre-2.0, LSHandlerRank, **`28640521` remove "FREE" lies from en-AU/GB/CA descriptions**, option-C paywall heroes. | **Salvage-specific-commits** onto LIVE: `6e62fb78` (LIVE never calls `incrementSignificantUsageCount`, so with `significantUsesUntilPrompt = 3` the auto rating prompt can never fire) and `28640521` (LIVE en-AU description still says "WHAT YOU GET FOR FREE"). `526184d3` LSHandlerRank is N/A (LIVE has no `CFBundleDocumentTypes`). Then archive. |
| *(detached)* `237f8372` "open 2.1 — version 2.1 (13)" | `.worktrees/rel-2.1-latency-base` | `237f8372` 2026-08-04 | `a1cdef7c` | 7 / 176 | 1 | 🟧🟥 | Version bump + glide-FTO doc note. | **Archive worktree.** |
| `feat/2.1-latency` | `.worktrees/rel-2.1-latency` | `c7b2ea0e` 2026-08-04 | `a1cdef7c` | 7 / 178 | 1 | 🟧🟥 | **Latency:** coalesce QWERTY suggestion work; don't learn unevaluated boundary words. | **Archive** (contained; QWERTY-only perf). |
| `feat/2.1-emoji` | — | `2e76f61d` 2026-08-04 | `a1cdef7c` | 7 / 193 | — | 🟧🟥 | **Emoji:** pinned catalog, search reducer, bounded recents, QWERTY emoji access key, accessible lazy emoji browser. (= `origin/feat/2.1`.) | **Archive** (contained). |
| `feat/2.1-emoji-family-root` | `.worktrees/rel-2.1-emoji` | `c21914ec` 2026-08-04 | `a1cdef7c` | 7 / 194 | 1 | 🟧🟥 | +project skin-tone families to browse roots. | **Archive** (contained). |
| `feat/2.1` | `.worktrees/rel-2.1` | `3e9a1131` 2026-08-04 | `a1cdef7c` | 7 / 195 | 1 | 🟧🟥 | Merge of emoji-family-root. **Local is 2 ahead of `origin/feat/2.1`.** | **Archive** (contained). |
| *(detached)* `3e9a1131` | `.worktrees/rel-2.1-t7` | `3e9a1131` | `a1cdef7c` | 7 / 195 | 0 | 🟧🟥 | Same as `feat/2.1`. | **Archive worktree** (clean). |
| `feat/2.1-2111-copy` | `.worktrees/rel-2.1-2111` | `8200a889` 2026-08-06 | `a1cdef7c` | 7 / 197 | 1 | 🟧🟥 | Copy: surface NumPad Type scope + "beta" label in-app / Studio row. | **Archive** (contained). |
| `feat/2.1-ux-owner-polish` | `.worktrees/rel-2.1-ux-owner` | `7cae7147` 2026-08-09 | `a1cdef7c` | 7 / 199 | 1 | 🟧🟥 | **Leaf of the 2.1 product line.** Studio owner UX waves A/B: header, dismissal, pinned preview, height, Studio chrome, one-shot ready hero, Typing rewrite. | **Keep as the reference head** of the unshipped 2.1 (Studio+QWERTY+emoji) line. Do **not** ship as-is (replaces iPhone Home). |
| *(remote)* `origin/codex/qwerty-typing-reliability` | — | `e05a0a06` 2026-09-07 | `a1cdef7c` | 7 / 197 | — | 🟧🟥 | Forks from `feat/2.1-emoji`: QWERTY input reliability, batch counters, CI pod pin, simulator app-group entitlements, "finish purchases without interrupting users". | **Archive** (contained in calibration). |
| *(detached)* `44579547` | `.worktrees/keyboard-calibration` | `44579547` 2026-09-14 | `a1cdef7c` | 7 / 200 | 1 | 🟧🟥 | **Calibration:** full-key calibration + **private swipe training** (`DEBUG && NUMPAD_PRIVATE_SWIPE`, separate app group). 3 commits behind `origin/codex/keyboard-calibration`. | **Archive worktree** (stale vs its own remote). |
| *(remote)* `origin/codex/keyboard-calibration` | — | `3c802b2c` 2026-09-15 | `a1cdef7c` | 7 / 203 | — | 🟧🟥 | +26-tap calibration, then three-natural-sentence calibration + better word suggestions. **Most-advanced QWERTY head.** Note: `qwertyAutocorrectEnabled` default flips to **true** here (false on home-shell). | **Keep as reference head** for QWERTY/calibration. Not shippable on iPhone (Studio root). |
| `james/rel-2.1.1-home-shell-settings` | `.worktrees/rel-2.1.1-home-shell-settings` | `988aaf54` 2026-09-15 | `a1cdef7c` | 7 / 157 | 0 | 🟧 (Studio code present, **not** iPhone root) | Forks from `grok/usability…` (`3a3ed78a`) — i.e. **before** excellence-pass/2.1/emoji/latency. `ea86df25` **restores classic iPhone `HomeViewController` root** with QWERTY settings rows, keeps iPad Studio, restores 2.1.0 monetization copy/storekit; `f6fd17a8` ports tap + private-swipe calibration onto classic Home. Stamped **2.1.1 (16)** — collides with LIVE's 2.1.1 (15). | **Keep** (it's the only "QWERTY on classic Home" candidate). **Do not ship as-is:** not based on LIVE (missing all 7 LIVE commits incl. What's New + 2.1.0 paywall flip), lacks emoji/latency, and **ships QWERTY to Pro users by default** (`isQwertyPageAvailable = fullKeyboardRemoteEnabled(default true) && entitled`; RC default `full_keyboard_enabled: true`). |
| `key/opus-home-shell-harden` | `.worktrees/opus-home-shell-harden` | `988aaf54` (same SHA) | `a1cdef7c` | 7 / 157 | 0 | 🟧 | Same pointer as above; no own commits yet. | Keep while its task is active; else archive (duplicate). |

### 2e. Old, fully merged (0 ahead of LIVE)

| Branch | Tip / date | Behind | Contents | Rec. |
|---|---|---|---|---|
| `feat/2.0-ux-overhaul` (+origin) | `46dad682` 2026-07-06 | 8 | 2.0 UX overhaul, merged into master. ✅ | **Archive.** |
| `feat/2.0` (+origin) | `3f021fcc` 2026-07-03 | 69 | 2.0 base. ✅ | **Archive.** |
| `release/1.8.1` | `0c8441be` 2026-06-21 | 132 | 1.8.1. ✅ | **Archive** (tag first). |
| `release/1.8.0` | `2e65d294` 2026-06-19 | 134 | 1.8.0. ✅ | **Archive** (tag first). |
| `fix/first-run-upsell-trigger` | `940fcacd` 2026-06-19 | 133 | ✅ | **Archive.** |
| `experiment` | `642817a4` 2026-06-15 | 140 | ✅ (origin/experiment `43c2ee5f` differs, also ✅) | **Archive.** |
| `feat/unified-improvements` | `43c2ee5f` 2026-06-14 | 141 | ✅ | **Archive.** |
| `experimental/keyboard-customization` (+origin) | `4ee3ae7d` 2026-06-12 | 166 | ✅ | **Archive.** |

### 2f. Remote-only legacy branches

| Remote branch | Tip / date | Merge-base | B / A | Notes | Rec. |
|---|---|---|---|---|---|
| `origin/claude/ipad-keyboard-switching-fix-30b8q1` | `de00cbea` 2026-06-12 | itself ✅ | 172 / 0 | merged | Archive |
| `origin/fix/review-validation-package` | `cf54c5a6` 2026-06-08 | itself ✅ | 172 / 0 | merged | Archive |
| `origin/improvements/full-review` | `1ad9ae1d` 2026-06-10 | `c88a8994` | 158 / 1 | 1 stray commit on old base | Archive |
| `origin/claude/review-app-code-fMk90` | `7920823f` 2026-02-18 | `19a808c7` (2018) | 194 / 1 | ancient base | Archive |
| `origin/claude/add-claude-documentation-GKqwB` | `86a6f81e` 2026-02-20 | **none** (unrelated history) | – / 271 | pre-rewrite history | Archive |
| `origin/claude/keyboard-height-investigation-CkOOS` | `618137e9` 2026-02-23 | **none** | – / 274 | pre-rewrite history | Archive |
| `origin/New` | `050bb9c8` 2025-08-11 | **none** | – / 268 | pre-rewrite history | Archive |

---

## 3. Explicit flags

### 3a. Replaces iPhone classic Home root with Studio tab bar 🟥
Introduced by **`919876c3`** (`NumPad/Controllers/Base/ViewController.swift` stops instantiating `HomeViewController`; adds `Controllers/Studio/StudioTabBarController.swift` etc.). Present in:
`codex/keyboard-studio-ux`, `grok/usability-qwerty-ipad-kiosk` (main checkout), `codex/ipad-keyboard-width-preview`, `buzz/numpad-revenue-sprint`, `feat/excellence-pass`, `237f8372` (rel-2.1-latency-base), `feat/2.1-latency`, `feat/2.1-emoji`, `feat/2.1-emoji-family-root`, `feat/2.1`, `3e9a1131` (rel-2.1-t7), `feat/2.1-2111-copy`, `feat/2.1-ux-owner-polish`, `origin/codex/qwerty-typing-reliability`, `44579547` (keyboard-calibration worktree), `origin/codex/keyboard-calibration`.
**Reversed (classic Home restored on iPhone, Studio kept for iPad)** only in `james/rel-2.1.1-home-shell-settings` / `key/opus-home-shell-harden` (`ea86df25`).

### 3b. Contains QWERTY 🟧
Everything descending from `feat/full-keyboard-v1` — all of §2d plus `origin/wip/stash-numpad`. LIVE, `master`, `codex/update-notifications`, `feat/onboarding-2`, and the mor-158/161/screenshot branches contain **no** QWERTY files.
Glide decoder ships compiled-in but dark (local flag OFF, forced off in App Store builds) on every 🟧 branch from `feat/qwerty-typing-v2` on.

### 3c. Subscription SKUs 💲
- Only commit adding them: **`fec4ea6b`** (`numpad.pro.sub.monthly`, `numpad.pro.sub.annual` in code + `Products.storekit`). It is in LIVE's history; **`11296b01` removed them** (LIVE comment: "Subscription SKUs intentionally NOT in the shipping catalog … LOCK 2026-09-05").
- **No branch tip** contains those IDs or a non-empty `subscriptionGroups`.
- Dormant plumbing (`Monetization.isProSubscriptionActive`, `Constants.proSubscriptionActive`, `StoreManager` writes it) remains in LIVE and `codex/update-notifications`. Inert without SKUs.

---

## 4. Recommended next steps (owner decisions — nothing done here)

1. **Triage the main checkout first:** `~/NumPad` is on `grok/usability-qwerty-ipad-kiosk` with **48 uncommitted entries**.
2. Fast-forward `master` → `478430f5`; tag `v2.1.0` (`11296b01`) and `v2.1.1` (`478430f5`).
3. Small, safe salvage onto a branch off LIVE: `6e62fb78` (rating prompt), `28640521` (en-AU/GB/CA "FREE" copy), `9fa9150f` (keyboard selection persistence / purchase interruptions), then decide on `154ded03` (first-run upsell off).
4. Decide whether `feat/onboarding-2`'s rev-3 onboarding + `63f6f8e9` hardening sweep should be ported to LIVE (0 of 31 commits are there).
5. If QWERTY is ever to ship: start from `james/rel-2.1.1-home-shell-settings` (classic Home), rebase onto LIVE, cherry-pick latency (`85a6fb5b`, `c7b2ea0e`), emoji (`d68ecf2c..c21914ec`), reliability/calibration (`b1f8bc67..3c802b2c`) — **not** the Studio-root commits — and flip `full_keyboard_enabled` default to false until the gate decision.
6. Archive everything marked "Archive" (all have 0 unique commits beyond the reference heads kept above, or are fully merged). Remove the detached worktrees `rel-2.1-latency-base`, `rel-2.1-t7`, `keyboard-calibration` after checking their 1/0/1 dirty files.
