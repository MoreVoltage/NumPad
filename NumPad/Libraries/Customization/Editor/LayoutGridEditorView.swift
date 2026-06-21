import SwiftUI

/// The grid editor: a live numpad preview the user can reorder (drag), add to (palette), and
/// remove from (tap-to-select, then Remove). Edits accumulate in a local `draft`; **Save** is
/// gated and commits `draft.repaired()` so the stored layout always keeps the essential keys.
///
/// Gesture split (so the two long-press gestures don't collide): a *tap* selects a key, a
/// *long-press drag* reorders it, and a separate Remove button deletes the selection.
struct LayoutGridEditorView: View {
    @ObservedObject var model: LayoutEditorModel
    let layoutID: KeyboardLayout.ID
    let onRequestPaywall: () -> Void
    /// Pops this screen after a successful save (the hosting controller is UIKit-pushed, so
    /// SwiftUI's `dismiss` can't pop it — the coordinator does).
    let onSaved: () -> Void

    @State private var draft: KeyboardLayout?
    @State private var selectedID: KeyDefinition.ID?

    private let paletteColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
    private var isEntitled: Bool { Monetization.isCustomKeyboardEntitled }

    var body: some View {
        Group {
            if let draft { editor(draft) } else { missingLayout }
        }
        .navigationTitle(draft?.name ?? "Layout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { saveButton } }
        .onAppear { if draft == nil { draft = model.layouts.first { $0.id == layoutID } } }
    }

    // MARK: Editor

    private func editor(_ layout: KeyboardLayout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                previewSection(layout)
                paletteSection
                Text("Drag keys to reorder. Tap a key to select it, then Remove. The digits 0–9, delete, and return are always kept.")
                    .font(.footnote).foregroundColor(.secondary)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    private func previewSection(_ layout: KeyboardLayout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Preview")
            VStack(spacing: 6) {
                ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 6) {
                        if row.isEmpty {
                            SwiftUI.Color.clear.frame(height: 46)
                        } else {
                            ForEach(row) { key in keyCap(key) }
                        }
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(SwiftUI.Color(.systemGroupedBackground)))
        }
    }

    private func keyCap(_ key: KeyDefinition) -> some View {
        KeyCapView(label: key.label ?? key.primary.displayLabel, isSelected: selectedID == key.id)
            .onTapGesture { selectedID = (selectedID == key.id) ? nil : key.id }
            .draggable(key.id.uuidString)
            .dropDestination(for: String.self) { items, _ in
                guard let raw = items.first, let dragged = UUID(uuidString: raw) else { return false }
                draft = draft?.reordering(dragged, before: key.id)
                return true
            }
    }

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Add Key")
            LazyVGrid(columns: paletteColumns, spacing: 6) {
                ForEach(Array(KeyTokenPalette.tokens.enumerated()), id: \.offset) { _, token in
                    Button { addKey(token) } label: { KeyCapView(label: token.displayLabel) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Bars

    private var bottomBar: some View {
        HStack {
            Button(role: .destructive) { removeSelected() } label: {
                Label("Remove Key", systemImage: "trash")
            }
            .disabled(selectedID == nil)
            Spacer()
            if hasUnsavedChanges {
                Text("Unsaved").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 4) {
                if !isEntitled { Image(systemName: "lock.fill").font(.caption) }
                Text("Save")
            }
        }
        .disabled(!hasUnsavedChanges)
    }

    private var missingLayout: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.secondary)
            Text("This layout no longer exists.").foregroundColor(.secondary)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption).foregroundColor(.secondary)
    }

    // MARK: Edits

    private var hasUnsavedChanges: Bool {
        guard let draft, let stored = model.layouts.first(where: { $0.id == layoutID }) else { return false }
        return draft != stored
    }

    private func addKey(_ token: KeyToken) {
        draft = draft?.appendingKey(KeyDefinition(primary: token))
    }

    private func removeSelected() {
        guard let id = selectedID else { return }
        draft = draft?.removingKey(id)
        selectedID = nil
    }

    private func save() {
        guard isEntitled else { onRequestPaywall(); return }
        guard let draft else { return }
        model.updateLayout(layoutID) { _ in draft.repaired() }
        onSaved()
    }
}
