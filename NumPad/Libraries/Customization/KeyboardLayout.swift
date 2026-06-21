import Foundation

/// One key in a layout: a tap action plus optional long-press, label/color overrides, and width.
struct KeyDefinition: Codable, Identifiable, Equatable {
    let id: UUID
    var primary: KeyToken
    var longPress: KeyToken?
    var label: String?
    var colorHex: String?
    var columnSpan: Int

    init(id: UUID = UUID(), primary: KeyToken, longPress: KeyToken? = nil,
         label: String? = nil, colorHex: String? = nil, columnSpan: Int = 1) {
        self.id = id
        self.primary = primary
        self.longPress = longPress
        self.label = label
        self.colorHex = colorHex
        self.columnSpan = columnSpan
    }
}

/// A named, fully-custom numpad grid. Value type — every edit returns a new copy.
struct KeyboardLayout: Codable, Identifiable, Equatable {
    static let currentSchema = 1

    let id: UUID
    var name: String
    var rows: [[KeyDefinition]]
    var keyScale: Double
    var schemaVersion: Int

    init(id: UUID = UUID(), name: String, rows: [[KeyDefinition]],
         keyScale: Double = 1.0, schemaVersion: Int = KeyboardLayout.currentSchema) {
        self.id = id
        self.name = name
        self.rows = rows
        self.keyScale = keyScale
        self.schemaVersion = schemaVersion
    }

    /// Tokens every usable layout must contain, so a user can never save a broken keyboard.
    static let essentialTokens: [KeyToken] = (0...9).map { .digit(String($0)) } + [.delete, .ret]

    /// The default numpad expressed as a custom layout — the seed for a brand-new custom layout.
    static var standard: KeyboardLayout {
        func d(_ s: String) -> KeyDefinition { KeyDefinition(primary: .digit(s)) }
        return KeyboardLayout(name: "Default", rows: [
            [d("7"), d("8"), d("9")],
            [d("4"), d("5"), d("6")],
            [d("1"), d("2"), d("3")],
            [KeyDefinition(primary: .decimalSeparator), d("0"), KeyDefinition(primary: .delete)],
            [KeyDefinition(primary: .ret)],
        ])
    }

    /// A copy guaranteed to contain every essential key, appending any missing ones in a
    /// trailing row (in `essentialTokens` order). Returns `self` unchanged when complete.
    func repaired() -> KeyboardLayout {
        let present = rows.flatMap { $0 }.map { $0.primary }
        let missing = KeyboardLayout.essentialTokens.filter { !present.contains($0) }
        guard !missing.isEmpty else { return self }
        var newRows = rows
        newRows.append(missing.map { KeyDefinition(primary: $0) })
        return KeyboardLayout(id: id, name: name, rows: newRows,
                              keyScale: keyScale, schemaVersion: schemaVersion)
    }
}
