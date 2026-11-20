//
//  HomeSettingsModelTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class HomeSettingsModelTests: XCTestCase {
    func test_storeIsNotTypingBehaviorDestination() {
        let sections = HomeSettingsModel.sections(fullKeyboardVisible: true, isPad: false)
        let typing = sections.first { $0.id == .typingBehavior }
        XCTAssertTrue(typing?.rows.contains(.typingBehavior) == true)
        XCTAssertFalse(typing?.rows.contains(.pro) == true)
    }

    func test_qwertyRowObeysRolloutVisibility() {
        let hidden = HomeSettingsModel.sections(fullKeyboardVisible: false, isPad: false)
        XCTAssertFalse(hidden.flatMap(\.rows).contains(.qwerty))
        let visible = HomeSettingsModel.sections(fullKeyboardVisible: true, isPad: false)
        XCTAssertTrue(visible.flatMap(\.rows).contains(.qwerty))
    }

    func test_sectionsAreDeterministicAndExcludeCommerceFromTyping() {
        let a = HomeSettingsModel.sections(fullKeyboardVisible: true, isPad: true)
        let b = HomeSettingsModel.sections(fullKeyboardVisible: true, isPad: true)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.map(\.id), [.dashboard, .keyboard, .typingBehavior, .content, .account, .help])
    }

    /// Typing & Behavior hosts the Haptics / Sound / Inline Calculator / iCloud Sync toggles that
    /// live 2.1.1 showed under Store → Settings. It must be reachable whether or not the NumPad
    /// Type rollout flag is on — otherwise App Store users lose every one of those settings.
    func test_typingBehaviorRowAlwaysVisibleRegardlessOfQwertyRollout() {
        for fullKeyboardVisible in [false, true] {
            for isPad in [false, true] {
                let sections = HomeSettingsModel.sections(fullKeyboardVisible: fullKeyboardVisible, isPad: isPad)
                XCTAssertTrue(sections.map(\.id).contains(.typingBehavior),
                              "fullKeyboard=\(fullKeyboardVisible) pad=\(isPad)")
                XCTAssertTrue(sections.flatMap(\.rows).contains(.typingBehavior),
                              "fullKeyboard=\(fullKeyboardVisible) pad=\(isPad)")
            }
        }
    }

    /// The `.dashboard` destination has no phone handler (HomeViewController treats it as a no-op),
    /// so the phone Home must not show a dead row. iPad keeps it (split detail → Dashboard).
    func test_phoneHomeHasNoDeadDashboardRow() {
        for fullKeyboardVisible in [false, true] {
            let phone = HomeSettingsModel.sections(fullKeyboardVisible: fullKeyboardVisible, isPad: false)
            XCTAssertFalse(phone.flatMap(\.rows).contains(.dashboard))
            XCTAssertTrue(phone.flatMap(\.rows).contains(.profiles))
            XCTAssertNil(phone.first { $0.id == .dashboard }?.title,
                         "phone first section holds only Saved setups — no 'Dashboard' header")
            let pad = HomeSettingsModel.sections(fullKeyboardVisible: fullKeyboardVisible, isPad: true)
            XCTAssertTrue(pad.flatMap(\.rows).contains(.dashboard))
            XCTAssertNotNil(pad.first { $0.id == .dashboard }?.title)
        }
    }

    /// The live-2.1.1 phone Home rows must all still be present on the restored shell.
    func test_phoneHomeKeepsEveryLiveRow() {
        let live: [SettingsDestination] = [
            .keyboardSetup, .theme, .packs, .height, .numberOrder, .roundedCorners, .grid,
            .snippets, .customKeyboard, .pro, .privacy, .featureGuide, .feedback, .rate
        ]
        let rows = HomeSettingsModel.sections(fullKeyboardVisible: false, isPad: false).flatMap(\.rows)
        for row in live {
            XCTAssertTrue(rows.contains(row), "missing live Home row \(row)")
        }
        XCTAssertFalse(rows.contains(.kioskProvisioning), "kiosk provisioning is iPad-only")
        XCTAssertFalse(rows.contains(.qwerty), "NumPad Type row stays behind the rollout flag")
    }
}

// MARK: - Phone Home navigation (classic Home shell)

