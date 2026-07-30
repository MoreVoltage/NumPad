import XCTest
@testable import NumPad

final class IPadOnboardingHeightFlowTests: XCTestCase {
    func test_firstInstallIPadPlacesHeightChoiceBetweenEnableAndTryIt() {
        XCTAssertEqual(
            OnboardingFlow.steps(isPad: true, isFirstInstall: true),
            [.wow, .enable, .height, .tryIt]
        )
    }

    func test_firstInstallIPhoneDoesNotReceiveHeightChoice() {
        XCTAssertEqual(
            OnboardingFlow.steps(isPad: false, isFirstInstall: true),
            [.wow, .enable, .tryIt]
        )
    }

    func test_existingIPadUserIsNotInterruptedByHeightChoice() {
        XCTAssertEqual(
            OnboardingFlow.steps(isPad: true, isFirstInstall: false),
            [.wow, .enable, .tryIt]
        )
    }

    func test_enableTransitionsToHeightOnlyOnIPad() {
        XCTAssertEqual(OnboardingStep.enable.next(isPad: true), .height)
        XCTAssertEqual(OnboardingStep.enable.next(isPad: false), .tryIt)
    }
}

final class OnboardingHeightSelectionTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var syncCount = 0
    private var proEntitled = false

    override func setUp() {
        super.setUp()
        suiteName = "onboarding-height-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        syncCount = 0
        proEntitled = false
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeSelection() -> OnboardingHeightSelection {
        OnboardingHeightSelection(
            defaults: defaults,
            isKioskEntitled: { [unowned self] in self.proEntitled },
            postSettingsSync: { [unowned self] in self.syncCount += 1 }
        )
    }

    func test_skipPreservesTheExistingDefaultAndDoesNotSync() {
        defaults.set(KeyboardHeightPreset.tall.rawValue, forKey: Constants.heightPreset.rawValue)

        makeSelection().skip()

        XCTAssertEqual(defaults.string(forKey: Constants.heightPreset.rawValue), KeyboardHeightPreset.tall.rawValue)
        XCTAssertEqual(syncCount, 0)
    }

    func test_freeHeightWritesSharedPreferenceAndPostsExactlyOneSync() {
        let outcome = makeSelection().select(.regular)

        XCTAssertEqual(outcome, .selected)
        XCTAssertEqual(defaults.string(forKey: Constants.heightPreset.rawValue), KeyboardHeightPreset.regular.rawValue)
        XCTAssertEqual(syncCount, 1)
    }

    func test_unentitledKioskDoesNotMutateHeightProfileOrPolicy() {
        let profileID = UUID().uuidString
        defaults.set(KeyboardHeightPreset.tall.rawValue, forKey: Constants.heightPreset.rawValue)
        defaults.set(profileID, forKey: Constants.activeKeyboardProfileID.rawValue)
        defaults.set(1_234, forKey: Constants.kioskLastActivity.rawValue)

        let outcome = makeSelection().select(.kiosk)

        XCTAssertEqual(outcome, .requiresPro)
        XCTAssertEqual(defaults.string(forKey: Constants.heightPreset.rawValue), KeyboardHeightPreset.tall.rawValue)
        XCTAssertEqual(defaults.string(forKey: Constants.activeKeyboardProfileID.rawValue), profileID)
        XCTAssertEqual(defaults.double(forKey: Constants.kioskLastActivity.rawValue), 1_234)
        XCTAssertEqual(syncCount, 0)
    }

    func test_purchaseOrRestoreRefreshesEntitlementSoKioskCanBeSelectedWithoutRestarting() {
        let selection = makeSelection()
        XCTAssertEqual(selection.select(.kiosk), .requiresPro)

        proEntitled = true

        XCTAssertEqual(selection.select(.kiosk), .selected)
        XCTAssertEqual(defaults.string(forKey: Constants.heightPreset.rawValue), KeyboardHeightPreset.kiosk.rawValue)
        XCTAssertEqual(syncCount, 1)
    }
}
