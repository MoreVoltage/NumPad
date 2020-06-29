//
//  StackView.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 6/26/20.
//  Copyright © 2020 MoreVoltage. All rights reserved.
//

import UIKit
import TinyConstraints

class StackView: UIView {
    lazy var verticalStackView: UIStackView = { [unowned self] in
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        self.addSubview(stackView)
        stackView.edgesToSuperview()
        return stackView
    }()
    
    func configure(_ items: [[Item]], keyboardType: KeyboardType, roundedCorners: Bool, grid: Bool, block: (Position, Item, Cell) -> Void, touchDown: @escaping (Position, Item) -> Void, tapped: @escaping (Position, Item) -> Void) {
        verticalStackView.spacing = roundedCorners ? 2 : grid ? 1 : 0
        for (row, rowItems) in items.enumerated() {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.spacing = verticalStackView.spacing
            for (column, item) in rowItems.enumerated() {
                let position = (row, column)
                let cell = Cell()
                cell.configure(item, roundedCorners: roundedCorners, touchDown: {
                    touchDown(position, item)
                }, tapped: {
                    tapped(position, item)
                })
                block(position, item, cell)
                if items.count - row < 5, column == rowItems.count - 1 {
//                    cell.width = 595
                } else {
//                    cell.width = 1000
                }
                stackView.addArrangedSubview(cell)
                if items.count - row < 5, column == rowItems.count - 1 {
                    cell.width(to: stackView.subviews.first!, multiplier: 0.7)
                }
                cell.constrain {[
                    $0.widthAnchor.constraint(equalTo: stackView.widthAnchor, multiplier: 0.18)
                ]}
            }
            verticalStackView.addArrangedSubview(stackView)
        }
    }
    
    lazy var cells: [Cell] = verticalStackView.arrangedSubviews.compactMap { ($0 as? UIStackView)?.arrangedSubviews as? [Cell] }.reduce([], +)
}
