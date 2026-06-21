import XCTest
@testable import NumPad

final class StandardLayoutTests: XCTestCase {
    func testStandardContainsEveryEssential() {
        let tokens = KeyboardLayout.standard.rows.flatMap { $0 }.map(\.primary)
        for essential in KeyboardLayout.essentialTokens {
            XCTAssertTrue(tokens.contains(essential), "standard missing \(essential)")
        }
    }
    func testStandardIsNamedDefault() {
        XCTAssertEqual(KeyboardLayout.standard.name, "Default")
    }
}

final class LayoutEditorModelTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    override func setUp() { super.setUp(); suite = "test.editor.\(UUID().uuidString)"; defaults = UserDefaults(suiteName: suite) }
    override func tearDown() { defaults.removePersistentDomain(forName: suite); super.tearDown() }
    private func makeModel() -> LayoutEditorModel { LayoutEditorModel(store: LayoutStore(defaults: defaults)) }

    func testInitLoadsExistingStateFromStore() {
        let layout = KeyboardLayout(name: "X", rows: [[KeyDefinition(primary: .digit("1"))]])
        let store = LayoutStore(defaults: defaults)
        store.saveLayouts([layout]); store.setActiveID(layout.id)
        let model = makeModel()
        XCTAssertEqual(model.layouts.map(\.id), [layout.id])
        XCTAssertEqual(model.activeID, layout.id)
    }

    func testCreateSeedsStandardAppendsAndPersists() {
        let model = makeModel()
        let created = model.createLayout(named: "Work")
        XCTAssertEqual(created.name, "Work")
        XCTAssertTrue(model.layouts.contains { $0.id == created.id })
        let tokens = created.rows.flatMap { $0 }.map(\.primary)
        XCTAssertTrue(tokens.contains(.digit("0")) && tokens.contains(.digit("9")), "should seed from standard")
        XCTAssertTrue(LayoutStore(defaults: defaults).loadLayouts().contains { $0.id == created.id }, "should persist")
    }

    func testActivatePersists() {
        let model = makeModel(); let c = model.createLayout(named: "A")
        model.activate(c.id)
        XCTAssertEqual(model.activeID, c.id)
        XCTAssertEqual(LayoutStore(defaults: defaults).activeID, c.id)
    }

    func testRenamePersists() {
        let model = makeModel(); let c = model.createLayout(named: "Old")
        model.rename(c.id, to: "New")
        XCTAssertEqual(model.layouts.first { $0.id == c.id }?.name, "New")
        XCTAssertEqual(LayoutStore(defaults: defaults).loadLayouts().first { $0.id == c.id }?.name, "New")
    }

    func testDeleteRemovesAndClearsActive() {
        let model = makeModel(); let c = model.createLayout(named: "A"); model.activate(c.id)
        model.delete(c.id)
        XCTAssertFalse(model.layouts.contains { $0.id == c.id })
        XCTAssertNil(model.activeID)
        XCTAssertNil(LayoutStore(defaults: defaults).activeID)
    }
}
