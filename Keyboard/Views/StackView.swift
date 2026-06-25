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
    
    /// `customHasTopRow` switches to the custom-keyboard layout: `nil` keeps the legacy pack/default
    /// path unchanged; non-nil renders every cell in a uniform fill-equally row (no narrow edge
    /// column, no pack lock-chips since custom keys are not pack-gated) and, when `true`, makes the
    /// first row a horizontally-scrollable top strip.
    func configure(_ items: [[Item]], keyboardType: KeyboardType, roundedCorners: Bool, grid: Bool, width: CGFloat, customHasTopRow: Bool? = nil, block: (Position, Item, Cell) -> Void, touchDown: @escaping (Position, Item) -> Void, tapped: @escaping (Position, Item) -> Void) {
        verticalStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let spacing: CGFloat = roundedCorners ? 2 : grid ? 1 : 0
        verticalStackView.spacing = spacing
        let isCustom = customHasTopRow != nil
        for (row, rowItems) in items.enumerated() {
            let outerStackView = UIStackView(axis: .horizontal, distribution: .fill, spacing: spacing)
            let innerStackView = UIStackView(axis: .horizontal, distribution: .fillEqually, spacing: spacing)
            let scrollableRow = isCustom ? (row == 0 && customHasTopRow == true) : (row == 0 && keyboardType != .default)
            if scrollableRow {
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
                // Give scrollable top-row cells an intrinsic width so they render in the scroll view
                if scrollableRow {
                    cell.width = 44
                }
                // Add lock chip overlay when the key belongs to a locked pack's extra row
                if Monetization.isKeyLocked(pack: keyboardType, row: row) {
                    // Convey the locked state to VoiceOver (the chip/tip below are decorative).
                    let base = cell.accessibilityLabel ?? item.title ?? ""
                    cell.accessibilityLabel = "\(base), \(NSLocalizedString("locked", comment: "VoiceOver suffix for a premium-locked key"))"
                    // Derive chip colors from the active theme so the lock stays visible on every theme.
                    let scheme = item.style.scheme
                    let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
                    lock.isAccessibilityElement = false
                    lock.tintColor = scheme.control.withAlphaComponent(0.55)
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
                    tip.isAccessibilityElement = false
                    tip.text = .unlock
                    tip.font = .systemFont(ofSize: 9, weight: .semibold)
                    tip.textColor = scheme.background
                    tip.backgroundColor = scheme.control.withAlphaComponent(0.7)
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
                block(position, item, cell)
                if !isCustom, items.count - row < 5, column == rowItems.count - 1 {
                    // Legacy layout: the right-edge column (slots / return) renders narrower.
                    cell.width = width * (2 / 11) - 0.75
                    outerStackView.addArrangedSubview(cell)
                } else {
                    // Custom layout renders every cell in a uniform fill-equally row.
                    innerStackView.addArrangedSubview(cell)
                }
            }
            
            verticalStackView.addArrangedSubview(outerStackView)
        }
        // Refresh the cached cell list after every rebuild so pan-to-type keeps working
        // after pack switches and rotations (was previously a one-time `lazy var`).
        cells = verticalStackView.arrangedSubviews(of: Cell.self)
    }

    private(set) var cells: [Cell] = []
}

private extension UIStackView {
    convenience init(axis: NSLayoutConstraint.Axis, distribution: UIStackView.Distribution, spacing: CGFloat = 0) {
        self.init()
        self.axis = axis
        self.distribution = distribution
        self.spacing = spacing
    }
    func arrangedSubviews<T>(of type: T.Type) -> [T] {
        return arrangedSubviews.compactMap { view -> [T]? in
            if let match = view as? T {
                return [match]
            } else if let stack = view as? UIStackView {
                return stack.arrangedSubviews(of: type)
            } else if let scroll = view as? UIScrollView {
                // Traverse into UIScrollView to find cells inside scrollable pack rows
                for sub in scroll.subviews {
                    if let stack = sub as? UIStackView {
                        return stack.arrangedSubviews(of: type)
                    }
                }
                return nil
            }
            return nil
        }.reduce([], +)
    }
}