/// Drives the real `HomeViewController` (storyboard instance) inside a navigation controller and
/// asserts every navigable row pushes the expected screen. Feedback/Rate (external side effects)
/// and the three inline switch rows are excluded.
final class HomeViewControllerNavigationTests: XCTestCase {
    private var window: UIWindow!
    private var navigation: UINavigationController!
    private var home: HomeViewController!
    private var savedFullKeyboardEnabled = false
    private var savedFullKeyboardRemoteEnabled = true

    override func setUp() {
        super.setUp()
        savedFullKeyboardEnabled = FeatureFlags.fullKeyboardEnabled
        savedFullKeyboardRemoteEnabled = FeatureFlags.fullKeyboardRemoteEnabled
        FeatureFlags.fullKeyboardEnabled = true
        FeatureFlags.fullKeyboardRemoteEnabled = true

        home = HomeViewController.instantiate()
        navigation = UINavigationController(rootViewController: home)
        window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        home.loadViewIfNeeded()
        home.tableView.reloadData()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        navigation = nil
        home = nil
        FeatureFlags.fullKeyboardEnabled = savedFullKeyboardEnabled
        FeatureFlags.fullKeyboardRemoteEnabled = savedFullKeyboardRemoteEnabled
        super.tearDown()
    }

    private var sections: [HomeSection] {
        HomeSettingsModel.sections(fullKeyboardVisible: FeatureFlags.isFullKeyboardActive,
                                   isPad: UIDevice.current.userInterfaceIdiom == .pad)
    }

    private func indexPath(of destination: SettingsDestination) -> IndexPath? {
        for (sectionIndex, section) in sections.enumerated() {
            if let row = section.rows.firstIndex(of: destination) {
                return IndexPath(row: row, section: sectionIndex)
            }
        }
        return nil
    }

    private func pushed(by destination: SettingsDestination,
                        file: StaticString = #filePath, line: UInt = #line) -> UIViewController? {
        guard let indexPath = indexPath(of: destination) else {
            XCTFail("row \(destination) not on phone Home", file: file, line: line)
            return nil
        }
        navigation.popToRootViewController(animated: false)
        UIView.performWithoutAnimation {
            home.tableView(home.tableView, didSelectRowAt: indexPath)
        }
        return navigation.topViewController === home ? nil : navigation.topViewController
    }

    func test_tableMirrorsHomeSettingsModel() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "phone Home shell only")
        XCTAssertEqual(home.numberOfSections(in: home.tableView), sections.count)
        for (index, section) in sections.enumerated() {
            XCTAssertEqual(home.tableView(home.tableView, numberOfRowsInSection: index), section.rows.count)
        }
    }

    func test_everyNavigableRowPushesItsScreen() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "phone Home shell only")
        let expectations: [(SettingsDestination, UIViewController.Type)] = [
            (.profiles, SavedSetupsStudioViewController.self),
            (.keyboardSetup, InstructionsViewController.self),
            (.theme, ThemeViewController.self),
            (.packs, PacksViewController.self),
            (.height, KeyboardHeightViewController.self),
            (.customKeyboard, CustomKeyboardEditorViewController.self),
            (.qwerty, QwertySetupViewController.self),
            (.typingBehavior, TypingBehaviorViewController.self),
            (.snippets, SnippetsViewController.self),
            (.pro, StoreViewController.self),
            (.privacy, PrivacyViewController.self),
            (.featureGuide, FeaturesGuideViewController.self),
        ]
        for (destination, expectedType) in expectations {
            let top = pushed(by: destination)
            XCTAssertNotNil(top, "\(destination) did not push anything")
            if let top {
                XCTAssertTrue(type(of: top) == expectedType,
                              "\(destination) pushed \(type(of: top)), expected \(expectedType)")
            }
        }
        navigation.popToRootViewController(animated: false)
    }

    func test_switchRowsDoNotNavigate() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "phone Home shell only")
        for destination in [SettingsDestination.numberOrder, .roundedCorners, .grid] {
            XCTAssertNil(pushed(by: destination), "\(destination) is an inline switch")
        }
    }

    /// Calibration entry point, step 1: Home → NumPad Type opens the setup screen.
    func test_qwertyRowLeadsToSetupScreen() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "phone Home shell only")
        XCTAssertTrue(pushed(by: .qwerty) is QwertySetupViewController)
        navigation.popToRootViewController(animated: false)
    }
}

