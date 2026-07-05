//
//  OnboardingConfettiView.swift
//  NumPad
//
//  A lightweight "confetti-lite" celebration for the onboarding ENABLE step: a spring-scaled
//  checkmark plus a brief particle burst. Reduce Motion collapses this to a static checkmark
//  fade-in — no motion, no particles — per Apple's accessibility guidance for non-essential
//  animation.
//

import UIKit

final class OnboardingConfettiView: UIView {
    private let checkmarkBackground = UIView()
    private let checkmarkImageView = UIImageView(image: UIImage(systemName: "checkmark"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        checkmarkBackground.backgroundColor = .primary
        checkmarkBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkmarkBackground)

        checkmarkImageView.tintColor = .white
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkBackground.addSubview(checkmarkImageView)

        NSLayoutConstraint.activate([
            checkmarkBackground.centerXAnchor.constraint(equalTo: centerXAnchor),
            checkmarkBackground.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkBackground.widthAnchor.constraint(equalToConstant: 88),
            checkmarkBackground.heightAnchor.constraint(equalToConstant: 88),

            checkmarkImageView.centerXAnchor.constraint(equalTo: checkmarkBackground.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: checkmarkBackground.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 40),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        checkmarkBackground.layer.cornerRadius = checkmarkBackground.bounds.width / 2
    }

    /// Plays the celebration once and calls `completion` when it's visually settled. Reduce Motion
    /// skips the spring bounce and the particle burst — the checkmark simply fades in.
    func play(completion: @escaping () -> Void) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            alpha = 0
            checkmarkBackground.transform = .identity
            UIView.animate(withDuration: 0.2, animations: {
                self.alpha = 1
            }, completion: { _ in
                completion()
            })
            return
        }

        alpha = 1
        checkmarkBackground.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0.6, options: [], animations: {
            self.checkmarkBackground.transform = .identity
        }, completion: { _ in
            completion()
        })
        emitBurst()
    }

    /// A short-lived `CAEmitterLayer` burst behind the checkmark. Emission is stopped almost
    /// immediately (a burst, not a fountain) and the layer is torn down shortly after the longest
    /// -lived particle fades, so it never lingers as a hidden always-on emitter.
    private func emitBurst() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitter.emitterShape = .point
        emitter.renderMode = .additive

        let colors: [UIColor] = [.systemYellow, .systemPink, .systemTeal, .systemPurple, .systemOrange]
        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 14
            cell.lifetime = 1.4
            cell.velocity = 140
            cell.velocityRange = 60
            cell.emissionRange = .pi * 2
            cell.scale = 0.05
            cell.scaleRange = 0.03
            cell.spin = 3
            cell.spinRange = 2
            cell.alphaSpeed = -0.9
            cell.contents = UIImage.confettiParticle(color: color)?.cgImage
            return cell
        }
        layer.addSublayer(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            emitter.removeFromSuperlayer()
        }
    }
}

private extension UIImage {
    /// A tiny filled circle used as the confetti particle texture, generated on the fly so the
    /// feature needs no bundled image assets.
    static func confettiParticle(color: UIColor, side: CGFloat = 8) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { context in
            color.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
    }
}
