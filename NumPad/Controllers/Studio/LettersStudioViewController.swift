//
//  LettersStudioViewController.swift
//  NumPad
//

import UIKit

final class LettersStudioViewController: StudioScreenViewController {
    private let writer: StudioSettingsWriter
    private var preview: StudioKeyboardPreviewView?
    private var layoutTiles: [IPadQwertyLayout: StudioTileView] = [:]
    private var sideControl: UISegmentedControl?
    private var sideContainer: UIView?

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
        title = NSLocalizedString("Letters", comment: "Keyboard Studio letters title")
        view.accessibilityIdentifier = "studio.letters"

        guard FeatureFlags.isQwertyPageAvailable else {
            let hero = StudioStatusHeroView(level: .unavailable, title: NSLocalizedString("Letters are not available right now", comment: "Keyboard Studio letters unavailable"), message: NSLocalizedString("This option will return when it is available for your keyboard.", comment: "Keyboard Studio letters unavailable description"), palette: palette)
            hero.accessibilityIdentifier = "studio.letters.unavailable"
            contentStack.addArrangedSubview(hero)
            return
        }

        let preview = StudioKeyboardPreviewView(model: .current(idiom: traitCollection.userInterfaceIdiom), palette: palette)
        preview.setCaption(leading: NSLocalizedString("LIVE PREVIEW", comment: "Keyboard Studio preview caption"), trailing: nil)
        preview.accessibilityIdentifier = "studio.letters.preview"
        contentStack.addArrangedSubview(preview)
        self.preview = preview

        addSection(title: NSLocalizedString("LETTERS PAGE", comment: "Keyboard Studio letters section"), rows: [
            toggleRow("Show letters page", "Switch between your number keys and letters", "textformat", isOn: UserPrefs.keyboardPageRaw == "qwerty") { [weak self] in
                self?.writer.setLettersPageEnabled($0)
                self?.refreshPreview()
            }
        ])
        if traitCollection.userInterfaceIdiom == .pad { addIPadLayoutChoices() }
        addSection(title: NSLocalizedString("TYPING", comment: "Keyboard Studio letters typing section"), rows: [
            toggleRow("Autocorrect", "Fix likely typing mistakes", "checkmark.circle", isOn: UserPrefs.qwertyAutocorrect) { [weak self] in
                self?.writer.setAutocorrectEnabled($0)
                self?.refreshPreview()
            },
            toggleRow("Suggestions", "Show word suggestions while you type", "text.badge.plus", isOn: UserPrefs.qwertySuggestions) { [weak self] in
                self?.writer.setSuggestionsEnabled($0)
                self?.refreshPreview()
            },
            toggleRow("Double-space period", "Add a period after two spaces", "space", isOn: UserPrefs.qwertyDoubleSpacePeriod) { [weak self] in
                self?.writer.setDoubleSpacePeriodEnabled($0)
                self?.refreshPreview()
            },
            toggleRow("Period and comma keys", "Keep both next to the space bar", "comma", isOn: UserPrefs.qwertyPeriodComma) { [weak self] in
                self?.writer.setPeriodCommaEnabled($0)
                self?.refreshPreview()
            }
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if traitCollection.userInterfaceIdiom == .pad { StudioPreviewContext.request(.qwerty) }
        refreshPreview()
        refreshIPadLayoutSelection()
    }

    private func addIPadLayoutChoices() {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = StudioMetrics.Spacing.s
        section.addArrangedSubview(StudioSectionLabel(
            text: NSLocalizedString("IPAD LAYOUT", comment: "Keyboard Studio iPad QWERTY layout section"),
            palette: palette
        ))
        let card = StudioCard(palette: palette, surface: .elevated, elevation: .flat)
        card.contentSpacing = StudioMetrics.Spacing.s
        for layout in IPadQwertyLayout.allCases {
            let tile = StudioTileView(
                title: layout.studioDisplayName,
                subtitle: layout == .standard
                    ? NSLocalizedString("Full-width letters with a number row", comment: "Standard iPad letters layout")
                    : NSLocalizedString("Letters plus your active NumPad", comment: "Full iPad letters layout"),
                leading: .symbol(layout == .standard ? "keyboard" : "rectangle.split.3x1"),
                isSelected: false,
                palette: palette
            )
            tile.accessibilityIdentifier = "studio.letters.layout.\(layout.rawValue)"
            tile.onTap = { [weak self] in self?.select(layout) }
            layoutTiles[layout] = tile
            card.addArrangedSubview(tile)
        }
        section.addArrangedSubview(card)

        let side = UIStackView()
        side.axis = .vertical
        side.spacing = StudioMetrics.Spacing.s
        side.addArrangedSubview(StudioSectionLabel(
            text: NSLocalizedString("NUMPAD SIDE", comment: "Keyboard Studio full keyboard numpad side"),
            palette: palette
        ))
        let control = UISegmentedControl(items: [
            NSLocalizedString("Left", comment: "Full keyboard numpad side"),
            NSLocalizedString("Right", comment: "Full keyboard numpad side")
        ])
        control.accessibilityIdentifier = "studio.letters.full-keyboard-side"
        control.accessibilityLabel = NSLocalizedString("Numpad side", comment: "Full keyboard numpad side")
        control.addTarget(self, action: #selector(selectNumpadSide), for: .valueChanged)
        side.addArrangedSubview(control)
        section.addArrangedSubview(side)
        sideControl = control
        sideContainer = side
        contentStack.addArrangedSubview(section)
        refreshIPadLayoutSelection()
    }

    private func select(_ layout: IPadQwertyLayout) {
        StudioPreviewContext.request(.qwerty)
        writer.setIPadQwertyLayout(layout)
        Analytics.logEvent(name: "ipad_qwerty_layout_changed", attributes: ["value": layout.rawValue])
        refreshPreview()
        refreshIPadLayoutSelection()
    }

    @objc private func selectNumpadSide() {
        guard let sideControl else { return }
        let side: FullKeyboardNumpadSide = sideControl.selectedSegmentIndex == 0 ? .left : .right
        StudioPreviewContext.request(.qwerty)
        writer.setFullKeyboardNumpadSide(side)
        Analytics.logEvent(name: "ipad_full_keyboard_numpad_side_changed", attributes: ["value": side.rawValue])
        refreshPreview()
        refreshIPadLayoutSelection()
    }

    private func toggleRow(_ title: String, _ subtitle: String, _ symbol: String, isOn: Bool, action: @escaping (Bool) -> Void) -> StudioRowView {
        let row = StudioRowView(title: NSLocalizedString(title, comment: "Keyboard Studio letters setting"), subtitle: NSLocalizedString(subtitle, comment: "Keyboard Studio letters setting description"), symbolName: symbol, accessory: .toggle(isOn: isOn, onChange: action), palette: palette)
        row.accessibilityIdentifier = "studio.letters.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
        return row
    }

    private func refreshPreview() {
        preview?.model = .current(idiom: traitCollection.userInterfaceIdiom)
    }

    private func refreshIPadLayoutSelection() {
        let layout = UserPrefs.iPadQwertyLayout
        for (choice, tile) in layoutTiles { tile.isSelected = choice == layout }
        sideContainer?.isHidden = layout != .full
        sideControl?.selectedSegmentIndex = UserPrefs.fullKeyboardNumpadSide == .left ? 0 : 1
    }
}
