//
//  TableViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/22/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import SwiftUI
import SwiftRater

class HomeViewController: TableViewController {
    
    enum Row: Int, CaseIterable {
        case instructions, keyboardTheme, packs, keyboardHeight, isReversedMode, hasRoundedCorners, hasGrid, snippets, customKeys, customKeyboard, store, privacy, featuresGuide, feedback, rate
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
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = String(describing: Cell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .disclosureIndicator
        guard let row = Row(rawValue: indexPath.row) else { return cell }
        switch row {
        case .instructions:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = .enableKeyboard
        case .keyboardTheme:
            cell.imageView?.image = UIImage(named: "theme")
            cell.textLabel?.text = .theme
            cell.detailTextLabel?.text = KeyboardTheme.selectedOrAutomatic.name
        case .packs:
            cell.imageView?.image = UIImage(named: "math")
            cell.textLabel?.text = NSLocalizedString("Keyboard Packs", comment: "Home row title for keyboard packs screen")
        case .keyboardHeight:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = NSLocalizedString("Keyboard Height", comment: "Home row title for keyboard height screen")
            cell.detailTextLabel?.text = KeyboardHeightPreset.selected.name
        case .isReversedMode:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "reversed")
            // Same setting as the old "Reversed" toggle — renamed so 10-key touch typists
            // discover it: ON puts 7-8-9 on the top row like a physical calculator.
            cell.textLabel?.text = NSLocalizedString("7-8-9 on Top", comment: "Home row title for the calculator-style number layout toggle (was 'Reversed')")
            cell.selectionStyle = .none
            cell.switchView.isOn = Keyboard.isReversedMode
            cell.valueChanged = { switchView in
                Keyboard.isReversedMode = switchView.isOn
                SettingsSync.post()
                Analytics.logEvent(name: "reversed_mode", attributes: [Analytics.ParameterValue: Keyboard.isReversedMode])
            }
            return cell
        case .hasRoundedCorners:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "rounded")
            cell.textLabel?.text = .rounded
            cell.selectionStyle = .none
            cell.switchView.isOn = Keyboard.hasRoundedCorners
            cell.valueChanged = { switchView in
                Keyboard.hasRoundedCorners = switchView.isOn
                SettingsSync.post()
                Analytics.logEvent(name: "rounded_corners", attributes: [Analytics.ParameterValue: Keyboard.hasRoundedCorners])
            }
            return cell
        case .hasGrid:
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "grid")
            cell.textLabel?.text = .grid
            cell.selectionStyle = .none
            cell.switchView.isOn = Keyboard.hasGrid
            cell.valueChanged = { switchView in
                Keyboard.hasGrid = switchView.isOn
                SettingsSync.post()
                Analytics.logEvent(name: "grid", attributes: [Analytics.ParameterValue: Keyboard.hasGrid])
            }
            return cell
        // removed obsolete .keyboardType row; packs are handled via dedicated screen
        case .snippets:
            cell.imageView?.image = UIImage(named: "chat")
            cell.textLabel?.text = NSLocalizedString("Snippets", comment: "Home row title for snippets screen")
        case .customKeys:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = NSLocalizedString("Custom Keys", comment: "Home row title for the custom keys screen")
        case .customKeyboard:
            cell.imageView?.image = UIImage(named: "keyboard")
            cell.textLabel?.text = NSLocalizedString("Custom Keyboard", comment: "Home row title for the customizable keyboard editor")
            // "On" when the user has built a custom keyboard (any peripheral key), else nothing.
            cell.detailTextLabel?.text = (CustomKeyboardStore(defaults: .group).load()?.hasAnyKeys == true)
                ? NSLocalizedString("On", comment: "Home row detail when a custom keyboard is active")
                : nil
        case .store:
            cell.imageView?.image = UIImage(named: "star")
            cell.textLabel?.text = NSLocalizedString("NumPad Pro", comment: "Home row title for the NumPad Pro store screen")
        case .privacy:
            cell.imageView?.image = UIImage(named: "darkmode")
            cell.textLabel?.text = NSLocalizedString("Privacy & Full Access", comment: "Home row title for privacy and full access screen")
        case .featuresGuide:
            cell.imageView?.image = UIImage(systemName: "questionmark.circle")
            cell.textLabel?.text = NSLocalizedString("Features & Guide", comment: "Home row title for the features and guide screen")
        case .feedback:
            cell.imageView?.image = UIImage(named: "chat")
            cell.textLabel?.text = NSLocalizedString("Send Feedback", comment: "Home row title to email feedback to support")
        case .rate:
            cell.imageView?.image = UIImage(named: "star")
            cell.textLabel?.text = .rateMe
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension HomeViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let row = Row(rawValue: indexPath.row) else { return }
        switch row {
        case .instructions:
            show(InstructionsViewController.instantiate(), sender: self)
        case .keyboardTheme:
            show(ThemeViewController.instantiate(), sender: self)
        case .packs:
            show(PacksViewController(), sender: self)
        case .keyboardHeight:
            show(KeyboardHeightViewController(), sender: self)
        case .snippets:
            show(SnippetsViewController(), sender: self)
        case .customKeys:
            show(CustomKeysViewController(), sender: self)
        case .customKeyboard:
            show(CustomKeyboardEditorViewController(), sender: self)
            Analytics.logEvent(name: "custom_keyboard_opened")
        case .store:
            show(StoreViewController(), sender: self)
        case .privacy:
            show(PrivacyViewController(), sender: self)
        case .featuresGuide:
            show(FeaturesGuideViewController(), sender: self)
        case .feedback:
            if let url = URL(string: "mailto:support@morevoltage.com?subject=NumPad%20Feedback") {
                UIApplication.shared.open(url)
            }
            Analytics.logEvent(name: "send_feedback")
        case .rate:
            SwiftRater.rateApp(host: self)
            Analytics.logEvent(name: "rate")
        default:
            break
        }
    }
    
}

 
