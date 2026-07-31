//
//  StudioKeyboardPreviewTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class StudioKeyboardPreviewTests: XCTestCase {
    private let liveKeys = [
        Constants.selectedKeyboardTheme.rawValue,
        Constants.selectedKeyboardType.rawValue,
        Constants.heightPreset.rawValue,
        Constants.reversedMode.rawValue,
        Constants.roundedCorners.rawValue,
        Constants.grid.rawValue,
        Constants.keyboardPage.rawValue,
        Constants.numpadWidthSize.rawValue,
        Constants.iPadQwertyLayout.rawValue,
        Constants.fullKeyboardNumpadSide.rawValue
    ]

    func test_modelUsesProductionPackCaptionsAndReversesDigitRows() {
        let normal = StudioKeyboardPreviewModel(
            theme: .teal,
            pack: .finance,
            heightPreset: .regular,
            isReversedMode: false,
            hasRoundedCorners: true,
            hasGrid: true,
            showsLettersRow: false,
            idiom: .phone
        )
        let reversed = StudioKeyboardPreviewModel(
            theme: .teal,
            pack: .finance,
            heightPreset: .regular,
            isReversedMode: true,
            hasRoundedCorners: true,
            hasGrid: true,
            showsLettersRow: false,
            idiom: .phone
        )

        XCTAssertEqual(normal.keyRows.first?.prefix(4), ["$", "€", "£", "¥"])
        XCTAssertEqual(normal.keyRows.dropFirst().first?.prefix(3), ["1", "2", "3"])
        XCTAssertEqual(reversed.keyRows.dropFirst().first?.prefix(3), ["7", "8", "9"])
    }

    func test_modelUsesTheProductionMathAndMath2CaptionRows() {
        let math = makeModel(pack: .math)
        let math2 = makeModel(pack: .math2)

        XCTAssertEqual(math.captionRows.first?.map(\.value), ["+", "-", "*", "/", "=", "%", "#", "$", "(", ")", "math2"])
        XCTAssertEqual(math.captionRows.first?.last?.presentation, .image)
        XCTAssertEqual(math2.captionRows.first?.map(\.value), ["'", "\"", "\\", ":", ";", "!", "?", "&", "[", "]", "math"])
        XCTAssertEqual(math2.captionRows.first?.last?.presentation, .image)
    }

    func test_modelUsesProductionImageBackedBottomCaptions() {
        let model = makeModel(pack: .default)
        let bottom = model.captionRows.last

        XCTAssertEqual(bottom?.map(\.value), [KeyGlyph.packSwitch, "0", "back", "Enter"])
        XCTAssertEqual(bottom?.map(\.presentation), [.image, .text, .image, .text])
    }

    func test_heightPresetChangesPreviewAspectRatio() {
        let compact = StudioKeyboardPreviewModel(
            theme: .white,
            pack: .default,
            heightPreset: .small,
            isReversedMode: false,
            hasRoundedCorners: false,
            hasGrid: true,
            showsLettersRow: false,
            idiom: .phone
        )
        let tall = StudioKeyboardPreviewModel(
            theme: .white,
            pack: .default,
            heightPreset: .tall,
            isReversedMode: false,
            hasRoundedCorners: false,
            hasGrid: true,
            showsLettersRow: false,
            idiom: .phone
        )

        XCTAssertLessThan(compact.aspectRatio, tall.aspectRatio)
    }

    func test_currentSnapshotsLiveSettingsWithoutChangingThem() {
        let defaults = UserDefaults.group
        let before = snapshot(defaults, keys: liveKeys)
        defer { restore(before, in: defaults) }
        defaults.set(KeyboardTheme.glassDark.rawValue, forKey: Constants.selectedKeyboardTheme.rawValue)
        defaults.set(KeyboardType.units.rawValue, forKey: Constants.selectedKeyboardType.rawValue)
        defaults.set(KeyboardHeightPreset.kiosk.rawValue, forKey: Constants.heightPreset.rawValue)
        defaults.set(true, forKey: Constants.reversedMode.rawValue)
        defaults.set(true, forKey: Constants.roundedCorners.rawValue)
        defaults.set(false, forKey: Constants.grid.rawValue)
        defaults.set("qwerty", forKey: Constants.keyboardPage.rawValue)
        defaults.set(NumpadWidthSize.comfortable.rawValue, forKey: Constants.numpadWidthSize.rawValue)
        defaults.set(IPadQwertyLayout.full.rawValue, forKey: Constants.iPadQwertyLayout.rawValue)
        defaults.set(FullKeyboardNumpadSide.left.rawValue, forKey: Constants.fullKeyboardNumpadSide.rawValue)
        let expectedSettings = snapshot(defaults, keys: liveKeys)

        let model = StudioKeyboardPreviewModel.current(idiom: .phone)

        XCTAssertEqual(model.theme, .glassDark)
        XCTAssertEqual(model.pack, .units)
        XCTAssertEqual(model.heightPreset, KeyboardHeightPreset.effective(stored: .kiosk, kioskEntitled: Monetization.isKioskHeightEntitled))
        XCTAssertTrue(model.isReversedMode)
        XCTAssertEqual(model.keyRows.first(where: { $0.prefix(3) == ["7", "8", "9"] })?.prefix(3), ["7", "8", "9"])
        XCTAssertTrue(model.hasRoundedCorners)
        XCTAssertFalse(model.hasGrid)
        XCTAssertEqual(model.numpadWidthSize, .comfortable)
        XCTAssertEqual(model.iPadQwertyLayout, .full)
        XCTAssertEqual(model.fullKeyboardNumpadSide, .left)
        XCTAssertEqual(model.showsLettersRow, FeatureFlags.isQwertyPageAvailable)
        XCTAssertEqual(snapshot(defaults, keys: liveKeys) as NSDictionary, expectedSettings as NSDictionary)
    }

    func test_fullIPadQwertyKeepsProductionQwertyAndActiveNumpadRowsTogether() {
        let model = StudioKeyboardPreviewModel(
            theme: .white,
            pack: .finance,
            heightPreset: .regular,
            isReversedMode: false,
            hasRoundedCorners: true,
            hasGrid: true,
            qwertyAvailable: true,
            activePage: .qwerty,
            idiom: .pad,
            numpadWidthSize: .compact,
            iPadQwertyLayout: .full,
            fullKeyboardNumpadSide: .left
        )

        XCTAssertEqual(model.qwertyCaptionRows.first?.map(\.value), ["NumPad", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "square.grid.2x2"])
        XCTAssertEqual(model.numpadCaptionRows.first?.map(\.value), ["$", "€", "£", "¥", "₹", "¢", "%", "‰", "(", ")"])
        XCTAssertEqual(model.qwertyCaptionRows.dropFirst().first?.map(\.value), ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
        XCTAssertEqual(model.numpadCaptionRows.dropFirst().first?.map(\.value), ["1", "2", "3", ","])
    }

    func test_iPadWidthChangesOnlyTheHorizontalPreviewComposition() {
        let compact = StudioKeyboardPreviewModel(
            theme: .teal,
            pack: .math,
            heightPreset: .tall,
            isReversedMode: true,
            hasRoundedCorners: false,
            hasGrid: true,
            qwertyAvailable: true,
            activePage: .numpad,
            idiom: .pad,
            numpadWidthSize: .compact
        )
        let full = StudioKeyboardPreviewModel(
            theme: .teal,
            pack: .math,
            heightPreset: .tall,
            isReversedMode: true,
            hasRoundedCorners: false,
            hasGrid: true,
            qwertyAvailable: true,
            activePage: .numpad,
            idiom: .pad,
            numpadWidthSize: .full
        )

        XCTAssertEqual(compact.aspectRatio, full.aspectRatio)
        XCTAssertEqual(compact.heightPreset, full.heightPreset)
        XCTAssertEqual(compact.numpadCaptionRows, full.numpadCaptionRows)
        XCTAssertEqual(compact.captionRows, full.captionRows)
    }

    func test_fullIPadRendererUsesSharedCompositionFramesForBothPanes() {
        let model = StudioKeyboardPreviewModel(
            theme: .white,
            pack: .default,
            heightPreset: .regular,
            isReversedMode: false,
            hasRoundedCorners: true,
            hasGrid: true,
            qwertyAvailable: true,
            activePage: .qwerty,
            idiom: .pad,
            iPadQwertyLayout: .full,
            fullKeyboardNumpadSide: .left
        )
        let view = StudioKeyboardPreviewView(model: model)
        view.frame = CGRect(x: 0, y: 0, width: 1_000, height: 260)
        view.layoutIfNeeded()

        let expectedKeyCount = model.qwertyCaptionRows.flatMap { $0 }.count
            + model.numpadCaptionRows.flatMap { $0 }.count
        XCTAssertEqual(view.renderedKeyViews.count, expectedKeyCount)
        let qwertyFirstKey = try! XCTUnwrap(view.renderedKeyViews.first)
        let numpadFirstKey = try! XCTUnwrap(view.renderedKeyViews[model.qwertyCaptionRows.flatMap { $0 }.count])
        XCTAssertLessThan(numpadFirstKey.frame.midX, qwertyFirstKey.frame.midX)
        XCTAssertEqual(numpadFirstKey.frame.minY, qwertyFirstKey.frame.minY, accuracy: 0.001)
    }

    func test_availableLettersAddABCToTheExistingNumpadBottomRow() {
        let model = StudioKeyboardPreviewModel(
            theme: .white,
            pack: .default,
            heightPreset: .regular,
            isReversedMode: false,
            hasRoundedCorners: false,
            hasGrid: true,
            qwertyAvailable: true,
            activePage: .numpad,
            idiom: .phone
        )

        XCTAssertTrue(model.isQwertyAvailable)
        XCTAssertEqual(model.page, .numpad)
        XCTAssertEqual(model.keyRows.last, ["ABC", "0", "Key sets", "Delete", "Enter"])
    }

    func test_activeLettersPageUsesProductionQwertyRowsInsteadOfNumpadPlusABC() {
        let model = StudioKeyboardPreviewModel(
            theme: .white,
            pack: .default,
            heightPreset: .regular,
            isReversedMode: false,
            hasRoundedCorners: false,
            hasGrid: true,
            qwertyAvailable: true,
            activePage: .qwerty,
            idiom: .phone
        )

        XCTAssertEqual(model.page, .qwerty)
        XCTAssertEqual(model.keyRows.first?.first, "NumPad")
        XCTAssertEqual(model.keyRows.dropFirst().first, ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
        XCTAssertEqual(model.keyRows.last, ["123", ",", "Space", ".", "Enter"])
        XCTAssertNotEqual(model.keyRows.last, ["ABC", "0", "Key sets", "Delete", "Enter"])
    }

    func test_unavailableLettersKeepTheNumpadAndDoNotAddABC() {
        let model = StudioKeyboardPreviewModel(
            theme: .white,
            pack: .default,
            heightPreset: .regular,
            isReversedMode: false,
            hasRoundedCorners: false,
            hasGrid: true,
            qwertyAvailable: false,
            activePage: .qwerty,
            idiom: .phone
        )

        XCTAssertFalse(model.isQwertyAvailable)
        XCTAssertEqual(model.page, .numpad)
        XCTAssertEqual(model.keyRows.last, ["Key sets", "0", "Delete", "Enter"])
    }

    func test_currentUsesTheConfiguredProductionSideKeyCaptions() {
        let defaults = UserDefaults.group
        let keys = [Constants.customKeySlots.rawValue, Constants.selectedKeyboardType.rawValue, Constants.reversedMode.rawValue]
        let before = snapshot(defaults, keys: keys)
        defer {
            keys.forEach(defaults.removeObject(forKey:))
            before.forEach { defaults.set($0.value, forKey: $0.key) }
        }
        defaults.set(["+", CustomKeys.spaceToken, "$"], forKey: Constants.customKeySlots.rawValue)
        defaults.set(KeyboardType.default.rawValue, forKey: Constants.selectedKeyboardType.rawValue)
        defaults.set(false, forKey: Constants.reversedMode.rawValue)

        let model = StudioKeyboardPreviewModel.current(idiom: .phone)

        XCTAssertEqual(model.keyRows.prefix(3).map { $0.last }, ["+", "Space", "$"])
    }

    func test_currentUsesTheConfiguredCustomPackKeys() {
        let defaults = UserDefaults.group
        let keys = [Constants.customPackKeys.rawValue, Constants.selectedKeyboardType.rawValue]
        let before = snapshot(defaults, keys: keys)
        defer {
            keys.forEach(defaults.removeObject(forKey:))
            before.forEach { defaults.set($0.value, forKey: $0.key) }
        }
        defaults.set(["VAT", "SKU", "×"], forKey: Constants.customPackKeys.rawValue)
        defaults.set(KeyboardType.custom.rawValue, forKey: Constants.selectedKeyboardType.rawValue)

        let model = StudioKeyboardPreviewModel.current(idiom: .phone)

        XCTAssertEqual(model.captionRows.first?.map(\.value), ["VAT", "SKU", "×"])
    }

    func test_projectedUsesFallbackResolutionWithoutWritingSharedSettings() {
        let suiteName = "studio-preview-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("unchanged", forKey: Constants.selectedKeyboardType.rawValue)
        let before = snapshot(defaults, keys: KeyboardProfileApplier.liveSettingKeys)
        var configuration = KeyboardProfile.Configuration.testFixture
        configuration.keyboardTypeRaw = KeyboardType.finance.rawValue
        configuration.themeRaw = KeyboardTheme.glass.rawValue
        configuration.heightRaw = KeyboardHeightPreset.kiosk.rawValue
        configuration.keyboardPageRaw = "qwerty"
        var applier = KeyboardProfileApplier(defaults: defaults)
        applier.qwertyRemoteEnabled = { false }
        let locked = ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: false,
            kioskHeightEntitled: false,
            customKeyboardEntitled: false,
            fullKeyboardEntitled: false,
            ownedPackProductIDs: []
        )

        let model = StudioKeyboardPreviewModel.projected(
            from: configuration,
            idiom: .pad,
            applier: applier,
            entitlements: locked
        )

        XCTAssertEqual(model.pack, .default)
        XCTAssertEqual(model.theme, .white)
        XCTAssertEqual(model.heightPreset, .tall)
        XCTAssertFalse(model.showsLettersRow)
        XCTAssertEqual(snapshot(defaults, keys: KeyboardProfileApplier.liveSettingKeys) as NSDictionary, before as NSDictionary)
    }

    func test_projectedQwertyPageUsesLettersLayoutWithoutApplyingCustomNumpadConfiguration() {
        let suiteName = "studio-preview-projected-qwerty-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let before = snapshot(defaults, keys: KeyboardProfileApplier.liveSettingKeys)
        var configuration = KeyboardProfile.Configuration.testFixture
        configuration.keyboardPageRaw = "qwerty"
        configuration.customKeyboardConfig = CustomKeyboardConfig(topRow: ["TAX"], column1: ["A"])
        var applier = KeyboardProfileApplier(defaults: defaults)
        applier.qwertyRemoteEnabled = { true }
        let entitled = ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: true,
            kioskHeightEntitled: true,
            customKeyboardEntitled: true,
            fullKeyboardEntitled: true,
            ownedPackProductIDs: []
        )

        let model = StudioKeyboardPreviewModel.projected(
            from: configuration,
            idiom: .phone,
            applier: applier,
            entitlements: entitled
        )

        XCTAssertEqual(model.page, .qwerty)
        XCTAssertTrue(model.isQwertyAvailable)
        XCTAssertEqual(model.keyRows.dropFirst().first, ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
        XCTAssertFalse(model.keyRows.flatMap { $0 }.contains("TAX"))
        XCTAssertEqual(snapshot(defaults, keys: KeyboardProfileApplier.liveSettingKeys) as NSDictionary, before as NSDictionary)
    }

    func test_projectedUsesEntitledCustomKeyboardConfigurationWithoutWritingDefaults() {
        let suiteName = "studio-preview-custom-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("unchanged", forKey: Constants.selectedKeyboardType.rawValue)
        let before = snapshot(defaults, keys: KeyboardProfileApplier.liveSettingKeys)
        var configuration = KeyboardProfile.Configuration.testFixture
        configuration.keyboardTypeRaw = KeyboardType.default.rawValue
        configuration.customKeyboardConfig = CustomKeyboardConfig(
            topRow: ["TAX", CustomKeys.spaceToken],
            column1: ["A", "B", "C"],
            column2: [CustomKeys.tabToken]
        )
        configuration.handednessRaw = Handedness.right.rawValue
        let entitled = ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: false,
            kioskHeightEntitled: false,
            customKeyboardEntitled: true,
            fullKeyboardEntitled: false,
            ownedPackProductIDs: []
        )

        let model = StudioKeyboardPreviewModel.projected(
            from: configuration,
            idiom: .phone,
            applier: KeyboardProfileApplier(defaults: defaults),
            entitlements: entitled
        )

        XCTAssertEqual(model.keyRows, [
            ["TAX", "Space"],
            ["1", "2", "3", "A", "Tab"],
            ["4", "5", "6", "B", ""],
            ["7", "8", "9", "C", ""],
            ["Key sets", "0", "Delete", "Enter"]
        ])
        XCTAssertEqual(snapshot(defaults, keys: KeyboardProfileApplier.liveSettingKeys) as NSDictionary, before as NSDictionary)
    }

    func test_projectedCustomPackRowPrecedesStructuredCustomTopRowWithoutWritingDefaults() {
        let suiteName = "studio-preview-custom-pack-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let customPack = CustomPackManager.shared
        let previousCustomPackKeys = customPack.keys
        defer { customPack.keys = previousCustomPackKeys }
        customPack.keys = ["PACK", "ROW"]
        let before = snapshot(defaults, keys: KeyboardProfileApplier.liveSettingKeys)
        var configuration = KeyboardProfile.Configuration.testFixture
        configuration.keyboardTypeRaw = KeyboardType.custom.rawValue
        configuration.customKeyboardConfig = CustomKeyboardConfig(topRow: ["PROFILE"])
        let entitled = ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: false,
            kioskHeightEntitled: false,
            customKeyboardEntitled: true,
            fullKeyboardEntitled: false,
            ownedPackProductIDs: []
        )

        let model = StudioKeyboardPreviewModel.projected(
            from: configuration,
            idiom: .phone,
            applier: KeyboardProfileApplier(defaults: defaults),
            entitlements: entitled
        )

        XCTAssertEqual(model.keyRows.first, ["PACK", "ROW"])
        XCTAssertEqual(customPack.keys, ["PACK", "ROW"])
        XCTAssertEqual(snapshot(defaults, keys: KeyboardProfileApplier.liveSettingKeys) as NSDictionary, before as NSDictionary)
    }

    func test_projectedEmptyCustomPackFallsBackToStructuredCustomTopRowWithoutWritingDefaults() {
        let suiteName = "studio-preview-empty-custom-pack-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let customPack = CustomPackManager.shared
        let previousCustomPackKeys = customPack.keys
        defer { customPack.keys = previousCustomPackKeys }
        customPack.keys = []
        let before = snapshot(defaults, keys: KeyboardProfileApplier.liveSettingKeys)
        var configuration = KeyboardProfile.Configuration.testFixture
        configuration.keyboardTypeRaw = KeyboardType.custom.rawValue
        configuration.customKeyboardConfig = CustomKeyboardConfig(topRow: ["PROFILE"])
        let entitled = ProfileEntitlements(
            paywallEnabled: true,
            proEntitled: false,
            kioskHeightEntitled: false,
            customKeyboardEntitled: true,
            fullKeyboardEntitled: false,
            ownedPackProductIDs: []
        )

        let model = StudioKeyboardPreviewModel.projected(
            from: configuration,
            idiom: .phone,
            applier: KeyboardProfileApplier(defaults: defaults),
            entitlements: entitled
        )

        XCTAssertEqual(model.keyRows.first, ["PROFILE"])
        XCTAssertEqual(customPack.keys, [])
        XCTAssertEqual(snapshot(defaults, keys: KeyboardProfileApplier.liveSettingKeys) as NSDictionary, before as NSDictionary)
    }

    func test_viewIsOneAccessibleImageAndVisiblyAppliesGridAndCorners() {
        let model = StudioKeyboardPreviewModel(
            theme: .glass,
            pack: .default,
            heightPreset: .tall,
            isReversedMode: false,
            hasRoundedCorners: true,
            hasGrid: true,
            showsLettersRow: true,
            idiom: .phone
        )
        let view = StudioKeyboardPreviewView(model: model)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 260)
        view.layoutIfNeeded()

        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertTrue(view.accessibilityTraits.contains(.image))
        XCTAssertTrue(view.accessibilityLabel?.contains("Keyboard preview") == true)
        XCTAssertTrue(view.renderedKeyViews.allSatisfy { !$0.isAccessibilityElement })
        XCTAssertGreaterThan(view.renderedKeyViews.first?.layer.cornerRadius ?? 0, 0)
        XCTAssertFalse(view.glassBlurView.isHidden)
        XCTAssertGreaterThan(view.renderedKeyViews[1].frame.minX - view.renderedKeyViews[0].frame.maxX, 0)
    }

    func test_viewScalesKeyboardCanvasForTheSelectedHeight() {
        let small = StudioKeyboardPreviewView(model: StudioKeyboardPreviewModel(
            theme: .teal,
            pack: .default,
            heightPreset: .small,
            isReversedMode: false,
            hasRoundedCorners: false,
            hasGrid: true,
            showsLettersRow: false,
            idiom: .phone
        ))
        let tall = StudioKeyboardPreviewView(model: StudioKeyboardPreviewModel(
            theme: .teal,
            pack: .default,
            heightPreset: .tall,
            isReversedMode: false,
            hasRoundedCorners: false,
            hasGrid: true,
            showsLettersRow: false,
            idiom: .phone
        ))
        [small, tall].forEach {
            $0.frame = CGRect(x: 0, y: 0, width: 320, height: 260)
            $0.layoutIfNeeded()
        }

        XCTAssertGreaterThan(tall.renderedKeyViews[0].bounds.height, small.renderedKeyViews[0].bounds.height)
    }

    func test_viewAppliesProductionCaptionStylesAndFonts() {
        let model = StudioKeyboardPreviewModel(
            theme: .teal,
            pack: .datetime,
            heightPreset: .regular,
            isReversedMode: false,
            hasRoundedCorners: false,
            hasGrid: true,
            showsLettersRow: false,
            idiom: .phone
        )
        let view = StudioKeyboardPreviewView(model: model)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 260)
        view.layoutIfNeeded()

        let dateKey = view.renderedKeyViews[0]
        let standardKey = view.renderedKeyViews[model.captionRows[0].count]
        let bottomStart = model.captionRows.dropLast().reduce(0) { $0 + $1.count }
        let primaryImageKey = view.renderedKeyViews[bottomStart]
        let returnKey = view.renderedKeyViews[bottomStart + 3]

        XCTAssertFalse(dateKey.backgroundColor!.isEqual(standardKey.backgroundColor!))
        XCTAssertFalse(primaryImageKey.backgroundColor!.isEqual(standardKey.backgroundColor!))
        XCTAssertFalse(returnKey.backgroundColor!.isEqual(standardKey.backgroundColor!))
        XCTAssertEqual(label(in: dateKey)!.font.pointSize, label(in: returnKey)!.font.pointSize)
        XCTAssertLessThan(label(in: dateKey)!.font.pointSize, label(in: standardKey)!.font.pointSize)
    }

    private func snapshot(_ defaults: UserDefaults, keys: [String]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            defaults.object(forKey: key).map { (key, $0) }
        })
    }

    private func restore(_ values: [String: Any], in defaults: UserDefaults) {
        liveKeys.forEach(defaults.removeObject(forKey:))
        values.forEach { defaults.set($0.value, forKey: $0.key) }
    }

    private func makeModel(pack: KeyboardType) -> StudioKeyboardPreviewModel {
        StudioKeyboardPreviewModel(
            theme: .white,
            pack: pack,
            heightPreset: .regular,
            isReversedMode: false,
            hasRoundedCorners: false,
            hasGrid: true,
            showsLettersRow: false,
            idiom: .phone
        )
    }

    private func label(in key: UIView) -> UILabel? {
        key.subviews.compactMap { $0 as? UILabel }.first
    }
}
