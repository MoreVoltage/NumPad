import XCTest
@testable import NumPad

final class PackCatalogTests: XCTestCase {
    func test_packs_areTheCuratedSix() {
        XCTAssertEqual(KeyboardType.packs, [.math, .math2, .finance, .symbols, .programmer, .datetime, .units])
    }
    func test_allPackProductIDs_areTheFivePremium() {
        XCTAssertEqual(Set(ProductCatalog.allPackProductIDs),
            ["numpad.pack.finance", "numpad.pack.symbols", "numpad.pack.programmer", "numpad.pack.datetime", "numpad.pack.units"])
    }
    func test_catalog_totalsSevenProducts() {
        XCTAssertEqual(ProductCatalog.allProductIDs.count, 7) // 5 packs + pro + earlybird
    }
    func test_droppedPacks_haveNoProductID() {
        // `.units` was revived as a real à la carte pack (see UnitsPackTests) — the rest stay dropped.
        for p in [KeyboardType.scientific, .business, .international, .programmerPlus] {
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
    func test_grandfatheredOrPro_unlocksEverySix() {
        for p in KeyboardType.packs {
            XCTAssertFalse(Monetization.isPackLocked(p, proEntitled: true, ownedPackProductIDs: []))
        }
    }
}
