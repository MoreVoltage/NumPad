import UIKit
import XCTest
@testable import NumPad

@MainActor
final class EmojiModifierChooserTests: XCTestCase {
    private let variants = [
        EmojiKeyboardVariant(sequence: "👍🏻", accessibilityLabel: "thumbs up: light skin tone"),
        EmojiKeyboardVariant(sequence: "👍🏼", accessibilityLabel: "thumbs up: medium-light skin tone"),
        EmojiKeyboardVariant(sequence: "👍🏽", accessibilityLabel: "thumbs up: medium skin tone"),
        EmojiKeyboardVariant(sequence: "👍🏾", accessibilityLabel: "thumbs up: medium-dark skin tone"),
        EmojiKeyboardVariant(sequence: "👍🏿", accessibilityLabel: "thumbs up: dark skin tone"),
    ]

    func testSmallFamilyUsesHorizontalStripAndReturnsExactSequence() {
        var selected: String?
        let chooser = EmojiModifierChooserView(
            variants: variants,
            sourceFrame: CGRect(x: 130, y: 180, width: 48, height: 48),
            availableBounds: CGRect(x: 0, y: 0, width: 320, height: 260)
        )
        chooser.onSelect = { selected = $0 }

        XCTAssertFalse(chooser.usesGrid)
        XCTAssertEqual(Set(chooser.variantButtons.map { $0.frame.minY }).count, 1)
        chooser.variantButtons[2].sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, "👍🏽")
    }

    func testLargeFamilyUsesGridWithoutSynthesizingSequences() {
        let exact = (0..<12).map {
            EmojiKeyboardVariant(sequence: "exact-\($0)", accessibilityLabel: "variant \($0)")
        }
        let chooser = EmojiModifierChooserView(
            variants: exact,
            sourceFrame: CGRect(x: 130, y: 180, width: 48, height: 48),
            availableBounds: CGRect(x: 0, y: 0, width: 320, height: 260)
        )

        XCTAssertTrue(chooser.usesGrid)
        XCTAssertGreaterThan(Set(chooser.variantButtons.map { $0.frame.minY }).count, 1)
        XCTAssertEqual(chooser.variantButtons.map { $0.title(for: .normal) ?? "" },
                       exact.map(\.sequence))
    }

    func testChooserPanelStaysInsidePhonePadSplitAndFloatingBounds() {
        let bounds = [
            CGRect(x: 0, y: 0, width: 320, height: 260),
            CGRect(x: 0, y: 0, width: 1024, height: 320),
            CGRect(x: 0, y: 0, width: 507, height: 320),
            CGRect(x: 0, y: 0, width: 375, height: 216),
        ]

        for available in bounds {
            for source in [
                CGRect(x: available.minX, y: available.minY, width: 44, height: 44),
                CGRect(x: available.maxX - 44, y: available.maxY - 44, width: 44, height: 44),
            ] {
                let chooser = EmojiModifierChooserView(
                    variants: variants,
                    sourceFrame: source,
                    availableBounds: available
                )
                XCTAssertTrue(available.contains(chooser.panelFrame), "\(available) source=\(source)")
                XCTAssertTrue(chooser.variantButtons.allSatisfy {
                    chooser.panelFrame.contains($0.frame)
                })
            }
        }
    }

    func testOutsideTapDismissesButInsideTapDoesNot() {
        var dismissals = 0
        let chooser = EmojiModifierChooserView(
            variants: variants,
            sourceFrame: CGRect(x: 130, y: 180, width: 48, height: 48),
            availableBounds: CGRect(x: 0, y: 0, width: 320, height: 260)
        )
        chooser.onDismiss = { dismissals += 1 }

        XCTAssertFalse(chooser.dismissIfOutside(point: chooser.panelFrame.center))
        XCTAssertEqual(dismissals, 0)
        XCTAssertTrue(chooser.dismissIfOutside(point: .zero))
        XCTAssertEqual(dismissals, 1)
    }

    func testButtonsExposeExactCLDRLabelsAndMinimumTargets() {
        let chooser = EmojiModifierChooserView(
            variants: variants,
            sourceFrame: CGRect(x: 130, y: 180, width: 48, height: 48),
            availableBounds: CGRect(x: 0, y: 0, width: 320, height: 260)
        )

        for (button, variant) in zip(chooser.variantButtons, variants) {
            XCTAssertEqual(button.accessibilityLabel, variant.accessibilityLabel)
            XCTAssertTrue(button.accessibilityTraits.contains(.button))
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
