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

    func test_rejectsAmbiguousAndCustomBuiltInSources() throws {
        let embedded = String(
            decoding: try KeyboardProfileDocument.encode(.testFixture),
            as: UTF8.self
        )
        XCTAssertEqual(
            ManagedProfileConfiguration.parse([
                "builtin_profile_kind": "standard",
                "profile_json": embedded
            ]),
            .failure(.invalid)
        )
        XCTAssertEqual(
            ManagedProfileConfiguration.parse(["builtin_profile_kind": "custom"]),
            .failure(.unsupportedKind)
        )
    }

    func test_digestIsDeterministicAcrossDictionaryOrdering() throws {
        let a: [String: Any] = [
            "lock_profile_editing": true,
            "builtin_profile_kind": "kiosk"
        ]
        let b: [String: Any] = [
            "builtin_profile_kind": "kiosk",
            "lock_profile_editing": true
        ]
        XCTAssertEqual(
            try ManagedProfileConfiguration.digest(a),
            try ManagedProfileConfiguration.digest(b)
        )
    }
}
