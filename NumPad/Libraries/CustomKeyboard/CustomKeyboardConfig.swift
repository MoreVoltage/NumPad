import Foundation

/// A user-built custom keyboard: the fixed numpad plus up to three customizable peripheral
/// sections (a top row and two side columns). Each section is optional — `nil` means the section's
/// switch is OFF; a non-nil (possibly empty) array means it is ON. Each key is a short string: a
/// literal to insert, or one of the `CustomKeys` function tokens
/// (`{space}`/`{tab}`/`{left}`/`{right}`/`{dismiss}`).
///
/// Value type — every edit returns a new copy. `id`/`name` exist so multiple custom keyboards can
/// be layered on later without a storage migration; today exactly one config is persisted.
/// Handedness is intentionally NOT stored here — it is a global ergonomic preference
/// (`UserPrefs.handedness`) shared across keyboards.
struct CustomKeyboardConfig: Codable, Identifiable, Equatable {
    static let currentSchema = 1

    let id: UUID
    var name: String
    var topRow: [String]?
    var column1: [String]?
    var column2: [String]?
    var schemaVersion: Int

    init(id: UUID = UUID(), name: String = "Custom",
         topRow: [String]? = nil, column1: [String]? = nil, column2: [String]? = nil,
         schemaVersion: Int = CustomKeyboardConfig.currentSchema) {
        self.id = id
        self.name = name
        self.topRow = topRow
        self.column1 = column1
        self.column2 = column2
        self.schemaVersion = schemaVersion
    }
}

extension CustomKeyboardConfig {
    var isTopRowEnabled: Bool { topRow != nil }
    var isColumn1Enabled: Bool { column1 != nil }
    var isColumn2Enabled: Bool { column2 != nil }

    /// Keys rendered for an enabled section (a disabled `nil` section yields `[]`).
    var topRowKeys: [String] { topRow ?? [] }
    var column1Keys: [String] { column1 ?? [] }
    var column2Keys: [String] { column2 ?? [] }

    /// True when at least one enabled section has a non-empty key — i.e. the keyboard would render
    /// something beyond the fixed numpad. The extension only takes the custom-keyboard rendering
    /// path when this is true; otherwise it falls back to the normal pack-based layout.
    var hasAnyKeys: Bool {
        [topRow, column1, column2]
            .compactMap { $0 }
            .contains { section in section.contains { !$0.isEmpty } }
    }

    /// A fresh config seeded from the user's existing customization so their first custom keyboard
    /// matches what they already have: Custom Pack → Top Row, right-side slots → Column 1 (tokens
    /// preserved). Column 2 starts OFF. An empty Custom Pack leaves the Top Row OFF.
    static func seeded(customPackKeys: [String], rightSlots: [String], id: UUID = UUID()) -> CustomKeyboardConfig {
        CustomKeyboardConfig(
            id: id,
            topRow: customPackKeys.isEmpty ? nil : customPackKeys,
            column1: rightSlots,
            column2: nil
        )
    }
}
