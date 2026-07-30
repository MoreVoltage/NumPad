import XCTest
@testable import NumPad

final class KioskMutationAuthorizerTests: XCTestCase {
    private enum TestError: Error { case denied, cancelled }

    func test_noAuthenticationPolicyRunsMutationImmediately() {
        var didMutate = false
        var authenticationCalled = false
        let authorizer = KioskMutationAuthorizer(
            requiresAuthentication: { false },
            authenticate: { _ in authenticationCalled = true }
        )

        authorizer.performIfAuthorized({ didMutate = true }) { result in
            XCTAssertEqual(result, .authorized)
        }

        XCTAssertTrue(didMutate)
        XCTAssertFalse(authenticationCalled)
    }

    func test_requiredAuthenticationFailureDoesNotRunMutation() {
        var didMutate = false
        let expectation = expectation(description: "authorization result")
        let authorizer = KioskMutationAuthorizer(
            requiresAuthentication: { true },
            authenticate: { completion in completion(.failure(TestError.denied)) }
        )

        authorizer.performIfAuthorized({ didMutate = true }) { result in
            XCTAssertEqual(result, .denied)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(didMutate)
    }

    func test_requiredAuthenticationCancellationDoesNotRunMutation() {
        var didMutate = false
        let expectation = expectation(description: "authorization result")
        let authorizer = KioskMutationAuthorizer(
            requiresAuthentication: { true },
            authenticate: { completion in completion(.failure(TestError.cancelled)) }
        )

        authorizer.performIfAuthorized({ didMutate = true }) { result in
            XCTAssertEqual(result, .denied)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(didMutate)
    }

    func test_requiredAuthenticationSuccessRunsMutationOnce() {
        var mutations = 0
        let expectation = expectation(description: "authorization result")
        let authorizer = KioskMutationAuthorizer(
            requiresAuthentication: { true },
            authenticate: { completion in completion(.success(())) }
        )

        authorizer.performIfAuthorized({ mutations += 1 }) { result in
            XCTAssertEqual(result, .authorized)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(mutations, 1)
    }

    func test_repeatedAuthenticationCallbackCannotRepeatMutation() {
        var mutations = 0
        let expectation = expectation(description: "authorization result")
        let authorizer = KioskMutationAuthorizer(
            requiresAuthentication: { true },
            authenticate: { completion in
                completion(.success(()))
                completion(.success(()))
            }
        )

        authorizer.performIfAuthorized({ mutations += 1 }) { _ in expectation.fulfill() }

        wait(for: [expectation], timeout: 1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(mutations, 1)
    }

    func test_requiredAuthenticationCompletionReturnsToMainQueue() {
        let expectation = expectation(description: "authorization result")
        let authorizer = KioskMutationAuthorizer(
            requiresAuthentication: { true },
            authenticate: { completion in
                DispatchQueue.global().async { completion(.success(())) }
            }
        )

        authorizer.performIfAuthorized({}) { result in
            XCTAssertEqual(result, .authorized)
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}
