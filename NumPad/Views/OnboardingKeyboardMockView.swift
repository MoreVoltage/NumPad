//
//  OnboardingKeyboardMockView.swift
//  NumPad
//
//  The WOW step's animated demo: a mock text field types out an expression, a result chip pops in
//  (mirroring the real Live Math Preview chip), and a caption cycles through the pack catalog above
//  a reused `StudioKeyboardPreviewView` (the same non-interactive keyboard visual the Theme picker uses),
//  so the demo reads as an authentic preview of the real keyboard rather than a generic mock.
//
//  Reduce Motion collapses the whole thing to one static settled frame — no typewriter loop, no
//  caption cycling — per Apple's accessibility guidance for non-essential animation.
//

import UIKit

final class OnboardingKeyboardMockView: UIView {
    private let fieldBackground = UIView()
    private let typedLabel = UILabel()
    private let resultChip = UILabel()
    private let packCaptionLabel = UILabel()
    private let keyboardPreview = StudioKeyboardPreviewView(
        model: .current(idiom: UIDevice.current.userInterfaceIdiom)
    )

    /// Bumped on every start/stop so in-flight `asyncAfter` steps from a previous run can recognize
    /// they're stale and quietly stop rescheduling, without needing Timer invalidation bookkeeping.
    private var generation = 0

