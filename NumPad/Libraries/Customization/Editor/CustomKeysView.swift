import SwiftUI

/// Observable model for the three remappable right-side key slots (`CustomKeys.slots`).
///
/// Holds an immutable snapshot of the slots in `@Published var slots`; `assign(token:toSlot:)`
/// produces a *new* array (never mutates in place), writes it through to the shared
/// `CustomKeys.slots` UserDefault, and posts a `SettingsSync` Darwin notification so a live
/// keyboard extension re-reads the slots immediately — the same mechanism the layout editor uses.
final class CustomKeysModel: ObservableObject {
    @Published private(set) var slots: [String]

    init() {
        // `CustomKeys.slots` always returns exactly `slotCount` padded tokens.
        slots = CustomKeys.slots
    }

    /// Assigns `token` to `slot`, persisting the change and notifying the keyboard.
    /// No-ops for an out-of-range slot. Immutable-update style: builds a new array.
    func assign(token: String, toSlot slot: Int) {
        guard slots.indices.contains(slot) else { return }
        var updated = slots
        updated[slot] = token
        slots = updated
        CustomKeys.slots = updated
        SettingsSync.post()
        Analytics.logEvent(name: "custom_key_slot", attributes: ["slot": slot, Analytics.ParameterValue: token])
    }
}

/// Observable model for the user-built Custom pack row (`CustomPackManager.shared.keys`).
///
/// Holds an immutable snapshot of the keys in `@Published var keys`; every mutation routes through
/// `CustomPackManager` (which owns sanitization, de-duping, the `maxKeys`/`maxKeyLength` caps, and
/// the read-modify-write lock), then re-reads the canonical array back into `keys`, posts a
/// `SettingsSync` Darwin notification so a live keyboard extension re-reads the pack immediately,
/// and logs the matching analytics event — mirroring `CustomKeysModel` for the right-side slots.
final class CustomPackModel: ObservableObject {
    @Published private(set) var keys: [String]

    private let manager = CustomPackManager.shared

    init() {
        keys = manager.keys
    }

    /// Whether another key can still be added (the pack is below `CustomPackManager.maxKeys`).
    var canAddKey: Bool { keys.count < CustomPackManager.maxKeys }

    /// Adds `text` (trimmed, capped at `maxKeyLength`, de-duped) to the end of the row.
    /// Delegates the sanitization/cap to the manager; refreshes the published snapshot afterward.
    func add(_ text: String) {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(CustomPackManager.maxKeyLength))
        guard !trimmed.isEmpty else { return }
        manager.add(trimmed)
        keys = manager.keys
        SettingsSync.post()
        Analytics.logEvent(name: "custom_pack_add_key", attributes: [Analytics.ParameterValue: trimmed])
    }

    /// Removes the key at `index` (no-op when out of range), then refreshes the snapshot.
    func remove(at index: Int) {
        guard keys.indices.contains(index) else { return }
        manager.remove(at: index)
        keys = manager.keys
        SettingsSync.post()
        Analytics.logEvent(name: "custom_pack_remove_key", attributes: ["index": index])
    }

    /// Handles a SwiftUI `.onMove`: maps the source `IndexSet`/destination to the manager's
    /// `move(from:to:)`. `.onMove` hands a destination that can equal `count` (drop past the end);
    /// the manager only accepts in-range indices, so clamp before delegating, then refresh.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard let from = source.first else { return }
        var to = destination
        if to > from { to -= 1 } // SwiftUI's post-removal insertion index → manager's in-array index
        to = min(max(to, 0), keys.count - 1)
        guard from != to else { return }
        manager.move(from: from, to: to)
        keys = manager.keys
        SettingsSync.post()
    }
}

