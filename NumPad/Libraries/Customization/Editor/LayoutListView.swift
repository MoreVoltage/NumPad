import SwiftUI

/// The layouts list: create / rename / delete / set-active named layouts, and open the grid
/// editor (via `onOpenLayout`, fulfilled by the UIKit coordinator). "Activate" is gated — it
/// routes to the paywall when the user isn't entitled.
///
/// No SwiftUI `NavigationStack`: this view is a hosting-controller island pushed onto the app's
/// existing UIKit navigation stack, so `.navigationTitle`/`.toolbar` bridge to the UIKit bar.
struct LayoutListView: View {
    @ObservedObject var model: LayoutEditorModel
    let onOpenLayout: (KeyboardLayout.ID) -> Void
    let onRequestPaywall: () -> Void

    @State private var showingCreate = false
    @State private var createName = ""
    @State private var renamingID: KeyboardLayout.ID?
    @State private var renameText = ""

    private var isEntitled: Bool { Monetization.isCustomKeyboardEntitled }

    var body: some View {
        Group {
            if model.layouts.isEmpty { emptyState } else { layoutList }
        }
        .navigationTitle("Custom Keyboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { createName = ""; showingCreate = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text("New Layout"))
            }
        }
        .alert("New Layout", isPresented: $showingCreate) {
            TextField("Name", text: $createName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { create() }
        } message: {
            Text("Starts from a copy of the standard numpad.")
        }
        .alert("Rename Layout",
               isPresented: Binding(get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") { commitRename() }
        }
    }

    private var layoutList: some View {
        List {
            Section {
                ForEach(model.layouts) { layout in
                    Button { onOpenLayout(layout.id) } label: { row(layout) }
                        .buttonStyle(.plain)
                        .contextMenu { menuActions(for: layout) }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) { activateAction(layout) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { model.delete(layout.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { startRename(layout) } label: {
                                Label("Rename", systemImage: "pencil")
                            }.tint(.blue)
                        }
                }
            } footer: {
                Text("Swipe right to activate, left to rename or delete. Activating a layout replaces the standard numpad on your keyboard. The Default layout matches the built-in numpad.")
            }
        }
    }

    private func row(_ layout: KeyboardLayout) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(layout.name).foregroundColor(.primary)
                Text("\(keyCount(layout)) keys").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if model.activeID == layout.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .accessibilityLabel(Text("Active"))
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(SwiftUI.Color(.tertiaryLabel))
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder private func menuActions(for layout: KeyboardLayout) -> some View {
        if model.activeID == layout.id {
            Button { model.activate(nil) } label: { Label("Deactivate", systemImage: "xmark.circle") }
        } else {
            activateAction(layout)
        }
        Button { startRename(layout) } label: { Label("Rename", systemImage: "pencil") }
        Button(role: .destructive) { model.delete(layout.id) } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder private func activateAction(_ layout: KeyboardLayout) -> some View {
        Button { setActive(layout) } label: {
            Label(isEntitled ? "Activate" : "Activate (Pro)",
                  systemImage: isEntitled ? "checkmark.circle" : "lock.fill")
        }.tint(.green)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "keyboard").font(.largeTitle).foregroundColor(.secondary)
            Text("No Custom Layouts").font(.headline)
            Text("Tap + to create one from the standard numpad.")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }.padding()
    }

    private func keyCount(_ layout: KeyboardLayout) -> Int { layout.rows.reduce(0) { $0 + $1.count } }

    private func setActive(_ layout: KeyboardLayout) {
        guard isEntitled else { onRequestPaywall(); return }
        model.activate(layout.id)
    }

    private func create() {
        let name = createName.trimmingCharacters(in: .whitespacesAndNewlines)
        model.createLayout(named: name.isEmpty ? "Untitled" : name)
    }

    private func startRename(_ layout: KeyboardLayout) {
        renamingID = layout.id
        renameText = layout.name
    }

    private func commitRename() {
        guard let id = renamingID else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { model.rename(id, to: name) }
        renamingID = nil
    }
}
