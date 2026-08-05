import UIKit
import XCTest
@testable import NumPad

@MainActor
final class EmojiKeyboardViewTests: XCTestCase {
    private final class DelegateSpy: EmojiKeyboardViewDelegate {
        var typingRequests = 0
        var searchRequests = 0
        var nextKeyboardRequests = 0
        var deleteRequests = 0
        var selectedSequences: [String] = []
        var globeButtons: [UIButton] = []

        func emojiKeyboardViewDidRequestTyping(_ view: EmojiKeyboardView) {
            typingRequests += 1
        }

        func emojiKeyboardViewDidRequestSearch(_ view: EmojiKeyboardView) {
            searchRequests += 1
        }

        func emojiKeyboardViewDidRequestNextKeyboard(_ view: EmojiKeyboardView) {
            nextKeyboardRequests += 1
        }

        func emojiKeyboardViewDidRequestDelete(_ view: EmojiKeyboardView) {
            deleteRequests += 1
        }

        func emojiKeyboardView(_ view: EmojiKeyboardView, didSelect sequence: String) {
            selectedSequences.append(sequence)
        }

        func emojiKeyboardView(_ view: EmojiKeyboardView, didCreateGlobe button: UIButton) {
            globeButtons.append(button)
        }
    }

    private let items = [
        EmojiKeyboardItem(catalogIndex: 0, sequence: "😀", category: .smileys,
                          accessibilityLabel: "grinning face", variants: []),
        EmojiKeyboardItem(catalogIndex: 1, sequence: "👍", category: .people,
                          accessibilityLabel: "thumbs up", variants: [
                            EmojiKeyboardVariant(sequence: "👍🏻", accessibilityLabel: "thumbs up: light skin tone"),
                            EmojiKeyboardVariant(sequence: "👍🏽", accessibilityLabel: "thumbs up: medium skin tone"),
                          ]),
        EmojiKeyboardItem(catalogIndex: 2, sequence: "🐝", category: .animals,
                          accessibilityLabel: "honeybee", variants: []),
    ]

    func testInitialCategoryUsesRecentsWhenNonEmptyAndSmileysOtherwise() {
        let withRecents = EmojiKeyboardView(items: items, recents: ["🐝", "😀"])
        XCTAssertEqual(withRecents.selectedCategory, .recents)
        XCTAssertEqual(withRecents.visibleItems.map(\.sequence), ["🐝", "😀"])

        let withoutRecents = EmojiKeyboardView(items: items, recents: [])
        XCTAssertEqual(withoutRecents.selectedCategory, .catalog(.smileys))
        XCTAssertEqual(withoutRecents.visibleItems.map(\.sequence), ["😀"])
    }

    func testFilteredEmptyStateIsAccessibleAndBecomesTheFocusTarget() {
        let view = EmojiKeyboardView(items: items, recents: [])
        view.showFiltered(catalogIndices: [], query: "unicorn", moveAccessibilityFocus: true)

        XCTAssertEqual(view.selectedCategory, .filtered(query: "unicorn"))
        XCTAssertTrue(view.visibleItems.isEmpty)
        XCTAssertFalse(view.emptyStateLabel.isHidden)
        XCTAssertTrue(view.emptyStateLabel.isAccessibilityElement)
        XCTAssertEqual(view.emptyStateLabel.accessibilityLabel,
                       NSLocalizedString("No emoji found", comment: "empty emoji search result"))
        XCTAssertTrue(view.lastAccessibilityFocusTarget === view.emptyStateLabel)
    }

    func testToolbarActionsRemainSeparateAndGlobeIsExposedForHostWiring() {
        let view = EmojiKeyboardView(items: items, recents: [])
        let delegate = DelegateSpy()
        view.delegate = delegate
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 260)
        view.layoutIfNeeded()

