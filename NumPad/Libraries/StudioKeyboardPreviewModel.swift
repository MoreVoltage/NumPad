//
//  StudioKeyboardPreviewModel.swift
//  NumPad
//

import UIKit

/// A truthful, non-interactive rendering of what the keyboard will actually look like.
/// Pure presentation: reads no globals, performs no writes, imports only UIKit.
struct StudioKeyboardPreviewModel: Equatable {
    /// The page that the extension is currently presenting. Availability is deliberately separate:
    /// a temporarily unavailable saved Letters selection falls back visually without rewriting it.
    enum Page: Equatable {
        case numpad, qwerty
    }

    var theme: KeyboardTheme
    var pack: KeyboardType
    var heightPreset: KeyboardHeightPreset
    var isReversedMode: Bool
    var hasRoundedCorners: Bool
    var hasGrid: Bool
    let isQwertyAvailable: Bool
    let page: Page
    var idiom: UIUserInterfaceIdiom
    /// Horizontal-only layout preferences mirrored from the extension's shared geometry inputs.
    let numpadWidthSize: NumpadWidthSize
    let iPadQwertyLayout: IPadQwertyLayout
    let fullKeyboardNumpadSide: FullKeyboardNumpadSide

    /// Compatibility for existing non-interactive callers. This means the Letters page is active,
    /// not that an ABC key should be appended to a numpad preview.
    var showsLettersRow: Bool { page == .qwerty }

    /// The text fallbacks used by the renderer. Image-backed keys use the matching semantic label.
    let keyRows: [[String]]

    /// The exact production captions, including image-backed keys, consumed by the renderer.
    let captionRows: [[KeyboardLayoutCaption]]

