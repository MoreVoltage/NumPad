//
//  ContainerAppOpenerTests.swift
//  NumPadTests
//
//  Fake responder chains — never touches UIApplication.shared, never launches anything.
//

import XCTest
import UIKit
@testable import NumPad

/// A plain link in the responder chain.
private final class ChainLink: UIResponder {
    private let nextLink: UIResponder?
    init(next: UIResponder?) { self.nextLink = next; super.init() }
    override var next: UIResponder? { nextLink }
}

/// Stands in for UIApplication on iOS 18+ (iOS 18 SDK build): the legacy one-argument
/// `openURL:` is still answered but does nothing and returns NO; only the modern
/// `open(_:options:completionHandler:)` path actually opens, reporting `result`.
private final class FakeApplication: UIResponder, ContainerURLOpening {
    let result: Bool
    private(set) var legacyCalls = 0
    private(set) var modernURLs: [URL] = []
    init(result: Bool) { self.result = result; super.init() }

    @objc(openURL:) func legacyOpenURL(_ url: URL) -> Bool { legacyCalls += 1; return false }

    func openContainerURL(_ url: URL, completion: @escaping (Bool) -> Void) {
        modernURLs.append(url)
        completion(result)
    }
}

/// Responds only to the legacy selector (no modern API) — must never be reported as success.
private final class LegacyOnlyResponder: UIResponder {
    private(set) var legacyCalls = 0
    @objc(openURL:) func legacyOpenURL(_ url: URL) -> Bool { legacyCalls += 1; return true }
}

final class ContainerAppOpenerTests: XCTestCase {
    private let url = URL(string: "numpad://store-preview?source=key_lock")!

    func testFailedOpenDoesNotCountStoreOpen() {
        let app = FakeApplication(result: false)
        var opens = 0
        ContainerAppOpener.open(url, from: ChainLink(next: ChainLink(next: app))) { opens += 1 }
        XCTAssertEqual(opens, 0, "a failed open must not be counted as a store open")
        XCTAssertEqual(app.legacyCalls, 0, "must not use the legacy openURL: selector")
        XCTAssertEqual(app.modernURLs, [url])
    }

    func testSuccessfulOpenCountsExactlyOnceViaModernAPI() {
        let app = FakeApplication(result: true)
        var opens = 0
        ContainerAppOpener.open(url, from: ChainLink(next: app)) { opens += 1 }
        XCTAssertEqual(opens, 1)
        XCTAssertEqual(app.modernURLs, [url])
        XCTAssertEqual(app.legacyCalls, 0, "must not use the legacy openURL: selector")
    }

    func testLegacySelectorOnlyResponderIsNotReportedAsSuccess() {
        let legacy = LegacyOnlyResponder()
        var opens = 0
        ContainerAppOpener.open(url, from: ChainLink(next: legacy)) { opens += 1 }
        XCTAssertEqual(opens, 0)
        XCTAssertEqual(legacy.legacyCalls, 0, "legacy openURL: must not be dispatched")
    }

    func testNoOpenerInChainDoesNotCount() {
        var opens = 0
        ContainerAppOpener.open(url, from: ChainLink(next: ChainLink(next: nil))) { opens += 1 }
        ContainerAppOpener.open(url, from: nil) { opens += 1 }
        XCTAssertEqual(opens, 0)
    }
}
