import SwiftUI
import UIKit

/// The structured custom-keyboard editor — a single screen: a live preview with checkboxes for
/// Row 1 / Column 1 / Column 2, a Key Library of ready-made draggable key chips, and per-slot entry.
/// Handedness is no longer a picker here — it's a nav-bar icon button owned by the hosting
/// `CustomKeyboardEditorViewController` (SwiftUI `.toolbar` content from a *child* hosting controller
/// never reaches the pushed controller's own nav bar), toggled from a shared `model` instance so this
/// view's live preview and the nav-bar icon always agree.
///
/// Per-slot entry uses a **secure** field, which forces iOS to show the system keyboard and blocks
/// third-party keyboards — so the user can type any character instead of being stuck with their own
/// numpad. The field itself is invisible (not just masked): its own text is never shown, in the
/// system keyboard's autofill bar or anywhere else. The typed character is mirrored, in full view
/// (never dots), into the **slot tile** in the preview above in real time — the field is bound
/// directly to the selected slot's model value (no shared entry state), so switching slots or
/// leaving never wipes input.
///
/// A hosted UIKit island (see `CustomKeyboardEditorViewController`, which owns `model` and injects
/// it here). Edits write through `CustomKeyboardEditorModel` to the shared store + `SettingsSync`.
/// Pro-gated.
struct CustomKeyboardEditorView: View {
    @ObservedObject var model: CustomKeyboardEditorModel

    /// Routes to the paywall (Store screen); injected by the host so this island reuses UIKit nav.
    let onRequestPaywall: () -> Void

    @State private var entitled = Monetization.isCustomKeyboardEntitled
    /// Escape hatch (`FeatureFlags.customKeyboardDragReorderEnabled`, default ON) ANDed with a
    /// Remote Config production kill switch (`RemoteConfigManager.customKeyboardDragReorderEnabled`)
    /// — either one turning off reverts the Configure preview to the legacy static tap-to-edit rows
    /// without a code change. Cached in `@State` (not read live) because it's flipped from a
    /// different screen (Store) or remotely (Firebase console), same pattern as `entitled` below.
    @State private var useDragReorder = FeatureFlags.dragReorderActive(
        remoteConfigEnabled: RemoteConfigManager.shared.customKeyboardDragReorderEnabled,
        localFlagEnabled: FeatureFlags.customKeyboardDragReorderEnabled)
    @State private var selectedCell: CustomKeyboardEditorModel.Cell?
    @FocusState private var entryFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    /// The handedness toast's current text, or `nil` when hidden. Driven by `.onChange(of:
    /// model.handedness)` so it fires regardless of whether the toggle came from this view or the
    /// nav-bar button (both mutate the same shared `model`).
    @State private var toastMessage: String?
    @State private var toastDismissWorkItem: DispatchWorkItem?

    private typealias Cell = CustomKeyboardEditorModel.Cell
    private typealias Section = CustomKeyboardEditorModel.Section

    private let capWidth: CGFloat = 48
    /// Matches `KeyCapView`'s own fixed height, so `CustomKeyboardSectionReorderView`'s explicit
    /// compositional-layout cell size lines up with the cap's rendered size exactly.
    private let capHeight: CGFloat = 46
    private let functionTokens = [CustomKeys.spaceToken, CustomKeys.tabToken,
                                  CustomKeys.cursorLeftToken, CustomKeys.cursorRightToken,
                                  CustomKeys.dismissToken]

    var body: some View {
        List {
            if !entitled {
                lockedPrompt
            } else {
                previewSection
                keyLibrarySection
                if let cell = selectedCell { entrySection(cell) }
            }
        }
        .overlay(alignment: .top) { toastOverlay }
        .onAppear { refreshFlags() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { refreshFlags() }
        }
        .onChange(of: model.handedness) { presentHandednessToast($0) }
    }

    // MARK: Pro gate

