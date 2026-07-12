# Glide Typing (Dark) + QWERTY Accuracy Stack — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship the three QWERTY accuracy improvements (frequency-lexicon re-ranking, personal
dictionary, per-key touch offsets) and a dark, flag-gated glide-typing decoder, per
`2026-07-12-glide-and-accuracy-design.md`.

**Architecture:** Every new algorithm is a pure module in `NumPad/Libraries/Qwerty/` (compiled
into app + Keyboard targets, unit-tested in `NumPadTests`); the Keyboard extension gets thin
glue in `QwertyPageHost`/`QwertyKeyboardView`. One bundled packed lexicon
(`qwerty_lexicon_en.bin`, built by an in-repo Swift tool that reuses the module's own encoder,
so the format can never drift) powers both the re-ranker and the glide decoder.

**Tech Stack:** Swift/UIKit, XCTest (`NumPadTests`), CocoaPods workspace, classic pbxproj
managed via the `xcodeproj` Ruby gem (NOT synchronized groups — memory note), Hermit Dave
`FrequencyWords` corpus (MIT/CC BY-SA 4.0).

**Verify commands** (long runs: detach via `nohup … &` and tail the log — harness kills long
foreground xcodebuild):

```bash
# Unit tests only (fast path used throughout):
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,name=QA-iPhone17' \
  -only-testing:NumPadTests 2>&1 | tail -30
```

---

## Task 1: Lexicon data + packed binary format + `QwertyFrequencyLexicon`

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyFrequencyLexicon.swift`
- Create: `NumPadTests/QwertyFrequencyLexiconTests.swift`
- Create: `tools/make_qwerty_lexicon.swift`
- Create: `tools/data/en_50k.txt` (downloaded corpus, committed for reproducibility)
- Create: `Keyboard/Resources/qwerty_lexicon_en.bin` (generated)

**Packed format** (little-endian):

```
"NPLX" (4 bytes) | version UInt8 = 1 | count UInt32
offsets: count × UInt32           (byte offset of each record, from file start)
records (sorted by UTF-8 byte order of word):
  length UInt8 | word UTF-8 bytes | rank UInt16   (rank = corpus line index, 0 = most frequent)
```

Binary search runs over the offset table comparing raw UTF-8 bytes — the `Data` blob itself is
the resident structure (~700KB), never inflated into a `Dictionary`.

**Step 1: Write the failing tests** — `NumPadTests/QwertyFrequencyLexiconTests.swift`:

```swift
import XCTest
@testable import NumPad

final class QwertyFrequencyLexiconTests: XCTestCase {

    private var lexicon: QwertyFrequencyLexicon!

    override func setUp() {
        super.setUp()
        // encode() is the same encoder the offline tool uses — round-trip by construction.
        let data = QwertyFrequencyLexicon.encode(rankedWords: ["the", "of", "and", "hello", "world"])
        lexicon = QwertyFrequencyLexicon(data: data)
    }

