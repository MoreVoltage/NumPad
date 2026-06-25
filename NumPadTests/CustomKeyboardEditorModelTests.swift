import XCTest
@testable import NumPad

final class CustomKeyboardEditorModelTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.cke.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private final class Counters {
        var notify = 0
        var handedness: [Handedness] = []
        var events: [String] = []
    }

    private typealias Cell = CustomKeyboardEditorModel.Cell

    private func makeModel(stored: CustomKeyboardConfig? = nil,
                           pack: [String] = [],
                           slots: [String] = [",", ".", CustomKeys.spaceToken],
                           handedness: Handedness = .right) -> (CustomKeyboardEditorModel, Counters) {
        let store = CustomKeyboardStore(defaults: defaults)
        if let stored { store.save(stored) }
        let c = Counters()
        let model = CustomKeyboardEditorModel(
            store: store, handedness: handedness, seedPackKeys: pack, seedSlots: slots,
            notify: { c.notify += 1 },
            persistHandedness: { c.handedness.append($0) },
            logEvent: { name, _ in c.events.append(name) })
        return (model, c)
    }

    func testSeedsFromExistingWhenStoreEmpty() {
        let (model, _) = makeModel(pack: ["00", "000"], slots: [",", ".", CustomKeys.spaceToken])
        XCTAssertEqual(model.config.topRow, ["00", "000"])
        XCTAssertEqual(model.config.column1, [",", ".", CustomKeys.spaceToken])
        XCTAssertNil(model.config.column2)
    }

    func testLoadsExistingConfigInsteadOfSeeding() {
        let stored = CustomKeyboardConfig(name: "Saved", topRow: ["X"], column1: nil, column2: nil)
        let (model, _) = makeModel(stored: stored, pack: ["should", "not", "seed"])
        XCTAssertEqual(model.config.topRow, ["X"])
        XCTAssertNil(model.config.column1)
    }

    func testSetEnabledTogglesNilAndEmpty() {
        let (model, _) = makeModel()
        model.setEnabled(.column2, true)
        XCTAssertEqual(model.config.column2, [])
        XCTAssertTrue(model.isEnabled(.column2))
        model.setEnabled(.column2, false)
        XCTAssertNil(model.config.column2)
        XCTAssertFalse(model.isEnabled(.column2))
    }

    func testSetKeyPadsAndCapsLength() {
        let (model, _) = makeModel(slots: [])
        model.setEnabled(.column1, true)
        model.setKey("ABCDEFG", at: Cell(section: .column1, index: 2))
        XCTAssertEqual(model.config.column1, ["", "", "ABCD"])
    }

    func testSetKeyPreservesFunctionToken() {
        let (model, _) = makeModel(slots: [])
        model.setKey(CustomKeys.spaceToken, at: Cell(section: .column1, index: 0))
        XCTAssertEqual(model.key(at: Cell(section: .column1, index: 0)), CustomKeys.spaceToken)
    }

    func testAppendKeyRespectsCapacityAndReturnsCell() {
        let (model, _) = makeModel(slots: [])
        XCTAssertEqual(model.appendKey("a", to: .column1), Cell(section: .column1, index: 0))
        XCTAssertEqual(model.appendKey("b", to: .column1), Cell(section: .column1, index: 1))
        XCTAssertEqual(model.appendKey("c", to: .column1), Cell(section: .column1, index: 2))
        XCTAssertNil(model.appendKey("d", to: .column1))   // column capacity is 3
        XCTAssertEqual(model.config.column1, ["a", "b", "c"])
    }

    func testAppendKeyIgnoresEmpty() {
        let (model, _) = makeModel(slots: [])
        XCTAssertNil(model.appendKey("   ", to: .column1))
    }

    func testRemoveKey() {
        let (model, _) = makeModel(slots: [])
        model.appendKey("a", to: .column1)
        model.appendKey("b", to: .column1)
        model.removeKey(at: Cell(section: .column1, index: 0))
        XCTAssertEqual(model.config.column1, ["b"])
    }

    func testNextCellAdvancesWithinSectionThenStops() {
        let (model, _) = makeModel(slots: [])
        model.appendKey("a", to: .column1)
        XCTAssertEqual(model.nextCell(after: Cell(section: .column1, index: 0)),
                       Cell(section: .column1, index: 1))
        model.appendKey("b", to: .column1)
        model.appendKey("c", to: .column1)
        XCTAssertNil(model.nextCell(after: Cell(section: .column1, index: 2)))  // at capacity
    }

    func testPersistSavesWhenHasKeysAndClearsWhenEmpty() {
        let (model, _) = makeModel(pack: [], slots: [])
        XCTAssertNil(CustomKeyboardStore(defaults: defaults).load())  // init does not persist
        model.appendKey("a", to: .column1)
        XCTAssertEqual(CustomKeyboardStore(defaults: defaults).load()?.column1, ["a"])
        model.removeKey(at: Cell(section: .column1, index: 0))
        XCTAssertNil(CustomKeyboardStore(defaults: defaults).load())  // empty config clears storage
    }

    func testSetHandednessPersistsAndNotifiesOnce() {
        let (model, c) = makeModel(handedness: .right)
        model.setHandedness(.left)
        XCTAssertEqual(model.handedness, .left)
        XCTAssertEqual(c.handedness, [.left])
        XCTAssertEqual(c.notify, 1)
        model.setHandedness(.left)   // no-op when unchanged
        XCTAssertEqual(c.notify, 1)
    }
}
