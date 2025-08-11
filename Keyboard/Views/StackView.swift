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
    
    func configure(_ items: [[Item]], keyboardType: KeyboardType, roundedCorners: Bool, grid: Bool, width: CGFloat, block: (Position, Item, Cell) -> Void, touchDown: @escaping (Position, Item) -> Void, tapped: @escaping (Position, Item) -> Void) {
        verticalStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let spacing: CGFloat = roundedCorners ? 2 : grid ? 1 : 0
        verticalStackView.spacing = spacing
        for (row, rowItems) in items.enumerated() {
            let outerStackView = UIStackView(axis: .horizontal, distribution: .fill, spacing: spacing)
            let innerStackView = UIStackView(axis: .horizontal, distribution: .fillEqually, spacing: spacing)
            if row == 0 && keyboardType != .default {
                // Make the top pack row horizontally scrollable when it overflows
                let scrollView = UIScrollView()
                scrollView.showsHorizontalScrollIndicator = false
                scrollView.alwaysBounceHorizontal = true
                outerStackView.addArrangedSubview(scrollView)
                scrollView.addSubview(innerStackView)
                innerStackView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    innerStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                    innerStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                    innerStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                    innerStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                    innerStackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
                ])
            } else {
                outerStackView.addArrangedSubview(innerStackView)
            }
            
            for (column, item) in rowItems.enumerated() {
                let position = (row, column)
                let cell = Cell(type: .custom)
                cell.configure(item, roundedCorners: roundedCorners, touchDown: {
                    touchDown(position, item)
                }, tapped: {
                    tapped(position, item)
                })
                // Give pack-row cells an intrinsic width when in scroll mode so they render
                if row == 0 && keyboardType != .default {
                    cell.width = 44
                }
                // Add lock chip overlay if paywall is enabled and item is considered premium and not entitled
                if Monetization.paywallEnabled && !Monetization.isProEntitled {
                    // Mark a few premium triggers: math toggle images, finance pack row keys
                    let premiumKeys: Set<String> = ["math", "math2", "%", "$", "€", "£", "¥"]
                    if let title = item.title, premiumKeys.contains(title) || (item.imageName.map { premiumKeys.contains($0) } ?? false) {
                        let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
                        lock.tintColor = UIColor.black.withAlphaComponent(0.35)
                        lock.translatesAutoresizingMaskIntoConstraints = false
                        cell.addSubview(lock)
                        NSLayoutConstraint.activate([
                            lock.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -3),
                            lock.topAnchor.constraint(equalTo: cell.topAnchor, constant: 3),
                            lock.widthAnchor.constraint(equalToConstant: 12),
                            lock.heightAnchor.constraint(equalToConstant: 12)
                        ])
                        // Add a lightweight tooltip label under the lock
                        let tip = UILabel()
                        tip.text = "Unlock"
                        tip.font = .systemFont(ofSize: 9, weight: .semibold)
                        tip.textColor = .white
                        tip.backgroundColor = UIColor.black.withAlphaComponent(0.6)
                        tip.layer.cornerRadius = 3
                        tip.clipsToBounds = true
                        tip.textAlignment = .center
                        tip.translatesAutoresizingMaskIntoConstraints = false
                        cell.addSubview(tip)
                        NSLayoutConstraint.activate([
                            tip.topAnchor.constraint(equalTo: lock.bottomAnchor, constant: 2),
                            tip.centerXAnchor.constraint(equalTo: lock.centerXAnchor),
                            tip.heightAnchor.constraint(equalToConstant: 12)
                        ])
                        // intrinsic width via content insets
                        tip.setContentHuggingPriority(.required, for: .horizontal)
                        tip.setContentCompressionResistancePriority(.required, for: .horizontal)
                        tip.layoutIfNeeded()
                    }
                }
                block(position, item, cell)
                if items.count - row < 5, column == rowItems.count - 1 {
                    cell.width = width * (2 / 11) - 0.75
                    outerStackView.addArrangedSubview(cell)
                } else {
                    innerStackView.addArrangedSubview(cell)
                }
            }
            
            verticalStackView.addArrangedSubview(outerStackView)
        }
    }
    
    lazy var cells: [Cell] = verticalStackView.arrangedSubviews(of: Cell.self)
}

private extension UIStackView {
    convenience init(axis: NSLayoutConstraint.Axis, distribution: UIStackView.Distribution, spacing: CGFloat = 0) {
        self.init()
        self.axis = axis
        self.distribution = distribution
        self.spacing = spacing
    }
    func arrangedSubviews<T>(of type: T.Type) -> [T] {
        return arrangedSubviews.compactMap {
            ($0 as? T).map { [$0] } ?? ($0 as? UIStackView)?.arrangedSubviews(of: type)
        }.reduce([], +)
    }
}
