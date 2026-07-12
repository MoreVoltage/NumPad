//
//  QwertyGlideCapture.swift
//  NumPad
//
//  Pure tap-vs-glide upgrade decision for the QWERTY glide recognizer
//  (docs/plans/full-keyboard/2026-07-12-glide-and-accuracy-design.md §4.1).
//  Implemented by the glide-capture pass.
//

import CoreGraphics

/// The pure half of glide touch capture: given the points a touch has visited and the keys
/// they resolved to, decide whether the touch is still a potential tap or has become a glide.
///
/// `QwertyGlideGestureRecognizer` (Keyboard target) feeds every sampled touch location into a
/// `State` via `record(point:keyIndex:)` and asks `shouldUpgrade(state:)` after each sample;
/// the first `true` upgrades the gesture to `.began`, which is what makes UIKit cancel the
/// origin key's own touch tracking (the disambiguation moment). Extracting the decision here
/// keeps both thresholds unit-testable without UIKit — the `NumPad/Libraries/Qwerty/`
/// 100%-tested convention.
///
/// A touch upgrades only when BOTH hold:
/// - it has traveled at least `minimumDistance` points away from where it landed, AND
/// - its path has resolved to at least `minimumDistinctKeys` distinct keys.
///
/// Requiring both means a sloppy tap that slides within one key never upgrades (distance
/// alone can't trigger), and a tap on a key boundary that flickers between two adjacent keys
/// never upgrades either (key count alone can't trigger).
enum QwertyGlideCapture {

    /// Minimum travel, in points, before a touch may upgrade to a glide.
    ///
    /// "Travel" is the maximum DISPLACEMENT from the first recorded point (the touch-down),
    /// not accumulated path length — displacement is O(1) per sample, is immune to jitter
    /// inflation (a finger trembling in place accumulates arc length but no displacement),
    /// and matches the intent "the finger moved 24pt away from where it landed". Once
    /// reached it never un-reaches (see `State.maxDisplacement`), so the decision cannot
    /// flap back to "tap" as the finger curls toward its next letter.
    static let minimumDistance: CGFloat = 24

    /// Minimum count of distinct keys (origin included) the path must have resolved to.
    /// A `Set` of key indices backs the count, so leaving and re-entering the same key
    /// still counts it exactly once.
    static let minimumDistinctKeys = 2

    /// Accumulated capture for one touch: every sampled point in order, the set of distinct
    /// key indices those points resolved to, and the running maximum displacement from the
    /// first point. Value type — the recognizer replaces it wholesale on `reset()`.
    struct State {
        private(set) var points: [CGPoint] = []
        private(set) var visitedKeyIndices: Set<Int> = []
        private(set) var maxDisplacement: CGFloat = 0

        init() {}

        /// Records one sampled touch location and the key it resolved to (`nil` when the
        /// caller's routing found no key — such samples still extend the path and the
        /// displacement, but never the distinct-key count).
        mutating func record(point: CGPoint, keyIndex: Int?) {
            if let origin = points.first {
                let dx = point.x - origin.x
                let dy = point.y - origin.y
                maxDisplacement = Swift.max(maxDisplacement, (dx * dx + dy * dy).squareRoot())
            }
            points.append(point)
            if let keyIndex = keyIndex {
                visitedKeyIndices.insert(keyIndex)
            }
        }
    }

    /// Whether the touch described by `state` has crossed BOTH upgrade thresholds
    /// (inclusive) and should become a glide.
    static func shouldUpgrade(state: State) -> Bool {
        state.maxDisplacement >= minimumDistance
            && state.visitedKeyIndices.count >= minimumDistinctKeys
    }
}