    /// Separate source rows let a full iPad keyboard render both real panes at once.
    let numpadCaptionRows: [[KeyboardLayoutCaption]]
    let qwertyCaptionRows: [[KeyboardLayoutCaption]]

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
        sideKeyCaptions: [String] = CustomKeys.defaultSlots.map(CustomKeys.displayName),
        customPackKeys: [String] = [],
        customKeyboardConfig: CustomKeyboardConfig? = nil,
        handedness: Handedness = .right,
        numpadWidthSize: NumpadWidthSize = .defaultValue,
        iPadQwertyLayout: IPadQwertyLayout = .defaultValue,
        fullKeyboardNumpadSide: FullKeyboardNumpadSide = .defaultValue
    ) {
        self.init(
            theme: theme,
            pack: pack,
            heightPreset: heightPreset,
            isReversedMode: isReversedMode,
            hasRoundedCorners: hasRoundedCorners,
            hasGrid: hasGrid,
            qwertyAvailable: showsLettersRow,
            activePage: showsLettersRow ? .qwerty : .numpad,
            idiom: idiom,
            sideKeyCaptions: sideKeyCaptions,
            customPackKeys: customPackKeys,
            customKeyboardConfig: customKeyboardConfig,
            handedness: handedness,
            numpadWidthSize: numpadWidthSize,
            iPadQwertyLayout: iPadQwertyLayout,
            fullKeyboardNumpadSide: fullKeyboardNumpadSide
        )
    }

    init(
        theme: KeyboardTheme,
        pack: KeyboardType,
        heightPreset: KeyboardHeightPreset,
        isReversedMode: Bool,
        hasRoundedCorners: Bool,
        hasGrid: Bool,
        qwertyAvailable: Bool,
        activePage: Page,
        idiom: UIUserInterfaceIdiom,
        sideKeyCaptions: [String] = CustomKeys.defaultSlots.map(CustomKeys.displayName),
        customPackKeys: [String] = [],
        customKeyboardConfig: CustomKeyboardConfig? = nil,
        handedness: Handedness = .right,
        qwertyPeriodComma: Bool = true,
        numpadWidthSize: NumpadWidthSize = .defaultValue,
        iPadQwertyLayout: IPadQwertyLayout = .defaultValue,
        fullKeyboardNumpadSide: FullKeyboardNumpadSide = .defaultValue
    ) {
        self.theme = theme
        self.pack = pack
        self.heightPreset = heightPreset
        self.isReversedMode = isReversedMode
        self.hasRoundedCorners = hasRoundedCorners
        self.hasGrid = hasGrid
        self.isQwertyAvailable = qwertyAvailable
        self.page = activePage == .qwerty && qwertyAvailable ? .qwerty : .numpad
        self.idiom = idiom
        self.numpadWidthSize = numpadWidthSize
        self.iPadQwertyLayout = iPadQwertyLayout
        self.fullKeyboardNumpadSide = fullKeyboardNumpadSide
        self.sideKeyCaptions = Array(sideKeyCaptions.prefix(CustomKeys.slotCount))
        self.numpadCaptionRows = Self.numpadRows(
            pack: pack,
            reversed: isReversedMode,
            sideKeyCaptions: self.sideKeyCaptions,
            customPackKeys: customPackKeys,
            customKeyboardConfig: customKeyboardConfig,
            handedness: handedness,
            qwertyAvailable: qwertyAvailable
        )
        self.qwertyCaptionRows = Self.qwertyRows(
            idiom: idiom,
            periodCommaOnLetters: qwertyPeriodComma
        )
        self.captionRows = self.page == .qwerty ? self.qwertyCaptionRows : self.numpadCaptionRows
        self.keyRows = self.captionRows.map { $0.map(\.previewText) }
        self.aspectRatio = heightPreset.baseHeight(idiom: idiom) / 320
    }

    /// Snapshot of the CURRENT live settings. The only place that touches globals.
    static func current(idiom: UIUserInterfaceIdiom) -> StudioKeyboardPreviewModel {
        let customKeyboardConfig = Monetization.isCustomKeyboardEntitled
            ? CustomKeyboardStore(defaults: .group).load()
            : nil
        return StudioKeyboardPreviewModel(
            theme: .selectedOrAutomatic,
            pack: .selected,
            heightPreset: KeyboardHeightPreset.effective(
                stored: .selected,
                kioskEntitled: Monetization.isKioskHeightEntitled
            ),
            isReversedMode: Keyboard.isReversedMode,
            hasRoundedCorners: Keyboard.hasRoundedCorners,
            hasGrid: Keyboard.hasGrid,
            qwertyAvailable: FeatureFlags.isQwertyPageAvailable,
            activePage: UserPrefs.keyboardPageRaw == "qwerty" ? .qwerty : .numpad,
            idiom: idiom,
            sideKeyCaptions: CustomKeys.slots.map(CustomKeys.displayName),
            customPackKeys: CustomPackManager.shared.keys,
            customKeyboardConfig: customKeyboardConfig,
            handedness: UserPrefs.handedness,
            qwertyPeriodComma: UserPrefs.qwertyPeriodComma,
            numpadWidthSize: UserPrefs.numpadWidthSize,
            iPadQwertyLayout: UserPrefs.iPadQwertyLayout,
            fullKeyboardNumpadSide: UserPrefs.fullKeyboardNumpadSide
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
        return model(
            from: resolved,
            idiom: idiom,
            qwertyAvailable: FeatureFlags.qwertyPageAvailable(
                remoteEnabled: applier.qwertyRemoteEnabled(),
                entitled: entitlements.fullKeyboardEntitled
            ),
            customPackKeys: CustomPackManager.shared.keys
        )
    }

    private static func model(
        from configuration: KeyboardProfile.Configuration,
        idiom: UIUserInterfaceIdiom,
        qwertyAvailable: Bool,
        customPackKeys: [String]
    ) -> StudioKeyboardPreviewModel {
        StudioKeyboardPreviewModel(
            theme: KeyboardTheme(rawValue: configuration.themeRaw) ?? .white,
            pack: KeyboardType(rawValue: configuration.keyboardTypeRaw) ?? .default,
            heightPreset: KeyboardHeightPreset(rawValue: configuration.heightRaw) ?? .regular,
            isReversedMode: configuration.reversedMode,
            hasRoundedCorners: configuration.roundedCorners,
            hasGrid: configuration.grid,
            qwertyAvailable: qwertyAvailable,
            activePage: configuration.keyboardPageRaw == "qwerty" ? .qwerty : .numpad,
            idiom: idiom,
            customPackKeys: customPackKeys,
            customKeyboardConfig: configuration.customKeyboardConfig,
            handedness: Handedness(rawValue: configuration.handednessRaw) ?? .right,
            qwertyPeriodComma: configuration.qwertyPeriodComma,
            numpadWidthSize: NumpadWidthSize(rawValue: configuration.numpadWidthSizeRaw ?? "")
                ?? NumpadWidthSize.migrated(from: NumpadPlacement(rawValue: configuration.numpadPlacementRaw) ?? .automatic),
            iPadQwertyLayout: IPadQwertyLayout(rawValue: configuration.iPadQwertyLayoutRaw ?? "")
                ?? IPadQwertyLayout.migrated(from: QwertyLayoutMode(rawValue: configuration.qwertyLayoutModeRaw) ?? .automatic),
            fullKeyboardNumpadSide: FullKeyboardNumpadSide(rawValue: configuration.fullKeyboardNumpadSideRaw ?? "")
                ?? .defaultValue
        )
    }

    private static func numpadRows(
        pack: KeyboardType,
        reversed: Bool,
        sideKeyCaptions: [String],
        customPackKeys: [String],
        customKeyboardConfig: CustomKeyboardConfig?,
        handedness: Handedness,
        qwertyAvailable: Bool
    ) -> [[KeyboardLayoutCaption]] {
        if let customKeyboardConfig, customKeyboardConfig.hasAnyKeys {
            return customKeyboardRows(
                config: customKeyboardConfig,
                pack: pack,
                customPackKeys: customPackKeys,
                handedness: handedness,
                reversed: reversed,
                qwertyAvailable: qwertyAvailable
            )
        }
        let packRow = PackKeys.layout(for: pack, customKeys: customPackKeys)
        var rows = packRow.isEmpty ? [] : [packRow]
        let digits = stride(from: 1, through: 9, by: 3).map { start in
            (start..<(start + 3)).map(String.init)
        }
        let orderedDigits = reversed ? digits.reversed() : digits
        rows += orderedDigits.enumerated().map { index, digits in
            digits.map { KeyboardLayoutCaption.text($0) }
                + [.text(sideKeyCaptions.indices.contains(index) ? sideKeyCaptions[index] : "")]
        }
        rows.append(numpadBottomRow(
            PackKeys.bottomRow(returnKeyTitle: NSLocalizedString("Enter", comment: "Generic return-key title")),
            qwertyAvailable: qwertyAvailable
        ))
        return rows
    }

    private static func customKeyboardRows(
        config: CustomKeyboardConfig,
        pack: KeyboardType,
        customPackKeys: [String],
        handedness: Handedness,
        reversed: Bool,
        qwertyAvailable: Bool
    ) -> [[KeyboardLayoutCaption]] {
        let topRow = PackKeys.customKeyboardTopRow(
            for: pack,
            customPackKeys: customPackKeys,
            configuration: config
        )
        var rows = CustomKeyboardLayout.bodyRows(
            for: config,
            handedness: handedness,
            needsSwitchKey: false,
            reversed: reversed
        ).map { $0.map(customCaption) }
        if !topRow.isEmpty {
            rows.insert(topRow, at: 0)
        }
        if var bottomRow = rows.popLast() {
            bottomRow = numpadBottomRow(bottomRow, qwertyAvailable: qwertyAvailable)
            rows.append(bottomRow)
        }
        return rows
    }

    /// Mirrors `KeyboardViewController.insertingQwertyPageKey(_:)`: ABC becomes the leading
    /// bottom-row key and the pack switch moves immediately after 0. The preview intentionally
    /// does not model the runtime-only dedicated globe-key decision (`needsSwitchKey`).
    private static func numpadBottomRow(
        _ original: [KeyboardLayoutCaption],
        qwertyAvailable: Bool
    ) -> [KeyboardLayoutCaption] {
        guard qwertyAvailable else { return original }
        var bottomRow = original
        let packSwitch = bottomRow.firstIndex { $0.value == KeyGlyph.packSwitch }
            .map { bottomRow.remove(at: $0) }
        bottomRow.insert(.text("ABC", style: .primary, usesTextFont: true), at: 0)
        if let packSwitch {
            let zeroIndex = bottomRow.firstIndex { $0.value == "0" }
            bottomRow.insert(packSwitch, at: zeroIndex.map { $0 + 1 } ?? min(2, bottomRow.count))
        }
        return bottomRow
    }

    /// Bounded page preview built from the same QWERTY layout sources as the extension. The
    /// extension alone knows its live `needsInputModeSwitchKey`; the Studio deliberately omits
    /// that device-specific globe variation rather than inventing it.
    private static func qwertyRows(
        idiom: UIUserInterfaceIdiom,
        periodCommaOnLetters: Bool
    ) -> [[KeyboardLayoutCaption]] {
        let strip = QwertyTopStrip.keys(for: .numbers).map(qwertyCaption)
        let options = QwertyLayoutOptions(
            periodCommaOnLetters: periodCommaOnLetters,
            needsSwitchKey: false,
            needsDismissKey: idiom == .pad
        )
        return [strip] + QwertyLayout.rows(layer: .letters, options: options).map { row in
            row.keys.map(qwertyCaption)
        }
    }

    private static func qwertyCaption(for key: QwertyKey) -> KeyboardLayoutCaption {
        switch key.kind {
        case .character(let value, _): return .text(value)
        case .shift: return .image("shift")
        case .backspace: return .image("back")
        case .space: return .text("Space", style: .secondary, usesTextFont: true)
        case .ret: return .text(NSLocalizedString("Enter", comment: "Generic return-key title"), style: .secondary, usesTextFont: true)
        case .globe: return .image("globe")
        case .emojiMode: return .image("face.smiling")
        case .emojiResult(let sequence, _): return .text(sequence)
        case .layerSwitch(let layer):
            let title = layer == .letters ? "ABC" : (layer == .symbols ? "123" : "#+=")
            return .text(title, style: .secondary, usesTextFont: true)
        case .numpadFlip: return .text("NumPad", style: .primary, usesTextFont: true)
        case .packSwitch: return .image(KeyGlyph.packSwitch)
        case .dismissKeyboard: return .image("keyboard.chevron.compact.down")
        case .dateTimeToken(let label, _): return .text(label, style: .primary, usesTextFont: true)
        case .snippet(let label, _): return .text(label, style: .primary, usesTextFont: true)
        }
    }

    private static func customCaption(for cell: CustomKeyboardCell) -> KeyboardLayoutCaption {
        switch cell {
        case .digit(let digit):
            return .text(digit)
        case .zero:
            return .text("0")
        case .peripheral(let token):
            return .text(
                CustomKeys.displayName(for: token),
                style: .secondary,
                usesTextFont: true,
                actionToken: token
            )
        case .blank:
            return .text("")
        case .next:
            return .image(KeyGlyph.packSwitch)
        case .globe:
            return .image("globe")
        case .back:
            return .image("back")
        case .ret:
            return .text(
                NSLocalizedString("Enter", comment: "Generic return-key title"),
                style: .secondary,
                usesTextFont: true
            )
        }
    }
}
