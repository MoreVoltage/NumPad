//
//  StackView.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/10/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

typealias Position = (Int, Int)

class StackView: UIView {
    
    lazy var verticalStackView: UIStackView = { [unowned self] in
        let stackView = UIStackView()
        stackView.frame.size = self.frame.size
        stackView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 1
        self.addSubview(stackView)
//        stackView.constrainToEdges()
        return stackView
    }()
    
    func configure(_ items: [[Item]], block: (Position, Item, Cell) -> Void, touchDown: @escaping (Position, Item) -> Void, tapped: @escaping (Position, Item) -> Void) {
        for (row, rowItems) in items.enumerated() {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fill
            stackView.spacing = 1
            
            let stackView2 = UIStackView()
            stackView2.axis = .horizontal
            stackView2.distribution = .fillEqually
            stackView2.spacing = 1
            stackView.addArrangedSubview(stackView2)
            
            for (column, item) in rowItems.enumerated() {
                let position = (row, column)
                let cell = Cell()
                cell.configure(item)
                block(position, item, cell)
                cell.buttonTouchDown = { _ in touchDown(position, item) }
                cell.buttonTapped = { _ in tapped(position, item) }
                if column == rowItems.count - 1 {
                    stackView.addArrangedSubview(cell)
                    cell.button.constrain {[
                        $0.widthAnchor.constraint(equalTo: stackView.widthAnchor, multiplier: 0.18)
                    ]}
                } else {
                    stackView2.addArrangedSubview(cell)
                }
            }
            verticalStackView.addArrangedSubview(stackView)
        }
    }
    
}
