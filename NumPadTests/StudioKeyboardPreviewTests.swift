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
        Constants.keyboardPage.rawValue
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
        let expectedSettings = snapshot(defaults, keys: liveKeys)

        let model = StudioKeyboardPreviewModel.current(idiom: .phone)

        XCTAssertEqual(model.theme, .glassDark)
        XCTAssertEqual(model.pack, .units)
        XCTAssertEqual(model.heightPreset, KeyboardHeightPreset.effective(stored: .kiosk, kioskEntitled: Monetization.isKioskHeightEntitled))
        XCTAssertTrue(model.isReversedMode)
        XCTAssertTrue(model.hasRoundedCorners)
        XCTAssertFalse(model.hasGrid)
        XCTAssertEqual(model.showsLettersRow, FeatureFlags.isQwertyPageAvailable)
        XCTAssertEqual(snapshot(defaults, keys: liveKeys) as NSDictionary, expectedSettings as NSDictionary)
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

    private func snapshot(_ defaults: UserDefaults, keys: [String]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            defaults.object(forKey: key).map { (key, $0) }
        })
    }

    private func restore(_ values: [String: Any], in defaults: UserDefaults) {
        liveKeys.forEach(defaults.removeObject(forKey:))
        values.forEach { defaults.set($0.value, forKey: $0.key) }
    }
}
