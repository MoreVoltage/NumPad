//
//  StoreKit.swift
//  NumPad
//
//  Created by Lasha Efremidze on 11/8/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import SwiftyStoreKit

struct StoreKit {
    static func getProducts() {
        SwiftyStoreKit.retrieveProductsInfo(["com.morevoltage.numpad.FinancePack"]) { result in
            for product in result.retrievedProducts {
                let priceString = product.localizedPrice!
                print("Product: \(product.localizedDescription), price: \(priceString)")
            }
            for id in result.invalidProductIDs {
                print("Invalid product identifier: \(id)")
            }
            print("Error: \(result.error)")
        }
    }
}
