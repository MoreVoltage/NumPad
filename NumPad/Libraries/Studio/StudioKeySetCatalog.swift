//
//  StudioKeySetCatalog.swift
//  NumPad
//

import Foundation

/// The short, customer-facing list of keyboard key sets used by Keyboard Studio.
/// It intentionally differs from `KeyboardType.packs`: legacy and specialist packs remain
/// reachable through their existing paths, while the Studio presents one unambiguous choice per
/// everyday outcome.
struct StudioKeySetCatalog {
    struct Choice: Equatable, Identifiable {
        enum ID: String, CaseIterable {
            case numbers
            case calculations
            case prices
            case measurements
            case dateAndTime
            case symbols
            case programming
        }

        let id: ID
        let title: String
        let description: String
        let packs: [KeyboardType]
        let isLocked: Bool

        func isSelected(for pack: KeyboardType) -> Bool {
            packs.contains(pack)
        }
    }

    private let isLocked: (KeyboardType) -> Bool

    init(isLocked: @escaping (KeyboardType) -> Bool = { Monetization.isLocked(pack: $0) }) {
        self.isLocked = isLocked
    }

    var visibleChoices: [Choice] {
        [
            choice(.numbers, "Numbers", "Clean number entry with basic symbols", packs: [.default]),
            choice(.calculations, "Calculations", "Operators, percent, and parentheses", packs: [.math, .math2]),
            choice(.prices, "Prices", "Currency symbols and finance keys", packs: [.finance]),
            choice(.measurements, "Measurements", "Units and quick conversions", packs: [.units]),
            choice(.dateAndTime, "Date & time", "Insert today's date or the time", packs: [.datetime]),
            choice(.symbols, "Symbols", "Common punctuation and marks", packs: [.symbols]),
            choice(.programming, "Programming", "Hex and bitwise operators", packs: [.programmer])
        ]
    }

    private func choice(
        _ id: Choice.ID,
        _ title: String,
        _ description: String,
        packs: [KeyboardType]
    ) -> Choice {
        Choice(
            id: id,
            title: NSLocalizedString(title, comment: "Keyboard Studio key set title"),
            description: NSLocalizedString(description, comment: "Keyboard Studio key set description"),
            packs: packs,
            isLocked: packs.contains(where: isLocked)
        )
    }
}
