//
//  Analytics.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 5/10/18.
//  Copyright © 2018 MoreVoltage. All rights reserved.
//

import Fabric
import Crashlytics
import Firebase

extension Analytics {
    static let start: Void = {
        Fabric.with([Crashlytics.self])
        FirebaseApp.configure()
    }()
}
