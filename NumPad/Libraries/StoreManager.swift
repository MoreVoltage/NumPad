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
        /// Non-consumable: unlocks every pack, premium themes, the customizable keyboard, and sync.
        static let proLifetime = ProductCatalog.pro
        /// 50%-off Pro for grandfathered users in their early-bird window (grants identical Pro).
        static let proEarlyBird = ProductCatalog.proEarlyBird
        /// Non-consumable: the Finance pack (one of the à la carte packs).
        static let financePack = "numpad.pack.finance"
        /// Every product the app sells (Pro + early-bird + all à la carte packs).
        static var all: [String] { ProductCatalog.allProductIDs }
    }

    /// Loaded App Store products, keyed by product ID.
    private(set) var products: [String: Product] = [:]

    /// Convenience accessors for the two known products.
    var proProduct: Product? { products[ProductID.proLifetime] }
    var earlyBirdProduct: Product? { products[ProductID.proEarlyBird] }
    var financeProduct: Product? { products[ProductID.financePack] }
    /// The à la carte product for a pack, if loaded.
    func product(for pack: KeyboardType) -> Product? {
        guard let id = ProductCatalog.packProductID(for: pack) else { return nil }
        return products[id]
    }

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
            // Cold launch: never downgrade — StoreKit may not be ready yet. A foreground refresh
            // (refreshEntitlementsOnForeground) applies any genuine revocation once it is.
            await shared.refreshEntitlements(allowDowngrade: false)
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

    /// Outcome of a purchase attempt, so the caller can give the right feedback.
    enum PurchaseOutcome {
        case success
        case userCancelled
        /// Ask to Buy / SCA: the entitlement arrives later via `Transaction.updates`.
        case pending
    }

    /// Purchase a product. Throws only on a real error (verification/StoreKit). A user cancel or a
    /// pending (Ask to Buy) result is reported via the return value rather than thrown.
    @discardableResult
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            applyEntitlement(for: transaction.productID, revoked: transaction.revocationDate != nil)
            await transaction.finish()
            persistAndNotify()
            Analytics.logEvent(name: "purchase_succeeded", attributes: ["product_id": product.id])
            return .success
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    /// Outcome of a restore attempt.
    enum RestoreOutcome {
        case restored
        case nothingToRestore
        /// `AppStore.sync()` failed (offline / sign-in cancelled) — distinct from "nothing found".
        case failed
    }

    /// Restore previous purchases: sync with the App Store, then walk current entitlements.
    @discardableResult
    func restorePurchases() async -> RestoreOutcome {
        do {
            // AppStore.sync() forces an App Store sign-in if needed and refreshes receipts.
            try await AppStore.sync()
        } catch {
            // Don't claim "no purchases found" when we simply couldn't reach the App Store.
            return .failed
        }
        await refreshEntitlements(allowDowngrade: true)
        let restored = Monetization.isProPurchased || Monetization.isGrandfathered || !Monetization.ownedPackProductIDs.isEmpty
        Analytics.logEvent(name: "restore_completed", attributes: [
            "pro": Monetization.isProPurchased,
            "finance": Monetization.isFinancePackPurchased
        ])
        return restored ? .restored : .nothingToRestore
    }

    /// Recompute owned products from `Transaction.currentEntitlements`.
    ///
    /// - Parameter allowDowngrade: when `true`, an absent entitlement clears the stored flag
    ///   (so refunds/revocations re-lock content). When `false`, the flags are only ever *raised*,
    ///   never cleared — used at cold launch, where `currentEntitlements` can transiently return
    ///   empty before StoreKit is ready and would otherwise wrongly re-lock a paid user mid-session.
    ///   Genuine revocations are still caught on the next foreground refresh (`allowDowngrade: true`).
    func refreshEntitlements(allowDowngrade: Bool = true) async {
        var ownsPro = false
        var ownedPacks: Set<String> = []
        let packIDs = Set(ProductCatalog.allPackProductIDs)
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            let pid = transaction.productID
            if pid == ProductID.proLifetime || pid == ProductID.proEarlyBird {
                ownsPro = true
            } else if packIDs.contains(pid) {
                ownedPacks.insert(pid)
            }
        }
        if allowDowngrade {
            Monetization.isProPurchased = ownsPro
            Monetization.ownedPackProductIDs = ownedPacks
        } else {
            // Cold launch: only ever raise entitlements (currentEntitlements can be transiently empty).
            if ownsPro { Monetization.isProPurchased = true }
            Monetization.ownedPackProductIDs.formUnion(ownedPacks)
        }
        Monetization.isFinancePackPurchased = Monetization.ownedPackProductIDs.contains(ProductID.financePack)
        persistAndNotify()
    }

    /// Re-derive entitlements when the app returns to the foreground. StoreKit is ready by then, so
    /// downgrades (refunds, family-sharing revocations, or a tampered flag) are applied promptly.
    static func refreshEntitlementsOnForeground() {
        Task { await shared.refreshEntitlements(allowDowngrade: true) }
    }

    // MARK: - Grandfathering

    /// Users whose original download predates 1.7.0 keep everything free.
    /// Runs once; the result is cached in the app group.
    ///
    /// IMPORTANT: `originalAppVersion` is only meaningful in the **production** environment.
    /// In the sandbox (App Review, TestFlight) and the Xcode StoreKit environment it always
    /// returns "1.0", which would grandfather every reviewer and tester — making Pro appear
    /// already unlocked and the purchase flow impossible to exercise (App Review rejection
    /// 2.1(b), submission 9181d011). So grandfathering is only ever granted when
    /// `AppTransaction.environment == .production`.
    ///
    /// The cache key is versioned (v2): installs that cached a bogus sandbox-derived
    /// grandfathering under the v1 key recompute once with the environment guard. Recomputing
    /// is idempotent for production users — `AppTransaction.shared` is read locally without
    /// prompting, and their real originalAppVersion yields the same result.
    func checkGrandfatheringIfNeeded() async {
        let defaults = UserDefaults.group
        guard defaults.bool(forKey: Constants.grandfatherCheckedV2.rawValue) == false else { return }

        if #available(iOS 16.0, *) {
            // AppTransaction.shared reads the locally cached signed app transaction.
            // Do NOT use AppTransaction.refresh() — that can prompt for App Store sign-in.
            let appTransaction = try? await AppTransaction.shared
            let migration: GrandfatherMigrationResult
            if let appTransaction,
               case .verified(let verified) = appTransaction {
                migration = Self.grandfatherMigrationResult(
                    appTransactionAvailable: true,
                    isProduction: verified.environment == .production,
                    originalAppVersion: verified.originalAppVersion
                )
            } else {
                migration = Self.grandfatherMigrationResult(
                    appTransactionAvailable: false,
                    isProduction: false,
                    originalAppVersion: nil
                )
            }

            Monetization.isGrandfathered = migration.isGrandfathered
            if migration.markChecked {
                defaults.set(true, forKey: Constants.grandfatherCheckedV2.rawValue)
            }
            persistAndNotify()
            // If unavailable/unverified, the v2 flag stays unset so we retry next launch, but any
            // stale v1 sandbox-derived unlock is cleared immediately.
        } else {
            // iOS 15 has no AppTransaction. Anyone still on iOS 15 installed long before
            // 1.7.0 shipped — grandfather them. Acceptable generosity. (App Review devices
            // run current OS versions, so this path never affects review.)
            Monetization.isGrandfathered = true
            defaults.set(true, forKey: Constants.grandfatherCheckedV2.rawValue)
            persistAndNotify()
        }
    }

    struct GrandfatherMigrationResult {
        let isGrandfathered: Bool
        let markChecked: Bool
    }

    static func grandfatherMigrationResult(appTransactionAvailable: Bool,
                                           isProduction: Bool,
                                           originalAppVersion: String?) -> GrandfatherMigrationResult {
        guard appTransactionAvailable else {
            return GrandfatherMigrationResult(isGrandfathered: false, markChecked: false)
        }
        guard isProduction, let originalAppVersion else {
            return GrandfatherMigrationResult(isGrandfathered: false, markChecked: true)
        }
        return GrandfatherMigrationResult(
            isGrandfathered: isVersion(originalAppVersion, lessThan: "1.7.0"),
            markChecked: true
        )
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
        // Fail closed: an unparseable version (no leading numeric components) is treated as NOT
        // older than `rhs`, so grandfathering is denied rather than granted on bad/tampered input.
        guard !a.isEmpty else { return false }
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
        if productID == ProductID.proLifetime || productID == ProductID.proEarlyBird {
            Monetization.isProPurchased = !revoked
        } else if Set(ProductCatalog.allPackProductIDs).contains(productID) {
            var owned = Monetization.ownedPackProductIDs
            if revoked { owned.remove(productID) } else { owned.insert(productID) }
            Monetization.ownedPackProductIDs = owned
            if productID == ProductID.financePack { Monetization.isFinancePackPurchased = !revoked }
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
