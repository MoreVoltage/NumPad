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

/// The right-side keys editor: a live preview of the three remappable slots (Top / Middle /
/// Bottom right) with tap-to-select, and an inline palette that appears below the selected slot
/// so the user can pick what it types — no action sheets or alerts.
///
/// No SwiftUI `NavigationStack`: this view is a hosting-controller island pushed onto the app's
/// existing UIKit navigation stack (see `CustomKeysViewController`), so the nav title stays on the
/// UIKit bar.
///
/// Note: the build-your-own Custom pack row is intentionally not here yet — it returns in a later
/// task. This screen edits only the right-side slots, which stay free (no Pro gate).
struct CustomKeysView: View {
    @StateObject private var model = CustomKeysModel()

    /// The slot whose palette is currently expanded, or `nil` when nothing is selected.
    @State private var selectedSlot: Int?

    /// Whether the inline free-form ("Custom…") `TextField` is revealed below the palette.
    @State private var showingCustomField = false

    /// The in-progress free-form token typed into the inline field (committed on submit/Set).
    @State private var customText = ""

    /// Drives keyboard focus for the inline custom field so revealing it auto-focuses (no second tap).
    @FocusState private var customFieldFocused: Bool

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
}
