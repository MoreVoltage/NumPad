import XCTest
@testable import NumPad

final class PackCatalogTests: XCTestCase {
    func test_packs_areTheCuratedFive() {
        XCTAssertEqual(KeyboardType.packs, [.math, .math2, .finance, .symbols, .programmer, .datetime])
    }
    func test_allPackProductIDs_areTheFourPremium() {
        XCTAssertEqual(Set(ProductCatalog.allPackProductIDs),
            ["numpad.pack.finance", "numpad.pack.symbols", "numpad.pack.programmer", "numpad.pack.datetime"])
    }
    func test_catalog_totalsSixProducts() {
        XCTAssertEqual(ProductCatalog.allProductIDs.count, 6) // 4 packs + pro + earlybird
    }
    func test_droppedPacks_haveNoProductID() {
        for p in [KeyboardType.units, .scientific, .business, .international, .programmerPlus] {
            XCTAssertNil(ProductCatalog.packProductID(for: p))
        }
    }
    func test_mergedRows_haveExpectedKeys() {
        XCTAssertEqual(PackKeys.symbols(for: .symbols).first, "%")
        XCTAssertTrue(PackKeys.symbols(for: .symbols).contains("√"))
        XCTAssertTrue(PackKeys.symbols(for: .finance).contains("₹"))
        XCTAssertTrue(PackKeys.symbols(for: .programmer).contains("0b"))
        XCTAssertEqual(KeyboardType.symbols.name, "Symbols & Science")
    }
    func test_newUser_premiumPacksLockedUntilOwned() {
        XCTAssertTrue(Monetization.isPackLocked(.finance, proEntitled: false, ownedPackProductIDs: []))
        XCTAssertFalse(Monetization.isPackLocked(.finance, proEntitled: false,
            ownedPackProductIDs: ["numpad.pack.finance"]))
        XCTAssertFalse(Monetization.isPackLocked(.math, proEntitled: false, ownedPackProductIDs: []))
    }
    func test_grandfatheredOrPro_unlocksEveryFive() {
        for p in KeyboardType.packs {
            XCTAssertFalse(Monetization.isPackLocked(p, proEntitled: true, ownedPackProductIDs: []))
        }
    }
}
