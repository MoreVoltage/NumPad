import SwiftUI

/// The structured custom-keyboard editor: section switches (Top Row / Column 1 / Column 2), a
/// Left/Right-handed toggle, and a live, tappable preview of the numpad. Tapping a peripheral cell
/// focuses a text field; typing edits the key and pressing return (or picking a function token)
/// auto-advances to the next cell. The fixed numpad (digits, 0, delete, return, 🌐) is shown but
/// never editable.
///
/// A hosted UIKit island (see `CustomKeyboardEditorViewController`) — no `NavigationStack`. Edits
/// write through `CustomKeyboardEditorModel` to the shared store + `SettingsSync`, so a live
/// keyboard updates immediately. Pro-gated: when the user isn't entitled the body is a paywall
/// prompt routed through `onRequestPaywall`.
struct CustomKeyboardEditorView: View {
    @StateObject private var model = CustomKeyboardEditorModel()

    /// Routes to the paywall (Store screen); injected by the host so this island reuses UIKit nav.
    let onRequestPaywall: () -> Void

    @State private var entitled = Monetization.isCustomKeyboardEntitled
    @State private var selectedCell: CustomKeyboardEditorModel.Cell?
    @State private var entryText = ""
    @FocusState private var entryFocused: Bool
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
                if let cell = selectedCell { entrySection(cell) }
            }
        }
        .onAppear { entitled = Monetization.isCustomKeyboardEntitled }
        .onChange(of: scenePhase) { phase in
            if phase == .active { entitled = Monetization.isCustomKeyboardEntitled }
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
            if !on, selectedCell?.section == section { deselect() }
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
            Text(NSLocalizedString("Preview — tap a key to edit", comment: "Header for the interactive custom keyboard preview"))
        }
    }

    private var topRowStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                let keys = model.keys(for: .topRow) ?? []
                ForEach(keys.indices, id: \.self) { i in
                    editableCell(Cell(section: .topRow, index: i))
                }
                if keys.count < model.capacity(.topRow) {
                    addCell(Cell(section: .topRow, index: keys.count))
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
                columnCell(.column2, row: row)
                columnCell(.column1, row: row)
            }
            ForEach(0..<3, id: \.self) { c in
                fixedCap(CustomKeyboardLayout.digitRows[row][c])
            }
            if model.handedness == .right {
                columnCell(.column1, row: row)
                columnCell(.column2, row: row)
            }
        }
    }

    /// One column slot at a number row: an editable key, a "+" add slot for the next free row, or a
    /// clear filler so the column stays aligned with the three digit rows. Nothing when disabled.
    @ViewBuilder
    private func columnCell(_ section: Section, row: Int) -> some View {
        if model.isEnabled(section) {
            let keys = model.keys(for: section) ?? []
            if row < keys.count {
                editableCell(Cell(section: section, index: row))
            } else if row == keys.count && keys.count < model.capacity(section) {
                addCell(Cell(section: section, index: row))
            } else {
                SwiftUI.Color.clear.frame(width: capWidth, height: 46)
            }
        }
    }

    private func editableCell(_ cell: Cell) -> some View {
        Button { select(cell) } label: {
            KeyCapView(label: displayLabel(for: model.key(at: cell)), isSelected: selectedCell == cell)
        }
        .buttonStyle(.plain)
        .frame(width: capWidth)
    }

    private func addCell(_ cell: Cell) -> some View {
        Button { select(cell) } label: {
            KeyCapView(label: "+", isSelected: selectedCell == cell, isDimmed: true)
        }
        .buttonStyle(.plain)
        .frame(width: capWidth)
    }

    private func fixedCap(_ label: String) -> some View {
        KeyCapView(label: label, isDimmed: true).frame(width: capWidth)
    }

    // MARK: Entry

    private func entrySection(_ cell: Cell) -> some View {
        SwiftUI.Section {
            HStack(spacing: 8) {
                TextField(NSLocalizedString("Type a key", comment: "Placeholder for the per-key entry field"), text: $entryText)
                    .focused($entryFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    .onChange(of: entryText) { value in
                        var v = value
                        if !CustomKeys.palette.contains(v), v.count > CustomKeyboardEditorModel.maxKeyLength {
                            v = String(v.prefix(CustomKeyboardEditorModel.maxKeyLength))
                            entryText = v
                        }
                        if v != model.key(at: cell) { model.setKey(v, at: cell) }
                    }
                    .onSubmit { advance(from: cell) }
                if !model.key(at: cell).isEmpty {
                    Button(NSLocalizedString("Clear", comment: "Button that clears the current key")) {
                        model.removeKey(at: cell)
                        entryText = ""
                    }
                    .foregroundColor(.secondary)
                }
                Button(NSLocalizedString("Done", comment: "Button that ends per-key editing")) { deselect() }
            }
            tokenPalette(cell)
        } header: {
            Text(NSLocalizedString("Edit key", comment: "Header for the per-key entry section"))
        } footer: {
            Text(NSLocalizedString("Type 1–4 characters, or pick a function key. Press return to move to the next key.", comment: "Footer explaining per-key entry and auto-advance"))
        }
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

    private func select(_ cell: Cell) {
        selectedCell = cell
        entryText = model.key(at: cell)
        entryFocused = true
    }

    private func deselect() {
        selectedCell = nil
        entryText = ""
        entryFocused = false
    }

    private func advance(from cell: Cell) {
        if let next = model.nextCell(after: cell) {
            select(next)
        } else {
            deselect()
        }
    }

    private func assignToken(_ token: String, to cell: Cell) {
        model.setKey(token, at: cell)
        advance(from: cell)
    }

    // MARK: Labels

    private func displayLabel(for key: String) -> String {
        key.isEmpty ? " " : CustomKeys.displayName(for: key)
    }

    private func sectionName(_ section: Section) -> String {
        switch section {
        case .topRow: return NSLocalizedString("Top Row", comment: "Custom keyboard section name")
        case .column1: return NSLocalizedString("Column 1", comment: "Custom keyboard section name")
        case .column2: return NSLocalizedString("Column 2", comment: "Custom keyboard section name")
        }
    }
}
