# NumPad Localization Reference — 2.0 UX Overhaul

Generated 2026-07-03T21:30:38Z from branch `feat/2.0-ux-overhaul`. This is a point-in-time inventory for the translation pass needed after the paywall, custom keyboard, packs, store redesign, kiosk height preset, and upsell-alert work landed with only English strings.

**Scope.** Two independent localization tables exist in this repo (one per Xcode target):
- `NumPad/<locale>.lproj/Localizable.strings` — container app (Home, Store, Packs, Snippets, Privacy, Custom Keyboard editor, Features Guide, Keyboard Height, early-bird/update prompts, etc.)
- `Keyboard/<locale>.lproj/Localizable.strings` — keyboard extension (key labels, accessibility strings, clipboard/snippets/tax-tip/conversion/result-tape overlays, theme & pack names used at keyboard runtime)

`SharedExtensions.swift`, `Keyboard.swift`, and `CustomKeyboard/Handedness.swift` are compiled into **both** targets, so keys they define (theme names, pack names, conversion-category names, etc.) must exist in **both** locale files to avoid a fallback in either surface.

## 1. Locales found in the repo

`15` non-English, non-Base locales have a `Localizable.strings` pair (one under `NumPad/`, one under `Keyboard/`), each with the **same 113 App keys / 40 Keyboard keys** — i.e. every locale is equally stale, none have picked up any 2.0-era key:

| Locale code | `NumPad/<loc>.lproj/Localizable.strings` | `Keyboard/<loc>.lproj/Localizable.strings` |
|---|---|---|
| `ar` | 113 keys defined | 40 keys defined |
| `de` | 113 keys defined | 40 keys defined |
| `es` | 113 keys defined | 40 keys defined |
| `fr` | 113 keys defined | 40 keys defined |
| `he` | 113 keys defined | 40 keys defined |
| `hi` | 113 keys defined | 40 keys defined |
| `it` | 113 keys defined | 40 keys defined |
| `ja` | 113 keys defined | 40 keys defined |
| `ko` | 113 keys defined | 40 keys defined |
| `nl` | 113 keys defined | 40 keys defined |
| `pl` | 113 keys defined | 40 keys defined |
| `pt-PT` | 113 keys defined | 40 keys defined |
| `ru` | 113 keys defined | 40 keys defined |
| `zh-Hans` | 113 keys defined | 40 keys defined |
| `zh-Hant` | 113 keys defined | 40 keys defined |

Excluded from the above (per the task): `en.lproj` (source language) and `Base.lproj` (storyboard/XIB strings, not `Localizable.strings`). Also note `NumPad/zh-HK.lproj/` exists but contains only `Main.strings`/`LaunchScreen.strings` stubs (no `Localizable.strings`), so it is not counted as a Localizable.strings locale. `Pods/SwiftRater/.../*.lproj` locales are vendored third-party resources, out of scope.

## 2. Dead legacy key: `"Symbols"`

English no longer defines `"Symbols"` (renamed to `"Symbols & Science"` — see `NumPad/Libraries/Keyboard.swift` `KeyboardType.title`, used by `PacksViewController` and `FeaturesGuideViewController`). Every one of the 15 non-English **App**-side `Localizable.strings` files still carries the old `"Symbols" = "..."` entry as dead weight; none of the **Keyboard**-side files have it (it was never added there). It is harmless (nothing looks it up any more) but should be deleted during the translation pass so translators don't waste time on it, and so it isn't mistaken for the new key.

| Locale | `NumPad/<loc>.lproj` has dead `"Symbols"` | value | `Keyboard/<loc>.lproj` has it |
|---|---|---|---|
| `ar` | yes | رموز | no |
| `de` | yes | Symbole | no |
| `es` | yes | Símbolos | no |
| `fr` | yes | Symboles | no |
| `he` | yes | סמלים | no |
| `hi` | yes | प्रतीक | no |
| `it` | yes | Simboli | no |
| `ja` | yes | 記号 | no |
| `ko` | yes | 기호 | no |
| `nl` | yes | Symbolen | no |
| `pl` | yes | Symbole | no |
| `pt-PT` | yes | Símbolos | no |
| `ru` | yes | Символы | no |
| `zh-Hans` | yes | 符号 | no |
| `zh-Hant` | yes | 符號 | no |

(`"Symbols & Science"` itself — the current key — is missing from all 15 locales; see the missing-key lists below.)

## 3. Per-locale missing-key counts

"Missing" = present in the English set (derived from `NSLocalizedString(` call sites across `NumPad/` and `Keyboard/`, deduplicated per target) but absent from that locale's file. Since all 15 locale files carry the identical pre-2.0 key set, every locale has the identical miss count.

| Locale | Missing in `NumPad/<loc>.lproj` (of 244 App keys) | Missing in `Keyboard/<loc>.lproj` (of 107 Keyboard keys) | Missing overall (union, of 290 total keys) |
|---|---|---|---|
| `ar` | 146 | 68 | 183 |
| `de` | 146 | 68 | 183 |
| `es` | 146 | 68 | 183 |
| `fr` | 146 | 68 | 183 |
| `he` | 146 | 68 | 183 |
| `hi` | 146 | 68 | 183 |
| `it` | 146 | 68 | 183 |
| `ja` | 146 | 68 | 183 |
| `ko` | 146 | 68 | 183 |
| `nl` | 146 | 68 | 183 |
| `pl` | 146 | 68 | 183 |
| `pt-PT` | 146 | 68 | 183 |
| `ru` | 146 | 68 | 183 |
| `zh-Hans` | 146 | 68 | 183 |
| `zh-Hant` | 146 | 68 | 183 |

