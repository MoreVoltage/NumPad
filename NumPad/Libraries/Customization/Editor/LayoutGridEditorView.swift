import SwiftUI

/// The grid editor: a live springboard the user can reorder by **long-press-drag** (keys lift and
/// the rest reflow around the finger), add to (palette), and — in **Edit** mode — remove from (⊖
/// badges on non-essential keys). Edits accumulate in a local flat `draftItems`; **Save** is gated
/// (`Monetization.isCustomKeyboardEntitled`) and commits `SpringboardLayout.rebuild(draftItems)`
/// re-chunked to the canonical grid width and `repaired()` so the stored layout always keeps the
/// essential keys (digits 0–9, delete, return).
///
/// The reorder gesture works regardless of Edit mode; Edit mode only reveals the delete badges
/// (essential keys never show one and can't be removed).
struct LayoutGridEditorView: View {
    @ObservedObject var model: LayoutEditorModel
    let layoutID: KeyboardLayout.ID
    let onRequestPaywall: () -> Void
    /// Pops this screen after a successful save (the hosting controller is UIKit-pushed, so
    /// SwiftUI's `dismiss` can't pop it — the coordinator does).
    let onSaved: () -> Void

    /// The flattened working copy. `nil` until `.onAppear` resolves the stored layout (and stays
    /// `nil` when the layout no longer exists, driving the `missingLayout` fallback).
    @State private var draftItems: [KeyDefinition]?
    @State private var editing = false

    private let paletteColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
    private var isEntitled: Bool { Monetization.isCustomKeyboardEntitled }

    /// The stored layout this editor targets, resolved fresh each render (its name drives the title;
    /// its flattened keys are the baseline for the unsaved-changes diff).
    private var storedLayout: KeyboardLayout? {
        model.layouts.first { $0.id == layoutID }
    }

    var body: some View {
        Group {
            if let draftItems, let layout = storedLayout {
                editor(layout, items: draftItems)
            } else {
                missingLayout
            }
        }
        .navigationTitle(storedLayout?.name ?? NSLocalizedString("Layout", comment: "Editor title fallback"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { saveButton } }
        .onAppear { loadIfNeeded() }
    }

    // MARK: Editor

    private func editor(_ layout: KeyboardLayout, items: [KeyDefinition]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                previewSection
                paletteSection
                Text(NSLocalizedString(
                    "Touch and hold a key, then drag to reorder. Tap Edit to remove keys. The digits 0–9, delete, and return are always kept.",
                    comment: "Springboard editor footer hint"))
                    .font(.footnote).foregroundColor(.secondary)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(NSLocalizedString("Preview", comment: "Editor preview header"))
            SpringboardGridView(
                items: draftItemsBinding,
                editing: editing,
                onReorderCommitted: {},
                onDelete: { deleteKey($0) }
            )
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(SwiftUI.Color(.systemGroupedBackground)))
        }
    }

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(NSLocalizedString("Add Key", comment: "Editor add-key header"))
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
            Button { editing.toggle() } label: {
                Label(editing ? NSLocalizedString("Done", comment: "Exit edit mode")
                              : NSLocalizedString("Edit", comment: "Enter edit mode"),
                      systemImage: editing ? "checkmark.circle" : "pencil")
            }
            Spacer()
            if hasUnsavedChanges {
                Text(NSLocalizedString("Unsaved", comment: "Unsaved changes indicator"))
                    .font(.caption).foregroundColor(.secondary)
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
                Text(NSLocalizedString("Save", comment: "Save layout button"))
            }
        }
        .disabled(!hasUnsavedChanges)
    }

    private var missingLayout: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.secondary)
            Text(NSLocalizedString("This layout no longer exists.", comment: "Missing layout fallback"))
                .foregroundColor(.secondary)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption).foregroundColor(.secondary)
    }

    // MARK: State

    /// A non-optional binding into `draftItems` for `SpringboardGridView` (only read inside the
    /// branch where `draftItems != nil`, so the fallback is never exercised).
    private var draftItemsBinding: Binding<[KeyDefinition]> {
        Binding(
            get: { draftItems ?? [] },
            set: { draftItems = $0 }
        )
    }

    private func loadIfNeeded() {
        guard draftItems == nil, let layout = storedLayout else { return }
        draftItems = SpringboardLayout.flatten(layout)
    }

    private var hasUnsavedChanges: Bool {
        guard let draftItems, let layout = storedLayout else { return false }
        return draftItems != SpringboardLayout.flatten(layout)
    }

    // MARK: Edits

    private func addKey(_ token: KeyToken) {
        draftItems = (draftItems ?? []) + [KeyDefinition(primary: token)]
    }

    private func deleteKey(_ key: KeyDefinition) {
        guard !SpringboardLayout.isLocked(key.primary) else { return }
        draftItems = (draftItems ?? []).filter { $0.id != key.id }
    }

    private func save() {
        guard isEntitled else { onRequestPaywall(); return }
        guard let draftItems else { return }
        model.updateLayout(layoutID) { stored in
            KeyboardLayout(id: stored.id, name: stored.name,
                           rows: SpringboardLayout.rebuild(draftItems),
                           keyScale: stored.keyScale,
                           schemaVersion: stored.schemaVersion)
                .repaired()
        }
        onSaved()
    }
}
