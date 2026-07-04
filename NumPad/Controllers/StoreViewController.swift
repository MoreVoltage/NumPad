//
//  StoreViewController.swift
//  NumPad
//
//  Real StoreKit 2 store: NumPad Pro (lifetime), the à la carte packs, restore, plus the keyboard
//  behavior toggles that previously lived here. The sales-facing hero header (theme preview
//  strip, price anchoring, Free-vs-Pro comparison, CTA button) lives in
//  StoreViewController+Hero.swift — this file owns the table's rows/actions.
//

import UIKit
import StoreKit

class StoreViewController: TableViewController {
    private enum Section: Int, CaseIterable { case pro, packs, restore, controls, featureFlags, debug }

    /// Sections visible in this build, purchase content first and behavior toggles last. Always
    /// show the purchase + settings sections; show the experimental Feature Flags section in
    /// DEBUG/TestFlight only (`experimentalUIVisible`); show the paywall/entitlement simulation
    /// toggles in DEBUG only — they must never ship to users.
    private static var visibleSections: [Section] {
        var sections: [Section] = [.pro, .packs, .restore, .controls]
        if FeatureFlags.experimentalUIVisible { sections.append(.featureFlags) }
        #if DEBUG
        sections.append(.debug)
        #endif
        return sections
    }

    /// The à la carte packs sold individually ($1.99 each), in display order. Internal (not
    /// private): StoreViewController+Hero.swift reads it for the price-anchoring line.
    var alaCartePacks: [KeyboardType] {
        KeyboardType.packs.filter { !ProductCatalog.isBasePack($0) && !ProductCatalog.isProOnlyPack($0) }
    }

    /// The hero's content stack, held so it can be re-measured (rotation, Dynamic Type) without
    /// walking `tableHeaderView.subviews`. Built in `makeHeroHeader()` (StoreViewController+Hero.swift).
    weak var heroStackView: UIStackView?

    private var entitlementObserver: NSObjectProtocol?
    private var isPurchasing = false

    /// Where the user came from, for funnel analytics: "home" (settings row), "packs" (locked
    /// pack row), "key_lock" / "pack_picker" (keyboard deep links), "features_guide" (Features &
    /// Guide Pro row). Set before presentation.
    var source: String = "home"
    private var didLogView = false