    private static let demoExpression = "1,284.50 × 3"
    private static let demoResult = "3,853.50"
    private static let packTypes = KeyboardType.packs

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildLayout() {
        fieldBackground.backgroundColor = .secondarySystemBackground
        fieldBackground.layer.cornerRadius = 12
        fieldBackground.translatesAutoresizingMaskIntoConstraints = false

        typedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        typedLabel.textColor = .label
        typedLabel.translatesAutoresizingMaskIntoConstraints = false

        resultChip.font = .preferredFont(forTextStyle: .headline)
        resultChip.textColor = .white
        resultChip.backgroundColor = .primary
        resultChip.textAlignment = .center
        resultChip.layer.cornerRadius = 14
        resultChip.layer.masksToBounds = true
        resultChip.alpha = 0
        resultChip.translatesAutoresizingMaskIntoConstraints = false

        packCaptionLabel.font = .preferredFont(forTextStyle: .subheadline)
        packCaptionLabel.textColor = .secondaryLabel
        packCaptionLabel.textAlignment = .center
        packCaptionLabel.translatesAutoresizingMaskIntoConstraints = false

        keyboardPreview.translatesAutoresizingMaskIntoConstraints = false

        addSubview(fieldBackground)
        fieldBackground.addSubview(typedLabel)
        addSubview(resultChip)
        addSubview(packCaptionLabel)
        addSubview(keyboardPreview)

        NSLayoutConstraint.activate([
            fieldBackground.topAnchor.constraint(equalTo: topAnchor),
            fieldBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            fieldBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            fieldBackground.heightAnchor.constraint(equalToConstant: 56),

            typedLabel.leadingAnchor.constraint(equalTo: fieldBackground.leadingAnchor, constant: 16),
            typedLabel.trailingAnchor.constraint(lessThanOrEqualTo: resultChip.leadingAnchor, constant: -8),
            typedLabel.centerYAnchor.constraint(equalTo: fieldBackground.centerYAnchor),

            resultChip.trailingAnchor.constraint(equalTo: fieldBackground.trailingAnchor, constant: -12),
            resultChip.centerYAnchor.constraint(equalTo: fieldBackground.centerYAnchor),
            resultChip.heightAnchor.constraint(equalToConstant: 32),
            resultChip.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),

            packCaptionLabel.topAnchor.constraint(equalTo: fieldBackground.bottomAnchor, constant: 20),
            packCaptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            packCaptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            keyboardPreview.topAnchor.constraint(equalTo: packCaptionLabel.bottomAnchor, constant: 14),
            keyboardPreview.leadingAnchor.constraint(equalTo: leadingAnchor),
            keyboardPreview.trailingAnchor.constraint(equalTo: trailingAnchor),
            keyboardPreview.bottomAnchor.constraint(equalTo: bottomAnchor),
            keyboardPreview.heightAnchor.constraint(equalToConstant: 220)
        ])
    }

    /// Starts (or restarts) the demo loop. Safe to call multiple times — bumps `generation` so any
    /// previously scheduled steps become no-ops.
    func startAnimating() {
        generation += 1
        let myGeneration = generation
        packCaptionLabel.text = Self.packTypes.first?.name
        if let pack = Self.packTypes.first {
            keyboardPreview.model = demoModel(for: pack)
        }

        guard !UIAccessibility.isReduceMotionEnabled else {
            typedLabel.text = "\(Self.demoExpression) ="
            resultChip.text = "  \(Self.demoResult)  "
            resultChip.alpha = 1
            return
        }

        runTypingLoop(generation: myGeneration)
        runPackCycle(generation: myGeneration, index: 0)
    }

    /// Stops the demo loop (any in-flight scheduled steps recognize the generation bump and bail).
    func stopAnimating() {
        generation += 1
    }

    // MARK: - Typewriter + result chip

    private func runTypingLoop(generation: Int) {
        typedLabel.alpha = 1
        typedLabel.text = ""
        resultChip.alpha = 0
        resultChip.transform = .identity
        typeCharacter(at: Self.demoExpression.startIndex, generation: generation)
    }

    private func typeCharacter(at index: String.Index, generation: Int) {
        guard generation == self.generation else { return }
        guard index < Self.demoExpression.endIndex else {
            revealResult(generation: generation)
            return
        }
        typedLabel.text = String(Self.demoExpression[Self.demoExpression.startIndex...index])
        let next = Self.demoExpression.index(after: index)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.typeCharacter(at: next, generation: generation)
        }
    }

    private func revealResult(generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self, generation == self.generation else { return }
            self.typedLabel.text = "\(Self.demoExpression) ="
            self.resultChip.text = "  \(Self.demoResult)  "
            self.resultChip.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.4, options: [], animations: {
                self.resultChip.alpha = 1
                self.resultChip.transform = .identity
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                guard let self = self, generation == self.generation else { return }
                self.restartTypingLoop(generation: generation)
            }
        }
    }

    private func restartTypingLoop(generation: Int) {
        UIView.animate(withDuration: 0.25, animations: {
            self.typedLabel.alpha = 0
            self.resultChip.alpha = 0
        }, completion: { [weak self] _ in
            guard let self = self, generation == self.generation else { return }
            self.runTypingLoop(generation: generation)
        })
    }

    // MARK: - Pack caption cycling

    private func runPackCycle(generation: Int, index: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self = self, generation == self.generation else { return }
            let packs = Self.packTypes
            guard !packs.isEmpty else { return }
            let nextIndex = (index + 1) % packs.count
            UIView.transition(with: self.packCaptionLabel, duration: 0.3, options: .transitionCrossDissolve, animations: {
                self.packCaptionLabel.text = packs[nextIndex].name
                self.keyboardPreview.model = self.demoModel(for: packs[nextIndex])
            })
            self.runPackCycle(generation: generation, index: nextIndex)
        }
    }

    private func demoModel(for pack: KeyboardType) -> StudioKeyboardPreviewModel {
        let live = StudioKeyboardPreviewModel.current(idiom: traitCollection.userInterfaceIdiom)
        return StudioKeyboardPreviewModel(
            theme: live.theme,
            pack: pack,
            heightPreset: live.heightPreset,
            isReversedMode: live.isReversedMode,
            hasRoundedCorners: live.hasRoundedCorners,
            hasGrid: live.hasGrid,
            showsLettersRow: live.showsLettersRow,
            idiom: live.idiom
        )
    }
}