    func testRankLookupReturnsCorpusOrder() {
        XCTAssertEqual(lexicon.rank(of: "the"), 0)
        XCTAssertEqual(lexicon.rank(of: "world"), 4)
        XCTAssertNil(lexicon.rank(of: "zzzz"))
    }

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(lexicon.rank(of: "The"), 0)
        XCTAssertEqual(lexicon.rank(of: "HELLO"), 3)
    }

    func testRerankOrdersKnownByRankUnknownLastStable() {
        let out = lexicon.rerank(["world", "quix", "the", "zorp", "and"])
        XCTAssertEqual(out, ["the", "and", "world", "quix", "zorp"])  // quix/zorp keep input order
    }

    func testEmptyAndCorruptDataAreSafe() {
        XCTAssertNil(QwertyFrequencyLexicon(data: Data()).rank(of: "the"))
        XCTAssertNil(QwertyFrequencyLexicon(data: Data([0x00, 0x01])).rank(of: "the"))
    }

    func testWordsIteratesEveryEntryInByteOrder() {
        XCTAssertEqual(QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["b", "a"])).allWords().sorted(),
            ["a", "b"])
    }
}
```

**Step 2: Run tests, verify FAIL** (type doesn't exist — build error is the failure).

**Step 3: Implement** `NumPad/Libraries/Qwerty/QwertyFrequencyLexicon.swift` (pure, Foundation
only). Key points:

- `init(data: Data)` validates magic/version/count/bounds; invalid → empty lexicon (never
  crashes on corrupt bundle data — validate at the boundary).
- `rank(of word: String) -> Int?` lowercases, UTF-8 bytes, binary search over offset table.
- `rerank(_ candidates: [String]) -> [String]` — stable: sort by `(rank ?? Int.max, inputIndex)`.
- `allWords() -> [String]` — sequential record walk (used by the glide decoder load and tests).
- `static func encode(rankedWords: [String]) -> Data` — lowercases, dedupes (first occurrence
  wins), sorts records by UTF-8 bytes, writes the format above. Used by tests AND the tool.

**Step 4: Add the new files to the Xcode project** (classic pbxproj — use the gem):

```bash
gem list xcodeproj || sudo gem install xcodeproj
ruby - <<'RUBY'
require 'xcodeproj'
project = Xcodeproj::Project.open('NumPad.xcodeproj')
app = project.targets.find { |t| t.name == 'NumPad' }
kb  = project.targets.find { |t| t.name == 'Keyboard' }
tests = project.targets.find { |t| t.name == 'NumPadTests' }
qwerty = project.main_group.find_subpath('NumPad/Libraries/Qwerty', false)
f = qwerty.new_file('QwertyFrequencyLexicon.swift')
[app, kb].each { |t| t.source_build_phase.add_file_reference(f) }
tg = project.main_group.find_subpath('NumPadTests', false)
tf = tg.new_file('QwertyFrequencyLexiconTests.swift')
tests.source_build_phase.add_file_reference(tf)
project.save
RUBY
```

**Step 5: Run tests, verify PASS.**

**Step 6: Build the corpus + binary.** Download (622,749 bytes expected):

```bash
mkdir -p tools/data Keyboard/Resources
curl -fsSL -o tools/data/en_50k.txt \
  https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/en/en_50k.txt
