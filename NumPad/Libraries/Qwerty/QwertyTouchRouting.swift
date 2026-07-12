//
//  QwertyTouchRouting.swift
//  NumPad
//
//  Pure touch routing for the QWERTY page: every point on the keyboard maps to a key
//  (no dead zones), with an optional likely-next-key bias derived from the completions
//  the autocorrect pipeline already computes. Implemented by the touch-routing pass.
//

import CoreGraphics

/// Zero-dead-zone touch routing for the QWERTY keyboard.
///
/// **Problem.** `QwertyKeyboardView` lays out keys with small visual gaps between them
/// (`Metrics.keyGap`/`rowGap`) so keycaps read as distinct — but a `UIButton`'s hit area is
/// exactly its own frame, so a touch landing in one of those gaps hits nothing. That is the
/// dead zone the owner flagged: "there should be no space where the user can press on the
/// keyboard that does not press a key." This type is the pure geometry layer that fixes it —
/// given a touch point and the keys' visual frames, `keyIndex(at:keyFrames:in:bias:)` always
/// resolves to exactly one key: a direct hit wins outright, and a point in a gap resolves to
/// the nearest key by distance-to-frame (not distance-to-center, so wide/tall keys like space
/// or shift claim the gap next to them naturally).
///
/// **Performance analysis (owner's second ask).** The owner also asked to investigate biasing
/// touch resolution toward the statistically likely next key, with the constraint that it
/// must not be processor-heavy. `bias(forCompletions:currentWord:keyOutputs:)` answers that by
/// reusing work the keyboard already does: `QwertySpellChecker`/`UITextChecker` fetches ranked
/// word completions for the in-progress word on every keystroke to feed the suggestion bar
/// (`QwertyKeyboardViewController.refreshSuggestions()` → `analysis.completions`). This type
/// takes that already-computed, already-ranked list and, for each completion that continues
/// the current word, casts a rank-weighted vote for the single next character — i.e. the key
/// the user is statistically likely to press next. Votes are summed per key index and
/// normalized to `[0, 1]`. The cost is O(completions + number of keys) simple arithmetic per
/// touch: no ML model, no shipped n-gram/frequency corpus, and zero additional calls to
/// `UITextChecker` or any other system API beyond what the suggestion bar already triggers —
/// negligible CPU and no measurable battery impact, safe for the keyboard extension's ~50MB
/// memory ceiling.
///
/// Deeper approaches were considered and rejected for v1:
/// - **A shipped n-gram / bigram frequency model** over words would likely predict better,
///   but requires bundling and loading a corpus (binary size + resident memory in a
///   memory-capped extension) and a lookup per touch; the `UITextChecker` completions we
///   already fetch draw on the same underlying signal (the system's own predictive text) for
///   effectively free, so the marginal accuracy isn't worth the cost or complexity.
/// - **An on-device learned touch model** (the kind of statistical touch-correction production
///   keyboards like Gboard/Apple's own keyboard use) is a research-grade investment — training
///   data, a runtime, calibration — wildly disproportionate to a v1 dead-zone fix for a niche
///   keyboard extension.
///
/// Both are unnecessary: completions-derived bias captures the common case (the next letter of
/// the most likely word) essentially for free, and the effective-distance cap (below) bounds
/// its influence so it can only ever tip a genuinely ambiguous touch, never override a clear
/// nearest-key or a direct hit.
enum QwertyTouchRouting {

    /// Caps how much `bias` can shrink a key's effective distance: a fully biased key
    /// (`bias == 1.0`) has its distance multiplied by `1 - 0.3 = 0.7` at most. This guarantees
    /// a far-away biased key can never beat a key that is genuinely much closer to the touch —
    /// bias can only swing a contest that was already close.
    private static let biasDistanceCap: CGFloat = 0.3

    /// Caps a learned per-key offset's magnitude at this fraction of the key's smaller
    /// dimension — the same philosophy as `biasDistanceCap`: a wildly large learned offset
    /// (corrupt storage, a pathological habit) can only ever nudge a key's effective frame,
    /// never teleport it across the keyboard.
    private static let offsetDistanceCap: CGFloat = 0.3

