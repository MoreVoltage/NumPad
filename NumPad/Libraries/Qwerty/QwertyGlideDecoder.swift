//
//  QwertyGlideDecoder.swift
//  NumPad
//
//  SHARK2-lineage glide-gesture decoder: cheap whole-lexicon pruning by gesture
//  anchors and path length, then two-channel (shape + location) scoring of the
//  survivors with a frequency prior. Pure value logic — CoreGraphics + Foundation
//  only, no UIKit, immutable after init.
//

import CoreGraphics
import Foundation

/// Decodes a glide gesture — a finger path across the letter keys — into ranked word
/// candidates, implementing the published SHARK2 pipeline description (Kristensson & Zhai;
/// design doc `docs/plans/full-keyboard/2026-07-12-glide-and-accuracy-design.md` §4.2 and
/// research doc `docs/plans/full-keyboard/research/2026-07-10-glide-typing.md` §2.1/§4.2).
/// Implemented CLEAN-ROOM from the paper's public description — no OSS keyboard code was
/// consulted or ported.
///
/// **Legal posture.** This module ships DARK behind `FeatureFlags.isGlideTypingActive` (the
/// local Beta toggle AND'd with the `qwerty_glide_typing_enabled` Remote Config kill switch):
/// no App Store exposure until legal review clears the Cerence shape-matching patent
/// (US 7,706,616, active through 2026-12-21) and Cerence v. Apple — see the design doc's
/// owner decisions.
///
/// **Pipeline** (per gesture, on the main thread — pruning does the heavy lifting):
///
/// 1. **Prepare once (init):** lexicon words whose every letter has a rendered key center are
///    kept as small records — `(word, rank, first/last key center, idealLength)` where
///    `idealLength` is the arc length of the word's key-center polyline. Words containing
///    characters with no center on the letters layer (apostrophes, hyphens) are dropped.
/// 2. **Prune (cheap, whole lexicon):** a word survives only when the gesture's start and end
///    points land within `Tuning.startEndToleranceInPitches × pitch` of the word's first/last
///    key centers, AND the gesture-vs-ideal path-length ratio sits inside
///    `[Tuning.minLengthRatio, Tuning.maxLengthRatio]` (inclusive). ~49k words → low
///    hundreds, BEFORE any resampling happens.
/// 3. **Score (survivors only):** the word's ideal template — the polyline through its
///    letters' key centers — is generated ON THE FLY, resampled to
///    `QwertyGlidePath.sampleCount`, compared, and discarded. **No per-word templates are
///    stored anywhere** (the research doc's key memory win over template-store designs: the
///    decoder's whole resident state is one small record per word). The gesture's resampled
///    and normalized forms are computed once per decode, not per candidate.
///    - **Shape channel:** `channelDistance` of the two `normalized(...)` paths —
///      translation/scale-invariant contour similarity.
///    - **Location channel:** `channelDistance` of the two raw resampled paths, scaled by
///      `1 / pitch` so absolute keyboard-space distance is expressed in key pitches and stays
///      comparable to the unit-bounding-box shape channel.
///    - `combined = shapeWeight·shape + locationWeight·location` (weights sum to 1).
/// 4. **Frequency integration:** `score = combined × frequencyMultiplier(rank)`; the
///    multiplier grows linearly from `frequencyBase` at rank 0 to
///    `frequencyBase + frequencySpan` at rank 50k, giving top-ranked words up to a ~1.86×
///    advantage. **Lower scores are better.** Score ties break by word order (determinism).
///
/// **Pitch** is the minimum distance between two DISTINCT key centers (coincident centers are
/// ignored); it makes every tolerance layout-relative. Degenerate layouts with fewer than two
/// distinct centers have no pitch — `decode` returns `[]`.
///
/// **Single-letter words** ("a", "i") have a zero-length ideal path, which no ratio band can
/// accept — they skip the ratio check and instead require the GESTURE itself to be short
/// (within the same anchor tolerance): a compact wiggle or stationary touch on the key
/// decodes them, a long scribble does not. (The capture layer only upgrades touches crossing
/// ≥2 keys to glides, so this branch is defensive completeness, not a hot path.)
struct QwertyGlideDecoder {

