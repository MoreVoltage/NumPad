//
//  KeySetStudioViewController.swift
//  NumPad
//

import UIKit

final class KeySetStudioViewController: StudioScreenViewController {
    private let writer: StudioSettingsWriter
    private let catalog: StudioKeySetCatalog
    private var preview: StudioKeyboardPreviewView?
    private var choicesCard: StudioCard?

    init(writer: StudioSettingsWriter = StudioSettingsWriter(), catalog: StudioKeySetCatalog = StudioKeySetCatalog()) {
        self.writer = writer
        self.catalog = catalog
        super.init()
    }

    required init?(coder: NSCoder) {
        writer = StudioSettingsWriter()
        catalog = StudioKeySetCatalog()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Choose keys", comment: "Keyboard Studio key set title")
        view.accessibilityIdentifier = "studio.keyset"

        let preview = StudioKeyboardPreviewView(model: .current(idiom: traitCollection.userInterfaceIdiom), palette: palette)
        preview.setCaption(leading: NSLocalizedString("LIVE PREVIEW", comment: "Keyboard Studio preview caption"), trailing: nil)
        preview.accessibilityIdentifier = "studio.keyset.preview"
        contentStack.addArrangedSubview(preview)
        self.preview = preview

        let card = StudioCard(palette: palette, surface: .elevated, elevation: .flat)
        card.contentSpacing = StudioMetrics.Spacing.s
        choicesCard = card
        contentStack.addArrangedSubview(StudioSectionLabel(text: NSLocalizedString("KEY SETS", comment: "Keyboard Studio key set section"), palette: palette))
        contentStack.addArrangedSubview(card)
        renderChoices()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshPreview()
        renderChoices()
    }

    private func select(_ choice: StudioKeySetCatalog.Choice) {
        guard writer.selectKeySet(choice, currentPack: .selected) else {
            let store = StoreViewController()
            store.source = "studio_key_set_\(choice.id.rawValue)"
            show(store, sender: self)
            return
        }
        Analytics.logEvent(name: "key_set_selected", attributes: ["source": "keyboard_studio", "state": choice.id.rawValue])
        refreshPreview()
        renderChoices()
    }

    private func refreshPreview() {
        preview?.model = .current(idiom: traitCollection.userInterfaceIdiom)
    }

    private func renderChoices() {
        guard let choicesCard else { return }
        choicesCard.removeAllArrangedSubviews()
        for choice in catalog.visibleChoices {
            let tile = StudioTileView(
                title: choice.title,
                subtitle: choice.description,
                leading: .symbol(symbol(for: choice.id)),
                isSelected: choice.isSelected(for: .selected),
                lockText: choice.isLocked ? NSLocalizedString("Pro", comment: "Locked Keyboard Studio tile") : nil,
                palette: palette
            )
            tile.accessibilityIdentifier = "studio.keyset.\(choice.id.rawValue)"
            tile.onTap = { [weak self] in self?.select(choice) }
            choicesCard.addArrangedSubview(tile)
        }
    }

    private func symbol(for id: StudioKeySetCatalog.Choice.ID) -> String {
        switch id {
        case .numbers: return "number.square"
        case .calculations: return "function"
        case .prices: return "dollarsign.circle"
        case .measurements: return "ruler"
        case .dateAndTime: return "calendar"
        case .symbols: return "textformat"
        case .programming: return "chevron.left.forwardslash.chevron.right"
        }
    }
}
