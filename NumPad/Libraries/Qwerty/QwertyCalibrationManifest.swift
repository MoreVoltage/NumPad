import Foundation

/// Includes the strip as row zero, exactly matching QwertyKeyboardView's flattened buttons.
enum QwertyCalibrationPage: String, Codable, CaseIterable {
    case letters, uppercase, symbols, extendedSymbols
    var layer: QwertyLayer {
        switch self {
        case .letters, .uppercase: return .letters
        case .symbols: return .symbols
        case .extendedSymbols: return .extendedSymbols
        }
    }
    var uppercase: Bool { self == .uppercase }
}

struct QwertyCalibrationEntry: Codable, Equatable {
    enum Kind: String, Codable { case character, control, alternate, behavior }
    let id: String
    let page: QwertyCalibrationPage
    let row: Int
    let column: Int
    let buttonIndex: Int
    let output: String
    let kind: Kind
    let minimumSamples: Int
    /// A menu item or gesture retains its physical parent key ID but never trains that key.
    let parentID: String?
    var trainsSpatialModel: Bool { kind == .character && output.count == 1 }
}

struct QwertyCalibrationManifest: Codable, Equatable {
    static let version = 2
    let layoutFingerprint: String
    let contextID: String
    let entries: [QwertyCalibrationEntry]

    /// The complete layout remains available for routing and compatibility. Quick
    /// calibration asks only for the 26 physical letter keys, each exactly once.
    var requiredEntries: [QwertyCalibrationEntry] {
        entries.filter {
            $0.page == .letters && $0.row > 0 && $0.parentID == nil
                && $0.kind == .character && $0.output.utf8.count == 1
                && ("a"..."z").contains($0.output) && $0.minimumSamples > 0
        }
    }

    func entry(id: String) -> QwertyCalibrationEntry? { entries.first { $0.id == id } }
    func entry(page: QwertyCalibrationPage, buttonIndex: Int) -> QwertyCalibrationEntry? {
        entries.first { $0.page == page && $0.buttonIndex == buttonIndex && $0.parentID == nil }
    }

    /// contextID must include resolved layout/handedness, device class, orientation, actual
    /// keyboard bounds, and typing mode. Never reuse a portrait profile for landscape.
    static func make(options: QwertyLayoutOptions, topStrip: QwertyTopStrip,
                     contextID: String) -> Self {
        var entries: [QwertyCalibrationEntry] = []
        var signatures = ["manifest-v\(version)", contextID]
        for page in QwertyCalibrationPage.allCases {
            let rows = [QwertyRow(keys: QwertyTopStrip.keys(for: topStrip))]
                + QwertyLayout.rows(layer: page.layer, options: options)
            var buttonIndex = 0
            for (rowIndex, row) in rows.enumerated() {
                signatures.append("\(page.rawValue):\(rowIndex):\(row.leadingMargin):\(row.trailingMargin)")
                for (column, key) in row.keys.enumerated() {
                    let id = "\(page.rawValue):\(rowIndex):\(column)"
                    let output = output(for: key.kind, uppercase: page.uppercase)
                    let kind: QwertyCalibrationEntry.Kind
                    if case .character = key.kind { kind = .character } else { kind = .control }
                    let isLetter = page == .letters && rowIndex > 0 && kind == .character
                        && output.utf8.count == 1 && ("a"..."z").contains(output)
                    let minimum = isLetter ? 1 : 0
                    entries.append(.init(id: id, page: page, row: rowIndex, column: column,
                                         buttonIndex: buttonIndex, output: output, kind: kind,
                                         minimumSamples: minimum, parentID: nil))
                    signatures.append("\(id):\(key.width):\(identity(for: key.kind))")
                    if case .character(let base, _) = key.kind {
                        for (index, alternate) in QwertyAlternates.values(for: base, uppercase: page.uppercase).enumerated() {
                            entries.append(.init(id: "\(id):alternate:\(index)", page: page,
                                                 row: rowIndex, column: column, buttonIndex: buttonIndex,
                                                 output: alternate, kind: .alternate,
                                                 minimumSamples: 0, parentID: id))
                            signatures.append("\(id):alternate:\(index):\(alternate)")
                        }
                    }
                    let behaviors: [String]
                    switch key.kind {
                    case .shift: behaviors = ["capsLock"]
                    case .space: behaviors = ["cursorHold"]
                    case .backspace: behaviors = ["deleteHold"]
                    default: behaviors = []
                    }
                    for behavior in behaviors {
                        entries.append(.init(id: "\(id):\(behavior)", page: page, row: rowIndex,
                                             column: column, buttonIndex: buttonIndex, output: behavior,
                                             kind: .behavior, minimumSamples: 0, parentID: id))
                    }
                    buttonIndex += 1
                }
            }
        }
        // A stable digest, unlike Swift's per-process-randomized Hasher. The full manifest is
        // stored too, so checkpoint compatibility checks also compare entries exactly.
        let digest = signatures.joined(separator: "\u{1f}").utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        return Self(layoutFingerprint: String(digest, radix: 16), contextID: contextID, entries: entries)
    }

    /// Avoid String(reflecting:): it embeds the module name, which differs between the
    /// containing app and keyboard extension and would make their fingerprints disagree.
    private static func identity(for kind: QwertyKeyKind) -> String {
        let parts: [String]
        switch kind {
        case .character(let base, let shifted): parts = ["character", base, shifted]
        case .dateTimeToken(let label, let token): parts = ["dateTime", label, token]
        case .snippet(let label, let text): parts = ["snippet", label, text]
        default: parts = ["action", output(for: kind, uppercase: false)]
        }
        return parts.map { "\($0.utf8.count):\($0)" }.joined()
    }

    static func output(for kind: QwertyKeyKind, uppercase: Bool) -> String {
        switch kind {
        case .character(let base, let shifted): return uppercase ? shifted : base
        case .space: return " "
        case .ret: return "\n"
        case .shift: return "shift"
        case .backspace: return "backspace"
        case .globe: return "globe"
        case .layerSwitch(let layer):
            switch layer {
            case .letters: return "page:letters"
            case .symbols: return "page:symbols"
            case .extendedSymbols: return "page:extendedSymbols"
            }
        case .numpadFlip: return "numpad"
        case .packSwitch: return "pack"
        case .dismissKeyboard: return "dismiss"
        case .dateTimeToken(let label, _): return "dateTime:\(label)"
        case .snippet(let label, _): return "snippet:\(label)"
        }
    }
}