    override func viewDidLoad() {
        super.viewDidLoad()

        interactiveNavigationBarHidden = false
        navigationItem.title = NSLocalizedString("NumPad Pro", comment: "Store screen navigation title")
        refreshHero()

        // Refresh the hero + rows whenever an entitlement changes (purchase, restore, Transaction.updates).
        entitlementObserver = NotificationCenter.default.addObserver(forName: StoreManager.entitlementsDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.refreshHero()
        }

        // Make sure prices are loaded; refresh the hero (CTA price, anchoring line) once they arrive.
        Task { [weak self] in
            await StoreManager.shared.loadProducts()
            await MainActor.run { self?.refreshHero() }
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
        // tableHeaderView ignores Auto Layout, so it's resized manually here (in viewDidLoad the
        // final width isn't known yet). See StoreViewController+Hero.swift for the sizing math.
        resizeHeroHeaderIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Dynamic Type changes the hero's required height without changing its width, so a
        // width-only check would miss it — force a re-measure (and re-render the rows' text).
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else { return }
        resizeHeroHeaderIfNeeded()
        tableView.reloadData()
    }

    deinit {
        if let observer = entitlementObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Rebuilds the hero header — its CTA price, anchoring line, and comparison table all depend
    /// on live StoreKit/entitlement data — and reloads the rows. Called on load, on every
    /// entitlement change, and once products finish loading.
    func refreshHero() {
        tableView.tableHeaderView = makeHeroHeader()
        resizeHeroHeaderIfNeeded()
        tableView.reloadData()
    }

    // MARK: - State helpers

    /// Internal (not private): StoreViewController+Hero.swift reads it to decide whether the hero
    /// still needs to sell Pro (CTA, anchoring line, comparison table) or just thank the owner.
    var isProUnlocked: Bool { Monetization.isProEntitled }
    private var isFinanceUnlocked: Bool { Monetization.isProEntitled || Monetization.isFinancePackPurchased }

    /// Internal (not private): shared with the hero's CTA button and price-anchoring fallback.
    func price(for product: Product?, fallback: String) -> String {
        return product?.displayPrice ?? fallback
    }

    // MARK: - Purchase / restore actions

    /// Internal (not private): the hero's CTA button buys Pro directly through this same path.
    func buy(_ product: Product?) {
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
                        self.refreshHero()
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
            var completedPackPurchase = false
            do {
                let outcome = try await StoreManager.shared.purchase(product)
                switch outcome {
                case .success:
                    Analytics.logEvent(name: "purchase_completed", attributes: ["product_id": productID, "source": source])
                    // Nudge à la carte buyers toward Pro right after their purchase completes —
                    // never for the Pro/early-bird products themselves.
                    completedPackPurchase = ProductCatalog.allPackProductIDs.contains(productID)
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
                self.refreshHero()
                if pending { self.showPendingAlert() }
                if completedPackPurchase { self.presentCompleteTheSetUpsell(purchasedProduct: product) }
            }
        }
    }

    private func restore() {
        Task { [weak self] in
            let outcome = await StoreManager.shared.restorePurchases()
            await MainActor.run {
                guard let self = self else { return }
                self.refreshHero()
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

    /// "Complete the set": shown once, right after an à la carte pack purchase completes (callers
    /// only pass pack purchases here — never Pro/early-bird). The Upgrade action re-enters the
    /// normal Pro purchase flow so funnel analytics and entitlement handling stay in one place.
    private func presentCompleteTheSetUpsell(purchasedProduct: Product) {
        guard !isProUnlocked else { return }
        Analytics.logEvent(name: "upsell_bundle_shown", attributes: ["product_id": purchasedProduct.id])
        let proProduct = StoreManager.shared.proProduct
        let priceText: String
        if let proProduct = proProduct, let delta = PriceAnchoring.upgradeDelta(proPrice: proProduct.price, ownedPackPrice: purchasedProduct.price) {
            priceText = proProduct.priceFormatStyle.format(delta)
        } else {
            priceText = price(for: proProduct, fallback: "$11.99")
        }
        let alert = UIAlertController(
            title: NSLocalizedString("Complete the Set", comment: "Title for the post-pack-purchase Pro upsell alert"),
            message: String(format: NSLocalizedString("Unlock every other pack, every premium theme, and the customizable keyboard — upgrade to Pro for just %@ more.", comment: "Body for the post-pack-purchase Pro upsell alert; %@ is the upgrade price"), priceText),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Not Now", comment: "Dismiss button for the post-pack-purchase Pro upsell alert"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Upgrade", comment: "Accept button for the post-pack-purchase Pro upsell alert"), style: .default) { [weak self] _ in
            Analytics.logEvent(name: "upsell_bundle_accepted", attributes: ["product_id": purchasedProduct.id])
            self?.buy(StoreManager.shared.proProduct)
        })
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
        label.adjustsFontForContentSizeCategory = true
        label.sizeToFit()
        cell.accessoryType = .none
        cell.accessoryView = label
    }

    /// "BEST VALUE" badge prefixed onto the main Pro row's detail text, so it visually stands out
    /// among the à la carte packs it makes redundant. Both runs use `preferredFont`-derived fonts
    /// so `adjustsFontForContentSizeCategory` scales the whole thing at any Dynamic Type size.
    private func bestValueDetailText(_ detail: String) -> NSAttributedString {
        let badgeText = NSLocalizedString("BEST VALUE", comment: "Badge prefix on the Pro store row marking it as the best-value purchase") + "  "
        let result = NSMutableAttributedString(
            string: badgeText,
            attributes: [.font: UIFont.preferredFont(for: .caption1, weight: .bold), .foregroundColor: UIColor.primary]
        )
        result.append(NSAttributedString(
            string: detail,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .caption1), .foregroundColor: UIColor.secondaryLabel]
        ))
        return result
    }

    /// One-line description for an à la carte pack row (mirrors the copy in Features & Guide).
    private func packDetail(for pack: KeyboardType) -> String {
        switch pack {
        case .finance:
            return NSLocalizedString("Currency symbols and finance keys.", comment: "Store pack row detail: finance")
        case .symbols:
            return NSLocalizedString("Common symbols alongside scientific constants and operators.", comment: "Store pack row detail: symbols")
        case .programmer:
            return NSLocalizedString("Bitwise operators and hex and binary prefixes.", comment: "Store pack row detail: programmer")
        case .datetime:
            return NSLocalizedString("Insert today's date, the time, and more live values.", comment: "Store pack row detail: date & time")
        case .units:
            return NSLocalizedString("Length, mass, and temperature keys, plus a live offline converter.", comment: "Store pack row detail: units & conversion")
        case .cooking:
            return NSLocalizedString("Cooking fractions and volume keys, plus a live cups-to-ml converter.", comment: "Store pack row detail: cooking & baking")
        default:
            return ""
        }
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
        case .restore: return nil
        case .controls: return NSLocalizedString("Settings", comment: "")
        case .featureFlags: return NSLocalizedString("Feature Flags (Beta)", comment: "Store section title for experimental feature toggles")
        case .debug: return "Debug"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section < Self.visibleSections.count else { return nil }
        if Self.visibleSections[section] == .featureFlags {
            return NSLocalizedString("Experimental features and escape hatches, visible in TestFlight and debug builds only. Most are off by default; a flag whose subtitle says otherwise defaults on for everyone.", comment: "Footer explaining the feature flags section")
        }
        return nil
    }

    /// Behavior toggles shown in the Settings (controls) section, after the purchase rows and
    /// Restore Purchases above. Data-driven so the row count and rendering can't drift apart. Each
    /// persists to UserPrefs + posts SettingsSync so a running keyboard reacts immediately. The
    /// last four were promoted from experimental flags in 2.0.
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
        case .restore: return 1
        case .controls: return controlToggles.count + 1 // behavior toggles + iCloud Sync (Pro)
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
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.adjustsFontForContentSizeCategory = true
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
            if indexPath.row == 1 {
                // Early-bird discounted Pro — only present while the offer is active.
                cell.textLabel?.text = NSLocalizedString("Early-bird: 50% off Pro", comment: "Store row title for the discounted early-bird Pro")
                cell.detailTextLabel?.text = NSLocalizedString("Limited time for early users — everything Pro unlocks, at half price.", comment: "Store row detail for the early-bird Pro")
                configureAccessory(for: cell, unlocked: isProUnlocked, priceText: price(for: StoreManager.shared.earlyBirdProduct, fallback: "$5.99"))
                return cell
            }
            cell.textLabel?.text = NSLocalizedString("Everything, forever", comment: "Store row title for the lifetime Pro purchase")
            let detail = NSLocalizedString("Every pack, premium themes, the customizable keyboard, iCloud sync, and every future pack.", comment: "Store row detail listing what Pro includes")
            if isProUnlocked {
                cell.detailTextLabel?.text = detail
            } else {
                cell.detailTextLabel?.attributedText = bestValueDetailText(detail)
            }
            configureAccessory(for: cell, unlocked: isProUnlocked, priceText: price(for: StoreManager.shared.proProduct, fallback: "$11.99"))
            return cell
        case .packs:
            let reuseIdentifier = "ProductCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .subtitle, reuseIdentifier: reuseIdentifier)
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.adjustsFontForContentSizeCategory = true
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
            guard indexPath.row < alaCartePacks.count else { return cell }
            let pack = alaCartePacks[indexPath.row]
            cell.imageView?.image = UIImage(named: "math")
            cell.textLabel?.text = pack.name
            cell.detailTextLabel?.text = packDetail(for: pack)
            configureAccessory(for: cell, unlocked: !Monetization.isLocked(pack: pack),
                               priceText: price(for: StoreManager.shared.product(for: pack), fallback: "$1.99"))
            return cell
        case .restore:
            let reuseIdentifier = String(describing: Cell.self)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? Cell(style: .default, reuseIdentifier: reuseIdentifier)
            cell.imageView?.image = UIImage(named: "switch")
            cell.textLabel?.text = NSLocalizedString("Restore Purchases", comment: "Store row to restore previous purchases")
            cell.textLabel?.numberOfLines = 0
            cell.accessoryType = .none
            cell.accessoryView = nil
            return cell
        case .controls:
            // Last row: Pro-gated iCloud Sync.
            if indexPath.row == controlToggles.count {
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
            if indexPath.row >= 0, indexPath.row < toggles.count {
                let toggle = toggles[indexPath.row]
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
                    self?.refreshHero()
                }
            } else if indexPath.row == 1 {
                cell.imageView?.image = UIImage(named: "star")
                cell.textLabel?.text = "Simulate Pro Entitlement"
                cell.switchView.isOn = Monetization.debugProOverride
                cell.valueChanged = { [weak self] switchView in
                    Monetization.debugProOverride = switchView.isOn
                    SettingsSync.post()
                    self?.refreshHero()
                }
            } else {
                cell.imageView?.image = UIImage(named: "keyboard")
                cell.textLabel?.text = "Force Locked State"
                cell.switchView.isOn = Monetization.debugForceLocked
                cell.valueChanged = { [weak self] switchView in
                    Monetization.debugForceLocked = switchView.isOn
                    SettingsSync.post()
                    self?.refreshHero()
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
        case .restore:
            restore()
        case .controls:
            if indexPath.row == controlToggles.count, !Monetization.isProEntitled {
                // Tapping the locked iCloud Sync row offers Pro (which unlocks it).
                buy(StoreManager.shared.proProduct)
            }
        case .featureFlags, .debug:
            break
        }
    }
}