**Total missing-key instances across all 15 locales: 2745** (15 × 183 — every locale is missing the same 146 App keys and 68 Keyboard keys, 31 of which overlap between the two tables, hence 146 + 68 − 31 = 183 per locale).

## 4. Authoritative English key → text list

Built by parsing every `NSLocalizedString(` call site under `NumPad/` and `Keyboard/` (Pods excluded), plus 13 dynamically-constructed theme-name keys resolved by reading the code (see §5): **290 unique keys** total across both targets (**244** used by the App target, **107** used by the Keyboard target, **61** shared by both, since a key can appear in either or both call sets).

For each key: if it already has an entry in the corresponding `en.lproj/Localizable.strings`, that entry's value is the English text. If it does not (this is the codebase's convention for not-yet-added strings — `NSLocalizedString` returns the key itself when no table entry exists), the key **is** the English text, flagged `NEW` below (these are exactly the ~2.0 keys the paywall / custom keyboard / packs / store redesign / kiosk height / upsell-alert work introduced today with no localization work done yet).

- App target: 244 keys, of which **145 are `NEW`** (not yet in `NumPad/en.lproj/Localizable.strings` at all).
- Keyboard target: 107 keys, of which **68 are `NEW`** (not yet in `Keyboard/en.lproj/Localizable.strings` at all).

### 4a. App target (`NumPad/<locale>.lproj/Localizable.strings`) — 244 keys

