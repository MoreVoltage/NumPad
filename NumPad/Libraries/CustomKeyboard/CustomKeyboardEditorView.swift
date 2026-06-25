import SwiftUI

/// The structured custom-keyboard editor: section switches (Top Row / Column 1 / Column 2), a
/// Left/Right-handed toggle, and a live preview of the numpad where **every editable slot is its own
/// text field**. Empty slots show a "+" so it's clear they can be filled; typing writes through to
/// the model immediately (so nothing is lost on navigation), and Return advances to the next slot.
/// Function keys (Space/Tab/←/→/Hide) are assigned from a palette to the selected slot. The fixed
/// numpad (digits, 0, delete, return, 🌐) is shown but never editable.
///
/// A hosted UIKit island (see `CustomKeyboardEditorViewController`) — no `NavigationStack`. Edits
/// write through `CustomKeyboardEditorModel` to the shared store + `SettingsSync`. Pro-gated.
struct CustomKeyboardEditorView: View {
    @StateObject private var model = CustomKeyboardEditorModel()

    /// Routes to the paywall (Store screen); injected by the host so this island reuses UIKit nav.
    let onRequestPaywall: () -> Void

    @State private var entitled = Monetization.isCustomKeyboardEntitled
    @FocusState private var focusedCell: CustomKeyboardEditorModel.Cell?
    /// The last slot that held focus — the target for the function-key palette (which would otherwise
    /// lose the focused field the moment a palette button is tapped).
    @State private var paletteTarget: CustomKeyboardEditorModel.Cell?
    @Environment(\.scenePhase) private var scenePhase

    private typealias Cell = CustomKeyboardEditorModel.Cell
    private typealias Section = CustomKeyboardEditorModel.Section

    private let capWidth: CGFloat = 48
    private let functionTokens = [CustomKeys.spaceToken, CustomKeys.tabToken,
                                  CustomKeys.cursorLeftToken, CustomKeys.cursorRightToken,
                                  CustomKeys.dismissToken]

    var body: some View {
        List {
            if !entitled {
                lockedPrompt
            } else {
                introSection
                sectionsSection
                previewSection
                paletteSection
            }
        }
        .onAppear { entitled = Monetization.isCustomKeyboardEntitled }
        .onChange(of: scenePhase) { phase in
            if phase == .active { entitled = Monetization.isCustomKeyboardEntitled }
        }
        .onChange(of: focusedCell) { cell in
            if let cell = cell { paletteTarget = cell }
        }
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

    // MARK: Intro + handedness

    private var introSection: some View {
        SwiftUI.Section {
            Picker(NSLocalizedString("Handedness", comment: "Left/right-handed picker label"), selection: handednessBinding) {
                ForEach(Handedness.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(NSLocalizedString("Custom Keyboard", comment: "Header for the custom keyboard editor"))
        } footer: {
            Text(NSLocalizedString("Add a top row and up to two side columns around the number pad. The digits, delete, return and 🌐 keys stay fixed.", comment: "Footer explaining the structured custom keyboard"))
        }
    }

    private var handednessBinding: Binding<Handedness> {
        Binding(get: { model.handedness }, set: { model.setHandedness($0) })
    }

    // MARK: Section switches

    private var sectionsSection: some View {
        SwiftUI.Section {
            ForEach(Section.allCases) { section in
                Toggle(sectionName(section), isOn: enabledBinding(section))
            }
        } header: {
            Text(NSLocalizedString("Sections", comment: "Header for the custom keyboard section switches"))
        }
    }

    private func enabledBinding(_ section: Section) -> Binding<Bool> {
        Binding(get: { model.isEnabled(section) }, set: { on in
            model.setEnabled(section, on)
            if !on, focusedCell?.section == section { focusedCell = nil }
            if !on, paletteTarget?.section == section { paletteTarget = nil }
        })
    }

    // MARK: Preview

    private var previewSection: some View {
        SwiftUI.Section {
            VStack(spacing: 6) {
                if model.isEnabled(.topRow) { topRowStrip }
                numpadGrid
            }
            .padding(.vertical, 4)
        } header: {
            Text(NSLocalizedString("Preview — tap a slot to edit", comment: "Header for the interactive custom keyboard preview"))
        } footer: {
            Text(NSLocalizedString("Empty slots show “+”. Type 1–4 characters, then Return to move to the next slot.", comment: "Footer explaining per-slot entry"))
        }
    }

    private var topRowStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<CustomKeyboardEditorModel.topRowCapacity, id: \.self) { i in
                    slotCell(Cell(section: .topRow, index: i))
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var numpadGrid: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                numberRow(row)
            }
            HStack(spacing: 6) {
                fixedCap("next"); fixedCap("0"); fixedCap("⌫"); fixedCap("⏎")
            }
        }
    }

