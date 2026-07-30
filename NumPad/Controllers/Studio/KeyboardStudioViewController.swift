//
//  KeyboardStudioViewController.swift
//  NumPad
//

import UIKit

final class KeyboardStudioViewController: StudioScreenViewController {
    private var didLogOpen = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Keyboard", comment: "Keyboard Studio title")
        view.accessibilityIdentifier = "studio.keyboard"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openAdvanced)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "studio.keyboard.advanced"

        let ready = Keyboard.isKeyboardEnabled
        let hero = StudioStatusHeroView(
            level: ready ? .ok : .warn,
            title: ready
                ? NSLocalizedString("Your keyboard is ready", comment: "Keyboard Studio ready title")
                : NSLocalizedString("Finish setting up NumPad", comment: "Keyboard Studio repair title"),
            message: ready
                ? NSLocalizedString("Choose an option below whenever you want a change.", comment: "Keyboard Studio ready message")
                : NSLocalizedString("Add NumPad in Settings before you use it in other apps.", comment: "Keyboard Studio repair message"),
            actionTitle: ready ? nil : NSLocalizedString("Open setup", comment: "Keyboard Studio repair action"),
            palette: palette
        )
        hero.accessibilityIdentifier = "studio.keyboard.status"
        hero.onAction = { [weak self] in
            self?.navigationController?.pushViewController(InstructionsViewController.instantiate(), animated: true)
        }
        contentStack.addArrangedSubview(hero)

        let preview = StudioKeyboardPreviewView(
            model: .current(idiom: traitCollection.userInterfaceIdiom),
            palette: palette
        )
        preview.setCaption(
            leading: NSLocalizedString("LIVE PREVIEW", comment: "Keyboard Studio preview caption"),
            trailing: nil
        )
        preview.accessibilityIdentifier = "studio.keyboard.preview"
        contentStack.addArrangedSubview(preview)

        let tryIt = UITextField()
        tryIt.translatesAutoresizingMaskIntoConstraints = false
        tryIt.placeholder = NSLocalizedString("Try the NumPad keyboard here", comment: "Keyboard Studio Try It placeholder")
        tryIt.borderStyle = .roundedRect
        tryIt.backgroundColor = palette.surfaceElevated
        tryIt.accessibilityIdentifier = "studio.keyboard.try-it"
        tryIt.heightAnchor.constraint(greaterThanOrEqualToConstant: StudioMetrics.Size.minTouchTarget).isActive = true
        contentStack.addArrangedSubview(tryIt)

        let appearance = studioRow(
            title: NSLocalizedString("Appearance", comment: "Keyboard Studio quick change action"),
            subtitle: NSLocalizedString("Theme, dark appearance, key shape, and grid", comment: "Keyboard Studio quick change description"),
            symbol: "paintpalette"
        ) { [weak self] in
            self?.navigationController?.pushViewController(ThemeViewController.instantiate(), animated: true)
        }
        appearance.accessibilityIdentifier = "studio.keyboard.appearance"

        let keys = studioRow(
            title: NSLocalizedString("Choose keys", comment: "Keyboard Studio quick change action"),
            subtitle: NSLocalizedString("Numbers, calculations, prices, and more", comment: "Keyboard Studio quick change description"),
            symbol: "plus.rectangle.on.rectangle"
        ) { [weak self] in
            self?.navigationController?.pushViewController(PacksViewController(), animated: true)
        }
        keys.accessibilityIdentifier = "studio.keyboard.choose-keys"

        let feel = studioRow(
            title: NSLocalizedString("Size & feel", comment: "Keyboard Studio quick change action"),
            subtitle: NSLocalizedString("Height, number order, sound, and vibration", comment: "Keyboard Studio quick change description"),
            symbol: "hand.tap"
        ) { [weak self] in
            self?.navigationController?.pushViewController(KeyboardHeightViewController(), animated: true)
        }
        feel.accessibilityIdentifier = "studio.keyboard.size-feel"

        var rows = [appearance, keys, feel]
        if FeatureFlags.isQwertyPageAvailable {
            let letters = studioRow(
                title: NSLocalizedString("Letters", comment: "Keyboard Studio quick change action"),
                subtitle: NSLocalizedString("Set up the letters page", comment: "Keyboard Studio quick change description"),
                symbol: "textformat"
            ) { [weak self] in
                self?.navigationController?.pushViewController(QwertySetupViewController(), animated: true)
            }
            letters.accessibilityIdentifier = "studio.keyboard.letters"
            rows.append(letters)
        }
        addSection(title: NSLocalizedString("QUICK CHANGES", comment: "Keyboard Studio section label"), rows: rows)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didLogOpen else { return }
        didLogOpen = true
        Analytics.logEvent(name: "studio_opened", attributes: ["surface": "keyboard"])
    }

    @objc private func openAdvanced() {
        Analytics.logEvent(name: "advanced_opened", attributes: ["source": "keyboard_gear"])
        present(StudioNavigationFactory.makeAdvancedNavigationController(), animated: true)
    }
}
