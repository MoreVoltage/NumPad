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
    private enum Section: Int, CaseIterable { case pro, packs, controls, featureFlags, debug }

    /// Sections visible in this build. Always show the purchase + settings sections; show the
    /// experimental Feature Flags section in DEBUG/TestFlight only (`experimentalUIVisible`); show
    /// the paywall/entitlement simulation toggles in DEBUG only — they must never ship to users.
    private static var visibleSections: [Section] {
        var sections: [Section] = [.pro, .packs, .controls]
        if FeatureFlags.experimentalUIVisible { sections.append(.featureFlags) }
        #if DEBUG
        sections.append(.debug)
        #endif
        return sections
    }

    /// The à la carte packs sold individually ($1.99 each), in display order.
    private var alaCartePacks: [KeyboardType] {
        KeyboardType.packs.filter { !ProductCatalog.isBasePack($0) && !ProductCatalog.isProOnlyPack($0) }
    }

    private var entitlementObserver: NSObjectProtocol?
    private var isPurchasing = false

    /// Where the user came from, for funnel analytics: "home" (settings row), "packs" (locked
    /// pack row), "key_lock" / "pack_picker" (keyboard deep links). Set before presentation.
    var source: String = "home"
    private var didLogView = false

    override func viewDidLoad() {
        super.viewDidLoad()

        interactiveNavigationBarHidden = false
        navigationItem.title = NSLocalizedString("NumPad Pro", comment: "Store screen navigation title")
        tableView.tableHeaderView = makeHeroHeader()

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // One store_viewed per presentation, attributed to its entry point. Together with the
        // existing purchase_succeeded/purchase_failed events this completes the purchase funnel.
        if !didLogView {
            didLogView = true
            Analytics.logEvent(name: "store_viewed", attributes: ["source": source])
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Funnel close-out: whether the paywall converted before it was dismissed.
        if isMovingFromParent || isBeingDismissed {
            Analytics.logEvent(name: "paywall_dismissed", attributes: ["source": source, "purchased": Monetization.isProEntitled])
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // tableHeaderView ignores Auto Layout, so size it to the table's real width here (in
        // viewDidLoad the width isn't final yet). Re-fit only when the width actually changes,
        // otherwise reassigning the header on every layout pass would loop.
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width
        guard width > 0, header.frame.width != width else { return }
        let height = header.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        ).height
        header.frame = CGRect(x: 0, y: 0, width: width, height: height)
        tableView.tableHeaderView = header
    }

    deinit {
        if let observer = entitlementObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Hero header: app icon, a context-aware headline + pitch, a "what's included" checklist, and a
    /// one-time / no-subscription reassurance — so the screen sells Pro rather than reading as a bare
    /// settings table, and adapts to where the user arrived from (a locked key, a pack, first run).
    private func makeHeroHeader() -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 0))

        let icon = UIImageView(image: UIImage(named: "star"))
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .primary

        let copy = heroCopy(for: source)

        let headline = UILabel()
        headline.text = copy.title
        headline.font = .preferredFont(for: .title1, weight: .bold)
        headline.adjustsFontForContentSizeCategory = true
        headline.textAlignment = .center
        headline.numberOfLines = 0

        let pitch = UILabel()
        pitch.text = copy.subtitle
        pitch.font = .preferredFont(forTextStyle: .subheadline)
        pitch.adjustsFontForContentSizeCategory = true
        pitch.textColor = .secondaryLabel
        pitch.textAlignment = .center
        pitch.numberOfLines = 0

        let benefits = UIStackView(arrangedSubviews: [
            makeBenefitRow(NSLocalizedString("Every keyboard pack — finance, symbols, code, math, custom", comment: "Paywall benefit: packs")),
            makeBenefitRow(NSLocalizedString("Every premium theme", comment: "Paywall benefit: themes")),
            makeBenefitRow(NSLocalizedString("Tax & tip, clipboard history, and every future pack", comment: "Paywall benefit: features")),
        ])
        benefits.axis = .vertical
        benefits.alignment = .leading
        benefits.spacing = 8

        let reassurance = UILabel()
        reassurance.text = NSLocalizedString("One-time purchase. No subscription, ever.", comment: "Reassurance under the paywall hero")
        reassurance.font = .preferredFont(for: .footnote, weight: .semibold)
        reassurance.adjustsFontForContentSizeCategory = true
        reassurance.textColor = .primary
        reassurance.textAlignment = .center
        reassurance.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, headline, pitch, benefits, reassurance])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(16, after: pitch)
        stack.setCustomSpacing(16, after: benefits)
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.heightAnchor.constraint(equalToConstant: 56),
            icon.widthAnchor.constraint(equalToConstant: 56),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        // Self-size the header (tableHeaderView ignores Auto Layout on its own).
        let height = container.systemLayoutSizeFitting(
            CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        ).height
        container.frame.size.height = height
        return container
    }

    /// A single checklist row: a tinted checkmark and a wrapping label.
    private func makeBenefitRow(_ text: String) -> UIView {
        let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        check.tintColor = .primary
        check.contentMode = .scaleAspectFit
        check.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [check, label])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 8
        NSLayoutConstraint.activate([
            check.widthAnchor.constraint(equalToConstant: 20),
            check.heightAnchor.constraint(equalToConstant: 20),
        ])
        return row
    }

    /// Context-aware hero copy keyed off the funnel `source`. Defaults to the Remote-Config pitch
    /// line for the settings entry point, otherwise a benefit-led message matched to the entry point.
    private func heroCopy(for source: String) -> (title: String, subtitle: String) {
        switch source {
        case "key_lock":
            return (NSLocalizedString("Unlock every key", comment: "Paywall hero title from a locked key"),
                    NSLocalizedString("That key is part of NumPad Pro — unlock every pack, theme, and future feature with one purchase.", comment: "Paywall hero subtitle from a locked key"))
        case "pack_picker", "packs":
            return (NSLocalizedString("Unlock every pack", comment: "Paywall hero title from a locked pack"),
                    NSLocalizedString("Get finance, symbols, programmer, math, and custom packs — plus every premium theme.", comment: "Paywall hero subtitle from a locked pack"))
        case "first_run":
            return (NSLocalizedString("Make NumPad yours", comment: "Paywall hero title for the first-run upsell"),
                    NSLocalizedString("Unlock every pack and premium theme with a single one-time purchase.", comment: "Paywall hero subtitle for the first-run upsell"))
        case "customize":
            return (NSLocalizedString("Build your own keyboard", comment: "Paywall hero title from the custom keyboard editor"),
                    NSLocalizedString("Touch and hold a key and drag to rearrange your own numpad — included in NumPad Pro, along with every pack and premium theme.", comment: "Paywall hero subtitle from the custom keyboard editor"))
        default:
            let rcCopy = RemoteConfigManager.shared.priceCopy
            let subtitle = rcCopy.isEmpty
                ? NSLocalizedString("All keyboard packs, all premium themes, and every future pack.", comment: "Store row detail listing what Pro includes")
                : rcCopy
            return (NSLocalizedString("NumPad Pro", comment: "Store screen navigation title"), subtitle)
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
        // Funnel: store_viewed -> purchase_initiated -> purchase_completed / _cancelled / _failed,
        // each attributed to the entry point (source) so conversion can be measured per surface.
        let source = self.source
        let productID = product.id
        Analytics.logEvent(name: "purchase_initiated", attributes: ["product_id": productID, "source": source])
        Task { [weak self] in
            var pending = false
            do {
                let outcome = try await StoreManager.shared.purchase(product)
                switch outcome {
                case .success:
                    Analytics.logEvent(name: "purchase_completed", attributes: ["product_id": productID, "source": source])
                case .userCancelled:
                    Analytics.logEvent(name: "purchase_cancelled", attributes: ["product_id": productID, "source": source])
                case .pending:
                    pending = true
                }
            } catch {
                Analytics.logEvent(name: "purchase_failed", attributes: ["product_id": productID, "source": source])
                await MainActor.run { self?.showErrorAlert() }
            }
            await MainActor.run {
                guard let self = self else { return }
                self.isPurchasing = false
                self.tableView.reloadData()
                if pending { self.showPendingAlert() }
            }
        }
    }

    private func restore() {
        Task { [weak self] in
            let outcome = await StoreManager.shared.restorePurchases()
            await MainActor.run {
                guard let self = self else { return }
                self.tableView.reloadData()
                let message: String
                switch outcome {
                case .restored:
                    message = NSLocalizedString("Your purchases have been restored.", comment: "Restore purchases success message")
                case .nothingToRestore:
                    message = NSLocalizedString("No previous purchases were found.", comment: "Restore purchases empty result message")
                case .failed:
                    message = NSLocalizedString("Couldn't reach the App Store. Please check your connection and try again.", comment: "Restore purchases network failure message")
                }
                let alert = UIAlertController(title: NSLocalizedString("Restore Purchases", comment: "Store row to restore previous purchases"), message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Generic alert confirmation button"), style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    private func showPendingAlert() {
        let alert = UIAlertController(
            title: NSLocalizedString("Waiting for Approval", comment: "Title for a pending (Ask to Buy) purchase"),
            message: NSLocalizedString("Your purchase needs approval and will unlock automatically once it's approved.", comment: "Body for a pending Ask to Buy purchase"),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Generic alert confirmation button"), style: .default))
        present(alert, animated: true)
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
        case .packs: return NSLocalizedString("Packs", comment: "Store section title for à la carte packs")
        case .controls: return NSLocalizedString("Settings", comment: "")
        case .featureFlags: return NSLocalizedString("Feature Flags (Beta)", comment: "Store section title for experimental feature toggles")
        case .debug: return "Debug"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section < Self.visibleSections.count else { return nil }
        if Self.visibleSections[section] == .featureFlags {
            return NSLocalizedString("Experimental features, off by default. Visible in TestFlight and debug builds only.", comment: "Footer explaining the feature flags section")
        }
        return nil
    }

    /// Behavior toggles shown in the Settings (controls) section after Restore Purchases. Data-driven
    /// so the row count and rendering can't drift apart. Each persists to UserPrefs + posts SettingsSync
    /// so a running keyboard reacts immediately. The last four were promoted from experimental flags in 2.0.
    private struct ToggleRow {
        let image: String
        let title: String
        let get: () -> Bool
        let set: (Bool) -> Void
    }
    private var controlToggles: [ToggleRow] {
        [
            ToggleRow(image: "tap", title: NSLocalizedString("Haptics", comment: "Store toggle for haptic feedback"),
                      get: { UserPrefs.hapticsEnabled }, set: { UserPrefs.hapticsEnabled = $0 }),
            ToggleRow(image: "switch", title: NSLocalizedString("Key Click Sound", comment: "Store toggle for key click sound"),
                      get: { UserPrefs.soundEnabled }, set: { UserPrefs.soundEnabled = $0 }),
            ToggleRow(image: "keyboard", title: NSLocalizedString("Repurpose Next Key", comment: "Store toggle to repurpose the next keyboard key"),
                      get: { UserPrefs.repurposeNextKey }, set: { UserPrefs.repurposeNextKey = $0 }),
            ToggleRow(image: "math2", title: NSLocalizedString("Inline Calculator", comment: "Store toggle for evaluating = expressions"),
                      get: { UserPrefs.inlineCalculator }, set: { UserPrefs.inlineCalculator = $0 }),
            ToggleRow(image: "next", title: NSLocalizedString("Cursor Controls", comment: "Store toggle for moving the caret from the keyboard"),
                      get: { UserPrefs.cursorControls }, set: { UserPrefs.cursorControls = $0 }),
            ToggleRow(image: "keyboard", title: NSLocalizedString("Smart Pack Defaulting", comment: "Store toggle for auto-picking a pack to match the field"),
                      get: { UserPrefs.smartPackDefaulting }, set: { UserPrefs.smartPackDefaulting = $0 }),
            ToggleRow(image: "switch", title: NSLocalizedString("Result Tape", comment: "Store toggle for keeping recent calculator results"),
                      get: { UserPrefs.lastResultTape }, set: { UserPrefs.lastResultTape = $0 }),
        ]
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < Self.visibleSections.count else { return 0 }
        switch Self.visibleSections[section] {
        case .pro: return EarlyBird.isCurrentlyActive ? 2 : 1 // Pro (+ early-bird discounted Pro when active)
        case .packs: return alaCartePacks.count
        case .controls: return 1 + controlToggles.count + 1 // Restore + behavior toggles + iCloud Sync (Pro)
        case .featureFlags: return FeatureFlags.all.count
        case .debug: return 3
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
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.textColor = .secondaryLabel
            if indexPath.row == 1 {
                // Early-bird discounted Pro — only present while the offer is active.
                cell.textLabel?.text = NSLocalizedString("Early-bird: 50% off Pro", comment: "Store row title for the discounted early-bird Pro")
                cell.detailTextLabel?.text = NSLocalizedString("Limited time for early users — everything Pro unlocks, at half price.", comment: "Store row detail for the early-bird Pro")
                configureAccessory(for: cell, unlocked: isProUnlocked, priceText: price(for: StoreManager.shared.earlyBirdProduct, fallback: "$5.99"))
                return cell
            }
            cell.textLabel?.text = NSLocalizedString("Everything, forever", comment: "Store row title for the lifetime Pro purchase")
            cell.detailTextLabel?.text = NSLocalizedString("Every pack, premium themes, the customizable keyboard, iCloud sync, and every future pack.", comment: "Store row detail listing what Pro includes")
            configureAccessory(for: cell, unlocked: isProUnlocked, priceText: price(for: StoreManager.shared.proProduct, fallback: "$11.99"))
            return cell
        case .packs:
            let reuseIdentifier = "ProductCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .subtitle, reuseIdentifier: reuseIdentifier)
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.textColor = .secondaryLabel
            guard indexPath.row < alaCartePacks.count else { return cell }
            let pack = alaCartePacks[indexPath.row]
            cell.imageView?.image = UIImage(named: "math")
            cell.textLabel?.text = pack.name
            cell.detailTextLabel?.text = nil
            configureAccessory(for: cell, unlocked: !Monetization.isLocked(pack: pack),
                               priceText: price(for: StoreManager.shared.product(for: pack), fallback: "$1.99"))
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
            let toggleIndex = indexPath.row - 1 // row 0 is Restore Purchases
            // Last row: Pro-gated iCloud Sync.
            if toggleIndex == controlToggles.count {
                if Monetization.isProEntitled {
                    let reuseIdentifier = String(describing: SwitchCell.self)
                    let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
                    cell.selectionStyle = .none
                    cell.imageView?.image = UIImage(named: "switch")
                    cell.textLabel?.text = NSLocalizedString("iCloud Sync", comment: "Store toggle for syncing packs, snippets and layouts across devices")
                    cell.switchView.isOn = UserPrefs.iCloudSyncEnabled
                    cell.valueChanged = { switchView in
                        UserPrefs.iCloudSyncEnabled = switchView.isOn
                        if switchView.isOn { CloudSync.start() }
                        SettingsSync.post()
                    }
                    return cell
                }
                let reuseIdentifier = "iCloudLockedCell"
                let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .default, reuseIdentifier: reuseIdentifier)
                cell.imageView?.image = UIImage(named: "switch")
                cell.textLabel?.text = NSLocalizedString("iCloud Sync", comment: "Store toggle for syncing packs, snippets and layouts across devices")
                let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
                lock.tintColor = .tertiaryLabel
                cell.accessoryView = lock
                return cell
            }
            let reuseIdentifier = String(describing: SwitchCell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.selectionStyle = .none
            let toggles = controlToggles
            if toggleIndex >= 0, toggleIndex < toggles.count {
                let toggle = toggles[toggleIndex]
                cell.imageView?.image = UIImage(named: toggle.image)
                cell.textLabel?.text = toggle.title
                cell.switchView.isOn = toggle.get()
                cell.valueChanged = { switchView in
                    toggle.set(switchView.isOn)
                    SettingsSync.post()
                }
            }
            return cell
        case .featureFlags:
            let reuseIdentifier = "FeatureFlagCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? SwitchCell ?? SwitchCell(style: .subtitle, reuseIdentifier: reuseIdentifier)
            cell.selectionStyle = .none
            cell.imageView?.image = nil
            guard indexPath.row < FeatureFlags.all.count else { return cell }
            let flag = FeatureFlags.all[indexPath.row]
            cell.textLabel?.text = flag.title
            cell.detailTextLabel?.text = flag.subtitle
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.detailTextLabel?.numberOfLines = 0
            cell.switchView.isOn = flag.get()
            cell.valueChanged = { switchView in
                flag.set(switchView.isOn)
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
            } else if indexPath.row == 1 {
                cell.imageView?.image = UIImage(named: "star")
                cell.textLabel?.text = "Simulate Pro Entitlement"
                cell.switchView.isOn = Monetization.debugProOverride
                cell.valueChanged = { [weak self] switchView in
                    Monetization.debugProOverride = switchView.isOn
                    SettingsSync.post()
                    self?.tableView.reloadData()
                }
            } else {
                cell.imageView?.image = UIImage(named: "keyboard")
                cell.textLabel?.text = "Force Locked State"
                cell.switchView.isOn = Monetization.debugForceLocked
                cell.valueChanged = { [weak self] switchView in
                    Monetization.debugForceLocked = switchView.isOn
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
            buy(indexPath.row == 1 ? StoreManager.shared.earlyBirdProduct : StoreManager.shared.proProduct)
        case .packs:
            guard indexPath.row < alaCartePacks.count else { return }
            let pack = alaCartePacks[indexPath.row]
            guard Monetization.isLocked(pack: pack) else { return } // already owned or covered by Pro
            buy(StoreManager.shared.product(for: pack))
        case .controls:
            if indexPath.row == 0 {
                restore()
            } else if indexPath.row == 1 + controlToggles.count, !Monetization.isProEntitled {
                // Tapping the locked iCloud Sync row offers Pro (which unlocks it).
                buy(StoreManager.shared.proProduct)
            }
        case .featureFlags, .debug:
            break
        }
    }
}
