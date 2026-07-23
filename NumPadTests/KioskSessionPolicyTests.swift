import XCTest
@testable import NumPad

final class KioskSessionPolicyTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "kiosk-session-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_noResetBeforeTimeout() throws {
        let policy = try KeyboardProfileFactory.kiosk().kioskPolicy!
        let now = Date()
        let actions = KioskSessionPolicy.actions(policy: policy, lastInteraction: now, now: now.addingTimeInterval(10))
        XCTAssertTrue(actions.isEmpty)
    }

    func test_resetAfterTimeout() throws {
        let policy = try KeyboardProfileFactory.kiosk().kioskPolicy!
        let now = Date()
        let actions = KioskSessionPolicy.actions(
            policy: policy,
            lastInteraction: now.addingTimeInterval(-policy.inactivityTimeout - 1),
            now: now)
        XCTAssertTrue(actions.contains(.dismissOverlays))
        XCTAssertTrue(actions.contains(.resetPageAndPack))
    }

    func test_sessionClockPersistsAcrossKeyboardAppearancesAndEvaluatesBeforeRefresh() throws {
        let policy = try XCTUnwrap(KeyboardProfileFactory.kiosk().kioskPolicy)
        let configuration = KioskSessionConfiguration(
            policy: policy,
            resetPage: "qwerty",
            resetPack: .finance,
            activeProfileID: UUID()
        )
        let timestampKey = "testKioskActivity"
        var now = Date(timeIntervalSince1970: 10_000.75)

        let firstAppearance = KioskSessionClock(
            defaults: defaults,
            timestampKey: timestampKey,
            now: { now }
        )
        let initial = firstAppearance.evaluateBeforeRecordingActivity(configuration: configuration)
        XCTAssertTrue(initial.actions.isEmpty)
        XCTAssertEqual(defaults.double(forKey: timestampKey), 10_000)

        now = now.addingTimeInterval(policy.inactivityTimeout + 1)
        let nextAppearance = KioskSessionClock(
            defaults: defaults,
            timestampKey: timestampKey,
            now: { now }
        )
        let expired = nextAppearance.evaluateBeforeRecordingActivity(configuration: configuration)

        XCTAssertTrue(expired.actions.contains(.resetPageAndPack))
        XCTAssertEqual(expired.resetPage, "qwerty")
        XCTAssertEqual(expired.resetPack, .finance)
        XCTAssertEqual(
            defaults.double(forKey: timestampKey),
            floor(now.timeIntervalSince1970),
            "Only after expiration is evaluated should the persisted timestamp refresh"
        )
    }

    func test_activeConfigurationCarriesConfiguredResetPageAndPack() throws {
        let store = KeyboardProfileStore(defaults: defaults)
        var snapshot = store.load()
        var kiosk = KeyboardProfileFactory.kiosk()
        kiosk.configuration.keyboardPageRaw = "qwerty"
        kiosk.configuration.keyboardTypeRaw = KeyboardType.finance.rawValue
        kiosk = try kiosk.validated()
        snapshot.activeProfileID = kiosk.id
        snapshot.profiles = snapshot.profiles.map { $0.id == kiosk.id ? kiosk : $0 }
        try store.save(snapshot)

        let configuration = try XCTUnwrap(KioskSessionPolicy.activeConfiguration(defaults: defaults))
        XCTAssertEqual(configuration.activeProfileID, kiosk.id)
        XCTAssertEqual(configuration.policy, kiosk.kioskPolicy)
        XCTAssertEqual(configuration.resetPage, "qwerty")
        XCTAssertEqual(configuration.resetPack, .finance)
    }

    func test_standardActiveProfileHasNoKioskSessionConfiguration() throws {
        let store = KeyboardProfileStore(defaults: defaults)
        var snapshot = store.load()
        snapshot.activeProfileID = KeyboardProfileFactory.BuiltInID.standard
        try store.save(snapshot)

        XCTAssertNil(KioskSessionPolicy.activeConfiguration(defaults: defaults))
    }

    func test_legacyTaxPackFailsClosedForKioskResolverAndReadiness() throws {
        let store = KeyboardProfileStore(defaults: defaults)
        var snapshot = store.load()
        var kiosk = KeyboardProfileFactory.kiosk()
        kiosk.configuration.keyboardTypeRaw = KeyboardType.tax.rawValue
        kiosk = try kiosk.validated()
        snapshot.activeProfileID = kiosk.id
        snapshot.profiles = snapshot.profiles.map { $0.id == kiosk.id ? kiosk : $0 }
        try store.save(snapshot)

        let configuration = KioskSessionPolicy.activeConfiguration(defaults: defaults)
        XCTAssertNil(
            configuration,
            "The backward-only Tax enum must never become a Kiosk reset destination"
        )

        let readiness = KioskReadiness.evaluate(.init(
            keyboardEnabled: true,
            activeProfileIsKiosk: true,
            kioskConfigurationIsValid: configuration != nil,
            fullAccessConfirmed: true,
            profileApplies: true,
            usedEntitlementFallback: false,
            tryItConfirmed: true,
            guidedAccessAcknowledged: true
        ))
        XCTAssertEqual(readiness.status, .blocked)
    }

    func test_settingsChangeWhileKeyboardIsHiddenCannotStartMonitor() {
        var lifecycle = KioskMonitorLifecycle()
        lifecycle.keyboardWillAppear()
        XCTAssertTrue(lifecycle.permitsMonitorStart)

        lifecycle.keyboardWillDisappear()

        XCTAssertFalse(
            lifecycle.permitsMonitorStart,
            "A settings/profile callback arriving after viewWillDisappear must not restart the monitor"
        )
    }

    func test_allMeaningfulKeyboardInteractionsUseOneKioskActivityEntryPoint() throws {
        let keyboard = try source(at: "Keyboard/KeyboardViewController.swift")
        let qwerty = try source(at: "Keyboard/Libraries/QwertyPageHost.swift")

        XCTAssertTrue(keyboard.contains("func recordKioskActivity()"))
        XCTAssertGreaterThanOrEqual(
            keyboard.components(separatedBy: "recordKioskActivity()").count - 1,
            16,
            "Keys, cursor, page/pack changes, overlays, calculators, clipboard, tape, and dismissals must share one entry point"
        )
        XCTAssertTrue(
            qwerty.contains("onUserActivity"),
            "QWERTY keys, suggestions, alternates, cursor movement, and glide must route activity back to the shared entry point"
        )
    }

    func test_keyboardControllerWiresVisibilityIntoEveryMonitorStart() throws {
        let source = try source(at: "Keyboard/KeyboardViewController.swift")

        XCTAssertTrue(source.contains("kioskMonitorLifecycle.keyboardWillAppear()"))
        XCTAssertTrue(source.contains("kioskMonitorLifecycle.keyboardWillDisappear()"))
        XCTAssertTrue(source.contains("guard kioskMonitorLifecycle.permitsMonitorStart else { return }"))
        XCTAssertTrue(source.contains("if self.kioskMonitorLifecycle.permitsMonitorStart {"))
    }

    func test_hostDocumentCallbacksDoNotRecordKioskActivity() throws {
        let source = try source(at: "Keyboard/KeyboardViewController.swift")
        let textDidChange = try methodBody(
            startingWith: "override func textDidChange",
            in: source
        )
        let selectionDidChange = try methodBody(
            startingWith: "override func selectionDidChange",
            in: source
        )

        XCTAssertFalse(
            textDidChange.contains("recordKioskActivity"),
            "Host-app text notifications are not proof of a NumPad interaction"
        )
        XCTAssertFalse(
            selectionDidChange.contains("recordKioskActivity"),
            "Host-app selection notifications are not proof of a NumPad cursor interaction"
        )
    }

    private func source(at relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func methodBody(startingWith marker: String, in source: String) throws -> String {
        let markerRange = try XCTUnwrap(source.range(of: marker))
        let openingBrace = try XCTUnwrap(source[markerRange.lowerBound...].firstIndex(of: "{"))
        var depth = 0
        var cursor = openingBrace

        while cursor < source.endIndex {
            switch source[cursor] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(source[openingBrace...cursor])
                }
            default:
                break
            }
            cursor = source.index(after: cursor)
        }
        XCTFail("Unbalanced method body for \(marker)")
        return ""
    }
}