    @ViewBuilder
    private func numberRow(_ row: Int) -> some View {
        HStack(spacing: 6) {
            if model.handedness == .left {
                columnSlot(.column2, row: row)
                columnSlot(.column1, row: row)
            }
            ForEach(0..<3, id: \.self) { c in
                fixedCap(CustomKeyboardLayout.digitRows[row][c])
            }
            if model.handedness == .right {
                columnSlot(.column1, row: row)
                columnSlot(.column2, row: row)
            }
        }
    }

    /// Every row of an enabled column shows a slot (all three capacity slots visible). Nothing when
    /// the column is disabled.
    @ViewBuilder
    private func columnSlot(_ section: Section, row: Int) -> some View {
        if model.isEnabled(section) {
            slotCell(Cell(section: section, index: row))
        }
    }

    /// One editable slot: a text field for an empty/literal key (empty shows a "+"), or a chip for a
    /// function token (tap to clear it back to an editable field).
    @ViewBuilder
    private func slotCell(_ cell: Cell) -> some View {
        let key = model.key(at: cell)
        if functionTokens.contains(key) {
            Button {
                model.setKey("", at: cell)
                focusedCell = cell
            } label: {
                KeyCapView(label: CustomKeys.displayName(for: key), isSelected: focusedCell == cell)
            }
            .buttonStyle(.plain)
            .frame(width: capWidth)
        } else {
            TextField("+", text: binding(for: cell))
                .multilineTextAlignment(.center)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.next)
                .focused($focusedCell, equals: cell)
                .onSubmit { focusedCell = model.nextCell(after: cell) }
                .frame(width: capWidth, height: 46)
                .background(RoundedRectangle(cornerRadius: 8).fill(SwiftUI.Color(.secondarySystemBackground)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(focusedCell == cell ? SwiftUI.Color.accentColor : SwiftUI.Color(.separator),
                                      lineWidth: focusedCell == cell ? 2 : 0.5)
                )
        }
    }

    private func fixedCap(_ label: String) -> some View {
        KeyCapView(label: label, isDimmed: true).frame(width: capWidth)
    }

    /// Writes through to the model on every keystroke (so input is never lost), and reads the model
    /// back so the length cap / token round-trips display correctly.
    private func binding(for cell: Cell) -> Binding<String> {
        Binding(get: { model.key(at: cell) }, set: { model.setKey($0, at: cell) })
    }

    // MARK: Function-key palette

    @ViewBuilder
    private var paletteSection: some View {
        if let cell = paletteTarget, model.isEnabled(cell.section) {
            SwiftUI.Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                    ForEach(functionTokens, id: \.self) { token in
                        Button { assignToken(token, to: cell) } label: {
                            KeyCapView(label: CustomKeys.displayName(for: token), isSelected: model.key(at: cell) == token)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(CustomKeys.displayName(for: token)))
                    }
                }
            } header: {
                Text(NSLocalizedString("Function key for the selected slot", comment: "Header for the function-key palette"))
            }
        }
    }

    private func assignToken(_ token: String, to cell: Cell) {
        model.setKey(token, at: cell)
        focusedCell = model.nextCell(after: cell)
    }

    // MARK: Labels

    private func sectionName(_ section: Section) -> String {
        switch section {
        case .topRow: return NSLocalizedString("Top Row", comment: "Custom keyboard section name")
        case .column1: return NSLocalizedString("Column 1", comment: "Custom keyboard section name")
        case .column2: return NSLocalizedString("Column 2", comment: "Custom keyboard section name")
        }
    }
}
