//
//  LettersStudioViewController.swift
//  NumPad
//

import UIKit

final class LettersStudioViewController: StudioScreenViewController {
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
        refreshPreview()
    }

    private func toggleRow(_ title: String, _ subtitle: String, _ symbol: String, isOn: Bool, action: @escaping (Bool) -> Void) -> StudioRowView {
        let row = StudioRowView(title: NSLocalizedString(title, comment: "Keyboard Studio letters setting"), subtitle: NSLocalizedString(subtitle, comment: "Keyboard Studio letters setting description"), symbolName: symbol, accessory: .toggle(isOn: isOn, onChange: action), palette: palette)
        row.accessibilityIdentifier = "studio.letters.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
        return row
    }

    private func refreshPreview() {
        preview?.model = .current(idiom: traitCollection.userInterfaceIdiom)
    }
}
