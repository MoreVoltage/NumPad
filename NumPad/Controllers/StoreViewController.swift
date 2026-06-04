//
//  StoreViewController.swift
//  NumPad
//
//  Real StoreKit 2 store: NumPad Pro (lifetime), Finance Pack, restore,
//  plus the keyboard behavior toggles that previously lived here.
//

import UIKit
import StoreKit

class StoreViewController: TableViewController {
    private enum Section: Int, CaseIterable { case pro, finance, controls, debug }

    /// Sections visible in this build. The paywall/entitlement test toggles
    /// are development-only and must never ship to users.
    #if DEBUG
    private static let visibleSections: [Section] = [.pro, .finance, .controls, .debug]
    #else
    private static let visibleSections: [Section] = [.pro, .finance, .controls]
    #endif

    private var entitlementObserver: NSObjectProtocol?
    private var isPurchasing = false

    override func viewDidLoad() {
        super.viewDidLoad()

        interactiveNavigationBarHidden = false
        navigationItem.title = NSLocalizedString("NumPad Pro", comment: "Store screen navigation title")

        // Refresh rows whenever an entitlement changes (purchase, restore, Transaction.updates)
        entitlementObserver = NotificationCenter.default.addObserver(forName: StoreManager.entitlementsDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.tableView.reloadData()
        }

        // Make sure prices are loaded; reload rows once they arrive.
        Task { [weak self] in
            await StoreManager.shared.loadProducts()
            await MainActor.run { self?.tableView.reloadData() }
        }
    }

