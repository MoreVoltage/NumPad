//
//  QwertyGlidePath.swift
//  NumPad
//
//  Pure gesture-path geometry for the glide-typing decoder: uniform arc-length
//  resampling, SHARK2-style shape normalization, and the mean point-to-point
//  channel distance. Implemented by the glide-decoder pass.
//

import CoreGraphics

/// Geometry substrate for the SHARK2-lineage glide decoder
/// (docs/plans/full-keyboard/2026-07-12-glide-and-accuracy-design.md §4.2).
///
/// The decoder compares a raw glide gesture against each candidate word's "ideal path" (the
/// polyline through its letters' key centers, generated on the fly from `QwertyLayout`
/// geometry) over two channels, following the published SHARK2 description (Kristensson &
/// Zhai) — implemented CLEAN-ROOM from the paper's math, no OSS keyboard code ported:
///
/// - **Shape channel:** both paths are resampled to `sampleCount` arc-length-equidistant
///   points and normalized — translated so the centroid sits at the origin, scaled so the
///   larger bounding-box side becomes 1 (SHARK2's scale `s = L / max(W, H)` with `L = 1`) —
///   making the comparison translation- and scale-invariant so it captures the gesture's
///   contour regardless of where or how large it was drawn.
/// - **Location channel:** the same resampled paths compared in absolute keyboard space (no
///   normalization), anchoring the contour to where on the keyboard it was actually drawn.
///
/// `channelDistance` is the shared metric for both channels: mean Euclidean distance over
/// index-paired points. `pathLength` additionally feeds the decoder's pruning step (the
/// path-length-implied word-length band).
///
/// Everything here is pure `CoreGraphics` value math — no UIKit, no Foundation, no state —
/// matching the `NumPad/Libraries/Qwerty/` 100%-unit-tested convention.
enum QwertyGlidePath {

    /// Number of equidistant points both the gesture and each candidate's ideal path are
    /// resampled to before channel comparison. SHARK2's pipeline uses a fixed small sample
    /// count; 48 balances contour fidelity against per-candidate cost (the decoder scores
    /// hundreds of pruning survivors per gesture inside the memory-capped extension).
    static let sampleCount = 48

    /// Resamples `points` to exactly `count` points spaced uniformly by **arc length** along
    /// the polyline (not uniformly per segment). The first output point is the input's first
    /// point and the last is the input's last point, both **exactly** — the decoder's
    /// start/end-key pruning depends on the endpoints never drifting.
    ///
    /// Degenerate-input contract:
    /// - empty input → empty output
    /// - `count <= 1` → the first point repeated `max(count, 0)` times (a resampling to one
    ///   point is the path's start; non-positive counts yield `[]`)
    /// - single-point input or zero total length → the first point repeated `count` times
    ///   (there is no direction to walk, and no division by the zero length occurs)
    static func resample(_ points: [CGPoint], to count: Int = sampleCount) -> [CGPoint] {
        guard let first = points.first else { return [] }
        guard count > 1 else { return Array(repeating: first, count: Swift.max(count, 0)) }

        // Cumulative arc length at each vertex: cumulative[i] is the distance along the
        // polyline from the start to points[i].
        var cumulative: [CGFloat] = [0]
        cumulative.reserveCapacity(points.count)
        for index in 1..<points.count {
            cumulative.append(cumulative[index - 1] + distance(points[index - 1], points[index]))
        }
        guard let total = cumulative.last, total > 0 else {
            return Array(repeating: first, count: count)
        }

        var result: [CGPoint] = [first]
        result.reserveCapacity(count)
        // Interior samples sit at arc positions k * total / (count - 1). Targets are strictly
        // increasing, so the segment cursor only ever moves forward (single pass overall).
        var segment = 1
        for sample in 1..<(count - 1) {
            let target = total * CGFloat(sample) / CGFloat(count - 1)
            while segment < points.count - 1 && cumulative[segment] < target {
                segment += 1
            }
            let segmentStart = cumulative[segment - 1]
            let segmentLength = cumulative[segment] - segmentStart
            // A zero-length segment can only contain a target when it coincides with it,
            // in which case its start point is the sample (t = 0 is exact, no divide).
            // t cannot go negative — the cursor invariant guarantees target > segmentStart
            // (the cursor only advances past a vertex whose cumulative length is below the
            // target). The clamp to 1 guards float dust in the cumulative sums from placing
            // an interior sample epsilon past its segment end, making "every sample lies on
            // the polyline" unconditional.
            let t = segmentLength > 0 ? Swift.min((target - segmentStart) / segmentLength, 1) : 0
            let a = points[segment - 1]
            let b = points[segment]
            result.append(CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y)))
        }
        result.append(points[points.count - 1])
        return result
    }

    /// Total arc length of the polyline: the sum of consecutive point-to-point Euclidean
    /// distances. Empty and single-point inputs have zero length.
    static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var length: CGFloat = 0
        for index in 1..<points.count {
            length += distance(points[index - 1], points[index])
        }
        return length
    }

    /// SHARK2 shape-channel normalization: translates the path so its **centroid** (mean
    /// point) sits at the origin, then scales it by the larger bounding-box side — the
    /// paper's scale `s = L / max(W, H)` with `L = 1` — so two paths tracing the same contour
    /// at different positions/sizes compare as (near-)identical.
    ///
    /// Degenerate-input contract: empty input → empty output; a zero-extent path (all points
    /// identical) has no shape, so every point maps to `.zero` — never NaN, never a division
    /// by zero.
    static func normalized(_ points: [CGPoint]) -> [CGPoint] {
        guard let first = points.first else { return [] }
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in points {
            sumX += point.x
            sumY += point.y
            minX = Swift.min(minX, point.x)
            maxX = Swift.max(maxX, point.x)
            minY = Swift.min(minY, point.y)
            maxY = Swift.max(maxY, point.y)
        }
        let extent = Swift.max(maxX - minX, maxY - minY)
        guard extent > 0 else {
            return Array(repeating: .zero, count: points.count)
        }
        let centroid = CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
        return points.map {
            CGPoint(x: ($0.x - centroid.x) / extent, y: ($0.y - centroid.y) / extent)
        }
    }

    /// Mean Euclidean distance over index-paired points — the shared metric for both the
    /// shape and location channels.
    ///
    /// Contract:
    /// - both empty → `0` (two empty paths are indistinguishable)
    /// - length mismatch → `.greatestFiniteMagnitude`. Mismatched lengths are a programmer
    ///   error in our pipeline (the decoder resamples both sides to `sampleCount` first),
    ///   so the mismatch is LOUD in DEBUG (`assertionFailure`) but must not trap in release:
    ///   an "infinite" distance degrades the bug to "this candidate never matches" instead
    ///   of silently producing a wrong match.
    ///
    /// `onMismatch` defaults to `assertionFailure` and exists only as a test seam: unit
    /// tests (which run with assertions enabled) inject a no-op/recorder to exercise both
    /// the release-mode fallback value and the loudness without killing the test runner.
    /// Production callers never pass it.
    static func channelDistance(_ a: [CGPoint], _ b: [CGPoint],
                                onMismatch: (String) -> Void = { assertionFailure($0) }) -> CGFloat {
        guard a.count == b.count else {
            onMismatch("channelDistance length mismatch: \(a.count) vs \(b.count)")
            return .greatestFiniteMagnitude
        }
        guard !a.isEmpty else { return 0 }
        var sum: CGFloat = 0
        for index in a.indices {
            sum += distance(a[index], b[index])
        }
        return sum / CGFloat(a.count)
    }

    // MARK: - Private

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
