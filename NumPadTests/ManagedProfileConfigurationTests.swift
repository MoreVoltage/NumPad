import XCTest
@testable import NumPad

final class ManagedProfileConfigurationTests: XCTestCase {
    func test_builtinKind() {
        let result = ManagedProfileConfiguration.parse([
            "builtin_profile_kind": "kiosk",
            "lock_profile_editing": true
        ])
        guard case .success(let request) = result else { return XCTFail() }
        XCTAssertEqual(request.source, .builtin(.kiosk))
        XCTAssertTrue(request.lockEditing)
    }

    func test_invalidDictionary() {
        let result = ManagedProfileConfiguration.parse(["junk": 1])
        guard case .failure(let error) = result else { return XCTFail() }
        XCTAssertEqual(error, .invalid)
    }
}

