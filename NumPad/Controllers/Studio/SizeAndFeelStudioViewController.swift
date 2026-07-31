//
//  SizeAndFeelStudioViewController.swift
//  NumPad
//

import UIKit

final class SizeAndFeelStudioViewController: StudioScreenViewController {
    private let writer: StudioSettingsWriter
    private let storedHeight: () -> KeyboardHeightPreset
    private let kioskEntitled: () -> Bool
    private let heightChoices: [KeyboardHeightPreset]?
    private var preview: StudioKeyboardPreviewView?
    private var heightTiles: [KeyboardHeightPreset: StudioTileView] = [:]
    private var widthTiles: [NumpadWidthSize: StudioTileView] = [:]

    init(
        writer: StudioSettingsWriter = StudioSettingsWriter(),
        storedHeight: @escaping () -> KeyboardHeightPreset = { KeyboardHeightPreset.selected },
        kioskEntitled: @escaping () -> Bool = { Monetization.isKioskHeightEntitled },
        heightChoices: [KeyboardHeightPreset]? = nil
    ) {
        self.writer = writer
        self.storedHeight = storedHeight
        self.kioskEntitled = kioskEntitled
        self.heightChoices = heightChoices
        super.init()
    }

    required init?(coder: NSCoder) {
        writer = StudioSettingsWriter()
        storedHeight = { KeyboardHeightPreset.selected }
        kioskEntitled = { Monetization.isKioskHeightEntitled }
        heightChoices = nil
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

        if traitCollection.userInterfaceIdiom == .pad { addWidthChoices() }
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
        if traitCollection.userInterfaceIdiom == .pad { StudioPreviewContext.request(.numpad) }
        refreshPreview()
        refreshWidthSelection()
        refreshHeightSelection()
    }

    private func addWidthChoices() {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = StudioMetrics.Spacing.s
        section.addArrangedSubview(StudioSectionLabel(
            text: NSLocalizedString("NUMPAD WIDTH", comment: "Keyboard Studio numpad width section"),
            palette: palette
        ))
        let card = StudioCard(palette: palette, surface: .elevated, elevation: .flat)
        card.contentSpacing = StudioMetrics.Spacing.s
        for width in NumpadWidthSize.allCases {
            let percentage = String(format: "%.0f%%", width.fraction * 100)
            let tile = StudioTileView(
                title: width.studioDisplayName,
                subtitle: percentage,
                leading: .symbol("arrow.left.and.right"),
                isSelected: false,
                palette: palette
            )
            tile.accessibilityIdentifier = "studio.size-feel.width.\(width.rawValue)"
            tile.accessibilityValue = percentage
            tile.onTap = { [weak self] in self?.select(width) }
            widthTiles[width] = tile
            card.addArrangedSubview(tile)
        }
        section.addArrangedSubview(card)
        contentStack.addArrangedSubview(section)
        refreshWidthSelection()
    }

    private func addHeightChoices() {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = StudioMetrics.Spacing.s
        section.addArrangedSubview(StudioSectionLabel(text: NSLocalizedString("KEY HEIGHT", comment: "Keyboard Studio height section"), palette: palette))
        let card = StudioCard(palette: palette, surface: .elevated, elevation: .flat)
        card.contentSpacing = StudioMetrics.Spacing.s
        let presets = heightChoices ?? ([.small, .regular, .tall] + (traitCollection.userInterfaceIdiom == .pad ? [.kiosk] : []))
        for preset in presets {
            let locked = preset == .kiosk && !kioskEntitled()
            let tile = StudioTileView(
                title: preset.name,
                subtitle: heightDescription(for: preset),
                leading: .symbol("rectangle.compress.vertical"),
                isSelected: false,
                lockText: locked ? NSLocalizedString("Pro", comment: "Locked Kiosk height") : nil,
                palette: palette
            )
            tile.accessibilityIdentifier = "studio.size-feel.height.\(preset.rawValue)"
            tile.onTap = { [weak self] in self?.select(preset) }
            heightTiles[preset] = tile
            card.addArrangedSubview(tile)
        }
        section.addArrangedSubview(card)
        contentStack.addArrangedSubview(section)
        refreshHeightSelection()
    }

    private func select(_ preset: KeyboardHeightPreset) {
        guard preset != .kiosk || kioskEntitled() else {
            let store = StoreViewController()
            store.source = "studio_size_feel_kiosk"
            show(store, sender: self)
            return
        }
        writer.setHeight(preset)
        Analytics.logEvent(name: "keyboard_height", attributes: ["source": "keyboard_studio", "state": preset.rawValue])
        refreshPreview()
        refreshHeightSelection()
    }

    private func select(_ width: NumpadWidthSize) {
        StudioPreviewContext.request(.numpad)
        writer.setNumpadWidthSize(width)
        Analytics.logEvent(name: "numpad_width_changed", attributes: ["value": width.rawValue])
        refreshPreview()
        refreshWidthSelection()
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

    private func refreshHeightSelection() {
        let entitlement = kioskEntitled()
        let effectivePreset = KeyboardHeightPreset.effective(
            stored: storedHeight(),
            kioskEntitled: entitlement
        )
        for (preset, tile) in heightTiles {
            tile.isSelected = preset == effectivePreset
            tile.lockText = preset == .kiosk && !entitlement
                ? NSLocalizedString("Pro", comment: "Locked Kiosk height")
                : nil
        }
    }

    private func refreshWidthSelection() {
        let selected = UserPrefs.numpadWidthSize
        for (width, tile) in widthTiles {
            tile.isSelected = width == selected
            tile.accessibilityValue = String(format: "%.0f%%", width.fraction * 100)
        }
    }
}
