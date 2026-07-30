//
//  StudioKeyboardPreviewModel.swift
//  NumPad
//

import UIKit

/// A truthful, non-interactive rendering of what the keyboard will actually look like.
/// Pure presentation: reads no globals, performs no writes, imports only UIKit.
struct StudioKeyboardPreviewModel: Equatable {
    var theme: KeyboardTheme
    var pack: KeyboardType
    var heightPreset: KeyboardHeightPreset
    var isReversedMode: Bool
    var hasRoundedCorners: Bool
    var hasGrid: Bool
    var showsLettersRow: Bool
    var idiom: UIUserInterfaceIdiom

    /// The caption rows used by the renderer. The pack row is sourced from the production pack
    /// catalogs; the number rows mirror `Item.all(type:)` in the Keyboard target.
    let keyRows: [[String]]

    /// The existing right-side key configuration is presentation data, captured by `current`.
    let sideKeyCaptions: [String]

    /// Height divided by the reference preview width. The view uses this for its intrinsic size.
    let aspectRatio: CGFloat

    init(
        theme: KeyboardTheme,
        pack: KeyboardType,
        heightPreset: KeyboardHeightPreset,
        isReversedMode: Bool,
        hasRoundedCorners: Bool,
        hasGrid: Bool,
        showsLettersRow: Bool,
        idiom: UIUserInterfaceIdiom,
        sideKeyCaptions: [String] = CustomKeys.defaultSlots.map(CustomKeys.displayName)
    ) {
        self.theme = theme
        self.pack = pack
        self.heightPreset = heightPreset
        self.isReversedMode = isReversedMode
        self.hasRoundedCorners = hasRoundedCorners
        self.hasGrid = hasGrid
        self.showsLettersRow = showsLettersRow
        self.idiom = idiom
        self.sideKeyCaptions = Array(sideKeyCaptions.prefix(CustomKeys.slotCount))
        self.keyRows = Self.rows(
            pack: pack,
            reversed: isReversedMode,
            sideKeyCaptions: self.sideKeyCaptions,
            showsLettersRow: showsLettersRow
        )
        self.aspectRatio = heightPreset.baseHeight(idiom: idiom) / 320
    }

    /// Snapshot of the CURRENT live settings. The only place that touches globals.
    static func current(idiom: UIUserInterfaceIdiom) -> StudioKeyboardPreviewModel {
        StudioKeyboardPreviewModel(
            theme: .selectedOrAutomatic,
            pack: .selected,
            heightPreset: KeyboardHeightPreset.effective(
                stored: .selected,
                kioskEntitled: Monetization.isKioskHeightEntitled
            ),
            isReversedMode: Keyboard.isReversedMode,
            hasRoundedCorners: Keyboard.hasRoundedCorners,
            hasGrid: Keyboard.hasGrid,
            showsLettersRow: UserPrefs.keyboardPageRaw == "qwerty" && FeatureFlags.isQwertyPageAvailable,
            idiom: idiom,
            sideKeyCaptions: CustomKeys.slots.map(CustomKeys.displayName)
        )
    }

    /// Snapshot of what a profile WOULD produce. This path deliberately probes the existing
    /// transactional profile resolver rather than applying the profile to shared defaults.
    static func projected(
        from configuration: KeyboardProfile.Configuration,
        idiom: UIUserInterfaceIdiom
    ) -> StudioKeyboardPreviewModel {
        projected(
            from: configuration,
            idiom: idiom,
            applier: KeyboardProfileApplier(defaults: .group),
            entitlements: .live()
        )
    }

    static func projected(
        from configuration: KeyboardProfile.Configuration,
        idiom: UIUserInterfaceIdiom,
        applier: KeyboardProfileApplier,
        entitlements: ProfileEntitlements
    ) -> StudioKeyboardPreviewModel {
        let previewProfile = KeyboardProfile(
            id: UUID(),
            name: "Preview",
            kind: .custom,
            configuration: configuration,
            kioskPolicy: nil,
            schemaVersion: KeyboardProfile.currentSchemaVersion
        )
        let resolved = (try? applier.probe(previewProfile, entitlements: entitlements))?.appliedConfiguration
            ?? configuration
        return model(from: resolved, idiom: idiom, qwertyAvailable: FeatureFlags.qwertyPageAvailable(
            remoteEnabled: applier.qwertyRemoteEnabled(),
            entitled: entitlements.fullKeyboardEntitled
        ))
    }

    private static func model(
        from configuration: KeyboardProfile.Configuration,
        idiom: UIUserInterfaceIdiom,
        qwertyAvailable: Bool
    ) -> StudioKeyboardPreviewModel {
        StudioKeyboardPreviewModel(
            theme: KeyboardTheme(rawValue: configuration.themeRaw) ?? .white,
            pack: KeyboardType(rawValue: configuration.keyboardTypeRaw) ?? .default,
            heightPreset: KeyboardHeightPreset(rawValue: configuration.heightRaw) ?? .regular,
            isReversedMode: configuration.reversedMode,
            hasRoundedCorners: configuration.roundedCorners,
            hasGrid: configuration.grid,
            showsLettersRow: configuration.keyboardPageRaw == "qwerty" && qwertyAvailable,
            idiom: idiom
        )
    }

    private static func rows(
        pack: KeyboardType,
        reversed: Bool,
        sideKeyCaptions: [String],
        showsLettersRow: Bool
    ) -> [[String]] {
        var rows = packCaptions(for: pack).isEmpty ? [] : [packCaptions(for: pack)]
        let digits = stride(from: 1, through: 9, by: 3).map { start in
            (start..<(start + 3)).map(String.init)
        }
        let orderedDigits = reversed ? digits.reversed() : digits
        rows += orderedDigits.enumerated().map { index, digits in
            digits + [sideKeyCaptions.indices.contains(index) ? sideKeyCaptions[index] : ""]
        }
        rows.append(["⌘", "0", "⌫", "↵"])
        if showsLettersRow {
            rows.append(["ABC"])
        }
        return rows
    }

    private static func packCaptions(for pack: KeyboardType) -> [String] {
        switch pack {
        case .datetime:
            return DateTimeTokens.ordered.map(\.label)
        case .math:
            return ["+", "−", "×", "÷", "=", "%", "#", "$", "(", ")"]
        case .math2:
            return ["'", "\"", "\\", ":", ";", "!", "?", "&", "[", "]"]
        default:
            return PackKeys.symbols(for: pack)
        }
    }
}
