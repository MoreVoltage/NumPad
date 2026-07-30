import XCTest
@testable import NumPad

final class StudioMutationAuthorizationTests: XCTestCase {
    private enum TestError: Error { case cancelled }

    func test_savedSetupApplyDoesNotWriteWhenKioskAuthenticationIsCancelled() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        defaults.set(KeyboardType.math.rawValue, forKey: Constants.selectedKeyboardType.rawValue)
        let authorizer = KioskMutationAuthorizer(
            requiresAuthentication: { true },
            authenticate: { completion in completion(.failure(TestError.cancelled)) }
        )
        let applier = KeyboardProfileApplier(defaults: defaults, notify: {})
        let controller = SavedSetupDetailViewController(
            profile: KeyboardProfileFactory.standard(),
            applier: applier,
            mutationAuthorizer: authorizer,
            isEditingLocked: { false }
        )

        controller.loadViewIfNeeded()
        let apply = try! button("studio.saved-setup.apply", in: controller.view)
        apply.sendActions(for: .touchUpInside)

        let settled = expectation(description: "authentication completion")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 1)
        XCTAssertEqual(defaults.string(forKey: Constants.selectedKeyboardType.rawValue), KeyboardType.math.rawValue)
    }

    func test_savedSetupApplyStillWorksWhenAuthenticationSucceeds() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        defaults.set(KeyboardType.math.rawValue, forKey: Constants.selectedKeyboardType.rawValue)
        let authorizer = KioskMutationAuthorizer(
            requiresAuthentication: { true },
            authenticate: { completion in completion(.success(())) }
        )
        let applier = KeyboardProfileApplier(defaults: defaults, notify: {})
        let controller = SavedSetupDetailViewController(
            profile: KeyboardProfileFactory.standard(),
            applier: applier,
            mutationAuthorizer: authorizer,
            isEditingLocked: { false }
        )

        controller.loadViewIfNeeded()
        let apply = try! button("studio.saved-setup.apply", in: controller.view)
        apply.sendActions(for: .touchUpInside)

        let applied = expectation(description: "authorized apply")
        DispatchQueue.main.async {
            XCTAssertEqual(
                defaults.string(forKey: Constants.selectedKeyboardType.rawValue),
                KeyboardType.default.rawValue
            )
            applied.fulfill()
        }
        wait(for: [applied], timeout: 1)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "studio-mutation-authorization-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(suite, forKey: "testSuiteName")
        return defaults
    }

    private func defaultsSuiteName(_ defaults: UserDefaults) -> String {
        defaults.string(forKey: "testSuiteName")!
    }

    private func button(_ identifier: String, in root: UIView) throws -> UIButton {
        if root.accessibilityIdentifier == identifier, let button = root as? UIButton { return button }
        for child in root.subviews {
            if let button = try? button(identifier, in: child) { return button }
        }
        throw NSError(domain: "StudioMutationAuthorizationTests", code: 1)
    }
}