    /// A decoded word candidate. Lower `score` = better match.
    struct Candidate: Equatable {
        let word: String
        let score: CGFloat
    }

    /// Named tuning constants — the knobs the wiring task (and future accuracy passes) may
    /// adjust without touching the pipeline.
    enum Tuning {
        /// Start/end anchor pruning tolerance, in key pitches ("adjacent-key tolerance").
        static let startEndToleranceInPitches: CGFloat = 1.6
        /// Inclusive lower bound on gestureLength / idealLength.
        static let minLengthRatio: CGFloat = 0.4
        /// Inclusive upper bound on gestureLength / idealLength.
        static let maxLengthRatio: CGFloat = 2.2
        /// Shape-channel weight; `shapeWeight + locationWeight = 1`.
        static let shapeWeight: CGFloat = 0.5
        /// Location-channel weight.
        static let locationWeight: CGFloat = 0.5
        /// Frequency multiplier at rank 0 (best possible).
        static let frequencyBase: CGFloat = 0.7
        /// Additional multiplier accrued linearly by `frequencyRankScale`.
        static let frequencySpan: CGFloat = 0.6
        /// Rank at which the full `frequencySpan` penalty applies (the corpus is ~50k words).
        static let frequencyRankScale: CGFloat = 50_000
        /// Hard ceiling on how many pruning survivors get the expensive scoring step. Real
        /// layouts leave low hundreds; if pathological geometry ever passes more, only the
        /// best `survivorScoringCap` by anchor distance are scored, keeping worst-case
        /// decode time bounded instead of degrading the whole keyboard's responsiveness.
        static let survivorScoringCap = 2_048
    }

    /// Everything pruning needs, precomputed once per layout — deliberately no polyline and
    /// no resampled template (both are regenerated on the fly for scoring survivors).
    private struct WordEntry {
        let word: String
        let rank: Int
        let first: CGPoint
        let last: CGPoint
        let idealLength: CGFloat
    }

    /// Rendered letter-key centers (view space), lowercased character → center.
    private let keyCenters: [String: CGPoint]
    /// Minimum distance between two distinct key centers; 0 when the layout is degenerate.
    private let pitch: CGFloat
    /// Prunable records for every lexicon word spellable on this layout.
    private let entries: [WordEntry]

    /// Prepares the decoder for one rendered layout. Runs once per layout: one polyline walk
    /// (for `idealLength`) plus one rank lookup per lexicon word — no resampling here.
    ///
    /// - Parameters:
    ///   - keyCenters: rendered letter-key centers (view space), lowercased character → center.
    ///   - lexicon: frequency lexicon; its words are filtered to those fully spellable with
    ///     `keyCenters` (drops `'`/`-` words on the letters layer).
    init(keyCenters: [String: CGPoint], lexicon: QwertyFrequencyLexicon) {
        self.keyCenters = keyCenters

        // Pitch: minimum pairwise distance over distinct centers (26 keys → ~325 pairs).
        // Coincident centers (distance 0) carry no spacing information and are skipped.
        let centers = Array(keyCenters.values)
        var minimumDistance = CGFloat.greatestFiniteMagnitude
        for i in centers.indices {
            for j in centers.indices where j > i {
                let separation = Self.distance(centers[i], centers[j])
                if separation > 0 && separation < minimumDistance {
                    minimumDistance = separation
                }
            }
        }
        let pitch = minimumDistance < .greatestFiniteMagnitude ? minimumDistance : 0
        self.pitch = pitch
        guard pitch > 0 else {
            self.entries = []
            return
        }

        var entries: [WordEntry] = []
        for word in lexicon.allWords() {
            var polyline: [CGPoint] = []
            var spellable = true
            for character in word {
                guard let center = keyCenters[String(character)] else {
                    spellable = false
                    break
                }
                polyline.append(center)
            }
            guard spellable, let first = polyline.first, let last = polyline.last,
                  let rank = lexicon.rank(of: word) else { continue }
            entries.append(WordEntry(word: word,
                                     rank: rank,
                                     first: first,
                                     last: last,
                                     idealLength: QwertyGlidePath.pathLength(polyline)))
        }
        self.entries = entries
    }

