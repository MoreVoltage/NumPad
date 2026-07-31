//
//  AppearanceStudioViewController.swift
//  NumPad
//

import UIKit

final class AppearanceStudioViewController: StudioScreenViewController {
    private let writer: StudioSettingsWriter
    private let showsInlinePreview: Bool
    private var preview: StudioKeyboardPreviewView?
    private var themeTiles: [KeyboardTheme: StudioTileView] = [:]

    init(writer: StudioSettingsWriter = StudioSettingsWriter(), showsInlinePreview: Bool = true) {
        self.writer = writer
        self.showsInlinePreview = showsInlinePreview
        super.init()
    }

    required init?(coder: NSCoder) {
        writer = StudioSettingsWriter()
        showsInlinePreview = true
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Appearance", comment: "Keyboard Studio appearance title")
        view.accessibilityIdentifier = "studio.appearance"

        if showsInlinePreview {
            let preview = StudioKeyboardPreviewView(model: .current(idiom: traitCollection.userInterfaceIdiom), palette: palette)
            preview.setCaption(leading: NSLocalizedString("LIVE PREVIEW", comment: "Keyboard Studio preview caption"), trailing: nil)
            preview.accessibilityIdentifier = "studio.appearance.preview"
            contentStack.addArrangedSubview(preview)
            self.preview = preview
        }

        addThemeChoices()
        addSection(title: NSLocalizedString("KEY STYLE", comment: "Keyboard Studio appearance section"), rows: [
            toggleRow("Match device appearance", "Use a light or dark theme to match your device", "circle.lefthalf.filled", isOn: KeyboardTheme.automaticDarkMode) { [weak self] in
                self?.writer.setAutomaticDarkMode($0)
                self?.refreshPreview()
                self?.refreshThemeSelection()
            },
            toggleRow("Rounded keys", "Give each key softer corners", "rectangle.roundedtop", isOn: Keyboard.hasRoundedCorners) { [weak self] in
                self?.writer.setRoundedCorners($0)
                self?.refreshPreview()
            },
            toggleRow("Key grid", "Show lines between keys", "square.grid.3x3", isOn: Keyboard.hasGrid) { [weak self] in
                self?.writer.setGrid($0)
                self?.refreshPreview()
            }
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshPreview()
        refreshThemeSelection()
    }

    private func addThemeChoices() {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = StudioMetrics.Spacing.s
        section.addArrangedSubview(StudioSectionLabel(text: NSLocalizedString("THEME", comment: "Keyboard Studio appearance section"), palette: palette))
        let card = StudioCard(palette: palette, surface: .elevated, elevation: .flat)
        card.contentSpacing = StudioMetrics.Spacing.s
        for theme in KeyboardTheme.allCases {
            let automaticAppearance = KeyboardTheme.automaticDarkMode
            let tile = StudioTileView(
                title: theme.name,
                subtitle: automaticAppearance
                    ? NSLocalizedString("Turn off Match device appearance to choose a theme.", comment: "Disabled theme choice explanation")
                    : nil,
                leading: .swatch(theme.color),
                isSelected: !KeyboardTheme.automaticDarkMode && theme == .selected,
                lockText: Monetization.isLocked(theme: theme) ? NSLocalizedString("Pro", comment: "Locked theme tile") : nil,
                palette: palette
            )
            tile.isEnabled = !automaticAppearance
            tile.hint = automaticAppearance
                ? NSLocalizedString("Turn off Match device appearance to choose a theme.", comment: "Disabled theme choice accessibility hint")
                : nil
            tile.accessibilityIdentifier = "studio.appearance.theme.\(theme.rawValue)"
            tile.onTap = { [weak self] in self?.select(theme) }
            card.addArrangedSubview(tile)
            themeTiles[theme] = tile
        }
        section.addArrangedSubview(card)
        contentStack.addArrangedSubview(section)
    }

    private func select(_ theme: KeyboardTheme) {
        guard !Monetization.isLocked(theme: theme) else {
            let store = StoreViewController()
            store.source = "studio_appearance_theme"
            show(store, sender: self)
            return
        }
        writer.setTheme(theme)
        Analytics.logEvent(name: "keyboard_theme", attributes: ["source": "keyboard_studio", "state": theme.rawValue])
        refreshPreview()
        refreshThemeSelection()
    }

    private func toggleRow(
        _ title: String,
        _ subtitle: String,
        _ symbol: String,
        isOn: Bool,
        action: @escaping (Bool) -> Void
    ) -> StudioRowView {
        let row = StudioRowView(title: NSLocalizedString(title, comment: "Keyboard Studio appearance setting"), subtitle: NSLocalizedString(subtitle, comment: "Keyboard Studio appearance setting description"), symbolName: symbol, accessory: .toggle(isOn: isOn, onChange: action), palette: palette)
        row.accessibilityIdentifier = "studio.appearance.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
        return row
    }

    private func refreshPreview() {
        preview?.model = .current(idiom: traitCollection.userInterfaceIdiom)
    }

    private func refreshThemeSelection() {
        for (theme, tile) in themeTiles {
            let automaticAppearance = KeyboardTheme.automaticDarkMode
            tile.isEnabled = !automaticAppearance
            tile.isSelected = !automaticAppearance && theme == .selected
            tile.lockText = Monetization.isLocked(theme: theme)
                ? NSLocalizedString("Pro", comment: "Locked theme tile")
                : nil
            tile.subtitle = automaticAppearance
                ? NSLocalizedString("Turn off Match device appearance to choose a theme.", comment: "Disabled theme choice explanation")
                : nil
            tile.hint = automaticAppearance
                ? NSLocalizedString("Turn off Match device appearance to choose a theme.", comment: "Disabled theme choice accessibility hint")
                : nil
        }
    }
}
