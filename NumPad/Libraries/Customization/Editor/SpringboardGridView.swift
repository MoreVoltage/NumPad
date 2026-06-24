import SwiftUI

/// A springboard-style reorder grid: the flat `items` are laid out in a fixed-width grid and
/// reordered with a **long-press lift → drag → live reflow → drop** gesture (the iOS Home-screen
/// feel). The lifted key scales up and follows the finger; the rest animate aside to open the gap
/// at the finger's insertion slot; on release everything snaps to its final slot. All reorder math
/// is delegated to the pure `SpringboardLayout` (`insertionIndex` / `moving`) — this view only owns
/// the gesture, the animation, and the haptics.
///
/// In edit mode, removable keys show a ⊖ delete badge; **locked keys**
/// (`SpringboardLayout.isLocked` — digits 0–9, delete, return) reorder freely but show no badge and
/// cannot be removed, so a layout can never lose an essential key.
struct SpringboardGridView: View {
    @Binding var items: [KeyDefinition]
    var columns: Int = SpringboardLayout.columns
    var spacing: CGFloat = 6
    var cellHeight: CGFloat = 46
    let editing: Bool
    /// Fired once on drop, after `items` has settled into its final order.
    let onReorderCommitted: () -> Void
    /// Fired when the ⊖ badge is tapped (only ever presented for non-locked keys).
    let onDelete: (KeyDefinition) -> Void

    @State private var draggingID: KeyDefinition.ID?
    @State private var dragLocation: CGPoint = .zero

    private let coordinateSpaceName = "springboard"
    private let liftScale: CGFloat = 1.12
    private let liftAnimation = Animation.spring(response: 0.28, dampingFraction: 0.7)
    private let reflowAnimation = Animation.spring(response: 0.3, dampingFraction: 0.75)

    var body: some View {
        GeometryReader { proxy in
            let cellWidth = cellWidth(in: proxy.size.width)
            ZStack(alignment: .topLeading) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, key in
                    keyCell(key, index: index, cellWidth: cellWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: gridHeight)
        .coordinateSpace(name: coordinateSpaceName)
    }

    // MARK: Cells

    @ViewBuilder
    private func keyCell(_ key: KeyDefinition, index: Int, cellWidth: CGFloat) -> some View {
        let isDragging = key.id == draggingID
        let slot = slotCenter(forIndex: index, cellWidth: cellWidth)
        let center = isDragging ? dragLocation : slot

        KeyCapView(label: key.label ?? key.primary.displayLabel)
            .overlay(alignment: .topLeading) { deleteBadge(for: key) }
            .frame(width: cellWidth, height: cellHeight)
            .scaleEffect(isDragging ? liftScale : 1)
            .shadow(color: SwiftUI.Color.black.opacity(isDragging ? 0.25 : 0),
                    radius: isDragging ? 8 : 0, x: 0, y: isDragging ? 4 : 0)
            .position(center)
            .zIndex(isDragging ? 1 : 0)
            .animation(isDragging ? nil : reflowAnimation, value: index)
            .gesture(dragGesture(for: key, index: index, cellWidth: cellWidth))
    }

    @ViewBuilder
    private func deleteBadge(for key: KeyDefinition) -> some View {
        if editing && !SpringboardLayout.isLocked(key.primary) {
            Button { onDelete(key) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(SwiftUI.Color.white, SwiftUI.Color.red)
                    .background(Circle().fill(SwiftUI.Color.white).padding(2))
            }
            .buttonStyle(.plain)
            .offset(x: -6, y: -6)
            .accessibilityLabel(Text(NSLocalizedString("Remove key", comment: "Springboard editor delete badge")))
        }
    }

    // MARK: Gesture

    private func dragGesture(for key: KeyDefinition, index: Int, cellWidth: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(coordinateSpace: .named(coordinateSpaceName)))
            .onChanged { value in
                switch value {
                case .first(true):
                    beginLift(of: key, index: index, cellWidth: cellWidth)
                case .second(true, let drag?):
                    updateDrag(drag, cellWidth: cellWidth)
                default:
                    break
                }
            }
            .onEnded { _ in endDrag() }
    }

    private func beginLift(of key: KeyDefinition, index: Int, cellWidth: CGFloat) {
        guard draggingID == nil else { return }
        dragLocation = slotCenter(forIndex: index, cellWidth: cellWidth)
        withAnimation(liftAnimation) { draggingID = key.id }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func updateDrag(_ drag: DragGesture.Value, cellWidth: CGFloat) {
        guard let id = draggingID, let current = items.firstIndex(where: { $0.id == id }) else { return }
        dragLocation = drag.location

        // `value.location` is already in the grid's coordinate space (slot 0's leading edge is the
        // origin), which is exactly what `insertionIndex` expects: it measures the point from the
        // grid's leading edge and snaps to the nearest cell-midpoint insertion slot. The finger
        // hovering a cell's centre therefore resolves to that cell's slot (taking its place).
        let target = SpringboardLayout.insertionIndex(
            at: drag.location,
            cell: CGSize(width: cellWidth, height: cellHeight),
            spacing: spacing,
            columns: columns,
            count: items.count
        )
        // `insertionIndex` returns a slot in `0...count`; when reinserting the same element the
        // valid destination range is `0...count-1`, and a target past the current index counts the
        // dragged element itself, so clamp to keep `moving` a true reorder rather than a no-op.
        let clamped = min(max(target, 0), items.count - 1)
        guard clamped != current else { return }
        withAnimation(reflowAnimation) {
            items = SpringboardLayout.moving(items, from: current, to: clamped)
        }
    }

    private func endDrag() {
        guard draggingID != nil else { return }
        withAnimation(liftAnimation) { draggingID = nil }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onReorderCommitted()
    }

    // MARK: Geometry

    private func cellWidth(in totalWidth: CGFloat) -> CGFloat {
        guard columns > 0 else { return totalWidth }
        let gaps = spacing * CGFloat(columns - 1)
        return max((totalWidth - gaps) / CGFloat(columns), 0)
    }

    /// Centre point (in grid coordinates) of the slot at flat `index`.
    private func slotCenter(forIndex index: Int, cellWidth: CGFloat) -> CGPoint {
        guard columns > 0 else { return .zero }
        let col = index % columns
        let row = index / columns
        let x = CGFloat(col) * (cellWidth + spacing) + cellWidth / 2
        let y = CGFloat(row) * (cellHeight + spacing) + cellHeight / 2
        return CGPoint(x: x, y: y)
    }

    private var rowCount: Int {
        guard columns > 0 else { return items.isEmpty ? 0 : 1 }
        return (items.count + columns - 1) / columns
    }

    private var gridHeight: CGFloat {
        guard rowCount > 0 else { return 0 }
        return CGFloat(rowCount) * cellHeight + CGFloat(rowCount - 1) * spacing
    }
}