    // MARK: - Decoding

    /// Decodes a gesture path (view-space points, in touch order) into at most
    /// `maxCandidates` word candidates, best (lowest score) first.
    ///
    /// Empty path, non-positive `maxCandidates`, a degenerate layout (no pitch), or zero
    /// pruning survivors all yield `[]`.
    func decode(path: [CGPoint], maxCandidates: Int = 3) -> [Candidate] {
        guard maxCandidates > 0, pitch > 0,
              let gestureStart = path.first, let gestureEnd = path.last else { return [] }

        let tolerance = Tuning.startEndToleranceInPitches * pitch
        let gestureLength = QwertyGlidePath.pathLength(path)

        // Prune the whole lexicon with cheap geometry only — no resampling yet. The anchor
        // distances double as the cap heuristic below.
        var survivors: [(entry: WordEntry, anchorDistance: CGFloat)] = []
        for entry in entries {
            let startDistance = Self.distance(gestureStart, entry.first)
            guard startDistance <= tolerance else { continue }
            let endDistance = Self.distance(gestureEnd, entry.last)
            guard endDistance <= tolerance else { continue }
            if entry.idealLength > 0 {
                let ratio = gestureLength / entry.idealLength
                guard ratio >= Tuning.minLengthRatio, ratio <= Tuning.maxLengthRatio else {
                    continue
                }
            } else {
                // Zero-length ideal path (single-letter word, or every letter on one key):
                // the ratio band cannot apply; accept only gestures short enough to read as
                // dwelling on that key.
                guard gestureLength <= tolerance else { continue }
            }
            survivors.append((entry, startDistance + endDistance))
        }

        // Pathological-geometry bound: score only the best `survivorScoringCap` by anchor
        // distance (word tiebreak keeps the cut deterministic).
        if survivors.count > Tuning.survivorScoringCap {
            survivors.sort {
                ($0.anchorDistance, $0.entry.word) < ($1.anchorDistance, $1.entry.word)
            }
            survivors.removeLast(survivors.count - Tuning.survivorScoringCap)
        }

        // The gesture's resampled + normalized forms are shared by every candidate —
        // computed exactly once per decode.
        let gestureResampled = QwertyGlidePath.resample(path)
        let gestureNormalized = QwertyGlidePath.normalized(gestureResampled)

        var candidates: [Candidate] = []
        candidates.reserveCapacity(survivors.count)
        for (entry, _) in survivors {
            // Ideal template: generated on the fly from the key centers, used, discarded.
            let template = QwertyGlidePath.resample(idealPolyline(for: entry.word))
            let shape = QwertyGlidePath.channelDistance(gestureNormalized,
                                                        QwertyGlidePath.normalized(template))
            let location = QwertyGlidePath.channelDistance(gestureResampled, template) / pitch
            let combined = Tuning.shapeWeight * shape + Tuning.locationWeight * location
            candidates.append(Candidate(word: entry.word,
                                        score: combined * Self.frequencyMultiplier(rank: entry.rank)))
        }

        candidates.sort { ($0.score, $0.word) < ($1.score, $1.word) }
        return Array(candidates.prefix(maxCandidates))
    }

    /// The frequency prior: `frequencyBase + frequencySpan × rank / frequencyRankScale`.
    /// Rank 0 pays ×0.7, rank 50k pays ×1.3 — a ~1.86× advantage for the most frequent
    /// words. Multiplicative on the combined distance, so a geometrically perfect match
    /// (distance 0) stays perfect regardless of rank.
    static func frequencyMultiplier(rank: Int) -> CGFloat {
        Tuning.frequencyBase + Tuning.frequencySpan * CGFloat(rank) / Tuning.frequencyRankScale
    }

    // MARK: - Private

    /// The word's ideal path: the polyline through its letters' key centers. Entries are
    /// pre-filtered to fully spellable words, so the compactMap never actually drops points.
    private func idealPolyline(for word: String) -> [CGPoint] {
        word.compactMap { keyCenters[String($0)] }
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
