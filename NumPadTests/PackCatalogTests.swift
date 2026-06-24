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
}
