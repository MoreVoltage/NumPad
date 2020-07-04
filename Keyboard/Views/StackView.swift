//
//  StackView.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 6/26/20.
//  Copyright © 2020 MoreVoltage. All rights reserved.
//

import UIKit
import TinyConstraints

typealias Position = (Int, Int)

class StackView: UIView {
    lazy var verticalStackView: UIStackView = { [unowned self] in
        let stackView = UIStackView(axis: .vertical, distribution: .fillEqually)
        self.addSubview(stackView)
        stackView.edgesToSuperview()
        return stackView
    }()
    
    func configure(_ items: [[Item]], keyboardType: KeyboardType, roundedCorners: Bool, grid: Bool, block: (Position, Item, Cell) -> Void, touchDown: @escaping (Position, Item) -> Void, tapped: @escaping (Position, Item) -> Void) {
        verticalStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let spacing: CGFloat = roundedCorners ? 2 : grid ? 1 : 0
        verticalStackView.spacing = spacing
        for (row, rowItems) in items.enumerated() {
            let outerStackView = UIStackView(axis: .horizontal, distribution: .fill, spacing: spacing)
            let innerStackView = UIStackView(axis: .horizontal, distribution: .fillEqually, spacing: spacing)
            outerStackView.addArrangedSubview(innerStackView)
            
            for (column, item) in rowItems.enumerated() {
                let position = (row, column)
                let cell = Cell(type: .custom)
                cell.configure(item, roundedCorners: roundedCorners, touchDown: {
                    touchDown(position, item)
                }, tapped: {
                    tapped(position, item)
                })
                block(position, item, cell)
                if items.count - row < 5, column == rowItems.count - 1 {
                    cell.width = UIScreen.main.bounds.width * 2 / 11
                    outerStackView.addArrangedSubview(cell)
                } else {
                    innerStackView.addArrangedSubview(cell)
                }
            }
            
            verticalStackView.addArrangedSubview(outerStackView)
        }
    }
    
    lazy var cells: [Cell] = verticalStackView.arrangedSubviews.compactMap { ($0 as? UIStackView)?.arrangedSubviews as? [Cell] }.reduce([], +)
}

private extension UIStackView {
    convenience init(axis: NSLayoutConstraint.Axis, distribution: UIStackView.Distribution, spacing: CGFloat = 0) {
        self.init()
        self.axis = axis
        self.distribution = distribution
        self.spacing = spacing
    }
}
