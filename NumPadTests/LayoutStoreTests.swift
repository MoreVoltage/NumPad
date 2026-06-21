import XCTest
@testable import NumPad

final class LayoutStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.layoutstore.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func sample(_ name: String) -> KeyboardLayout {
        KeyboardLayout(name: name, rows: [[KeyDefinition(primary: .digit("1"))]])
    }

    func testSaveLoadRoundTrip() {
        let layouts = [sample("A"), sample("B")]
        LayoutStore(defaults: defaults).saveLayouts(layouts)
        XCTAssertEqual(LayoutStore(defaults: defaults).loadLayouts(), layouts)
    }

    func testLoadEmptyWhenNothingStored() {
        XCTAssertEqual(LayoutStore(defaults: defaults).loadLayouts(), [])
    }

    func testLoadEmptyWhenCorrupt() {
        defaults.set(Data("not json".utf8), forKey: "customLayouts")
        XCTAssertEqual(LayoutStore(defaults: defaults).loadLayouts(), [])
    }

    func testSaveTriggersOnChange() {
        var count = 0
        LayoutStore(defaults: defaults, onChange: { count += 1 }).saveLayouts([sample("A")])
        XCTAssertEqual(count, 1)
    }

    func testActiveLayoutResolvesAndRepairs() {
        let layout = sample("Active")
        let store = LayoutStore(defaults: defaults)
        store.saveLayouts([layout])
        store.setActiveID(layout.id)
        let active = LayoutStore(defaults: defaults).activeLayout()
        XCTAssertEqual(active?.id, layout.id)
        let tokens = active?.rows.flatMap { $0 }.map { $0.primary } ?? []
        XCTAssertTrue(tokens.contains(.delete), "active layout should be repaired()")
        XCTAssertTrue(tokens.contains(.ret))
    }

    func testActiveLayoutNilWhenNoActiveSet() {
        let store = LayoutStore(defaults: defaults)
        store.saveLayouts([sample("A")])
        XCTAssertNil(store.activeLayout())
    }

    func testSetActiveTriggersOnChange() {
        var count = 0
        LayoutStore(defaults: defaults, onChange: { count += 1 }).setActiveID(UUID())
        XCTAssertEqual(count, 1)
    }
}
