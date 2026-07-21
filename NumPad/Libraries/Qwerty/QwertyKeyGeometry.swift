//
//  QwertyKeyGeometry.swift
//  NumPad
//
//  Pure key-distance model for the QWERTY grid: where letters physically sit,
//  in key-pitch units, and how far apart two letters are.
//

import Foundation

/// Physical positions of letters on a standard QWERTY grid, in "key pitch" units
/// (1.0 = the horizontal distance between two neighboring keys). Row stagger matches
/// the rendered keyboard: home row +0.5, bottom row +1.5. Hardcoded on purpose —
/// keeps the module pure and usable from the offline eval harness.
enum QwertyKeyGeometry {

    static let adjacencyThreshold = 1.2   // covers horizontal (1.0) + diagonal (~1.118)

    private static let unitCenters: [Character: (x: Double, y: Double)] = {
        var centers: [Character: (Double, Double)] = [:]
        let rows: [(letters: String, xOffset: Double, y: Double)] = [
            ("qwertyuiop", 0.0, 0.0),
            ("asdfghjkl", 0.5, 1.0),
            ("zxcvbnm", 1.5, 2.0),
        ]
        for row in rows {
            for (index, letter) in row.letters.enumerated() {
                centers[letter] = (row.xOffset + Double(index), row.y)
            }
        }
        return centers
    }()

    /// Euclidean distance in key-pitch units; nil when either character is not a letter key.
    static func distance(_ a: Character, _ b: Character) -> Double? {
        guard let ca = unitCenter(of: a), let cb = unitCenter(of: b) else { return nil }
        return ((ca.x - cb.x) * (ca.x - cb.x) + (ca.y - cb.y) * (ca.y - cb.y)).squareRoot()
    }

    static func areAdjacent(_ a: Character, _ b: Character) -> Bool {
        guard let d = distance(a, b) else { return false }
        return d > 0 && d <= adjacencyThreshold
    }

    /// Lowercases via `String.first` rather than `Character(_:)` — the latter traps when a
    /// character's lowercase form is more than one grapheme cluster. Unknown characters
    /// (accented letters, digits, symbols) simply miss the table and return nil.
    private static func unitCenter(of character: Character) -> (x: Double, y: Double)? {
        guard let lowered = character.lowercased().first else { return nil }
        return unitCenters[lowered]
    }
}
