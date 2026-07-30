//
//  SizeAndFeelStudioViewController.swift
//  NumPad
//

import UIKit

final class SizeAndFeelStudioViewController: StudioScreenViewController {
    private let writer: StudioSettingsWriter
    private var preview: StudioKeyboardPreviewView?

    init(writer: StudioSettingsWriter = StudioSettingsWriter()) {
        self.writer = writer
        super.init()
    }

    required init?(coder: NSCoder) {
        writer = StudioSettingsWriter()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Size & feel", comment: "Keyboard Studio size title")
        view.accessibilityIdentifier = "studio.size-feel"

        let preview = StudioKeyboardPreviewView(model: .current(idiom: traitCollection.userInterfaceIdiom), palette: palette)
        preview.setCaption(leading: NSLocalizedString("LIVE PREVIEW", comment: "Keyboard Studio preview caption"), trailing: nil)
        preview.accessibilityIdentifier = "studio.size-feel.preview"
        contentStack.addArrangedSubview(preview)
        self.preview = preview

        addHeightChoices()
        addSection(title: NSLocalizedString("FEEL", comment: "Keyboard Studio size section"), rows: [
            toggleRow("Calculator number order", "Show 7, 8, 9 at the top", "arrow.up.arrow.down", isOn: Keyboard.isReversedMode) { [weak self] in
                self?.writer.setReversedMode($0)
                self?.refreshPreview()
            },
            toggleRow("Vibration", "Feel a light tap when you press a key", "waveform", isOn: UserPrefs.hapticsEnabled) { [weak self] in
                self?.writer.setHapticsEnabled($0)
                self?.refreshPreview()
            },
            toggleRow("Key sounds", "Play a click when you press a key", "speaker.wave.2", isOn: UserPrefs.soundEnabled) { [weak self] in
                self?.writer.setSoundEnabled($0)
                self?.refreshPreview()
            },
            toggleRow("Cursor controls", "Use the side keys to move through text", "arrow.left.and.right", isOn: UserPrefs.cursorControls) { [weak self] in
                self?.writer.setCursorControlsEnabled($0)
                self?.refreshPreview()
            }
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshPreview()
    }

    private func addHeightChoices() {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = StudioMetrics.Spacing.s
        section.addArrangedSubview(StudioSectionLabel(text: NSLocalizedString("KEY HEIGHT", comment: "Keyboard Studio height section"), palette: palette))
        let card = StudioCard(palette: palette, surface: .elevated, elevation: .flat)
        card.contentSpacing = StudioMetrics.Spacing.s
        let presets: [KeyboardHeightPreset] = [.small, .regular, .tall] + (traitCollection.userInterfaceIdiom == .pad ? [.kiosk] : [])
        for preset in presets {
            let locked = preset == .kiosk && !Monetization.isKioskHeightEntitled
            let tile = StudioTileView(
                title: preset.name,
                subtitle: heightDescription(for: preset),
                leading: .symbol("rectangle.compress.vertical"),
                isSelected: KeyboardHeightPreset.selected == preset,
                lockText: locked ? NSLocalizedString("Pro", comment: "Locked Kiosk height") : nil,
                palette: palette
            )
            tile.accessibilityIdentifier = "studio.size-feel.height.\(preset.rawValue)"
            tile.onTap = { [weak self] in self?.select(preset, locked: locked) }
            card.addArrangedSubview(tile)
        }
        section.addArrangedSubview(card)
        contentStack.addArrangedSubview(section)
    }

    private func select(_ preset: KeyboardHeightPreset, locked: Bool) {
        guard !locked else {
            let store = StoreViewController()
            store.source = "studio_size_feel_kiosk"
            show(store, sender: self)
            return
        }
        writer.setHeight(preset)
        Analytics.logEvent(name: "keyboard_height", attributes: ["source": "keyboard_studio", "state": preset.rawValue])
        refreshPreview()
    }

    private func heightDescription(for preset: KeyboardHeightPreset) -> String {
        switch preset {
        case .small: return NSLocalizedString("More room above the keyboard", comment: "Keyboard height description")
        case .regular: return NSLocalizedString("A balanced everyday size", comment: "Keyboard height description")
        case .tall: return NSLocalizedString("Larger keys that are easier to see", comment: "Keyboard height description")
        case .kiosk: return NSLocalizedString("Extra-tall keys for shared-use setups", comment: "Keyboard height description")
        }
    }

    private func toggleRow(_ title: String, _ subtitle: String, _ symbol: String, isOn: Bool, action: @escaping (Bool) -> Void) -> StudioRowView {
        let row = StudioRowView(title: NSLocalizedString(title, comment: "Keyboard Studio feel setting"), subtitle: NSLocalizedString(subtitle, comment: "Keyboard Studio feel setting description"), symbolName: symbol, accessory: .toggle(isOn: isOn, onChange: action), palette: palette)
        row.accessibilityIdentifier = "studio.size-feel.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
        return row
    }

    private func refreshPreview() {
        preview?.model = .current(idiom: traitCollection.userInterfaceIdiom)
    }
}