    deinit {
        if let observer = entitlementObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - State helpers

    private var isProUnlocked: Bool { Monetization.isProEntitled }
    private var isFinanceUnlocked: Bool { Monetization.isProEntitled || Monetization.isFinancePackPurchased }

    private func price(for product: Product?, fallback: String) -> String {
        return product?.displayPrice ?? fallback
    }

    // MARK: - Purchase / restore actions

    private func buy(_ product: Product?) {
        guard !isPurchasing else { return }
        guard let product = product else {
            // Products not loaded yet (offline / App Store hiccup) — retry the load.
            Task { [weak self] in
                await StoreManager.shared.loadProducts()
                await MainActor.run {
                    guard let self = self else { return }
                    if StoreManager.shared.products.isEmpty {
                        self.showErrorAlert()
                    } else {
                        self.tableView.reloadData()
                    }
                }
            }
            return
        }
        isPurchasing = true
        Task { [weak self] in
            do {
                try await StoreManager.shared.purchase(product)
            } catch StoreKitError.userCancelled {
                // Silent: the user backed out of the payment sheet.
            } catch {
                Analytics.logEvent(name: "purchase_failed", attributes: ["product_id": product.id])
                await MainActor.run { self?.showErrorAlert() }
            }
            await MainActor.run {
                self?.isPurchasing = false
                self?.tableView.reloadData()
            }
        }
    }

    private func restore() {
        Task { [weak self] in
            await StoreManager.shared.restorePurchases()
            await MainActor.run {
                guard let self = self else { return }
                self.tableView.reloadData()
                let message = (Monetization.isProPurchased || Monetization.isFinancePackPurchased || Monetization.isGrandfathered)
                    ? NSLocalizedString("Your purchases have been restored.", comment: "Restore purchases success message")
                    : NSLocalizedString("No previous purchases were found.", comment: "Restore purchases empty result message")
                let alert = UIAlertController(title: NSLocalizedString("Restore Purchases", comment: "Store row to restore previous purchases"), message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Generic alert confirmation button"), style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    /// Right-side accessory: a "✓ Unlocked" label for owned items, or a bold price for sale items.
    private func configureAccessory(for cell: UITableViewCell, unlocked: Bool, priceText: String) {
        let label = UILabel()
        if unlocked {
            label.text = "✓ " + NSLocalizedString("Unlocked", comment: "Store label for an owned product")
            label.textColor = .secondaryLabel
            label.font = .preferredFont(forTextStyle: .body)
            cell.selectionStyle = .none
        } else {
            label.text = priceText
            label.textColor = .primary
            label.font = .preferredFont(for: .body, weight: .semibold)
            cell.selectionStyle = .default
        }
        label.sizeToFit()
        cell.accessoryType = .none
        cell.accessoryView = label
    }

    private func showErrorAlert() {
        let alert = UIAlertController(title: nil, message: NSLocalizedString("Something went wrong. Please try again.", comment: "Generic purchase/restore error alert"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Generic alert confirmation button"), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension StoreViewController {
    override func numberOfSections(in tableView: UITableView) -> Int { Self.visibleSections.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section < Self.visibleSections.count else { return nil }
        switch Self.visibleSections[section] {
        case .pro: return NSLocalizedString("NumPad Pro", comment: "Store screen navigation title")
        case .finance: return NSLocalizedString("Finance Pack", comment: "Store section title for the finance pack")
        case .controls: return NSLocalizedString("Settings", comment: "")
        case .debug: return "Debug"
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < Self.visibleSections.count else { return 0 }
        switch Self.visibleSections[section] {
        case .pro: return 1
        case .finance: return 1
        case .controls: return 4 // Restore + Haptics + Sound + Repurpose Next Key
        case .debug: return 2
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section < Self.visibleSections.count else {
            return UITableViewCell()
        }
        switch Self.visibleSections[indexPath.section] {
        case .pro:
            let reuseIdentifier = "ProductCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .subtitle, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "star")
            cell.textLabel?.text = NSLocalizedString("Everything, forever", comment: "Store row title for the lifetime Pro purchase")
            cell.detailTextLabel?.text = NSLocalizedString("All keyboard packs, all premium themes, and every future pack.", comment: "Store row detail listing what Pro includes")
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.textColor = .secondaryLabel
            configureAccessory(for: cell, unlocked: isProUnlocked, priceText: price(for: StoreManager.shared.proProduct, fallback: "$4.99"))
            return cell
        case .finance:
            let reuseIdentifier = "ProductCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .subtitle, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "math")
            cell.textLabel?.text = NSLocalizedString("Finance Pack", comment: "Store section title for the finance pack")
            cell.detailTextLabel?.text = NSLocalizedString("Currency symbols and finance keys.", comment: "Store row detail describing the finance pack")
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.textColor = .secondaryLabel
            configureAccessory(for: cell, unlocked: isFinanceUnlocked, priceText: price(for: StoreManager.shared.financeProduct, fallback: "$1.99"))
            return cell
        case .controls:
            if indexPath.row == 0 {
                let reuseIdentifier = String(describing: Cell.self)
                let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .default, reuseIdentifier: reuseIdentifier)
                cell.imageView?.image = UIImage(named: "switch")
                cell.textLabel?.text = NSLocalizedString("Restore Purchases", comment: "Store row to restore previous purchases")
                cell.accessoryType = .none
                cell.accessoryView = nil
                return cell
            }
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.selectionStyle = .none
            if indexPath.row == 1 {
                cell.imageView?.image = UIImage(named: "tap")
                cell.textLabel?.text = NSLocalizedString("Haptics", comment: "Store toggle for haptic feedback")
                cell.switchView.isOn = UserPrefs.hapticsEnabled
                cell.valueChanged = { switchView in
                    UserPrefs.hapticsEnabled = switchView.isOn
                    SettingsSync.post()
                }
            } else if indexPath.row == 2 {
                cell.imageView?.image = UIImage(named: "switch")
                cell.textLabel?.text = NSLocalizedString("Key Click Sound", comment: "Store toggle for key click sound")
                cell.switchView.isOn = UserPrefs.soundEnabled
                cell.valueChanged = { switchView in
                    UserPrefs.soundEnabled = switchView.isOn
                    SettingsSync.post()
                }
            } else {
                cell.imageView?.image = UIImage(named: "keyboard")
                cell.textLabel?.text = NSLocalizedString("Repurpose Next Key", comment: "Store toggle to repurpose the next keyboard key")
                cell.switchView.isOn = UserPrefs.repurposeNextKey
                cell.valueChanged = { switchView in
                    UserPrefs.repurposeNextKey = switchView.isOn
                    SettingsSync.post()
                }
            }
            return cell
        case .debug:
            #if DEBUG
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.selectionStyle = .none
            if indexPath.row == 0 {
                cell.imageView?.image = UIImage(named: "switch")
                cell.textLabel?.text = "Enable Paywall"
                cell.switchView.isOn = Monetization.paywallEnabled
                cell.valueChanged = { [weak self] switchView in
                    Monetization.paywallEnabled = switchView.isOn
                    SettingsSync.post()
                    self?.tableView.reloadData()
                }
            } else {
                cell.imageView?.image = UIImage(named: "star")
                cell.textLabel?.text = "Simulate Pro Entitlement"
                cell.switchView.isOn = Monetization.debugProOverride
                cell.valueChanged = { [weak self] switchView in
                    Monetization.debugProOverride = switchView.isOn
                    SettingsSync.post()
                    self?.tableView.reloadData()
                }
            }
            return cell
            #else
            return UITableViewCell()
            #endif
        }
    }
}

// MARK: - UITableViewDelegate
extension StoreViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section < Self.visibleSections.count else { return }
        switch Self.visibleSections[indexPath.section] {
        case .pro:
            guard !isProUnlocked else { return }
            buy(StoreManager.shared.proProduct)
        case .finance:
            guard !isFinanceUnlocked else { return }
            buy(StoreManager.shared.financeProduct)
        case .controls:
            if indexPath.row == 0 {
                restore()
            }
        case .debug:
            break
        }
    }
}