wc -c tools/data/en_50k.txt
```

`tools/make_qwerty_lexicon.swift` — a `main`-style script: reads `word count` lines in corpus
order, filters to words matching `^[a-z'-]+$` of length 1–24, calls
`QwertyFrequencyLexicon.encode(rankedWords:)`, writes the output path. Compile it *with* the
module file so the encoder is shared:

```bash
swiftc -o /tmp/mklex tools/make_qwerty_lexicon.swift NumPad/Libraries/Qwerty/QwertyFrequencyLexicon.swift
/tmp/mklex tools/data/en_50k.txt Keyboard/Resources/qwerty_lexicon_en.bin
ls -la Keyboard/Resources/qwerty_lexicon_en.bin   # expect roughly 600–750KB
```

Add the resource to the Keyboard target (resources phase, `Keyboard/Resources` group) via the
same gem pattern (`kb.resources_build_phase.add_file_reference(...)`).

**Step 7: Commit** — `feat: packed frequency lexicon module + build tooling + bundled en_50k`.

---

## Task 2: Wire re-ranking into the suggestion pipeline

**Files:**
- Modify: `Keyboard/Libraries/QwertyPageHost.swift` (lexicon property, `refreshSuggestions()`,
  `applyPendingCorrection()`)
- Modify: `NumPadTests/QwertyAutocorrectTests.swift` (ordering-through-rerank cases)

**Step 1: Failing test** — assert that re-ranked completions flow through
`QwertyAutocorrect.suggestions` in frequency order:

```swift
func testSuggestionsPreserveRerankedCompletionOrder() {
    let lexicon = QwertyFrequencyLexicon(
        data: QwertyFrequencyLexicon.encode(rankedWords: ["hello", "helm", "held"]))
    let reranked = lexicon.rerank(["held", "helm", "hello"])   // alphabetical, as UITextChecker returns
    let out = QwertyAutocorrect.suggestions(word: "hel", guesses: [], completions: reranked)
    XCTAssertEqual(out, [.literal("hel"), .candidate("hello"), .candidate("helm")])
}
```

**Step 2–4:** Implement in `QwertyPageHost`: a lazy
`private let frequencyLexicon = QwertyFrequencyLexicon(bundled: .main)` (add a convenience
`init(bundled:)` that loads `qwerty_lexicon_en.bin` from the given bundle, empty on absence —
tests/app target don't carry the resource). In `refreshSuggestions()` and
`applyPendingCorrection()`, pass `frequencyLexicon.rerank(analysis.guesses)` /
`rerank(analysis.completions)` everywhere the raw arrays flow today (four call sites total).
The touch-bias call keeps receiving the re-ranked completions — better bias for free.

**Step 5: Run full unit suite, verify green. Commit** —
`feat: frequency re-ranking of guesses/completions (fixes alphabetical completions)`.

---

## Task 3: `QwertyPersonalDictionary` (learned words)

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyPersonalDictionary.swift`
- Create: `NumPadTests/QwertyPersonalDictionaryTests.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyAutocorrect.swift` (`decide` protection +
  personal-first suggestion ordering)
- Modify: `NumPadTests/QwertyAutocorrectTests.swift`
- Modify: `NumPad/Libraries/SharedExtensions.swift` (`Constants.qwertyPersonalDictionary` key +
  storage accessor)
- Modify: `Keyboard/Libraries/QwertyPageHost.swift` (record on boundary/chip-tap; consult in
  decide/suggestions)
- Modify: `NumPad/Controllers/QwertySetupViewController.swift` (Reset Typing Personalization row)

**Pure model (test-first):**

```swift
struct QwertyPersonalDictionary: Codable, Equatable {
    private(set) var counts: [String: Int] = [:]
    private(set) var recordingsSinceDecay = 0

    static let capacity = 1_500
    static let decayInterval = 2_000      // recordings between halvings (tuned up from 200
                                          // in review — see design §2 decay tuning)
    static let protectionThreshold = 3    // count at which a word is "known"

    mutating func recordAcceptance(of word: String)   // lowercase; letters/'/- only, length 2–24
    func boost(for word: String) -> Int               // 0 when absent
    func isKnown(_ word: String) -> Bool              // count >= protectionThreshold
}
```

Behaviors under test: counting; ignoring numbers/single letters/junk; decay halves all counts
and drops zeros every `decayInterval` recordings; eviction removes the lowest-count entry at
capacity; round-trips through `Codable`.

**Ranking + protection (test-first), in `QwertyAutocorrect`:**

- `decide(word:isMisspelled:guesses:userRejected:isUserKnownWord: Bool = false)` — new guard
  `guard !isUserKnownWord else { return .keep }` before the misspelling check.
- New pure hook `rankCandidates(_ candidates: [String], personalBoost: (String) -> Int) ->
  [String]` — stable sort, higher boost first, zero-boost items keep their (already
  frequency-ranked) order. Applied to guesses+completions in `suggestions` call sites, not
  inside `suggestions` itself (its literal-first/dedupe contract is untouched).

**Glue:** `QwertyPageHost` holds a `QwertyPersonalDictionary` loaded from
`UserDefaults.group` (new `Constants.qwertyPersonalDictionary` raw-`Data` key, JSON-coded;
follow the `@UserDefault` pattern), saves after mutation, records on: (a) boundary insertion
whose word was NOT auto-corrected, (b) suggestion-chip candidate/literal tap. Consults
`isKnown` in `applyPendingCorrection` and `boost(for:)` in `refreshSuggestions`. **Privacy:**
no `SettingsSync.post()` for dictionary writes, no analytics, no export path (design §2).

**Reset row:** read `QwertySetupViewController` first and follow its existing row pattern —
add "Reset Typing Personalization" (destructive style, confirmation alert) clearing this key
AND the Task-4 offsets key.

**Commit** — `feat: personal dictionary — learned words rank first, never auto-corrected`.

---

## Task 4: Per-key touch offsets

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyTouchPersonalization.swift`
- Create: `NumPadTests/QwertyTouchPersonalizationTests.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyTouchRouting.swift` (`offsets` parameter)
- Modify: `NumPadTests/QwertyTouchRoutingTests.swift`
- Modify: `Keyboard/Views/QwertyKeyboardView.swift` (tap-location capture, offsets feed)
- Modify: `Keyboard/Libraries/QwertyPageHost.swift` (commit-on-next-keystroke acceptance)
- Modify: `NumPad/Libraries/SharedExtensions.swift` (`Constants.qwertyTouchOffsets` key)

**Pure model:** per-key EMA offset in key-size-normalized units, keyed by base character:

```swift
struct QwertyTouchPersonalization: Codable, Equatable {
    struct Offset: Codable, Equatable { var dx: Double; var dy: Double; var samples: Int }
    private(set) var offsets: [String: Offset] = [:]
    static let smoothing = 0.2            // EMA alpha
    static let warmupSamples = 5          // no output until a key has this many samples

    mutating func recordAcceptedTap(keyCharacter: String, normalizedOffset: (dx: Double, dy: Double))
    func offset(forKeyCharacter: String) -> (dx: Double, dy: Double)?  // nil during warmup
}
```

Tests: EMA convergence toward a constant bias; warmup returns nil; `Codable` round-trip.

**Routing change (test-first in `QwertyTouchRoutingTests`):**
`keyIndex(at:keyFrames:in:bias:offsets:)` gains `offsets: [Int: CGVector] = [:]` (view-space,
per key index). Rule: **direct hits on true frames still win first** (invariant test:
an offset never steals a direct hit); gap resolution measures edge distance to
`frame.offsetBy(dx:dy:)` with magnitude clamped to `0.3 × min(frame.width, frame.height)`
(`offsetDistanceCap`, same philosophy as `biasDistanceCap`). New tests: an offset flips an
equidistant gap point; the cap bounds a huge learned offset; empty model reproduces every
existing test's result (run the whole existing file unchanged — that IS the regression test).

**Glue:** `QwertyKeyboardView.makeButton` adds a `.touchDown` target capturing the touch
location via the `(sender:event:)` action form; the view exposes
`lastTouchOffset(for button:)` (normalized to the key frame). `QwertyPageHost` buffers
`(character, offset)` per character tap and commits it to the model **on the next non-backspace
key event** (backspace discards the buffer — the cheap acceptance proxy from the research);
persisted like Task 3, cleared by the same reset row. The view rebuilds its `offsets` map
(character → key-index → view-space `CGVector`) whenever the grid or the model changes.

**Commit** — `feat: per-key mean-offset touch personalization (capped bias channel)`.

---

## Task 5: Glide feature flags (dark gate)

**Files:**
- Modify: `NumPad/Libraries/SharedExtensions.swift` — `Constants.ffQwertyGlideTyping` +
  `Constants.qwertyGlideRemoteEnabled`; `FeatureFlags`: stored flag via `effective()` (the ff*
  experimental pattern — forces OFF in App Store builds by construction, which is exactly the
  "dark" posture), remote mirror defaulting `true`, pure combinator
  `glideTypingActive(remoteEnabled:localEnabled:)`, convenience `isGlideTypingActive`, Beta row
  in `FeatureFlags.all` ("Glide Typing (Experimental)").
- Modify: `RemoteConfigManager` — `qwerty_glide_typing_enabled` default `true` in
  `configureDefaults()` + mirror step (copy `mirrorFullKeyboardKillSwitch` exactly).
- Test: `NumPadTests/QwertyGatingTests.swift` — combinator truth table.

TDD the combinator; the rest is mechanical pattern-following. **Commit** —
`feat: qwerty glide typing flag pair (dark: local OFF default, RC kill switch)`.

---

## Task 6: `QwertyGlidePath` — pure gesture geometry

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyGlidePath.swift`
- Create: `NumPadTests/QwertyGlidePathTests.swift`

```swift
enum QwertyGlidePath {
    static let sampleCount = 48
    static func resample(_ points: [CGPoint], to count: Int = sampleCount) -> [CGPoint]
    static func pathLength(_ points: [CGPoint]) -> CGFloat
    static func normalized(_ points: [CGPoint]) -> [CGPoint]   // translate to centroid origin,
                                                               // scale by max(bbox.w, bbox.h) (SHARK2 shape channel)
    static func channelDistance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat  // mean point-to-point
}
```

Tests (all synthetic): resampling a 2-point segment yields `count` uniformly spaced points;
resampling is idempotent on already-uniform paths; single-point/empty inputs are safe (repeat
the point / return empty); `normalized` is translation- and scale-invariant
(`channelDistance(normalized(p), normalized(p × 3 + shift)) ≈ 0`); degenerate zero-extent paths
don't divide by zero. **Commit** — `feat: pure glide path geometry (resample/normalize/distance)`.

---

## Task 7: `QwertyGlideDecoder` — pruning + two-channel scoring

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyGlideDecoder.swift`
- Create: `NumPadTests/QwertyGlideDecoderTests.swift`

```swift
struct QwertyGlideDecoder {
    /// keyCenters: rendered letter-key centers (view space), lowercased character → center.
    /// words: letter-only lexicon entries with ranks, prepared once per layout.
    init(keyCenters: [String: CGPoint], lexicon: QwertyFrequencyLexicon)

    struct Candidate: Equatable { let word: String; let score: CGFloat }  // lower = better
    func decode(path: [CGPoint], maxCandidates: Int = 3) -> [Candidate]
}
```

Implementation contract (SHARK2 lineage, clean-room from the published description —
research §2.1/§4.2):

1. **Prepare once:** filter `lexicon.allWords()` to words whose every letter has a key center
   (drops `'`/`-` words on the letters layer); keep `(word, rank, firstKey, lastKey,
   idealLength)` where `idealLength = pathLength(key-center polyline)`.
2. **Prune:** gesture start/end points must land within `1.6 × interKeyPitch` of the word's
   first/last key centers (pitch = min distance between two distinct centers); ideal-vs-gesture
   path-length ratio within `[0.4, 2.2]`. Single-letter words pass when start≈end≈that key.
3. **Score survivors:** ideal template = key-center polyline resampled to 48 (generated on the
   fly, discarded after — no stored templates); `shape = channelDistance(normalized(g),
   normalized(t))`; `location = channelDistance(resampled g, t)` scaled by `1/pitch` so the two
   channels are comparable; `combined = 0.5·shape + 0.5·location`.
4. **Frequency integration:** `score = combined × (0.7 + 0.6 × rank/50_000)` — top-ranked words
   get up to a ~1.86× advantage over rank-50k words; constants are named `Tuning` statics.
5. Return the `maxCandidates` lowest scores.

Tests (synthetic 3-row grid of key centers built in-test, not from `QwertyLayout` — the decoder
must not care where centers come from):

- The ideal polyline for "hello" decodes to "hello" as candidate 0 (lexicon: hello/help/held/…).
- The same path with ±0.3-key-pitch per-point jitter still ranks "hello" first.
- Start/end pruning: a "cat" gesture never surfaces "bat" when `c` and `b` are far apart.
- Frequency tiebreak: identical-shape same-key-sequence pair ("to" vs "ot" can't collide —
  use a genuinely ambiguous pair like "or"/"our" variants in the fixture) ranks the more
  frequent word first.
- Empty path / no survivors → `[]`; a path visiting one key decodes single-letter words.

**Commit** — `feat: clean-room SHARK2-lineage glide decoder (prune + shape/location channels)`.

---

## Task 8: Glide capture — gesture recognizer + trail

**Files:**
- Create: `Keyboard/Views/QwertyGlideGestureRecognizer.swift`
- Create: `NumPad/Libraries/Qwerty/QwertyGlideCapture.swift` (pure upgrade-decision core)
- Create: `NumPadTests/QwertyGlideCaptureTests.swift`
- Modify: `Keyboard/Views/QwertyKeyboardView.swift`

**Pure core first (TDD):** the tap-vs-glide decision extracted so thresholds are testable:

```swift
enum QwertyGlideCapture {
    static let minimumDistance: CGFloat = 24      // pts of travel before upgrade
    static let minimumDistinctKeys = 2
    struct State { /* accumulated points + distinct key indices */ }
    static func shouldUpgrade(state: State) -> Bool
}
```

Tests: short wiggle inside one key never upgrades; a Q→T drag upgrades exactly when both
thresholds pass; leaving and re-entering the same key counts one distinct key.

**Recognizer:** `QwertyGlideGestureRecognizer: UIGestureRecognizer` (subclass, NOT pan — we
need fail-fast semantics): `touchesBegan` asks its `isGlideOrigin: (CGPoint) -> Bool` closure
(view supplies: point resolves to a `.character` letter key); non-letter origin → `state =
.failed` immediately (space-pan, backspace-repeat, shift, strip keys untouched). `touchesMoved`
feeds the pure core; on `shouldUpgrade` → `state = .began` (UIKit then auto-cancels the origin
button's tracking — the disambiguation mechanism, no manual `touchesCancelled` synthesis) and
`.changed` thereafter. Gate: the view installs the recognizer only when
`FeatureFlags.isGlideTypingActive && !UIAccessibility.isVoiceOverRunning` — flag off means the
recognizer object doesn't exist (byte-for-byte current behavior).

**Trail:** one `CAShapeLayer` on `QwertyKeyboardView`, rebuilt from the recognizer's points on
`.changed`, 0.25s opacity fade + removal on `.ended`/`.cancelled`. Reduced-motion: skip the
fade, just remove.

**View API for the host:** `letterKeyCenters() -> [String: CGPoint]` (from rendered
`.character` single-letter buttons, lowercased) and a
`glideDelegate` callback `didCompleteGlide(path: [CGPoint])`.

Manual verification (flag ON, DEBUG sim): glide produces trail and cancels the origin tap;
space-bar cursor drag, backspace autorepeat, callouts, and plain taps all behave identically
with the flag ON-but-not-gliding and with the flag OFF.

**Commit** — `feat: glide touch capture (fail-fast recognizer, pure thresholds, trail)`.

---

## Task 9: Wire glide into the typing pipeline

**Files:**
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`

Behavior (design §4.3):

1. On `didCompleteGlide`: build/reuse the decoder (rebuild when the letter grid or theme
   rebuild changes key frames — cache keyed by the centers map), decode, take candidate 0.
   No candidates → do nothing (the gesture already cancelled the tap; no text side effect).
2. **Chaining:** if `documentContextBeforeInput` ends in a letter/number, insert `" "` first.
3. Insert the word **without** trailing boundary (it stays the "current word"), shift/autocap
   via the existing `didInsert(word)` path, then `refreshSuggestions()` — but override the bar
   to `[.literal(top), .candidate(alt1), .candidate(alt2)]` from the decoder's candidates so
   alternates are one tap away; the existing chip handler already replaces the current word.
4. Record the accepted word into the personal dictionary at the next boundary exactly like a
   typed word (no special path).
5. Everything inside `guard FeatureFlags.isGlideTypingActive else { return }`.

Manual sim pass: glide "hello" → inserts hello; immediate second glide "world" → "hello world";
chip swaps the last glide; backspace after chaining behaves sanely.

**Commit** — `feat: glide decoding wired into suggestion/insert pipeline (dark)`.

---

## Task 10: Full verification + docs + memory

1. Full unit suite green (detached run, tail log): all existing + new tests.
2. Build both targets Release-config to catch extension-only compile issues:
   `xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad -configuration Release
   -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` (detached).
3. `QwertyTypeSmokeTests` E2E on QA-iPhone17 (flag off — proves no regression dark).
4. Attribution: add the Hermit Dave / OpenSubtitles CC BY-SA 4.0 credit line where the app's
   existing acknowledgements live (locate; likely Privacy or Settings.bundle).
5. `graphify update .`; update `memory/full-keyboard-implementation.md` (branch state, new
   modules, glide legal gate reminder); final commit + squash-review of the branch.

**Definition of done:** flag OFF = zero behavioral diff (E2E-proven); flag ON in DEBUG =
glide works end-to-end; A/B/C accuracy features active unconditionally on the QWERTY page;
all tests green; no new Full Access requirement; resident lexicon ≈ file size.
