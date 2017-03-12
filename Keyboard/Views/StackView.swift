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
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 1
        self.addSubview(stackView)
        stackView.constrainToEdges()
        return stackView
    }()
    
    func configure(_ items: [[Item]], block: (Position, Item, Cell) -> Void, touchDown: @escaping (Position, Item) -> Void, tapped: @escaping (Position, Item) -> Void) {
        for (row, rowItems) in items.enumerated() {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.spacing = 1
            for (column, item) in rowItems.enumerated() {
                let position = (row, column)
                let cell = Cell()
                cell.configure(item)
                block(position, item, cell)
                cell.buttonTouchDown = { _ in touchDown(position, item) }
                cell.buttonTapped = { _ in tapped(position, item) }
                stackView.addArrangedSubview(cell)
            }
            verticalStackView.addArrangedSubview(stackView)
        }
    }
    
}