        view.typingButton.sendActions(for: .touchUpInside)
        view.searchButton.sendActions(for: .touchUpInside)
        view.globeButton.sendActions(for: .touchUpInside)
        view.backspaceButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(delegate.typingRequests, 1)
        XCTAssertEqual(delegate.searchRequests, 1)
        XCTAssertEqual(delegate.nextKeyboardRequests, 1)
        XCTAssertEqual(delegate.deleteRequests, 1)
        XCTAssertEqual(delegate.globeButtons.count, 1)
        XCTAssertTrue(delegate.globeButtons.first === view.globeButton)
        XCTAssertTrue([view.typingButton, view.searchButton, view.globeButton, view.backspaceButton]
            .allSatisfy { $0.bounds.width >= 44 && $0.bounds.height >= 44 })
        XCTAssertEqual(
            (view.accessibilityElements?.prefix(4).compactMap { $0 as? UIButton }) ?? [],
            [view.typingButton, view.searchButton, view.globeButton, view.backspaceButton]
        )
    }

    func testCollectionSelectionReturnsTheExactCatalogSequence() {
        let view = EmojiKeyboardView(items: items, recents: [])
        let delegate = DelegateSpy()
        view.delegate = delegate
        view.showCategory(.catalog(.people), moveAccessibilityFocus: false)

        view.collectionView.delegate?.collectionView?(
            view.collectionView,
            didSelectItemAt: IndexPath(item: 0, section: 0)
        )

        XCTAssertEqual(delegate.selectedSequences, ["👍"])
    }

    func testReusableCellUsesExactSequenceCLDRLabelAndVariantAction() throws {
        let view = EmojiKeyboardView(items: items, recents: [])
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 260)
        view.showCategory(.catalog(.people), moveAccessibilityFocus: false)
        view.layoutIfNeeded()

        let cell = try XCTUnwrap(
            view.collectionView.dataSource?.collectionView(
                view.collectionView,
                cellForItemAt: IndexPath(item: 0, section: 0)
            ) as? EmojiCollectionViewCell
        )
        XCTAssertEqual(cell.reuseIdentifier, EmojiCollectionViewCell.reuseIdentifier)
        XCTAssertEqual(cell.sequenceLabel.text, "👍")
        XCTAssertEqual(cell.accessibilityLabel, "thumbs up")
        XCTAssertEqual(
            cell.accessibilityHint,
            NSLocalizedString("Variants available", comment: "emoji skin-tone variant accessibility hint")
        )
        XCTAssertTrue(cell.accessibilityTraits.contains(.button))
        XCTAssertEqual(
            cell.accessibilityCustomActions?.map(\.name),
            [NSLocalizedString("Choose skin tone", comment: "emoji variant accessibility action")]
        )

        XCTAssertTrue(cell.performVariantAccessibilityAction())
        XCTAssertNotNil(view.modifierChooser)
        XCTAssertTrue(view.modifierChooser?.superview === view)
        XCTAssertTrue(view.bounds.contains(view.modifierChooser?.panelFrame ?? .null))
    }

    func testCategorySelectionIsOrderedSelectedAndMovesFocusDeliberately() throws {
        let view = EmojiKeyboardView(items: items, recents: ["😀"])
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 260)
        view.layoutIfNeeded()

        XCTAssertEqual(view.categorySelections.first, .recents)
        XCTAssertEqual(Array(view.categorySelections.dropFirst()),
                       EmojiCategory.allCases.map(EmojiKeyboardCategory.catalog))
        let animals = try XCTUnwrap(view.categoryButton(for: .catalog(.animals)))
        view.showCategory(.catalog(.animals), moveAccessibilityFocus: true)

        XCTAssertTrue(animals.accessibilityTraits.contains(.selected))
        XCTAssertEqual(view.visibleItems.map(\.sequence), ["🐝"])
        XCTAssertTrue(view.lastAccessibilityFocusTarget === view.headingLabel)
        XCTAssertEqual(view.accessibilityElements?.first as? UIButton, view.typingButton)
    }

    func testSearchHeaderExposesLocalizedLabelAndLiveQueryValue() {
        let header = EmojiSearchHeaderView()
        header.update(query: "happy face")

        XCTAssertTrue(header.isAccessibilityElement)
        XCTAssertEqual(header.accessibilityLabel,
                       NSLocalizedString("Emoji search", comment: "emoji search header"))
        XCTAssertEqual(header.accessibilityValue, "happy face")
        XCTAssertEqual(header.queryLabel.text, "happy face")
    }
}
