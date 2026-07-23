//
//  DeepLinkRouterTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class DeepLinkRouterTests: XCTestCase {
    func test_parseStorePreviewWithSource() {
        let url = URL(string: "numpad://store-preview?source=key_lock")!
        XCTAssertEqual(DeepLinkRouter.parse(url), .storePreview(source: "key_lock"))
    }

    func test_parseStorePreviewDefaultSource() {
        let url = URL(string: "numpad://store-preview")!
        XCTAssertEqual(DeepLinkRouter.parse(url), .storePreview(source: "deep_link"))
    }

    func test_parseRejectsUnknownSchemeAndHost() {
        XCTAssertNil(DeepLinkRouter.parse(URL(string: "https://example.com/store-preview")!))
        XCTAssertNil(DeepLinkRouter.parse(URL(string: "numpad://unknown")!))
    }

    func test_activeNavigationPrefersSplitSecondary() {
        let host = UIViewController()
        let split = UISplitViewController(style: .doubleColumn)
        let primary = UINavigationController(rootViewController: UIViewController())
        let secondary = UINavigationController(rootViewController: UIViewController())
        split.setViewController(primary, for: .primary)
        split.setViewController(secondary, for: .secondary)
        host.addChild(split)
        host.view.addSubview(split.view)
        split.didMove(toParent: host)

        XCTAssertTrue(DeepLinkRouter.activeNavigationController(from: host) === secondary)
    }
}