/// The right-side keys editor: a live preview of the three remappable slots (Top / Middle /
/// Bottom right) with tap-to-select, and an inline palette that appears below the selected slot
/// so the user can pick what it types — no action sheets or alerts.
///
/// No SwiftUI `NavigationStack`: this view is a hosting-controller island pushed onto the app's
/// existing UIKit navigation stack (see `CustomKeysViewController`), so the nav title stays on the
/// UIKit bar.
///
/// Two sections: the free right-side slots editor (top), and the Pro-gated build-your-own Custom
/// pack row (bottom). When the Custom pack is locked the second section shows a paywall prompt that
/// calls `onRequestPaywall`; the host (`CustomKeysViewController`) routes that to the Store screen.
struct CustomKeysView: View {
    @StateObject private var model = CustomKeysModel()
    @StateObject private var packModel = CustomPackModel()

    /// Routes to the paywall (Store screen) when the locked Custom-pack prompt's button is tapped.
    /// Injected by `CustomKeysViewController` so this island reuses the app's UIKit navigation.
    let onRequestPaywall: () -> Void

    /// The slot whose palette is currently expanded, or `nil` when nothing is selected.
    @State private var selectedSlot: Int?

    /// Whether the inline free-form ("Custom…") `TextField` is revealed below the palette.
    @State private var showingCustomField = false

    /// The in-progress free-form token typed into the inline field (committed on submit/Set).
    @State private var customText = ""

    /// Drives keyboard focus for the inline custom field so revealing it auto-focuses (no second tap).
    @FocusState private var customFieldFocused: Bool

    /// Whether the Custom pack is currently Pro-locked. Cached in `@State` (rather than read inline)
    /// so the section flips to the editor the moment the user returns entitled from the paywall —
    /// refreshed on appear and on foreground (see `refreshLock()`).
    @State private var isCustomPackLocked = Monetization.isLocked(pack: .custom)

    /// The in-progress key typed into the Custom-pack "add" field (committed on submit/Set).
    @State private var newKeyText = ""

    /// Drives keyboard focus for the Custom-pack add field.
    @FocusState private var newKeyFieldFocused: Bool

    /// Foreground transitions re-read the lock so a Pro purchase made on the pushed Store screen is
    /// reflected when the user pops back here (belt-and-braces alongside `.onAppear`).
    @Environment(\.scenePhase) private var scenePhase

