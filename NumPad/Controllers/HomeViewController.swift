//
//  HomeViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/22/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import SwiftUI
import SwiftRater
import StoreKit

class HomeViewController: TableViewController {

    private var sections: [HomeSection] {
        HomeSettingsModel.sections(
            fullKeyboardVisible: FeatureFlags.isFullKeyboardActive,
            isPad: UIDevice.current.userInterfaceIdiom == .pad
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        interactiveNavigationBarHidden = true

        self.tableView.tableHeaderView = {
            let view = UIView()
            view.frame.size.height = 300
            let imageView = UIImageView(image: UIImage(named: "header"))
            imageView.contentMode = .scaleAspectFit
            view.addSubview(imageView)
            imageView.edgesToSuperview(insets: UIEdgeInsets(top: 10, left: 0, bottom: 20, right: 0))
            return view
        }()

        SwiftRater.check()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

}

// MARK: - UITableViewDataSource
extension HomeViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section < sections.count else { return nil }
        return sections[section].title
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < sections.count else { return 0 }
        return sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .disclosureIndicator
        cell.accessoryView = nil
        cell.detailTextLabel?.text = nil
        cell.textLabel?.font = .body
        cell.textLabel?.textColor = .text
        guard indexPath.section < sections.count,
              indexPath.row < sections[indexPath.section].rows.count else { return cell }
        let destination = sections[indexPath.section].rows[indexPath.row]

        switch destination {
        case .dashboard:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = NSLocalizedString("Dashboard", comment: "Home row title for dashboard")
            let activeName = KeyboardProfileStore(defaults: .group).activeProfile()?.name
            let status = KeyboardStatusPresentation.detail(isEnabled: Keyboard.isKeyboardEnabled)
            cell.detailTextLabel?.text = [activeName, status].compactMap { $0 }.joined(separator: " · ")
        case .profiles:
            cell.imageView?.image = UIImage(systemName: "person.crop.circle")
            cell.textLabel?.text = NSLocalizedString("Profiles", comment: "Home row title for profiles")
            cell.detailTextLabel?.text = KeyboardProfileStore(defaults: .group).activeProfile()?.name
        case .keyboardSetup:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = .enableKeyboard
        case .theme:
            cell.imageView?.image = UIImage(named: "theme")
            cell.textLabel?.text = .theme
            cell.detailTextLabel?.text = KeyboardTheme.selectedOrAutomatic.name
        case .packs:
            cell.imageView?.image = UIImage(named: "math")
            cell.textLabel?.text = NSLocalizedString("Keyboard Packs", comment: "Home row title for keyboard packs screen")
        case .height:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = NSLocalizedString("Keyboard Height", comment: "Home row title for keyboard height screen")
            cell.detailTextLabel?.text = KeyboardHeightPreset.selected.name
        case .numberOrder:
            return makeLayoutSwitchCell(
                image: "reversed",
                title: NSLocalizedString("7-8-9 on Top", comment: "Home row title for the calculator-style number layout toggle (was 'Reversed')"),
                isOn: Keyboard.isReversedMode,
                onChange: { isOn in
                    Keyboard.isReversedMode = isOn
                    SettingsSync.post()
                    Analytics.logEvent(name: "reversed_mode", attributes: [Analytics.ParameterValue: Keyboard.isReversedMode])
                }
            )
        case .roundedCorners:
            return makeLayoutSwitchCell(
                image: "rounded",
                title: .rounded,
                isOn: Keyboard.hasRoundedCorners,
                onChange: { isOn in
                    Keyboard.hasRoundedCorners = isOn
                    SettingsSync.post()
                    Analytics.logEvent(name: "rounded_corners", attributes: [Analytics.ParameterValue: Keyboard.hasRoundedCorners])
                }
            )
        case .grid:
            return makeLayoutSwitchCell(
                image: "grid",
                title: .grid,
                isOn: Keyboard.hasGrid,
                onChange: { isOn in
                    Keyboard.hasGrid = isOn
                    SettingsSync.post()
                    Analytics.logEvent(name: "grid", attributes: [Analytics.ParameterValue: Keyboard.hasGrid])
                }
            )
        case .snippets:
            cell.imageView?.image = UIImage(named: "chat")
            cell.textLabel?.text = NSLocalizedString("Snippets", comment: "Home row title for snippets screen")
        case .customKeyboard:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = NSLocalizedString("Custom Keyboard", comment: "Home row title for the customizable keyboard editor")
            cell.detailTextLabel?.text = (CustomKeyboardStore(defaults: .group).load()?.hasAnyKeys == true)
                ? NSLocalizedString("On", comment: "Home row detail when a custom keyboard is active")
                : nil
        case .qwerty:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = NSLocalizedString("NumPad Type", comment: "Home row title for the full QWERTY keyboard setup screen")
            cell.detailTextLabel?.text = KeyboardStatusPresentation.detail(isEnabled: Keyboard.isKeyboardEnabled)
        case .typingBehavior:
            cell.imageView?.image = UIImage(named: "tap")
            cell.textLabel?.text = NSLocalizedString("Typing & Behavior", comment: "Home row title for typing behavior screen")
        case .pro:
            cell.imageView?.image = UIImage(named: "star")
            cell.textLabel?.text = NSLocalizedString("NumPad Pro", comment: "Home row title for the NumPad Pro store screen")
            if Monetization.isProEntitled {
                cell.detailTextLabel?.text = "✓ " + NSLocalizedString("Unlocked", comment: "Store label for an owned product")
            } else {
                cell.textLabel?.font = .preferredFont(for: .body, weight: .semibold)
                cell.textLabel?.textColor = .primary
                cell.detailTextLabel?.text = StoreManager.shared.proProduct?.displayPrice ?? "$11.99"
            }
        case .privacy:
            cell.imageView?.image = UIImage(named: "darkmode")
            cell.textLabel?.text = NSLocalizedString("Privacy & Full Access", comment: "Home row title for privacy and full access screen")
        case .featureGuide:
            cell.imageView?.image = UIImage(systemName: "questionmark.circle")
            cell.textLabel?.text = NSLocalizedString("Features & Guide", comment: "Home row title for the features and guide screen")
        case .feedback:
            cell.imageView?.image = UIImage(named: "chat")
            cell.textLabel?.text = NSLocalizedString("Send Feedback", comment: "Home row title to email feedback to support")
        case .rate:
            cell.imageView?.image = UIImage(named: "star")
            cell.textLabel?.text = .rateMe
        case .kioskProvisioning:
            cell.imageView?.image = UIImage(systemName: "ipad.and.arrow.forward")
            cell.textLabel?.text = NSLocalizedString("Kiosk Provisioning", comment: "Home row title for kiosk provisioning")
        }
        return cell
    }

