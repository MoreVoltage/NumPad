//
//  KeyboardStudioRefreshTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class KeyboardStudioRefreshTests: XCTestCase {
    func test_readinessRefreshChangesHeroAndRemovesRepairActionAfterReturning() {
        var isReady = false
        let controller = KeyboardStudioViewController(keyboardReady: { isReady })
        controller.loadViewIfNeeded()

        let hero = view(withAccessibilityIdentifier: "studio.keyboard.status", in: controller.view)
            as? StudioStatusHeroView
        XCTAssertEqual(hero?.title, "Finish setting up NumPad")
        XCTAssertEqual(hero?.actionAccessibilityIdentifier, "studio.keyboard.openSetup")
        XCTAssertNotNil(view(withAccessibilityIdentifier: "studio.keyboard.openSetup", in: controller.view))

        isReady = true
        // `viewWillAppear` is the return path from the setup instructions / Settings app.
        // Drive it directly because a headless XCTest UIWindow does not reliably send appearance
        // callbacks when a navigation controller pushes and immediately pops non-animated views.
        controller.viewWillAppear(false)

        XCTAssertEqual(hero?.title, "Your keyboard is ready")
        XCTAssertNil(hero?.actionAccessibilityIdentifier)
        XCTAssertNil(view(withAccessibilityIdentifier: "studio.keyboard.openSetup", in: controller.view))
    }

    func test_unentitledStoredKioskShowsTallAsTheEffectiveSelectionAndKeepsKioskLocked() {
        let controller = SizeAndFeelStudioViewController(
            storedHeight: { .kiosk },
            kioskEntitled: { false },
            heightChoices: [.small, .regular, .tall, .kiosk]
        )
        controller.loadViewIfNeeded()

        let tall = view(withAccessibilityIdentifier: "studio.size-feel.height.tall", in: controller.view)
            as? StudioTileView
        let kiosk = view(withAccessibilityIdentifier: "studio.size-feel.height.kiosk", in: controller.view)
            as? StudioTileView
        XCTAssertTrue(tall?.isSelected == true)
        XCTAssertFalse(kiosk?.isSelected == true)
        XCTAssertEqual(kiosk?.lockText, "Pro")
    }

    func test_selectingHeightImmediatelyRefreshesTheSelectedTile() {
        let suiteName = "KeyboardStudioRefreshTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(KeyboardHeightPreset.small.rawValue, forKey: Constants.heightPreset.rawValue)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let writer = StudioSettingsWriter(
            defaults: defaults,
            postSettingsSync: {}
        )
        let controller = SizeAndFeelStudioViewController(
            writer: writer,
            storedHeight: { KeyboardHeightPreset(rawValue: defaults.string(forKey: Constants.heightPreset.rawValue) ?? "") ?? .regular },
            kioskEntitled: { true },
            heightChoices: [.small, .regular, .tall]
        )
        controller.loadViewIfNeeded()

        let small = view(withAccessibilityIdentifier: "studio.size-feel.height.small", in: controller.view)
            as? StudioTileView
        let tall = view(withAccessibilityIdentifier: "studio.size-feel.height.tall", in: controller.view)
            as? StudioTileView
        XCTAssertTrue(small?.isSelected == true)

        tall?.sendActions(for: .touchUpInside)

        XCTAssertEqual(defaults.string(forKey: Constants.heightPreset.rawValue), KeyboardHeightPreset.tall.rawValue)
        XCTAssertFalse(small?.isSelected == true)
        XCTAssertTrue(tall?.isSelected == true)
    }

    private func view(withAccessibilityIdentifier identifier: String, in root: UIView?) -> UIView? {
        guard let root else { return nil }
        if root.accessibilityIdentifier == identifier { return root }
        for child in root.subviews {
            if let match = view(withAccessibilityIdentifier: identifier, in: child) {
                return match
            }
        }
        return nil
    }
}