    /// Maps `point` to exactly one key index — there is no point inside `bounds` this can
    /// return `nil` for; the only `nil` case is an empty `keyFrames`.
    ///
    /// - Parameters:
    ///   - point: The touch location, in the same coordinate space as `keyFrames`/`bounds`.
    ///   - keyFrames: Each key's visual frame, in on-screen order (index == key index).
    ///   - bounds: The routable area (typically the keyboard view's `bounds`). `point` is
    ///     clamped into `bounds` first, so a touch reported a hair outside the view (which
    ///     happens with real touch events near an edge) still resolves sensibly.
    ///   - bias: Optional per-key-index bias in `[0, 1]` (values outside that range are
    ///     clamped) that favors a key when resolving an ambiguous gap point. See
    ///     `bias(forCompletions:currentWord:keyOutputs:)`.
    ///   - offsets: Optional per-key-index learned touch offsets in view space (the user's
    ///     habitual tap bias for that key, denormalized from
    ///     `QwertyTouchPersonalization` — design §3). A second, independent channel from
    ///     `bias`: during GAP resolution each key's effective frame is shifted by its offset
    ///     (magnitude-capped by `offsetDistanceCap`); direct hits are still resolved against
    ///     the TRUE frames, so an offset can never steal a direct hit.
    /// - Returns: The routed key index, or `nil` only when `keyFrames` is empty.
    static func keyIndex(at point: CGPoint,
                          keyFrames: [CGRect],
                          in bounds: CGRect,
                          bias: [Int: CGFloat] = [:],
                          offsets: [Int: CGVector] = [:]) -> Int? {
        guard !keyFrames.isEmpty else { return nil }

        let clampedPoint = CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX),
                                    y: min(max(point.y, bounds.minY), bounds.maxY))

        // (a) A direct hit always wins — neither bias nor a learned offset may steal it.
        for (index, frame) in keyFrames.enumerated() where frame.contains(clampedPoint) {
            return index
        }

        // (b) + (c) Gap resolution: nearest key by edge distance to the offset-shifted
        // frame, the distance then shrunk (capped) by bias.
        var bestIndex = 0
        var bestEffectiveDistance = CGFloat.greatestFiniteMagnitude
        for (index, frame) in keyFrames.enumerated() {
            let distance = edgeDistance(from: clampedPoint,
                                        to: frame.shifted(by: offsets[index],
                                                          cappedTo: offsetDistanceCap))
            let clampedBias = min(max(bias[index] ?? 0, 0), 1)
            let effectiveDistance = distance * (1 - biasDistanceCap * clampedBias)
            if effectiveDistance < bestEffectiveDistance {
                bestEffectiveDistance = effectiveDistance
                bestIndex = index
            }
        }
        return bestIndex
    }

    /// Nearest-edge distance from `point` to `frame` — zero when `point` is inside `frame`,
    /// otherwise the straight-line distance to the closest point on the frame's boundary.
    /// Using edge distance (rather than distance-to-center) is what makes wide/tall keys
    /// (space bar, shift, return) correctly claim the gap immediately next to them instead of
    /// losing it to a narrower key whose center happens to be closer.
    private static func edgeDistance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let dx = max(frame.minX - point.x, point.x - frame.maxX, 0)
        let dy = max(frame.minY - point.y, point.y - frame.maxY, 0)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Derives per-key bias in `[0, 1]` from the ranked word completions the autocorrect
    /// pipeline already computes every keystroke (`QwertySpellChecker`/`UITextChecker`, via
    /// `QwertyKeyboardViewController.refreshSuggestions()` → `analysis.completions`) — no new
    /// prediction is run.
    ///
    /// For every completion that has `currentWord` as a prefix (case-insensitive) and is
    /// strictly longer than it, the character immediately following the prefix casts a vote —
    /// weighted `1 / (rank + 1)` so earlier (higher-ranked) completions count more — for the
    /// key whose single-character output matches that next character (case-insensitive; keys
    /// whose output isn't exactly one character, e.g. "return" or a multi-character token,
    /// never receive a vote). Votes for the same key accumulate across completions, and the
    /// resulting map is normalized so its largest value is `1.0`.
    ///
    /// - Returns: An empty dictionary when `currentWord` is empty, `completions` is empty, or
    ///   no completion continues `currentWord` with a matching key.
    static func bias(forCompletions completions: [String],
                      currentWord: String,
                      keyOutputs: [Int: String]) -> [Int: CGFloat] {
        guard !currentWord.isEmpty, !completions.isEmpty else { return [:] }
        let prefix = currentWord.lowercased()

        var votes: [Int: CGFloat] = [:]
        for (rank, completion) in completions.enumerated() {
            let lowered = completion.lowercased()
            guard lowered.hasPrefix(prefix), lowered.count > prefix.count else { continue }
            let nextChar = lowered[lowered.index(lowered.startIndex, offsetBy: prefix.count)]
            let weight = 1.0 / CGFloat(rank + 1)
            for (index, output) in keyOutputs {
                guard output.count == 1, let outputChar = output.lowercased().first,
                      outputChar == nextChar else { continue }
                votes[index, default: 0] += weight
            }
        }

        guard let maxVote = votes.values.max(), maxVote > 0 else { return [:] }
        return votes.mapValues { $0 / maxVote }
    }
}

private extension CGRect {
    /// This frame translated by `offset`, with the offset VECTOR's magnitude clamped to
    /// `cap × min(width, height)` — direction is preserved, so a huge learned offset becomes
    /// a maximal nudge along the same heading, never a per-axis box clamp. Nil, zero, and
    /// non-finite offsets (corrupt storage is a caller's persistence concern, but never a
    /// crash here) all return the frame unchanged.
    func shifted(by offset: CGVector?, cappedTo cap: CGFloat) -> CGRect {
        guard let offset = offset, offset.dx.isFinite, offset.dy.isFinite,
              offset.dx != 0 || offset.dy != 0 else { return self }
        let magnitude = (offset.dx * offset.dx + offset.dy * offset.dy).squareRoot()
        let limit = cap * min(width, height)
        let scale = magnitude > limit ? limit / magnitude : 1
        return offsetBy(dx: offset.dx * scale, dy: offset.dy * scale)
    }
}
