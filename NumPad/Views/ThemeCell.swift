//
//  ThemeCell.swift
//  NumPad
//
//  Created by Lasha Efremidze on 4/3/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import DynamicColor

class ThemeCell: Cell {
    lazy var radioButton: RadioButton = configure(RadioButton()) {
        self.contentView.addSubview($0)
        $0.leadingAndCenterY(to: self.contentView, offset: 15)
        $0.size(CGSize(width: 15, height: 15))
    }
}

class RadioButton: UIView {
    lazy var innerCircle: UIView = { [unowned self] in
        let view = UIView()
        self.addSubview(view)
        view.edgesToSuperview(insets: .uniform(2))
        return view
    }()
    var color: UIColor? {
        didSet {
            innerCircle.backgroundColor = color?.withAlphaComponent(0.8)
            layer.borderColor = (color == .white ? UIColor(white: 0, alpha: 0.5) : color)?.cgColor
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        
        innerCircle.layer.cornerRadius = innerCircle.frame.width / 2
        
        backgroundColor = .clear
        layer.borderWidth = 1
        layer.cornerRadius = frame.width / 2
    }
}