    private let paletteColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        List {
            Section {
                slotsPreview
                if let slot = selectedSlot {
                    palette(forSlot: slot)
                }
            } header: {
                Text(NSLocalizedString("Right-Side Keys", comment: "Header for the remappable key slots section"))
            } footer: {
                Text(NSLocalizedString("These keys sit to the right of the number grid. Tap one, then pick what it types. Assign Tab to jump between cells in spreadsheets.", comment: "Footer explaining the remappable key slots"))
            }

            customPackSection
        }
        .onAppear { refreshLock() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { refreshLock() }
        }
    }

    // MARK: Preview

    /// A vertical Top / Middle / Bottom column mirroring the keyboard's right edge.
    private var slotsPreview: some View {
        VStack(spacing: 10) {
            ForEach(model.slots.indices, id: \.self) { slot in
                slotRow(slot)
            }
        }
        .padding(.vertical, 4)
    }

    private func slotRow(_ slot: Int) -> some View {
        HStack(spacing: 12) {
            Text(slotName(for: slot))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Button { toggleSelection(slot) } label: {
                KeyCapView(label: CustomKeys.displayName(for: model.slots[slot]),
                           isSelected: selectedSlot == slot)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(slotName(for: slot)))
            .accessibilityValue(Text(CustomKeys.displayName(for: model.slots[slot])))
        }
    }

    // MARK: Palette

    @ViewBuilder
    private func palette(forSlot slot: Int) -> some View {
        // Guard against a slot index that no longer exists (Task 4.3 makes this screen more
        // dynamic). Today the slot count is fixed, but reading `model.slots[slot]` below must
        // only happen when `slot` is in range.
        if model.slots.indices.contains(slot) {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Pick what this key types", comment: "Header above the inline palette of key tokens"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                LazyVGrid(columns: paletteColumns, spacing: 6) {
                    ForEach(Array(CustomKeys.palette.enumerated()), id: \.offset) { _, token in
                        Button { assign(token: token, toSlot: slot) } label: {
                            KeyCapView(label: CustomKeys.displayName(for: token),
                                       isSelected: model.slots[slot] == token)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(CustomKeys.displayName(for: token)))
                        .accessibilityAddTraits(model.slots[slot] == token ? .isSelected : [])
                    }
                    // Free-form entry: reveals an inline TextField for an arbitrary token (≤ 4 chars).
                    Button { toggleCustomField() } label: {
                        KeyCapView(label: NSLocalizedString("Custom…", comment: "Palette chip that reveals an inline field for typing a custom key token"),
                                   isSelected: showingCustomField)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(NSLocalizedString("Custom key", comment: "Accessibility label for the chip that reveals the custom key text field")))
                    .accessibilityAddTraits(showingCustomField ? .isSelected : [])
                }
                if showingCustomField {
                    customField(forSlot: slot)
                }
            }
            .padding(.top, 4)
        }
    }

    /// The inline free-form token field, shown beneath the palette when "Custom…" is tapped.
    /// Commits on the return key or the "Set" button; no `UIAlertController`/sheet involved.
    private func customField(forSlot slot: Int) -> some View {
        HStack(spacing: 8) {
            TextField(NSLocalizedString("Up to 4 characters", comment: "Placeholder for the inline custom key text field"),
                      text: $customText)
                .textFieldStyle(.roundedBorder)
                .focused($customFieldFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit { commitCustomText(toSlot: slot) }
                .accessibilityLabel(Text(NSLocalizedString("Custom key text", comment: "Accessibility label for the inline custom key text field")))
            Button(NSLocalizedString("Set", comment: "Button that assigns the typed custom key to the selected slot")) {
                commitCustomText(toSlot: slot)
            }
            .disabled(customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.top, 4)
    }

    // MARK: Helpers

    private func slotName(for slot: Int) -> String {
        switch slot {
        case 0: return NSLocalizedString("Top Right", comment: "Label for the top remappable key slot")
        case 1: return NSLocalizedString("Middle Right", comment: "Label for the middle remappable key slot")
        default: return NSLocalizedString("Bottom Right", comment: "Label for the bottom remappable key slot")
        }
    }

    private func toggleSelection(_ slot: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedSlot = (selectedSlot == slot) ? nil : slot
            // Collapse and clear any in-progress free-form entry so a stale value can't leak
            // when switching to (or re-opening) a different slot's palette.
            resetCustomField()
        }
    }

    /// Reveals or hides the inline free-form field. Clears the text whenever it hides so the
    /// next reveal starts empty.
    private func toggleCustomField() {
        if showingCustomField {
            withAnimation(.easeInOut(duration: 0.2)) {
                resetCustomField()
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingCustomField = true
            }
            // Focus after the field is in the view tree so the keyboard comes up on reveal
            // (a single tap). A plain assignment — focus changes shouldn't be animated.
            customFieldFocused = true
        }
    }

    /// Sanitizes and assigns the typed token to `slot`. Trims whitespace, caps at
    /// `CustomKeys.maxTokenLength`, and assigns only when non-empty (reusing the model's
    /// write-through + SettingsSync + analytics). Always hides and clears the field afterward.
    private func commitCustomText(toSlot slot: Int) {
        let trimmed = String(customText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(CustomKeys.maxTokenLength))
        if !trimmed.isEmpty {
            model.assign(token: trimmed, toSlot: slot)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            resetCustomField()
        }
    }

    /// Collapses the inline field and clears its text. Call inside an animation block.
    private func resetCustomField() {
        showingCustomField = false
        customText = ""
        // Release focus so dismiss/commit/slot-switch lowers the keyboard cleanly.
        customFieldFocused = false
    }

    private func assign(token: String, toSlot slot: Int) {
        model.assign(token: token, toSlot: slot)
    }

    // MARK: Custom Pack section

    /// The build-your-own Custom pack row. Pro-gated: shows a paywall prompt when locked, otherwise
    /// the editor (current keys as deletable/reorderable rows + an inline add field).
    @ViewBuilder
    private var customPackSection: some View {
        Section {
            if isCustomPackLocked {
                customPackLockedPrompt
            } else {
                customPackEditor
            }
        } header: {
            Text(NSLocalizedString("Custom Pack", comment: "Header for the build-your-own custom pack row editor"))
        } footer: {
            Text(NSLocalizedString("Build your own key row — up to 10 keys, 4 characters each.", comment: "Footer explaining the custom pack row editor"))
        }
    }

    // MARK: Custom Pack — locked (Pro) prompt

    /// Shown in place of the editor when the Custom pack is locked. A lock glyph, a short pitch, and
    /// a button that routes to the paywall via `onRequestPaywall`.
    private var customPackLockedPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("NumPad Pro unlocks the custom pack", comment: "Pitch shown when the build-your-own custom pack is locked behind Pro"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(NSLocalizedString("Unlock with NumPad Pro", comment: "Button that opens the paywall to unlock the custom pack")) {
                onRequestPaywall()
            }
            .font(.body.weight(.semibold))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: Custom Pack — editor

    /// The unlocked editor: each existing key as a `KeyCapView` row (swipe-to-delete + drag-reorder),
    /// followed by an inline add field. Rows live directly in the enclosing `List` `Section` so the
    /// `.onDelete`/`.onMove` editing affordances work without nesting a second `List`.
    @ViewBuilder
    private var customPackEditor: some View {
        ForEach(Array(packModel.keys.enumerated()), id: \.offset) { index, key in
            keyRow(key, at: index)
        }
        .onDelete { offsets in
            // SwiftUI hands an IndexSet; the model removes one key per offset (single-row deletes
            // here, but handle the set defensively). Remove high→low so earlier indices stay valid.
            for index in offsets.sorted(by: >) {
                packModel.remove(at: index)
            }
        }
        .onMove { source, destination in
            packModel.move(fromOffsets: source, toOffset: destination)
        }

        if packModel.canAddKey {
            addKeyRow
        }
    }

    /// A single existing-key row: its 1-based position and the key rendered as a `KeyCapView`.
    private func keyRow(_ key: String, at index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .leading)
                .accessibilityHidden(true)
            KeyCapView(label: key)
                .frame(maxWidth: 80)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String.localizedStringWithFormat(
            NSLocalizedString("Custom key %1$d: %2$@", comment: "Accessibility label for a custom pack key row: its position and value"),
            index + 1, key)))
    }

    /// The inline "add key" field at the bottom of the editor. Caps input at `maxKeyLength`,
    /// commits on the return key or the "Add" button, and clears afterward. Hidden once the pack
    /// reaches `maxKeys` (see `customPackEditor`).
    private var addKeyRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            TextField(NSLocalizedString("Add a key (up to 4 characters)", comment: "Placeholder for the custom pack add-key field"),
                      text: $newKeyText)
                .focused($newKeyFieldFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onChange(of: newKeyText) { value in
                    // Hard-cap the field so the user can't type past the key length.
                    if value.count > CustomPackManager.maxKeyLength {
                        newKeyText = String(value.prefix(CustomPackManager.maxKeyLength))
                    }
                }
                .onSubmit { commitNewKey() }
                .accessibilityLabel(Text(NSLocalizedString("New custom key", comment: "Accessibility label for the custom pack add-key text field")))
            Button(NSLocalizedString("Add", comment: "Button that adds the typed key to the custom pack")) {
                commitNewKey()
            }
            .disabled(newKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    /// Adds the typed key (when non-empty) through the model, then clears and re-focuses the field
    /// so several keys can be added in a row without re-tapping it.
    private func commitNewKey() {
        let trimmed = newKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        packModel.add(trimmed)
        newKeyText = ""
        // Keep focus only while there's still room; otherwise the field disappears (lower keyboard).
        newKeyFieldFocused = packModel.canAddKey
    }

    /// Re-reads the Pro lock for the Custom pack into `@State`. Called on appear and on foreground so
    /// a purchase completed on the pushed Store screen flips this section to the editor on return.
    private func refreshLock() {
        let locked = Monetization.isLocked(pack: .custom)
        if locked != isCustomPackLocked {
            isCustomPackLocked = locked
        }
    }
}