    private var lockedPrompt: some View {
        SwiftUI.Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill").font(.title3).foregroundColor(.secondary)
                    Text(NSLocalizedString("NumPad Pro unlocks the custom keyboard", comment: "Pitch shown when the structured custom keyboard is locked behind Pro"))
                        .font(.subheadline).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(NSLocalizedString("Unlock with NumPad Pro", comment: "Button that opens the paywall to unlock the custom keyboard")) {
                    onRequestPaywall()
                }
                .font(.body.weight(.semibold))
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Handedness toast (triggered by `.onChange(of: model.handedness)` in `body`)

    @ViewBuilder
    private var toastOverlay: some View {
        if let toastMessage {
            Text(toastMessage)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(SwiftUI.Color.black.opacity(0.85)))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .combine)
        }
    }

    /// Shows the toast for `handedness`, announces it to VoiceOver, and auto-dismisses after 3s.
    /// Cancels any prior pending dismissal so rapid re-toggles don't cut each other off early.
    private func presentHandednessToast(_ handedness: Handedness) {
        let message = handedness.toastMessage
        withAnimation(.easeInOut(duration: 0.25)) { toastMessage = message }
        UIAccessibility.post(notification: .announcement, argument: message)
        toastDismissWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.25)) { toastMessage = nil }
        }
        toastDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    // MARK: Key Library (ready-made draggable key chips)

    @ViewBuilder
    private var keyLibrarySection: some View {
        if CustomKeyboardKeyLibrary.isVisible(dragReorderActive: useDragReorder) {
            SwiftUI.Section {
                CustomKeyboardKeyLibraryView(
                    chips: CustomKeyboardKeyLibrary.chips,
                    capWidth: capWidth,
                    capHeight: capHeight,
                    onTap: { token in
                        guard let cell = selectedCell else { return }
                        assignToken(token, to: cell)
                    }
                )
                .frame(height: 3 * (capHeight + 20))
            } header: {
                Text(NSLocalizedString("Key Library", comment: "Header for the ready-made draggable key chips section in the custom keyboard editor"))
            } footer: {
                Text(NSLocalizedString("Drag a chip into any slot above to assign it. If a slot is selected below, tap a chip to assign it there instead.", comment: "Footer explaining the Key Library palette"))
            }
        }
    }

    // MARK: Preview

    private var previewSection: some View {
        SwiftUI.Section {
            VStack(spacing: 8) {
                HStack { Spacer(); checkbox(NSLocalizedString("Row 1", comment: "Custom keyboard top-row section"), .topRow) }
                if model.isEnabled(.topRow) { topRowStrip }
                columnCheckboxes
                numpadGrid
            }
            .padding(.vertical, 4)
        } header: {
            Text(NSLocalizedString("Preview — tap a slot to edit", comment: "Header for the interactive custom keyboard preview"))
        } footer: {
            Text(NSLocalizedString("Tick Row 1 / Column 1 / Column 2 to add sections. Empty slots show “+”.", comment: "Footer explaining the preview checkboxes"))
        }
    }

    private var columnCheckboxes: some View {
        HStack(spacing: 14) {
            if model.handedness == .left {
                checkbox(NSLocalizedString("Column 2", comment: "Custom keyboard column section"), .column2)
                checkbox(NSLocalizedString("Column 1", comment: "Custom keyboard column section"), .column1)
                Spacer()
            } else {
                Spacer()
                checkbox(NSLocalizedString("Column 1", comment: "Custom keyboard column section"), .column1)
                checkbox(NSLocalizedString("Column 2", comment: "Custom keyboard column section"), .column2)
            }
        }
    }

    private func checkbox(_ label: String, _ section: Section) -> some View {
        Button {
            let on = !model.isEnabled(section)
            model.setEnabled(section, on)
            if !on, selectedCell?.section == section { deselect() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.isEnabled(section) ? "checkmark.square.fill" : "square")
                    .foregroundColor(model.isEnabled(section) ? .accentColor : .secondary)
                Text(label).foregroundColor(.primary)
            }
            .font(.footnote)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.isEnabled(section) ? .isSelected : [])
    }

    /// Top Row strip: drag-reorder (Option B, `CustomKeyboardSectionReorderView`) when the escape
    /// hatch is on, otherwise the legacy static tap-to-edit strip.
    @ViewBuilder
    private var topRowStrip: some View {
        if useDragReorder {
            CustomKeyboardSectionReorderView(
                keys: paddedKeys(for: .topRow),
                axis: .horizontal,
                capWidth: capWidth,
                capHeight: capHeight,
                selectedIndex: selectedIndex(in: .topRow),
                onSelect: { select(Cell(section: .topRow, index: $0)) },
                onMove: { move(.topRow, from: $0, to: $1) },
                onExternalDrop: { assignExternalDrop($0, in: .topRow, at: $1) }
            )
            .frame(height: capHeight + 8)
        } else {
            legacyTopRowStrip
        }
    }

    private var legacyTopRowStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<CustomKeyboardEditorModel.topRowCapacity, id: \.self) { i in
                    slotButton(Cell(section: .topRow, index: i))
                }
            }
            .padding(.horizontal, 2)
        }
    }

    /// The numpad area: drag-reorder columns beside the (always non-interactive, always untouched)
    /// fixed digit grid when the escape hatch is on, otherwise the legacy per-row interleaved
    /// layout. Either way the three digit rows + fixed bottom row are built the same, static way —
    /// this view never makes them part of the editable/draggable model.
    @ViewBuilder
    private var numpadGrid: some View {
        if useDragReorder {
            dragNumpadGrid
        } else {
            legacyNumpadGrid
        }
    }

    private var dragNumpadGrid: some View {
        HStack(alignment: .top, spacing: 6) {
            if model.handedness == .left {
                dragColumnView(.column2)
                dragColumnView(.column1)
            }
            fixedDigitsAndBottomRow
            if model.handedness == .right {
                dragColumnView(.column1)
                dragColumnView(.column2)
            }
        }
    }

    private var fixedDigitsAndBottomRow: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { c in fixedCap(CustomKeyboardLayout.digitRows[row][c]) }
                }
            }
            HStack(spacing: 6) {
                fixedCap("next"); fixedCap("0"); fixedCap("⌫"); fixedCap("⏎")
            }
        }
    }

    @ViewBuilder
    private func dragColumnView(_ section: Section) -> some View {
        if model.isEnabled(section) {
            let rows = CGFloat(CustomKeyboardEditorModel.columnCapacity)
            CustomKeyboardSectionReorderView(
                keys: paddedKeys(for: section),
                axis: .vertical,
                capWidth: capWidth,
                capHeight: capHeight,
                selectedIndex: selectedIndex(in: section),
                onSelect: { select(Cell(section: section, index: $0)) },
                onMove: { move(section, from: $0, to: $1) },
                onExternalDrop: { assignExternalDrop($0, in: section, at: $1) }
            )
            .frame(width: capWidth, height: rows * capHeight + (rows - 1) * 6)
        }
    }

    private var legacyNumpadGrid: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in legacyNumberRow(row) }
            HStack(spacing: 6) {
                fixedCap("next"); fixedCap("0"); fixedCap("⌫"); fixedCap("⏎")
            }
        }
    }

    @ViewBuilder
    private func legacyNumberRow(_ row: Int) -> some View {
        HStack(spacing: 6) {
            if model.handedness == .left {
                legacyColumnSlot(.column2, row: row)
                legacyColumnSlot(.column1, row: row)
            }
            ForEach(0..<3, id: \.self) { c in
                fixedCap(CustomKeyboardLayout.digitRows[row][c])
            }
            if model.handedness == .right {
                legacyColumnSlot(.column1, row: row)
                legacyColumnSlot(.column2, row: row)
            }
        }
    }

    /// All three slots of an enabled column are shown (empty ones as "+"); nothing when disabled.
    @ViewBuilder
    private func legacyColumnSlot(_ section: Section, row: Int) -> some View {
        if model.isEnabled(section) {
            slotButton(Cell(section: section, index: row))
        }
    }

    /// `selectedCell`, restricted to `section` and expressed as a plain index for
    /// `CustomKeyboardSectionReorderView` (which knows nothing about `Cell`/other sections).
    private func selectedIndex(in section: Section) -> Int? {
        selectedCell?.section == section ? selectedCell?.index : nil
    }

    /// Every slot of `section` up to its full capacity (unfilled trailing slots as "" — the "+"
    /// placeholder), so the drag view always has a real index for every visible cap, matching the
    /// legacy strip's behavior of always showing a fixed number of slots.
    private func paddedKeys(for section: Section) -> [String] {
        let cap = model.capacity(section)
        return (0..<cap).map { model.key(at: Cell(section: section, index: $0)) }
    }

    /// A completed drag reorder: apply it, then deselect — the currently-open secure field was
    /// addressing a *position*, not the key that just moved out from under it (same caution the
    /// section checkbox already takes when disabling a section out from under a selection).
    private func move(_ section: Section, from source: Int, to destination: Int) {
        model.moveKey(in: section, from: source, to: destination)
        deselect()
    }

    /// A Key Library chip dropped onto `section` at `index` — a plain assignment (not a reorder), so
    /// unlike `move` there's no prior selection to invalidate; if the changed slot happens to be the
    /// one currently selected, its entry field simply reflects the new value on its next render.
    private func assignExternalDrop(_ token: String, in section: Section, at index: Int) {
        model.setKey(token, at: Cell(section: section, index: index))
    }

    /// A display slot: shows the key (or "+" when empty). Tapping selects it for entry; the actual
    /// typing happens in the secure field below so the character is visible here (not masked).
    private func slotButton(_ cell: Cell) -> some View {
        Button { select(cell) } label: {
            KeyCapView(label: displayLabel(for: model.key(at: cell)), isSelected: selectedCell == cell)
        }
        .buttonStyle(.plain)
        .frame(width: capWidth)
    }

    private func fixedCap(_ label: String) -> some View {
        KeyCapView(label: label, isDimmed: true).frame(width: capWidth)
    }

    // MARK: Entry (secure → forces the system keyboard)

    private func entrySection(_ cell: Cell) -> some View {
        SwiftUI.Section {
            HStack(spacing: 8) {
                Text(NSLocalizedString("Type on your keyboard — it appears on the slot above.", comment: "Inline hint shown while a custom keyboard slot is selected for entry"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer(minLength: 8)
                if !model.key(at: cell).isEmpty {
                    Button(NSLocalizedString("Clear", comment: "Button that clears the current slot")) {
                        model.setKey("", at: cell)
                    }
                    .foregroundColor(.secondary)
                }
                Button(NSLocalizedString("Done", comment: "Button that ends per-slot editing")) { deselect() }
            }
            // The actual input surface: a secure field so iOS shows the system keyboard and blocks
            // third-party keyboards, but it is never shown to the user — not even masked. It's
            // shrunk to a single point and hidden from the accessibility tree; the live keystrokes
            // are mirrored, in full view, into the slot tile above via `binding(for:)`.
            SecureField("", text: binding(for: cell))
                .focused($entryFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)
                .submitLabel(.next)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { advance(from: cell) }
            tokenPalette(cell)
        } header: {
            Text(NSLocalizedString("Edit slot", comment: "Header for the per-slot entry controls"))
        } footer: {
            Text(NSLocalizedString("What you type appears on the slot above, in full — nothing is hidden. Return moves to the next slot.", comment: "Footer explaining the per-slot entry controls"))
        }
    }

    /// Writes through to the model on every keystroke and reads it back, so the preview slot updates
    /// live and the length cap / token round-trips display correctly.
    private func binding(for cell: Cell) -> Binding<String> {
        Binding(get: { model.key(at: cell) }, set: { model.setKey($0, at: cell) })
    }

    private func tokenPalette(_ cell: Cell) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
            ForEach(functionTokens, id: \.self) { token in
                Button { assignToken(token, to: cell) } label: {
                    KeyCapView(label: CustomKeys.displayName(for: token), isSelected: model.key(at: cell) == token)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(CustomKeys.displayName(for: token)))
            }
        }
    }

    // MARK: Actions

    private func refreshFlags() {
        entitled = Monetization.isCustomKeyboardEntitled
        useDragReorder = FeatureFlags.dragReorderActive(
            remoteConfigEnabled: RemoteConfigManager.shared.customKeyboardDragReorderEnabled,
            localFlagEnabled: FeatureFlags.customKeyboardDragReorderEnabled)
    }

    private func select(_ cell: Cell) {
        selectedCell = cell
        entryFocused = true
    }

    private func deselect() {
        selectedCell = nil
        entryFocused = false
    }

    private func advance(from cell: Cell) {
        if let next = model.nextCell(after: cell) {
            selectedCell = next
            entryFocused = true
        } else {
            deselect()
        }
    }

    private func assignToken(_ token: String, to cell: Cell) {
        model.setKey(token, at: cell)
        advance(from: cell)
    }

    private func displayLabel(for key: String) -> String {
        key.isEmpty ? "+" : CustomKeys.displayName(for: key)
    }
}