    private func makeLayoutSwitchCell(
        image: String,
        title: String,
        isOn: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> UITableViewCell {
        let reuseIdentifier = String(describing: SwitchCell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell
            ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
        cell.imageView?.image = UIImage(named: image)
        cell.textLabel?.text = title
        cell.selectionStyle = .none
        cell.switchView.isOn = isOn
        cell.valueChanged = { switchView in
            onChange(switchView.isOn)
        }
        return cell
    }

}

// MARK: - UITableViewDelegate
extension HomeViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section < sections.count,
              indexPath.row < sections[indexPath.section].rows.count else { return }

        switch sections[indexPath.section].rows[indexPath.row] {
        case .dashboard:
            break // Task 13 moves Try It ownership into DashboardViewController.
        case .profiles:
            show(ProfilesViewController(), sender: self)
        case .keyboardSetup:
            show(InstructionsViewController.instantiate(), sender: self)
        case .theme:
            show(ThemeViewController.instantiate(), sender: self)
        case .packs:
            show(PacksViewController(), sender: self)
        case .height:
            show(KeyboardHeightViewController(), sender: self)
        case .numberOrder, .roundedCorners, .grid:
            break
        case .snippets:
            show(SnippetsViewController(), sender: self)
        case .customKeyboard:
            show(CustomKeyboardEditorViewController(), sender: self)
            Analytics.logEvent(name: "custom_keyboard_opened")
        case .qwerty:
            show(QwertySetupViewController(), sender: self)
            Analytics.logEvent(name: "qwerty_setup_opened")
        case .typingBehavior:
            show(TypingBehaviorViewController(), sender: self)
        case .pro:
            show(StoreViewController(), sender: self)
        case .privacy:
            show(PrivacyViewController(), sender: self)
        case .featureGuide:
            show(FeaturesGuideViewController(), sender: self)
        case .feedback:
            if let url = URL(string: "mailto:support@morevoltage.com?subject=NumPad%20Feedback") {
                UIApplication.shared.open(url)
            }
            Analytics.logEvent(name: "send_feedback")
        case .rate:
            SwiftRater.rateApp(host: self)
            Analytics.logEvent(name: "rate")
        case .kioskProvisioning:
            let placeholder = TableViewController(style: .insetGrouped)
            placeholder.title = NSLocalizedString("Kiosk Provisioning", comment: "Kiosk provisioning screen title")
            show(placeholder, sender: self)
        }
    }

}
