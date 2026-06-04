//
//  StoreManager.swift
//  NumPad
//
//  StoreKit 2 purchase handling for NumPad Pro and the Finance Pack.
//  App target only — the keyboard extension reads entitlements from
//  UserDefaults.group via the Monetization flags in SharedExtensions.swift.
//

import Foundation
import StoreKit

final class StoreManager {

    static let shared = StoreManager()

    enum ProductID {
        /// Non-consumable: unlocks every pack and every premium theme, forever.
        static let proLifetime = "numpad.pro.lifetime"
        /// Non-consumable: unlocks the Finance pack only.
        static let financePack = "numpad.pack.finance"
        static let all: [String] = [proLifetime, financePack]
    }

    /// Loaded App Store products, keyed by product ID.
    private(set) var products: [String: Product] = [:]

    /// Convenience accessors for the two known products.
    var proProduct: Product? { products[ProductID.proLifetime] }
    var financeProduct: Product? { products[ProductID.financePack] }

    private var updatesTask: Task<Void, Never>?

    private init() {
        // Listen for transaction updates (purchases from other devices, Ask to Buy
        // approvals, refunds) for the lifetime of the app.
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// One-shot startup: grandfather check, product load, and entitlement refresh.
    /// Call once from app launch (mirrors RemoteConfigManager.start()).
    static func start() {
        Task {
            await shared.checkGrandfatheringIfNeeded()
            await shared.loadProducts()
            await shared.refreshEntitlements()
        }
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProductID.all)
            var map: [String: Product] = [:]
            for product in loaded {
                map[product.id] = product
            }
            products = map
        } catch {
            // Leave products empty; the Store screen shows placeholder pricing
            // and the next loadProducts() call can retry.
        }
    }

    // MARK: - Purchasing

    enum StoreError: Error {
        case failedVerification
    }

    /// Purchase a product. Throws on failure. `userCancelled` and `pending` results are
    /// handled silently — cancellation needs no feedback, and Ask to Buy / SCA entitlements
    /// arrive later via Transaction.updates.
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            applyEntitlement(for: transaction.productID, revoked: transaction.revocationDate != nil)
            await transaction.finish()
            persistAndNotify()
            Analytics.logEvent(name: "purchase_succeeded", attributes: ["product_id": product.id])
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    /// Restore previous purchases: sync with the App Store, then walk current entitlements.
    func restorePurchases() async {
        // AppStore.sync() forces an App Store sign-in if needed and refreshes receipts.
        try? await AppStore.sync()
        await refreshEntitlements()
        Analytics.logEvent(name: "restore_completed", attributes: [
            "pro": Monetization.isProPurchased,
            "finance": Monetization.isFinancePackPurchased
        ])
    }

    /// Recompute owned products from Transaction.currentEntitlements.
    func refreshEntitlements() async {
        var ownsPro = false
        var ownsFinance = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            switch transaction.productID {
            case ProductID.proLifetime: ownsPro = true
            case ProductID.financePack: ownsFinance = true
            default: break
            }
        }
        Monetization.isProPurchased = ownsPro
        Monetization.isFinancePackPurchased = ownsFinance
        persistAndNotify()
    }

    // MARK: - Grandfathering

    /// Users whose original download predates 1.7.0 keep everything free.
    /// Runs once; the result is cached in the app group.
    func checkGrandfatheringIfNeeded() async {
        let defaults = UserDefaults.group
        guard defaults.bool(forKey: Constants.grandfatherChecked.rawValue) == false else { return }

        if #available(iOS 16.0, *) {
            // AppTransaction.shared reads the locally cached signed app transaction.
            // Do NOT use AppTransaction.refresh() — that can prompt for App Store sign-in.
            if let result = try? await AppTransaction.shared,
               case .verified(let appTransaction) = result {
                let original = appTransaction.originalAppVersion
                Monetization.isGrandfathered = Self.isVersion(original, lessThan: "1.7.0")
                defaults.set(true, forKey: Constants.grandfatherChecked.rawValue)
                persistAndNotify()
            }
            // If unavailable/unverified, leave the flag unset so we retry next launch.
        } else {
            // iOS 15 has no AppTransaction. Anyone still on iOS 15 installed long before
            // 1.7.0 shipped — grandfather them. Acceptable generosity.
            Monetization.isGrandfathered = true
            defaults.set(true, forKey: Constants.grandfatherChecked.rawValue)
            persistAndNotify()
        }
    }

    /// Compare leading dotted-numeric components of two version strings.
    /// Non-numeric trailing parts are ignored; missing components count as 0.
    static func isVersion(_ lhs: String, lessThan rhs: String) -> Bool {
        func components(_ s: String) -> [Int] {
            var result: [Int] = []
            for part in s.split(separator: ".") {
                guard let n = Int(part.prefix(while: { $0.isNumber })), part.first?.isNumber == true else { break }
                result.append(n)
            }
            return result
        }
        let a = components(lhs)
        let b = components(rhs)
        // Treat an unparseable version (no leading numeric components) as old → grandfathered.
        guard !a.isEmpty else { return true }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    // MARK: - Private

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(result) else { return }
        applyEntitlement(for: transaction.productID, revoked: transaction.revocationDate != nil)
        await transaction.finish()
        persistAndNotify()
    }

    private func applyEntitlement(for productID: String, revoked: Bool) {
        switch productID {
        case ProductID.proLifetime:
            Monetization.isProPurchased = !revoked
        case ProductID.financePack:
            Monetization.isFinancePackPurchased = !revoked
        default:
            break
        }
    }

    /// Flush the group defaults and tell the keyboard extension to re-read them.
    private func persistAndNotify() {
        SettingsSync.post()
        NotificationCenter.default.post(name: StoreManager.entitlementsDidChange, object: nil)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    /// In-process notification for UI (Store screen) refreshes.
    static let entitlementsDidChange = Notification.Name("com.morevoltage.numpad.entitlementsDidChange")
}