| Key | English text | Shared with other target | Status | Source (first call site) |
|---|---|---|---|---|
| `%@ Keyboard` | %@ Keyboard | no | existing | `NumPad/Libraries/Extensions.swift:115` |
| `%d themes` | %d themes | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:267` |
| `7-8-9 on Top` | 7-8-9 on Top | no | existing | `NumPad/Controllers/HomeViewController.swift:87` |
| `A secure field forces the system keyboard so you can type any character; what you type appears in the preview above. Return moves to the next slot.` | A secure field forces the system keyboard so you can type any character; what you type appears in the preview above. Return moves to the next slot. | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:241` |
| `Add` | Add | no | existing | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:508` |
| `Add a key (up to 4 characters)` | Add a key (up to 4 characters) | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:494` |
| `Add a top row and side columns around the number pad and make them type whatever you want — included in NumPad Pro, along with every pack and premium theme.` | Add a top row and side columns around the number pad and make them type whatever you want — included in NumPad Pro, along with every pack and premium theme. | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:209` |
| `Add a top row and side columns around the number pad, type the keys you want, and choose left- or right-handed. Included with Pro.` | Add a top row and side columns around the number pad, type the keys you want, and choose left- or right-handed. Included with Pro. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:62` |
| `Add at least one key first.` | Add at least one key first. | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:448` |
| `All 5 packs` | All 5 packs | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:265` |
| `All keyboard packs, all premium themes, and every future pack.` | All keyboard packs, all premium themes, and every future pack. | no | existing | `NumPad/Controllers/StoreViewController+Hero.swift:216` |
| `All packs separately: %@. Pro includes everything, forever.` | All packs separately: %@. Pro includes everything, forever. | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:255` |
| `All themes` | All themes | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:268` |
| `Almost done! Turn on the %@ Keyboard by going to Settings and following the steps below.` | Almost done! Turn on the %@ Keyboard by going to Settings and following the steps below. | no | existing | `NumPad/Libraries/Extensions.swift:110` |
| `Amber` | Amber | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Applies on iPhone and iPad. Pinching the keyboard into its floating mini layout always uses the system height.` | Applies on iPhone and iPad. Pinching the keyboard into its floating mini layout always uses the system height. | no | **NEW** | `NumPad/Controllers/KeyboardHeightViewController.swift:36` |
| `Automatic Dark Mode` | Automatic Dark Mode | no | existing | `NumPad/Libraries/Extensions.swift:129` |
| `BEST VALUE` | BEST VALUE | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:265` |
| `Bitwise operators and hex and binary prefixes.` | Bitwise operators and hex and binary prefixes. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:46` |
| `Black` | Black | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Blue` | Blue | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Bottom Right` | Bottom Right | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:270` |
| `Build your own key row — up to 10 keys, 4 characters each.` | Build your own key row — up to 10 keys, 4 characters each. | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:340` |
| `Build your own keyboard` | Build your own keyboard | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:208` |
| `Business` | Business | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:138` |
| `Calculator & result tape` | Calculator & result tape | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:54` |
| `Cancel` | Cancel | no | existing | `NumPad/Controllers/PrivacyViewController.swift:58` |
| `Clear` | Clear | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:230` |
| `Clipboard` | Clipboard | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1010` |
| `Column 1` | Column 1 | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:132` |
| `Column 2` | Column 2 | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:131` |
| `Common symbols alongside scientific constants and operators.` | Common symbols alongside scientific constants and operators. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:42` |
| `Complete the Set` | Complete the Set | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:230` |
| `Configure` | Configure | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:84` |
| `Conversion Overlay` | Conversion Overlay | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:487` |
| `Couldn't reach the App Store. Please check your connection and try again.` | Couldn't reach the App Store. Please check your connection and try again. | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:198` |
| `Currency symbols and finance keys.` | Currency symbols and finance keys. | no | existing | `NumPad/Controllers/FeaturesGuideViewController.swift:44` |
| `Cursor Controls` | Cursor Controls | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:344` |
| `Custom` | Custom | yes | existing | `NumPad/Libraries/Keyboard.swift:130` |
| `Custom Keyboard` | Custom Keyboard | no | **NEW** | `NumPad/Controllers/HomeViewController.swift:128` |
| `Custom Keys` | Custom Keys | no | existing | `NumPad/Controllers/CustomKeysViewController.swift:18` |
| `Custom Pack` | Custom Pack | no | existing | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:351` |
| `Custom key` | Custom key | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:232` |
| `Custom key %1$d: %2$@` | Custom key %1$d: %2$@ | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:482` |
| `Custom key text` | Custom key text | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:255` |
| `Custom keyboard` | Custom keyboard | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:269` |
| `Customizable Keyboard` | Customizable Keyboard | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:59` |
| `Custom…` | Custom… | no | existing | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:228` |
| `Date` | Date | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1002` |
| `Date & Time` | Date & Time | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:136` |
| `Date+Time` | Date+Time | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1004` |
| `Day` | Day | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1005` |
| `Deep Orange` | Deep Orange | yes | existing | `NumPad/Libraries/Keyboard.swift:176` |
| `Deep Purple` | Deep Purple | yes | existing | `NumPad/Libraries/Keyboard.swift:173` |
| `Default` | Default | yes | existing | `NumPad/Libraries/Keyboard.swift:70` |
| `Design your own keyboard` | Design your own keyboard | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:61` |
| `Done` | Done | yes | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:235` |
| `Drag across the space bar to nudge the caret left or right.` | Drag across the space bar to nudge the caret left or right. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:57` |
| `Early-bird: 50% off Pro` | Early-bird: 50% off Pro | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:381` |
| `Edit` | Edit | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:356` |
| `Edit Snippet` | Edit Snippet | no | **NEW** | `NumPad/Controllers/SnippetEditorViewController.swift:88` |
| `Edit slot — uses your phone's keyboard` | Edit slot — uses your phone's keyboard | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:239` |
| `Enable Full Access for click sounds. Nothing you type is tracked.` | Enable Full Access for click sounds. Nothing you type is tracked. | no | existing | `NumPad/Libraries/Extensions.swift:111` |
| `Enable Keyboard` | Enable Keyboard | no | existing | `NumPad/Libraries/Extensions.swift:105` |
| `Enable the keyboard` | Enable the keyboard | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:31` |
| `Enjoying NumPad?` | Enjoying NumPad? | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:205` |
| `Every keyboard pack — finance, symbols, code, math, custom` | Every keyboard pack — finance, symbols, code, math, custom | no | existing | `NumPad/Controllers/StoreViewController+Hero.swift:53` |
| `Every pack, premium themes, the customizable keyboard, iCloud sync, and every future pack.` | Every pack, premium themes, the customizable keyboard, iCloud sync, and every future pack. | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:387` |
| `Every premium theme` | Every premium theme | no | existing | `NumPad/Controllers/StoreViewController+Hero.swift:54` |
| `Everything, forever` | Everything, forever | no | existing | `NumPad/Controllers/FeaturesGuideViewController.swift:67` |
| `Experimental features, off by default. Visible in TestFlight and debug builds only.` | Experimental features, off by default. Visible in TestFlight and debug builds only. | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:319` |
| `Extra tall — for counters & kiosks` | Extra tall — for counters & kiosks | no | **NEW** | `NumPad/Controllers/KeyboardHeightViewController.swift:45` |
| `Fast Delete` | Fast Delete | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:493` |
| `Feature Flags (Beta)` | Feature Flags (Beta) | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:311` |
| `Features & Guide` | Features & Guide | no | **NEW** | `NumPad/Controllers/HomeViewController.swift:150` |
| `Finance` | Finance | yes | existing | `NumPad/Libraries/Keyboard.swift:122` |
| `Free` | Free | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:280` |
| `Free. One-tap operators for everyday arithmetic.` | Free. One-tap operators for everyday arithmetic. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:40` |
| `Full Access` | Full Access | no | existing | `NumPad/Libraries/Extensions.swift:116` |
| `Full Access enables clipboard history, haptics and key sounds. NumPad never logs or transmits what you type.` | Full Access enables clipboard history, haptics and key sounds. NumPad never logs or transmits what you type. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:29` |
| `Get finance, symbols, programmer, math, and custom packs — plus every premium theme.` | Get finance, symbols, programmer, math, and custom packs — plus every premium theme. | no | existing | `NumPad/Controllers/StoreViewController+Hero.swift:194` |
| `Getting Started` | Getting Started | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:28` |
| `Go to Settings` | Go to Settings | no | existing | `NumPad/Libraries/Extensions.swift:112` |
| `Green` | Green | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Grid` | Grid | no | existing | `NumPad/Libraries/Extensions.swift:124` |
| `Handedness` | Handedness | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:95` |
| `Haptics` | Haptics | no | existing | `NumPad/Controllers/StoreViewController.swift:336` |
| `Haptics, key click sounds, and on‑device clipboard history. Clipboard history is stored only on this device and is cleared automatically.` | Haptics, key click sounds, and on‑device clipboard history. Clipboard history is stored only on this device and is cleared automatically. | no | existing | `NumPad/Controllers/PrivacyViewController.swift:36` |
| `Held backspace deletes whole numbers and words` | Held backspace deletes whole numbers and words | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:494` |
| `Hide` | Hide | yes | existing | `NumPad/Libraries/SharedExtensions.swift:1105` |
| `Hold 0 for clipboard history, . for snippets, and % for the tax/tip calculator.` | Hold 0 for clipboard history, . for snippets, and % for the tax/tip calculator. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:53` |
| `ISO` | ISO | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1008` |
| `Indigo` | Indigo | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Inline Calculator` | Inline Calculator | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:342` |
| `Insert a token` | Insert a token | no | **NEW** | `NumPad/Controllers/SnippetEditorViewController.swift:170` |
| `Insert today's date, the time, and more live values.` | Insert today's date, the time, and more live values. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:48` |
| `Inserts this token into the snippet body.` | Inserts this token into the snippet body. | no | **NEW** | `NumPad/Controllers/SnippetEditorViewController.swift:141` |
| `Instructions` | Instructions | no | existing | `NumPad/Libraries/Extensions.swift:104` |
| `International` | International | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:140` |
| `Key Click Sound` | Key Click Sound | no | existing | `NumPad/Controllers/StoreViewController.swift:338` |
| `Keyboard Height` | Keyboard Height | no | existing | `NumPad/Controllers/HomeViewController.swift:79` |
| `Keyboard Packs` | Keyboard Packs | yes | existing | `NumPad/Controllers/HomeViewController.swift:76` |
| `Keyboard packs` | Keyboard packs | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:263` |
| `Keyboards` | Keyboards | no | existing | `NumPad/Libraries/Extensions.swift:114` |
| `Kiosk` | Kiosk | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:72` |
| `Left-handed` | Left-handed | yes | **NEW** | `NumPad/Libraries/CustomKeyboard/Handedness.swift:13` |
| `Length` | Length | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:731` |
| `Light Blue` | Light Blue | yes | existing | `NumPad/Libraries/Keyboard.swift:174` |
| `Light Green` | Light Green | yes | existing | `NumPad/Libraries/Keyboard.swift:175` |
| `Lime` | Lime | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Limited time for early users — everything Pro unlocks, at half price.` | Limited time for early users — everything Pro unlocks, at half price. | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:382` |
| `Locale-Aware Separators` | Locale-Aware Separators | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:484` |
| `Long-press keys` | Long-press keys | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:52` |
| `Make NumPad yours` | Make NumPad yours | no | existing | `NumPad/Controllers/StoreViewController+Hero.swift:196` |
| `Mass` | Mass | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:732` |
| `Math` | Math | yes | existing | `NumPad/Libraries/Keyboard.swift:120` |
| `Math Pack` | Math Pack | no | existing | `NumPad/Libraries/Extensions.swift:125` |
| `Math only` | Math only | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:264` |
| `Middle Right` | Middle Right | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:269` |
| `Month` | Month | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1006` |
| `Move the cursor` | Move the cursor | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:56` |
| `New Snippet` | New Snippet | no | **NEW** | `NumPad/Controllers/SnippetEditorViewController.swift:87` |
| `New custom key` | New custom key | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:507` |
| `No previous purchases were found.` | No previous purchases were found. | no | existing | `NumPad/Controllers/StoreViewController.swift:196` |
| `None` | None | no | existing | `NumPad/Controllers/PacksViewController.swift:18` |
| `Not Now` | Not Now | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:233` |
| `Not now` | Not now | no | **NEW** | `NumPad/Controllers/UpdatesPreprompt.swift:68` |
| `Nothing you type is tracked` | Nothing you type is tracked | no | existing | `NumPad/Libraries/Extensions.swift:117` |
| `NumPad Pro` | NumPad Pro | no | existing | `NumPad/Controllers/HomeViewController.swift:135` |
| `NumPad Pro unlocks the custom keyboard` | NumPad Pro unlocks the custom keyboard | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:65` |
| `NumPad Pro unlocks the custom pack` | NumPad Pro unlocks the custom pack | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:375` |
| `NumPad can send occasional notifications about new features and important updates — and the rare early-bird offer. No spam, ever.` | NumPad can send occasional notifications about new features and important updates — and the rare early-bird offer. No spam, ever. | no | **NEW** | `NumPad/Controllers/UpdatesPreprompt.swift:60` |
| `NumPad never records or transmits what you type. Usage analytics are anonymous and never include typed content.` | NumPad never records or transmits what you type. Usage analytics are anonymous and never include typed content. | no | existing | `NumPad/Controllers/PrivacyViewController.swift:32` |
| `OK` | OK | no | existing | `NumPad/Controllers/StoreViewController.swift:201` |
| `On` | On | no | **NEW** | `NumPad/Controllers/HomeViewController.swift:131` |
| `One-time purchase — no subscription. Tap to view NumPad Pro.` | One-time purchase — no subscription. Tap to view NumPad Pro. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:65` |
| `One-time purchase. No subscription, ever.` | One-time purchase. No subscription, ever. | no | existing | `NumPad/Controllers/StoreViewController+Hero.swift:95` |
| `Only a few hours left to unlock NumPad Pro at half price.` | Only a few hours left to unlock NumPad Pro at half price. | no | **NEW** | `NumPad/Libraries/EarlyBird.swift:112` |
| `Open Link` | Open Link | no | existing | `NumPad/Controllers/PrivacyViewController.swift:55` |
| `Open Settings and go to %@` | Open Settings and go to %@ | no | existing | `NumPad/Libraries/Extensions.swift:106` |
| `Open our policy and contact support in Safari.` | Open our policy and contact support in Safari. | no | existing | `NumPad/Controllers/PrivacyViewController.swift:44` |
| `Orange` | Orange | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Overlays & Gestures` | Overlays & Gestures | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:50` |
| `Packs` | Packs | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:36` |
| `Pick a pack in Keyboard Packs — its extra row appears above the numbers.` | Pick a pack in Keyboard Packs — its extra row appears above the numbers. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:37` |
| `Pick what this key types` | Pick what this key types | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:213` |
| `Pink` | Pink | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Premium theme preview` | Premium theme preview | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:243` |
| `Preview` | Preview | no | existing | `NumPad/Controllers/ThemeViewController.swift:64` |
| `Preview — tap a slot to edit` | Preview — tap a slot to edit | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:122` |
| `Privacy & Full Access` | Privacy & Full Access | no | existing | `NumPad/Controllers/HomeViewController.swift:147` |
| `Privacy Policy` | Privacy Policy | no | existing | `NumPad/Controllers/PrivacyViewController.swift:56` |
| `Privacy Policy and Support` | Privacy Policy and Support | no | existing | `NumPad/Controllers/PrivacyViewController.swift:43` |
| `Pro` | Pro | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:281` |
| `Programmer` | Programmer | yes | existing | `NumPad/Libraries/Keyboard.swift:126` |
| `Programmer+` | Programmer+ | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:142` |
| `Purple` | Purple | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Quick offline unit conversions` | Quick offline unit conversions | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:488` |
| `Rate Me` | Rate Me | no | existing | `NumPad/Libraries/Extensions.swift:126` |
| `Red` | Red | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Repurpose Next Key` | Repurpose Next Key | no | existing | `NumPad/Controllers/StoreViewController.swift:340` |
| `Restore Purchases` | Restore Purchases | no | existing | `NumPad/Controllers/StoreViewController.swift:200` |
| `Result Tape` | Result Tape | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:348` |
| `Reversed` | Reversed | no | existing | `NumPad/Libraries/Extensions.swift:122` |
| `Right-Side Keys` | Right-Side Keys | no | existing | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:153` |
| `Right-handed` | Right-handed | yes | **NEW** | `NumPad/Libraries/CustomKeyboard/Handedness.swift:14` |
| `Rounded` | Rounded | no | existing | `NumPad/Libraries/Extensions.swift:123` |
| `Row 1` | Row 1 | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:115` |
| `Save Snippet From Keyboard` | Save Snippet From Keyboard | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:490` |
| `Save the last result as a snippet` | Save the last result as a snippet | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:491` |
| `Scientific` | Scientific | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:134` |
| `Send Feedback` | Send Feedback | no | existing | `NumPad/Controllers/HomeViewController.swift:153` |
| `Set` | Set | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:256` |
| `Settings` | Settings | no | existing | `NumPad/Libraries/Extensions.swift:113` |
| `Settings ▸ General ▸ Keyboard ▸ Keyboards ▸ Add New Keyboard ▸ NumPad, then turn on Full Access.` | Settings ▸ General ▸ Keyboard ▸ Keyboards ▸ Add New Keyboard ▸ NumPad, then turn on Full Access. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:32` |
| `Small` | Small | yes | existing | `NumPad/Libraries/Keyboard.swift:69` |
| `Smart Pack Defaulting` | Smart Pack Defaulting | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:346` |
| `Snippets` | Snippets | yes | existing | `NumPad/Controllers/HomeViewController.swift:125` |
| `Snippets are reusable text you insert from the keyboard — long-press the . key. Tap a token to drop in a live value.` | Snippets are reusable text you insert from the keyboard — long-press the . key. Tap a token to drop in a live value. | no | **NEW** | `NumPad/Controllers/SnippetsViewController.swift:63` |
| `Something went wrong. Please try again.` | Something went wrong. Please try again. | no | existing | `NumPad/Controllers/StoreViewController.swift:294` |
| `Space` | Space | yes | existing | `NumPad/Libraries/SharedExtensions.swift:1101` |
| `Stay in the loop` | Stay in the loop | no | **NEW** | `NumPad/Controllers/UpdatesPreprompt.swift:59` |
| `Support` | Support | no | existing | `NumPad/Controllers/PrivacyViewController.swift:57` |
| `Switch to NumPad` | Switch to NumPad | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:33` |
| `Symbols & Science` | Symbols & Science | yes | existing | `NumPad/Libraries/Keyboard.swift:124` |
| `Tab` | Tab | yes | existing | `NumPad/Libraries/SharedExtensions.swift:1102` |
| `Tall` | Tall | yes | existing | `NumPad/Libraries/Keyboard.swift:71` |
| `Tap + to create your first snippet.` | Tap + to create your first snippet. | no | **NEW** | `NumPad/Controllers/SnippetsViewController.swift:71` |
| `Tap = to evaluate the expression you typed; long-press return to reuse a recent result.` | Tap = to evaluate the expression you typed; long-press return to reuse a recent result. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:55` |
| `Tap Keyboards` | Tap Keyboards | no | existing | `NumPad/Libraries/Extensions.swift:107` |
| `Tap and hold the 🌐 globe key on any keyboard and choose NumPad.` | Tap and hold the 🌐 globe key on any keyboard and choose NumPad. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:34` |
| `Tax & tip, clipboard history, and every future pack` | Tax & tip, clipboard history, and every future pack | no | existing | `NumPad/Controllers/StoreViewController+Hero.swift:55` |
| `Tax/Tips` | Tax/Tips | yes | existing | `NumPad/Libraries/Keyboard.swift:128` |
| `Teal` | Teal | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Temperature` | Temperature | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:733` |
| `Thanks for being an early user — unlock every pack, the custom keyboard and more at half price. Limited time.` | Thanks for being an early user — unlock every pack, the custom keyboard and more at half price. Limited time. | no | **NEW** | `NumPad/Libraries/EarlyBird.swift:109` |
| `That key is part of NumPad Pro — unlock every pack, theme, and future feature with one purchase.` | That key is part of NumPad Pro — unlock every pack, theme, and future feature with one purchase. | no | existing | `NumPad/Controllers/StoreViewController+Hero.swift:191` |
| `That theme is part of NumPad Pro — unlock every theme, pack, and future feature with one purchase.` | That theme is part of NumPad Pro — unlock every theme, pack, and future feature with one purchase. | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:200` |
| `The extra-tall Kiosk height is part of NumPad Pro — unlock every pack, theme, and future feature with one purchase.` | The extra-tall Kiosk height is part of NumPad Pro — unlock every pack, theme, and future feature with one purchase. | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:203` |
| `Theme` | Theme | no | existing | `NumPad/Libraries/Extensions.swift:121` |
| `Themes` | Themes | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:266` |
| `These keys sit to the right of the number grid. Tap one, then pick what it types. Assign Tab to jump between cells in spreadsheets.` | These keys sit to the right of the number grid. Tap one, then pick what it types. Assign Tab to jump between cells in spreadsheets. | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:155` |
| `Tick Row 1 / Column 1 / Column 2 to add sections. Empty slots show “+”.` | Tick Row 1 / Column 1 / Column 2 to add sections. Empty slots show “+”. | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:124` |
| `Time` | Time | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1003` |
| `Title` | Title | no | existing | `NumPad/Controllers/SnippetEditorViewController.swift:96` |
| `Top Right` | Top Right | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:268` |
| `Try the NumPad keyboard here` | Try the NumPad keyboard here | no | existing | `NumPad/Controllers/Base/ViewController.swift:38` |
| `Turn on %@` | Turn on %@ | no | existing | `NumPad/Libraries/Extensions.swift:108` |
| `Turn on updates` | Turn on updates | no | **NEW** | `NumPad/Controllers/UpdatesPreprompt.swift:77` |
| `Type the key` | Type the key | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:223` |
| `Units & Conversion` | Units & Conversion | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:132` |
| `Unix` | Unix | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1009` |
| `Unlock NumPad Pro — %@` | Unlock NumPad Pro — %@ | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:349` |
| `Unlock every key` | Unlock every key | no | existing | `NumPad/Controllers/StoreViewController+Hero.swift:190` |
| `Unlock every other pack, every premium theme, and the customizable keyboard — upgrade to Pro for just %@ more.` | Unlock every other pack, every premium theme, and the customizable keyboard — upgrade to Pro for just %@ more. | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:231` |
| `Unlock every pack` | Unlock every pack | no | existing | `NumPad/Controllers/StoreViewController+Hero.swift:193` |
| `Unlock every pack and premium theme with a single one-time purchase.` | Unlock every pack and premium theme with a single one-time purchase. | no | existing | `NumPad/Controllers/StoreViewController+Hero.swift:197` |
| `Unlock every theme` | Unlock every theme | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:199` |
| `Unlock the Kiosk height` | Unlock the Kiosk height | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:202` |
| `Unlock with NumPad Pro` | Unlock with NumPad Pro | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:69` |
| `Unlocked` | Unlocked | no | existing | `NumPad/Controllers/HomeViewController.swift:137` |
| `Unlocks every pack, the customizable keyboard, premium themes, iCloud sync, and all future packs.` | Unlocks every pack, the customizable keyboard, premium themes, iCloud sync, and all future packs. | no | **NEW** | `NumPad/Controllers/FeaturesGuideViewController.swift:68` |
| `Up to 4 characters` | Up to 4 characters | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:247` |
| `Upgrade` | Upgrade | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:234` |
| `Use this pack on the keyboard` | Use this pack on the keyboard | no | **NEW** | `NumPad/Libraries/Customization/Editor/CustomKeysView.swift:446` |
| `Use your region's decimal separator` | Use your region's decimal separator | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:485` |
| `Waiting for Approval` | Waiting for Approval | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:209` |
| `We do not log keystrokes` | We do not log keystrokes | no | existing | `NumPad/Controllers/PrivacyViewController.swift:31` |
| `What Full Access enables` | What Full Access enables | no | existing | `NumPad/Controllers/PrivacyViewController.swift:35` |
| `Which side the customizable columns sit on. The digits, delete, return and 🌐 keys stay fixed.` | Which side the customizable columns sit on. The digits, delete, return and 🌐 keys stay fixed. | no | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:102` |
| `White` | White | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Why iOS shows a warning` | Why iOS shows a warning | no | existing | `NumPad/Controllers/PrivacyViewController.swift:39` |
| `Year` | Year | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1007` |
| `Yellow` | Yellow | yes | existing | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `You own NumPad Pro — thank you for supporting indie development.` | You own NumPad Pro — thank you for supporting indie development. | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:73` |
| `You're looking at NumPad Pro — every pack, every premium theme, and the customizable keyboard, unlocked with one purchase.` | You're looking at NumPad Pro — every pack, every premium theme, and the customizable keyboard, unlocked with one purchase. | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:212` |
| `Your 50% off ends soon` | Your 50% off ends soon | no | **NEW** | `NumPad/Libraries/EarlyBird.swift:111` |
| `Your early-bird 50% off NumPad Pro` | Your early-bird 50% off NumPad Pro | no | **NEW** | `NumPad/Libraries/EarlyBird.swift:108` |
| `Your expanded snippet appears here.` | Your expanded snippet appears here. | no | **NEW** | `NumPad/Controllers/SnippetEditorViewController.swift:258` |
| `Your purchase needs approval and will unlock automatically once it's approved.` | Your purchase needs approval and will unlock automatically once it's approved. | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:210` |
| `Your purchases have been restored.` | Your purchases have been restored. | no | existing | `NumPad/Controllers/StoreViewController.swift:194` |
| `iCloud Sync` | iCloud Sync | no | **NEW** | `NumPad/Controllers/StoreViewController.swift:428` |
| `iCloud sync` | iCloud sync | no | **NEW** | `NumPad/Controllers/StoreViewController+Hero.swift:270` |
| `iOS shows a generic message for all third‑party keyboards.` | iOS shows a generic message for all third‑party keyboards. | no | existing | `NumPad/Controllers/PrivacyViewController.swift:40` |

### 4b. Keyboard target (`Keyboard/<locale>.lproj/Localizable.strings`) — 107 keys

| Key | English text | Shared with other target | Status | Source (first call site) |
|---|---|---|---|---|
| `Amber` | Amber | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Amount` | Amount | no | existing | `Keyboard/Views/TaxTipView.swift:36` |
| `Bit shift left` | Bit shift left | no | existing | `Keyboard/Views/Cell.swift:74` |
| `Bit shift right` | Bit shift right | no | existing | `Keyboard/Views/Cell.swift:75` |
| `Black` | Black | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Blue` | Blue | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Business` | Business | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:138` |
| `Clear All` | Clear All | no | existing | `Keyboard/Views/ClipboardHistoryView.swift:37` |
| `Clipboard` | Clipboard | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1010` |
| `Clipboard History` | Clipboard History | no | existing | `Keyboard/Views/ClipboardHistoryView.swift:33` |
| `Clipboard history is turned off. Turn it on in the NumPad app.` | Clipboard history is turned off. Turn it on in the NumPad app. | no | existing | `Keyboard/Views/ClipboardHistoryView.swift:101` |
| `Close` | Close | no | existing | `Keyboard/Views/PackPickerView.swift:38` |
| `Continue` | Continue | no | **NEW** | `Keyboard/KeyboardViewController.swift:719` |
| `Conversion Overlay` | Conversion Overlay | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:487` |
| `Convert` | Convert | no | **NEW** | `Keyboard/Views/ConversionView.swift:31` |
| `Custom` | Custom | yes | existing | `NumPad/Libraries/Keyboard.swift:130` |
| `Date` | Date | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1002` |
| `Date & Time` | Date & Time | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:136` |
| `Date+Time` | Date+Time | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1004` |
| `Day` | Day | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1005` |
| `Deep Orange` | Deep Orange | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:176` |
| `Deep Purple` | Deep Purple | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:173` |
| `Default` | Default | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:70` |
| `Delete` | Delete | no | existing | `Keyboard/Views/Cell.swift:68` |
| `Done` | Done | yes | **NEW** | `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift:235` |
| `Double tap and hold for clipboard history` | Double tap and hold for clipboard history | no | existing | `Keyboard/KeyboardViewController.swift:401` |
| `Double tap and hold for snippets` | Double tap and hold for snippets | no | existing | `Keyboard/KeyboardViewController.swift:409` |
| `Double tap and hold for the tax and tip calculator` | Double tap and hold for the tax and tip calculator | no | existing | `Keyboard/KeyboardViewController.swift:417` |
| `Enable Full Access in Settings to use clipboard history.` | Enable Full Access in Settings to use clipboard history. | no | existing | `Keyboard/Views/ClipboardHistoryView.swift:104` |
| `Enter` | Enter | no | existing | `Keyboard/Libraries/Extensions.swift:102` |
| `Fast Delete` | Fast Delete | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:493` |
| `Finance` | Finance | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:122` |
| `Go` | Go | no | **NEW** | `Keyboard/KeyboardViewController.swift:712` |
| `Green` | Green | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Held backspace deletes whole numbers and words` | Held backspace deletes whole numbers and words | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:494` |
| `Hexadecimal prefix` | Hexadecimal prefix | no | existing | `Keyboard/Views/Cell.swift:73` |
| `Hide` | Hide | yes | existing | `NumPad/Libraries/SharedExtensions.swift:1105` |
| `ISO` | ISO | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1008` |
| `Indigo` | Indigo | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Insert` | Insert | no | existing | `Keyboard/Views/TaxTipView.swift:48` |
| `International` | International | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:140` |
| `Join` | Join | no | **NEW** | `Keyboard/KeyboardViewController.swift:717` |
| `Keyboard Packs` | Keyboard Packs | yes | existing | `NumPad/Controllers/HomeViewController.swift:76` |
| `Kiosk` | Kiosk | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:72` |
| `Left-handed` | Left-handed | yes | **NEW** | `NumPad/Libraries/CustomKeyboard/Handedness.swift:13` |
| `Length` | Length | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:731` |
| `Light Blue` | Light Blue | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:174` |
| `Light Green` | Light Green | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:175` |
| `Lime` | Lime | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Locale-Aware Separators` | Locale-Aware Separators | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:484` |
| `Mass` | Mass | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:732` |
| `Math` | Math | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:120` |
| `Month` | Month | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1006` |
| `More symbols` | More symbols | no | existing | `Keyboard/Views/Cell.swift:69` |
| `Next` | Next | no | **NEW** | `Keyboard/KeyboardViewController.swift:716` |
| `Next Keyboard` | Next Keyboard | no | **NEW** | `Keyboard/KeyboardViewController.swift:393` |
| `Next keyboard` | Next keyboard | no | existing | `Keyboard/Views/Cell.swift:67` |
| `No clipboard items yet. Copy something, then long-press 0.` | No clipboard items yet. Copy something, then long-press 0. | no | existing | `Keyboard/Views/ClipboardHistoryView.swift:106` |
| `No results yet. Tap = to calculate, then your results appear here.` | No results yet. Tap = to calculate, then your results appear here. | no | **NEW** | `Keyboard/Views/ResultTapeView.swift:47` |
| `No snippets yet. Add snippets in the NumPad app.` | No snippets yet. Add snippets in the NumPad app. | no | existing | `Keyboard/Views/SnippetsListView.swift:52` |
| `No snippets yet. Tap + to save your last result, or add snippets in the NumPad app.` | No snippets yet. Tap + to save your last result, or add snippets in the NumPad app. | no | **NEW** | `Keyboard/Views/SnippetsListView.swift:51` |
| `Orange` | Orange | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Pin` | Pin | no | existing | `Keyboard/Views/ClipboardHistoryView.swift:162` |
| `Pink` | Pink | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Pinned` | Pinned | no | existing | `Keyboard/Views/ClipboardHistoryView.swift:137` |
| `Plus or minus` | Plus or minus | no | existing | `Keyboard/Views/Cell.swift:76` |
| `Programmer` | Programmer | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:126` |
| `Programmer+` | Programmer+ | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:142` |
| `Purple` | Purple | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Quick offline unit conversions` | Quick offline unit conversions | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:488` |
| `Recent Results` | Recent Results | no | **NEW** | `Keyboard/Views/ResultTapeView.swift:26` |
| `Red` | Red | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Right-handed` | Right-handed | yes | **NEW** | `NumPad/Libraries/CustomKeyboard/Handedness.swift:14` |
| `Route` | Route | no | **NEW** | `Keyboard/KeyboardViewController.swift:718` |
| `Save Snippet From Keyboard` | Save Snippet From Keyboard | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:490` |
| `Save last result as snippet` | Save last result as snippet | no | **NEW** | `Keyboard/Views/SnippetsListView.swift:39` |
| `Save the last result as a snippet` | Save the last result as a snippet | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:491` |
| `Scientific` | Scientific | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:134` |
| `Search` | Search | no | **NEW** | `Keyboard/KeyboardViewController.swift:713` |
| `Send` | Send | no | **NEW** | `Keyboard/KeyboardViewController.swift:714` |
| `Show clipboard history` | Show clipboard history | no | existing | `Keyboard/KeyboardViewController.swift:402` |
| `Show snippets` | Show snippets | no | existing | `Keyboard/KeyboardViewController.swift:410` |
| `Show tax and tip calculator` | Show tax and tip calculator | no | existing | `Keyboard/KeyboardViewController.swift:418` |
| `Small` | Small | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:69` |
| `Snippets` | Snippets | yes | existing | `NumPad/Controllers/HomeViewController.swift:125` |
| `Space` | Space | yes | existing | `NumPad/Libraries/SharedExtensions.swift:1101` |
| `Symbols & Science` | Symbols & Science | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:124` |
| `TAX/TIP` | TAX/TIP | no | existing | `Keyboard/Views/TaxTipView.swift:32` |
| `Tab` | Tab | yes | existing | `NumPad/Libraries/SharedExtensions.swift:1102` |
| `Tall` | Tall | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:71` |
| `Tax` | Tax | no | existing | `Keyboard/Views/TaxTipView.swift:54` |
| `Tax/Tips` | Tax/Tips | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:128` |
| `Teal` | Teal | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Temperature` | Temperature | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:733` |
| `Time` | Time | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1003` |
| `Tip` | Tip | no | existing | `Keyboard/Views/TaxTipView.swift:55` |
| `Tip only` | Tip only | no | existing | `Keyboard/Views/TaxTipView.swift:17` |
| `Total` | Total | no | existing | `Keyboard/Views/TaxTipView.swift:16` |
| `Units & Conversion` | Units & Conversion | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:132` |
| `Unix` | Unix | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1009` |
| `Unlock` | Unlock | no | existing | `Keyboard/Libraries/Extensions.swift:104` |
| `Unpin` | Unpin | no | existing | `Keyboard/Views/ClipboardHistoryView.swift:161` |
| `Use your region's decimal separator` | Use your region's decimal separator | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:485` |
| `White` | White | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `Year` | Year | yes | **NEW** | `NumPad/Libraries/SharedExtensions.swift:1007` |
| `Yellow` | Yellow | yes | **NEW** | `NumPad/Libraries/Keyboard.swift:177 (dynamic: rawValue.capitalized)` |
| `locked` | locked | no | existing | `Keyboard/Views/StackView.swift:70` |

## 5. Methodology & caveats

- Key extraction: a small parser walked every `.swift` file under `NumPad/` and `Keyboard/` (excluding `Pods/`) looking for `NSLocalizedString(` call sites and capturing the first string literal argument (334 call sites → 277 distinct string-literal keys).
- One call site is **not** a string literal and had to be resolved by reading the code: `NumPad/Libraries/Keyboard.swift:177`, `KeyboardTheme.name`'s `default:` branch does `NSLocalizedString(rawValue.capitalized, comment: "")`. The 13 `KeyboardTheme` cases that fall through to that branch (`white, black, red, pink, purple, indigo, blue, teal, green, lime, yellow, amber, orange` — the other 4 cases `deepPurple/lightBlue/lightGreen/deepOrange` have explicit literal cases) were added to the key list manually as `White, Black, Red, Pink, Purple, Indigo, Blue, Teal, Green, Lime, Yellow, Amber, Orange` (290 keys total after adding these).
- Target assignment (App vs Keyboard vs both) is by source file, cross-checked against `NumPad.xcodeproj/project.pbxproj`'s `Sources` build phases: files under `Keyboard/` → Keyboard target; files under `NumPad/` → App target; `NumPad/Libraries/SharedExtensions.swift`, `NumPad/Libraries/Keyboard.swift`, and `NumPad/Libraries/CustomKeyboard/Handedness.swift` are compiled into **both** targets (confirmed in the project file) so their keys are required in both locale tables.
- Orphan check (bonus, not requested but flagged for awareness): `NumPad/en.lproj/Localizable.strings` has 14 keys with **no current call site** (e.g. `"Add Key…"`, `"Bottom Right Key"`, `"Custom Key"`, `"Finance Pack"`, `"Save"`) — likely leftovers from the older, still-present-but-unsurfaced Custom Keys screen (`CustomKeysViewController.swift`) before the new `CustomKeysView.swift`/Custom Keyboard editor superseded its copy. `Keyboard/en.lproj/Localizable.strings` has one such orphan: `"Delta"`. These aren't part of the missing-key counts above (they're already localized) and don't need translator attention, but they're candidates for cleanup in a future pass.
- No `.strings` files were modified. Nothing was committed.
