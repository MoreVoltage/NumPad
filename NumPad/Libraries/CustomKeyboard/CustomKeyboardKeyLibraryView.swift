import SwiftUI
import UIKit

/// Shared drag-session identity so `CustomKeyboardSectionReorderView`'s drop delegate can recognize a
/// drag that originated from the Key Library palette — an external value **assignment** — and accept
/// it regardless of which section's slot it lands on, while continuing to reject a drag that began in
/// a *different* section's own reorder view (same-section reorder remains the only same-collection-
/// view case; cross-section reorder is still out of scope by construction). Neither file needs to
/// know the other's internals beyond this one marker type.
final class CustomKeyboardKeyLibraryDragMarker {
    static let shared = CustomKeyboardKeyLibraryDragMarker()
    private init() {}
}

/// The "Key Library" palette: a small, non-reorderable grid of ready-made key chips
/// (`CustomKeyboardKeyLibrary.chips`) the user drags into any slot rendered by
/// `CustomKeyboardSectionReorderView`. This is the other half of the isolated drag seam — like that
/// file, it is a SwiftUI-hosted `UICollectionView` (the same on-device-proven drag mechanism; see
/// that file's doc comment for why a hand-rolled gesture was rejected), but it is a **drag source
/// only**: it has no drop delegate of its own and never reorders itself. Every drag it originates is
/// tagged with `CustomKeyboardKeyLibraryDragMarker.shared` via `dragSessionWillBegin`.
///
/// A tap on a chip is the non-drag fallback (VoiceOver, or anyone who'd rather not drag): it reports
/// through `onTap`, and the caller assigns it to whichever slot is currently selected for entry —
/// the same target a completed drag would land on, just chosen explicitly instead of by drop
/// location.
struct CustomKeyboardKeyLibraryView: UIViewRepresentable {
    let chips: [CustomKeyboardKeyLibrary.Chip]
    let capWidth: CGFloat
    let capHeight: CGFloat
    let onTap: (_ token: String) -> Void

    /// Extra height under the cap for the optional subtitle caption (Date/Time chips).
    private static let chipSubtitleHeight: CGFloat = 14
    private static let reuseID = "CustomKeyboardKeyLibraryCell"

    func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: Self.makeLayout(capWidth: capWidth, capHeight: capHeight))
        collectionView.backgroundColor = .clear
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.dragDelegate = context.coordinator
        collectionView.dragInteractionEnabled = true
        collectionView.isScrollEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Self.reuseID)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard coordinator.chips != chips else { return }
        coordinator.chips = chips
        collectionView.reloadData()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// A wrapping grid (not the single-row/column compositional layout `CustomKeyboardSectionReorderView`
    /// uses) — `UICollectionViewFlowLayout`'s default vertical scroll direction wraps items left to
    /// right automatically, which is exactly the palette's read-only grid shape.
    private static func makeLayout(capWidth: CGFloat, capHeight: CGFloat) -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: capWidth, height: capHeight + chipSubtitleHeight)
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 6
        layout.sectionInset = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        return layout
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDragDelegate {
        var parent: CustomKeyboardKeyLibraryView
        var chips: [CustomKeyboardKeyLibrary.Chip]

        init(_ parent: CustomKeyboardKeyLibraryView) {
            self.parent = parent
            self.chips = parent.chips
        }

        // MARK: DataSource

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            chips.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomKeyboardKeyLibraryView.reuseID, for: indexPath)
            let chip = chips[indexPath.item]
            cell.contentConfiguration = UIHostingConfiguration {
                VStack(spacing: 2) {
                    KeyCapView(label: chip.label)
                    if let subtitle = chip.subtitle {
                        Text(subtitle)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .margins(.all, 0)
            cell.accessibilityLabel = chip.subtitle.map { "\(chip.label) — \($0)" } ?? chip.label
            cell.accessibilityHint = NSLocalizedString(
                "Double-tap to assign to the selected slot, or drag it onto any slot.",
                comment: "VoiceOver hint for a Key Library chip in the custom keyboard editor")
            return cell
        }

        // MARK: Delegate (tap = the non-drag fallback)

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard chips.indices.contains(indexPath.item) else { return }
            parent.onTap(chips[indexPath.item].token)
        }

        // MARK: Drag (source only — no drop delegate here; `CustomKeyboardSectionReorderView` is the target)

        func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
            guard chips.indices.contains(indexPath.item) else { return [] }
            let token = chips[indexPath.item].token
            let dragItem = UIDragItem(itemProvider: NSItemProvider(object: token as NSString))
            dragItem.localObject = token
            return [dragItem]
        }

        func collectionView(_ collectionView: UICollectionView, dragSessionWillBegin session: UIDragSession) {
            session.localContext = CustomKeyboardKeyLibraryDragMarker.shared
        }
    }
}
