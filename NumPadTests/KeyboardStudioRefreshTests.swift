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

    func test_returningFromQuickChangeRefreshesTheExistingPreviewAndLettersAction() {
        var selectedPack: KeyboardType = .default
        var lettersAvailable = false
        let controller = KeyboardStudioViewController(
            previewModel: { idiom in
                StudioKeyboardPreviewModel(
                    theme: .white,
                    pack: selectedPack,
                    heightPreset: .regular,
                    isReversedMode: false,
                    hasRoundedCorners: false,
                    hasGrid: true,
                    qwertyAvailable: lettersAvailable,
                    activePage: .numpad,
                    idiom: idiom
                )
            },
            lettersAvailable: { lettersAvailable }
        )
        controller.loadViewIfNeeded()

        XCTAssertEqual(controller.preview?.model.pack, .default)
        XCTAssertNil(view(withAccessibilityIdentifier: "studio.keyboard.letters", in: controller.view))

        // This models selecting a free key set in the destination and popping back to the
        // already-created root controller rather than reconstructing the Studio.
        selectedPack = .math
        lettersAvailable = true
        controller.viewWillAppear(false)

        XCTAssertEqual(controller.preview?.model.pack, .math)
        XCTAssertNotNil(view(withAccessibilityIdentifier: "studio.keyboard.letters", in: controller.view))

        lettersAvailable = false
        controller.viewWillAppear(false)
        XCTAssertNil(view(withAccessibilityIdentifier: "studio.keyboard.letters", in: controller.view))
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

    func test_automaticAppearanceDisablesThemeTilesAndExplainsHowToChooseOne() {
        let previousAutomaticAppearance = KeyboardTheme.automaticDarkMode
        defer { KeyboardTheme.automaticDarkMode = previousAutomaticAppearance }
        KeyboardTheme.automaticDarkMode = true

        let controller = AppearanceStudioViewController()
        controller.loadViewIfNeeded()

        let theme = view(withAccessibilityIdentifier: "studio.appearance.theme.white", in: controller.view)
            as? StudioTileView
        XCTAssertFalse(theme?.isEnabled ?? true)
        XCTAssertTrue(theme?.accessibilityTraits.contains(.notEnabled) ?? false)
        XCTAssertEqual(
            theme?.accessibilityHint,
            "Turn off Match device appearance to choose a theme."
        )
    }

    func test_statusHeroReportsOnlyAnActualReadinessChangeForAnnouncement() {
        let hero = StudioStatusHeroView(
            level: .warn,
            title: "Finish setting up NumPad",
            message: "Add NumPad in Settings before you use it in other apps.",
            actionTitle: "Open setup"
        )

        let unchanged = hero.update(
            level: .warn,
            title: "Finish setting up NumPad",
            message: "Add NumPad in Settings before you use it in other apps.",
            actionTitle: "Open setup",
            announce: true
        )
        let changed = hero.update(
            level: .ok,
            title: "Your keyboard is ready",
            message: "Choose an option below whenever you want a change.",
            announce: true
        )

        XCTAssertFalse(unchanged, "An unchanged readiness state must not announce again.")
        XCTAssertTrue(changed, "A real readiness transition must remain announceable.")
    }

    func test_helpVersionRowOpensLocalizedReleaseDetails() {
        let help = HelpStudioViewController()
        let window = makeVisibleWindow(rootViewController: UINavigationController(rootViewController: help))
        defer { window.isHidden = true }
        help.loadViewIfNeeded()

        let version = view(withAccessibilityIdentifier: "studio.help.version", in: help.view)
            as? StudioRowView
        version?.sendActions(for: .touchUpInside)

        let alert = help.presentedViewController as? UIAlertController
        XCTAssertEqual(alert?.title, "NumPad version")
        XCTAssertEqual(alert?.actions.first?.title, "OK")
        XCTAssertTrue(alert?.message?.contains(Bundle.main.version ?? "Unavailable") ?? false)
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

    private func makeVisibleWindow(rootViewController: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        rootViewController.view.layoutIfNeeded()
        return window
    }
}
