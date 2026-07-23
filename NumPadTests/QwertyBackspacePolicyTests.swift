import XCTest
@testable import NumPad

final class QwertyBackspacePolicyTests: XCTestCase {
    func testInteractionConfigurationOwnsTheSingleInitialDelay() {
        let configuration = QwertyBackspaceInteractionConfiguration(
            wordDeleteEnabled: true,
            initialDelay: 0.35,
            repeatInterval: 0.10
        )

        XCTAssertTrue(configuration.wordDeleteEnabled)
        XCTAssertEqual(configuration.initialDelay, 0.35, accuracy: 0.000_001)
        XCTAssertEqual(configuration.repeatInterval, 0.10, accuracy: 0.000_001)
        XCTAssertEqual(QwertyBackspacePolicy.nextInterval(elapsed: 0,
                                                         configuration: configuration),
                       0.35,
                       accuracy: 0.000_001)
        XCTAssertEqual(QwertyBackspacePolicy.action(elapsed: 0.35,
                                                   configuration: configuration),
                       .deleteCharacter,
                       "the first repeat fires at exactly 0.35 seconds")
    }

    func testFeatureOffNeverTransitionsToWordDeletion() {
        let configuration = QwertyBackspaceInteractionConfiguration(
            wordDeleteEnabled: false,
            initialDelay: 0.35,
            repeatInterval: 0.10
        )

        XCTAssertEqual(QwertyBackspacePolicy.action(elapsed: 0.349,
                                                   configuration: configuration),
                       .wait)
        XCTAssertEqual(QwertyBackspacePolicy.action(elapsed: 0.35,
                                                   configuration: configuration),
                       .deleteCharacter)
        XCTAssertEqual(QwertyBackspacePolicy.action(elapsed: 20,
                                                   configuration: configuration),
                       .deleteCharacter)
    }

    func testFeatureOnTransitionsToWordDeletionAtThreshold() {
        let configuration = QwertyBackspaceInteractionConfiguration(
            wordDeleteEnabled: true,
            initialDelay: 0.35,
            repeatInterval: 0.10
        )

        XCTAssertEqual(QwertyBackspacePolicy.action(
            elapsed: QwertyBackspacePolicy.wordDeleteAfter,
            configuration: configuration
        ), .deleteWord)
    }
}
