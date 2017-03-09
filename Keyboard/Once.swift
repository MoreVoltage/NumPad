//
//  Once.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/9/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import Fabric
import Crashlytics

class Once {
    static let run: Void = {
        Fabric.with([Crashlytics.self])
        return ()
    }()
}