// MARK: - Calibration entry point

/// Calibration entry point, step 2: NumPad Type setup → Calibration row presents the tap
/// calibration flow full-screen inside its own navigation controller.
final class QwertyCalibrationEntryPointTests: XCTestCase {
    private var window: UIWindow!

    override func tearDown() {
        window?.rootViewController?.dismiss(animated: false)
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func test_calibrationSectionIsPresentAndPresentsCalibrationFullScreen() throws {
        let setup = QwertySetupViewController()
        let navigation = UINavigationController(rootViewController: setup)
        window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        setup.loadViewIfNeeded()

        let calibrationSection = (0..<setup.numberOfSections(in: setup.tableView)).first {
            setup.tableView(setup.tableView, titleForHeaderInSection: $0)
                == NSLocalizedString("Calibration", comment: "QWERTY setup section header")
        }
        let section = try XCTUnwrap(calibrationSection, "NumPad Type setup must have a Calibration section")
        XCTAssertGreaterThanOrEqual(setup.tableView(setup.tableView, numberOfRowsInSection: section), 1)

        UIView.performWithoutAnimation {
            setup.tableView(setup.tableView, didSelectRowAt: IndexPath(row: 0, section: section))
        }
        let presented = try XCTUnwrap(setup.presentedViewController as? UINavigationController,
                                      "Calibration row must present a navigation controller")
        XCTAssertTrue(presented.viewControllers.first is QwertyCalibrationViewController)
        XCTAssertEqual(presented.modalPresentationStyle, .fullScreen)
    }
}

// MARK: - Monetization: no subscriptions

/// The app sells lifetime Pro + à la carte packs only. Nothing in the catalog, the StoreKit config,
/// or the app/extension sources may reference a subscription product.
final class NoSubscriptionProductsTests: XCTestCase {
    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    func test_catalogIsExactlyLifetimeProAndPacks() {
        let expected: Set<String> = [
            "numpad.pro.lifetime", "numpad.pro.lifetime.earlybird",
            "numpad.pack.finance", "numpad.pack.symbols", "numpad.pack.programmer",
            "numpad.pack.datetime", "numpad.pack.units", "numpad.pack.cooking",
        ]
        XCTAssertEqual(Set(ProductCatalog.allProductIDs), expected)
        XCTAssertEqual(Set(StoreManager.ProductID.all), expected)
        for id in ProductCatalog.allProductIDs {
            XCTAssertFalse(id.lowercased().contains("sub"), "\(id) looks like a subscription")
        }
    }

    func test_storeKitConfigurationHasNoSubscriptions() throws {
        let url = projectRoot.appendingPathComponent("NumPad/Products.storekit")
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let groups = json["subscriptionGroups"] as? [Any] ?? []
        XCTAssertTrue(groups.isEmpty, "Products.storekit must not define subscription groups")
        let nonRenewing = json["nonRenewingSubscriptions"] as? [Any] ?? []
        XCTAssertTrue(nonRenewing.isEmpty, "Products.storekit must not define non-renewing subscriptions")
        let products = json["products"] as? [[String: Any]] ?? []
        for product in products {
            XCTAssertEqual(product["type"] as? String, "NonConsumable",
                           "\(product["productID"] ?? "?") must be a non-consumable")
        }
    }

    func test_sourcesNeverReferenceSubscriptionProducts() throws {
        let forbidden = ["numpad.pro.sub", "isProSubscriptionActive", ".autoRenewable",
                         "Product.SubscriptionInfo", "subscriptionStatus"]
        var offenders: [String] = []
        for directory in ["NumPad", "Keyboard"] {
            let root = projectRoot.appendingPathComponent(directory)
            let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            for case let file as URL in enumerator where file.pathExtension == "swift" {
                let source = try String(contentsOf: file, encoding: .utf8)
                for token in forbidden where source.contains(token) {
                    offenders.append("\(file.lastPathComponent): \(token)")
                }
            }
        }
        XCTAssertEqual(offenders, [], "subscription references found")
    }
}
