#if DEBUG && NUMPAD_PRIVATE_SWIPE
import XCTest
import CoreGraphics
@testable import NumPad

final class QwertySwipeCalibrationTests: XCTestCase {
    private var centers: [String: CGPoint] {
        var value: [String: CGPoint] = [:]
        for (y, row) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
            for (x, key) in row.enumerated() { value[String(key)] = CGPoint(x: CGFloat(x * 30), y: CGFloat(y * 30)) }
        }
        return value
    }
    private func path(_ word: String, dx: CGFloat = 0, dy: CGFloat = 0) -> [CGPoint] {
        word.compactMap { centers[String($0)] }.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
    }
    func testDistinctIntendedWordsCannotBeReplacedByCrossedKeysOrRepeatedWord() {
        var coverage = QwertySwipeCalibration.Coverage()
        for _ in 0..<100 { coverage.accept(word: "quick") }
        XCTAssertEqual(coverage.count("q"), 1)
        XCTAssertEqual(coverage.count("w"), 0)
        XCTAssertFalse(coverage.complete)
    }
    func testPlannerRequiresEveryLetterInThreeDifferentWords() {
        var coverage = QwertySwipeCalibration.Coverage()
        var count = 0
        while !coverage.complete, let word = coverage.nextWord, count < 100 {
            coverage.accept(word: word); count += 1
        }
        XCTAssertTrue(coverage.complete)
        XCTAssertGreaterThanOrEqual(count, 20)
        for letter in QwertySwipeCalibration.alphabet { XCTAssertGreaterThanOrEqual(coverage.count(letter), 3) }
    }
    func testTrainingCannotAcceptUnpromptedWordOrScribble() {
        var session = QwertySwipeCalibration.Session(contextID: "portrait", tapRunID: UUID())
        XCTAssertFalse(session.acceptConfirmedPath(path("hello"), word: "hello", centers: centers))
        let word = session.nextWord!
        XCTAssertFalse(session.acceptConfirmedPath([.zero, CGPoint(x: 9000, y: 9000)], word: word, centers: centers))
        XCTAssertTrue(session.acceptConfirmedPath(path(word), word: word, centers: centers))
        XCTAssertEqual(session.training.count, 1)
        XCTAssertTrue(session.heldOut.isEmpty)
    }
    func testCandidateRequiresFullCoverageAndOffsetsStayBounded() {
        var session = QwertySwipeCalibration.Session(contextID: "portrait", tapRunID: UUID())
        XCTAssertNil(session.candidate(centers: centers))
        while !session.coverage.complete, let word = session.nextWord {
            XCTAssertTrue(session.acceptConfirmedPath(path(word, dx: 10, dy: -10), word: word, centers: centers))
        }
        let candidate = session.candidate(centers: centers)!
        XCTAssertGreaterThan(candidate.startX, 0)
        XCTAssertLessThanOrEqual(candidate.startX, 0.35)
        XCTAssertLessThan(candidate.endY, 0)
        XCTAssertGreaterThanOrEqual(candidate.endY, -0.35)
    }
    func testPerfectBaselineTieRetainsPriorProfileAndHeldoutNeverTrains() {
        var session = QwertySwipeCalibration.Session(contextID: "portrait", tapRunID: UUID())
        while !session.complete, let word = session.nextWord {
            XCTAssertTrue(session.acceptConfirmedPath(path(word), word: word, centers: centers))
        }
        XCTAssertTrue(Set(session.training.map(\.word)).isDisjoint(with: Set(session.heldOut.map(\.word))))
        let lexicon = QwertyFrequencyLexicon(data: QwertyFrequencyLexicon.encode(rankedWords: QwertySwipeCalibration.trainingWords + QwertySwipeCalibration.validationWords))
        let run = session.evaluate(centers: centers, decoder: QwertyGlideDecoder(keyCenters: centers, lexicon: lexicon), current: nil)!
        XCTAssertFalse(run.metrics.accepted)
        XCTAssertEqual(run.metrics.baselineTop1Errors, run.metrics.candidateTop1Errors)
        XCTAssertEqual(run.metrics.words, QwertySwipeCalibration.validationWords.count)
    }
    func testCheckpointAndResetNeverTouchTapState() {
        let suite = "swipe-test-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("tap sentinel", forKey: "qwertyTouchOffsets")
        let store = QwertySwipeCalibrationStore(defaults: defaults)
        let session = QwertySwipeCalibration.Session(contextID: "portrait", tapRunID: UUID())
        store.saveCheckpoint(session)
        XCTAssertEqual(store.checkpoint(contextID: "portrait", tapRunID: session.tapRunID)?.id, session.id)
        XCTAssertNil(store.checkpoint(contextID: "landscape", tapRunID: session.tapRunID))
        XCTAssertNil(store.checkpoint(contextID: "portrait", tapRunID: UUID()))
        store.reset()
        XCTAssertFalse(store.saveCheckpoint(session), "A delayed checkpoint cannot resurrect a reset")
        XCTAssertEqual(store.generation, 1)
        XCTAssertNil(store.checkpoint(contextID: "portrait", tapRunID: session.tapRunID))
        XCTAssertEqual(defaults.string(forKey: "qwertyTouchOffsets"), "tap sentinel")
    }
}
#endif
