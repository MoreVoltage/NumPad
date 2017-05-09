//
//  ThemeCell.swift
//  NumPad
//
//  Created by Lasha Efremidze on 4/3/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import DynamicColor

class ThemeCell: Cell {
    
    lazy var radioButton: RadioButton = { [unowned self] in
        let view = RadioButton()
        self.contentView.addSubview(view)
        return view
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size: CGFloat = 15
        imageView?.frame.size = CGSize(width: size, height: size)
        imageView?.center.x = 26
        imageView?.center.y = contentView.center.y
        
        radioButton.frame = imageView!.frame
    }
    
}

class RadioButton: UIView {
    lazy var innerCircle: UIView = { [unowned self] in
        let view = UIView()
        self.addSubview(view)
        view.constrainToEdges(UIEdgeInsetsMake(2, 2, -2, -2))
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
