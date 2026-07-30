//
//  StudioSettingsWriterTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class StudioSettingsWriterTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""
    private var syncCount = 0

    override func setUp() {
        super.setUp()
        suiteName = "StudioSettingsWriterTests.\(UUID().uuidString)"
        defaults = try! XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        syncCount = 0
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeWriter() -> StudioSettingsWriter {
        StudioSettingsWriter(defaults: defaults, postSettingsSync: { [weak self] in
            self?.syncCount += 1
        })
    }

    func test_selectingAKeySetWritesTheSharedSettingAndPostsOneSync() {
        let writer = makeWriter()
        let prices = try! XCTUnwrap(
            StudioKeySetCatalog(isLocked: { _ in false }).visibleChoices.first { $0.id == .prices }
        )

        writer.selectKeySet(prices, currentPack: .default)

        XCTAssertEqual(defaults.string(forKey: Constants.selectedKeyboardType.rawValue), KeyboardType.finance.rawValue)
        XCTAssertEqual(syncCount, 1)
    }

    func test_selectingCalculationsTogglesMathLayoutAndPostsOneSync() {
        let writer = makeWriter()
        let calculations = try! XCTUnwrap(
            StudioKeySetCatalog(isLocked: { _ in false }).visibleChoices.first { $0.id == .calculations }
        )

        writer.selectKeySet(calculations, currentPack: .math)

        XCTAssertEqual(defaults.string(forKey: Constants.selectedKeyboardType.rawValue), KeyboardType.math2.rawValue)
        XCTAssertEqual(syncCount, 1)
    }

    func test_lockedKeySetDoesNotWriteOrPostASync() {
        let writer = makeWriter()
        let lockedPrices = try! XCTUnwrap(
            StudioKeySetCatalog(isLocked: { $0 == .finance }).visibleChoices.first { $0.id == .prices }
        )

        XCTAssertFalse(writer.selectKeySet(lockedPrices, currentPack: .default))
        XCTAssertNil(defaults.object(forKey: Constants.selectedKeyboardType.rawValue))
        XCTAssertEqual(syncCount, 0)
    }

    func test_appearanceMutationsWriteSharedDefaultsAndPostOneSyncEach() {
        let writer = makeWriter()

        writer.setTheme(.purple)
        XCTAssertEqual(defaults.string(forKey: Constants.selectedKeyboardTheme.rawValue), KeyboardTheme.purple.rawValue)
        XCTAssertEqual(syncCount, 1)

        writer.setAutomaticDarkMode(true)
        XCTAssertTrue(defaults.bool(forKey: Constants.automaticDarkMode.rawValue))
        XCTAssertEqual(syncCount, 2)

        writer.setRoundedCorners(true)
        XCTAssertTrue(defaults.bool(forKey: Constants.roundedCorners.rawValue))
        XCTAssertEqual(syncCount, 3)

        writer.setGrid(false)
        XCTAssertFalse(defaults.bool(forKey: Constants.grid.rawValue))
        XCTAssertEqual(syncCount, 4)
    }

    func test_sizeAndFeelMutationsWriteSharedDefaultsAndPostOneSyncEach() {
        let writer = makeWriter()

        writer.setHeight(.tall)
        XCTAssertEqual(defaults.string(forKey: Constants.heightPreset.rawValue), KeyboardHeightPreset.tall.rawValue)
        XCTAssertEqual(syncCount, 1)

        writer.setReversedMode(true)
        XCTAssertTrue(defaults.bool(forKey: Constants.reversedMode.rawValue))
        XCTAssertEqual(syncCount, 2)

        writer.setHapticsEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: Constants.hapticsEnabled.rawValue))
        XCTAssertEqual(syncCount, 3)

        writer.setSoundEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: Constants.soundEnabled.rawValue))
        XCTAssertEqual(syncCount, 4)

        writer.setCursorControlsEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: Constants.cursorControlsEnabled.rawValue))
        XCTAssertEqual(syncCount, 5)
    }

    func test_lettersMutationsWriteSharedDefaultsAndPostOneSyncEach() {
        let writer = makeWriter()

        writer.setLettersPageEnabled(true)
        XCTAssertEqual(defaults.string(forKey: Constants.keyboardPage.rawValue), "qwerty")
        XCTAssertEqual(syncCount, 1)

        writer.setAutocorrectEnabled(true)
        XCTAssertTrue(defaults.bool(forKey: Constants.qwertyAutocorrectEnabled.rawValue))
        XCTAssertEqual(syncCount, 2)

        writer.setSuggestionsEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: Constants.qwertySuggestionsEnabled.rawValue))
        XCTAssertEqual(syncCount, 3)

        writer.setDoubleSpacePeriodEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: Constants.qwertyDoubleSpacePeriodEnabled.rawValue))
        XCTAssertEqual(syncCount, 4)

        writer.setPeriodCommaEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: Constants.qwertyPeriodComma.rawValue))
        XCTAssertEqual(syncCount, 5)
    }
}
