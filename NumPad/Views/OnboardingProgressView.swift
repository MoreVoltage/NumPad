//
//  OnboardingProgressView.swift
//  NumPad
//
//  A minimal dot step indicator for the onboarding container's header.
//

import UIKit

final class OnboardingProgressView: UIView {
    private var dots: [UIView] = []

    var currentIndex: Int = 0 {
        didSet {
            guard currentIndex != oldValue else { return }
            updateDots()
        }
    }

    init(stepCount: Int) {
        super.init(frame: .zero)

        for _ in 0..<stepCount {
            let dot = UIView()
            dot.layer.cornerRadius = 3
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 6).isActive = true
            dots.append(dot)
        }

        let stack = UIStackView(arrangedSubviews: dots)
        stack.axis = .horizontal
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updateDots()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateDots() {
        for (index, dot) in dots.enumerated() {
            dot.backgroundColor = index == currentIndex ? .primary : UIColor.secondaryLabel.withAlphaComponent(0.3)
        }
    }
}
