//
//  PriceAnchoring.swift
//  NumPad
//
//  Pure price math for the Store screen's "all packs separately" anchoring line and the
//  post-pack-purchase "Complete the set" upsell delta. Kept free of StoreKit/UIKit so the
//  arithmetic is unit-testable without live products — StoreViewController supplies the
//  `Decimal` prices (from `Product.price`) and formats the result with `Product.priceFormatStyle`
//  so the string stays in the product's real currency/locale.
//

import Foundation

enum PriceAnchoring {
    /// Sum of the given prices, or `nil` if any price is missing — i.e. a product hasn't finished
    /// loading from the App Store yet. Callers should omit the anchoring line entirely rather than
    /// show a partial total.
    static func sum(of prices: [Decimal?]) -> Decimal? {
        var total = Decimal(0)
        for price in prices {
            guard let price = price else { return nil }
            total += price
        }
        return total
    }

    /// Pro price minus an already-owned pack's price — the "complete the set" upgrade cost shown
    /// in the post-purchase upsell. Returns `nil` (callers should fall back to the full Pro price)
    /// when either price is missing, or when the difference isn't a genuine discount (an owned
    /// pack priced at or above Pro, which should never happen but must never be presented as a
    /// zero/negative upgrade).
    static func upgradeDelta(proPrice: Decimal?, ownedPackPrice: Decimal?) -> Decimal? {
        guard let proPrice = proPrice, let ownedPackPrice = ownedPackPrice else { return nil }
        let delta = proPrice - ownedPackPrice
        guard delta > 0 else { return nil }
        return delta
    }
}
