import SwiftUI
import UIKit

/// A SwiftUI-hosted `UICollectionView` that lets the user drag-reorder the keys of ONE Custom
/// Keyboard section (Top Row / Column 1 / Column 2) — Option B from
/// docs/plans/2026-07-03-editor-ux-research.md.
///
/// Why a `UICollectionView` and not a custom SwiftUI gesture: the earlier "Phase-5 springboard"
/// editor attached a hand-rolled `LongPressGesture(minimumDuration:).sequenced(before:
/// DragGesture())` to every cell, nested inside a `ScrollView`/`GeometryReader`, hosted via a
/// pushed `UIHostingController` — and the drag never fired reliably on device (see the research
/// doc §1 for the full forensic trail). `UICollectionViewDragDelegate`/`DropDelegate` hands the
/// entire gesture lifecycle to UIKit instead (long-press-to-lift, haptics, reflow animation), the
/// same API family this codebase already ships on device for
/// `ClipboardHistoryView`/`SnippetsListView`'s iPad drag-out rows — just applied here to in-place
/// reorder rather than drag-out. **No custom gesture recognizer is attached anywhere in this file.**
///
/// Scope is deliberately narrow and self-contained (fallback seam): this file is the *only* place
/// that knows about `UICollectionView`. It takes one section's `keys` in and reports moves out
/// via `onMove`; it never sees `CustomKeyboardConfig` or other sections, so a cross-section drop is
/// structurally impossible (the collection view's drop delegate only accepts a drag session that
/// began in itself — see `dropSessionDidUpdate`). If Option B needs to be swapped for Option A
/// (SwiftUI `List` + `.onMove`) after on-device testing, only this file and its two call sites in
/// `CustomKeyboardEditorView` change; `CustomKeyboardEditorModel.moveKey(in:from:to:)` and
/// `CustomKeyboardReorder` are untouched either way.
struct CustomKeyboardSectionReorderView: UIViewRepresentable {
    enum Axis { case horizontal, vertical }

    /// Every slot in the section, already padded to the section's full capacity by the caller
    /// (empty string = an unfilled "+" slot). Index-aligned with `selectedIndex` and with the
    /// `from`/`to` indices reported by `onMove`.
    let keys: [String]
    let axis: Axis
    let capWidth: CGFloat
    let capHeight: CGFloat
    /// The index (within this section) currently open for secure-field entry, or `nil`.
    let selectedIndex: Int?
    /// Tap (not drag) on a slot — opens it for secure-field entry, same as the legacy `slotButton`.
    let onSelect: (_ index: Int) -> Void
    /// A completed reorder. Indices are pre-move positions (`from`) and the `CustomKeyboardReorder`
    /// destination convention (`to`) — see that type's doc comment.
    let onMove: (_ from: Int, _ to: Int) -> Void

    private static let spacing: CGFloat = 6
    private static let edgeInset: CGFloat = 2
    private static let reuseID = "CustomKeyboardSectionReorderCell"

    func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: Self.makeLayout(axis: axis, capWidth: capWidth, capHeight: capHeight))
        collectionView.backgroundColor = .clear
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.dragDelegate = context.coordinator
        collectionView.dropDelegate = context.coordinator
        collectionView.dragInteractionEnabled = true
        collectionView.isScrollEnabled = axis == .horizontal
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Self.reuseID)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard coordinator.keys != keys || coordinator.selectedIndex != selectedIndex else { return }
        coordinator.keys = keys
        coordinator.selectedIndex = selectedIndex
        collectionView.reloadData()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private static func makeLayout(axis: Axis, capWidth: CGFloat, capHeight: CGFloat) -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(capWidth), heightDimension: .absolute(capHeight))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(capWidth), heightDimension: .absolute(capHeight))
        let group: NSCollectionLayoutGroup
        switch axis {
        case .horizontal: group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        case .vertical: group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        }
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(top: edgeInset, leading: edgeInset, bottom: edgeInset, trailing: edgeInset)
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = axis == .horizontal ? .horizontal : .vertical
        return UICollectionViewCompositionalLayout(section: section, configuration: config)
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate,
                              UICollectionViewDragDelegate, UICollectionViewDropDelegate {
        var parent: CustomKeyboardSectionReorderView
        var keys: [String]
        var selectedIndex: Int?

        init(_ parent: CustomKeyboardSectionReorderView) {
            self.parent = parent
            self.keys = parent.keys
            self.selectedIndex = parent.selectedIndex
        }

        // MARK: DataSource

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            keys.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomKeyboardSectionReorderView.reuseID, for: indexPath)
            let key = indexPath.item < keys.count ? keys[indexPath.item] : ""
            let label = key.isEmpty ? "+" : CustomKeys.displayName(for: key)
            let isSelected = selectedIndex == indexPath.item
            cell.contentConfiguration = UIHostingConfiguration {
                KeyCapView(label: label, isSelected: isSelected)
            }
            .margins(.all, 0)
            cell.accessibilityLabel = key.isEmpty
                ? NSLocalizedString("Empty slot", comment: "VoiceOver label for an empty custom-keyboard slot")
                : label
            return cell
        }

        // MARK: Delegate (tap = select; long-press-drag is handled entirely by UIKit below)

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            parent.onSelect(indexPath.item)
        }

        // MARK: Drag

        func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
            guard keys.indices.contains(indexPath.item) else { return [] }
            let dragItem = UIDragItem(itemProvider: NSItemProvider(object: keys[indexPath.item] as NSString))
            dragItem.localObject = indexPath.item
            return [dragItem]
        }

        /// Tags the session with this collection view so `dropSessionDidUpdate` can refuse any
        /// drag that didn't start in this exact section (cross-section moves are out of scope by
        /// construction, not by convention).
        func collectionView(_ collectionView: UICollectionView, dragSessionWillBegin session: UIDragSession) {
            session.localContext = collectionView
        }

        func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
            session.localContext = nil
        }

        // MARK: Drop (local reorder only)

        func collectionView(_ collectionView: UICollectionView,
                             dropSessionDidUpdate session: UIDropSession,
                             withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
            guard collectionView.hasActiveDrag,
                  session.localDragSession?.localContext as? UICollectionView === collectionView else {
                return UICollectionViewDropProposal(operation: .forbidden)
            }
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }

        func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
            guard let dragItem = coordinator.items.first,
                  let sourceIndexPath = dragItem.sourceIndexPath,
                  keys.indices.contains(sourceIndexPath.item) else { return }
            let destinationItem = coordinator.destinationIndexPath?.item ?? keys.count
            guard sourceIndexPath.item != destinationItem else { return }

            let reordered = CustomKeyboardReorder.moved(keys, from: sourceIndexPath.item, to: destinationItem)
            guard reordered != keys else { return }
            let landingIndex = min(destinationItem, reordered.count - 1)
            let landingIndexPath = IndexPath(item: landingIndex, section: 0)

            collectionView.performBatchUpdates {
                keys = reordered
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [landingIndexPath])
            }
            coordinator.drop(dragItem.dragItem, toItemAt: landingIndexPath)
            parent.onMove(sourceIndexPath.item, destinationItem)
        }
    }
}
