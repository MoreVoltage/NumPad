//
//  TinyConstraintsExtensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 11/1/20.
//  Copyright © 2020 MoreVoltage. All rights reserved.
//

import TinyConstraints

extension View {
    func leadingAndCenterY(to view: TinyConstraints.Constrainable, offset: CGFloat = 0) {
        leading(to: view, offset: offset)
        centerY(to: view)
    }
}
