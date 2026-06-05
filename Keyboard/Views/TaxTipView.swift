import UIKit

protocol TaxTipViewDelegate: AnyObject {
    func taxTipView(_ view: TaxTipView, didCompute value: String)
    func taxTipViewDidRequestClose(_ view: TaxTipView)
}

class TaxTipView: UIView {
    weak var delegate: TaxTipViewDelegate?

    private let titleLabel = UILabel()
    private let amountField = UITextField()
    private let segControl = UISegmentedControl(items: ["5%", "10%", "15%", "18%", "20%", "25%"])
    private let modeControl = UISegmentedControl(items: [
        NSLocalizedString("Total", comment: "Tax/tip result mode: full total"),
        NSLocalizedString("Delta", comment: "Tax/tip result mode: just the added amount")
    ])
    private let applyButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let scrollView = UIScrollView()

    private let percents = [0.05, 0.10, 0.15, 0.18, 0.20, 0.25]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        clipsToBounds = true

        titleLabel.text = NSLocalizedString("TAX/TIP", comment: "Tax and tip overlay title")
        titleLabel.textAlignment = .center
        titleLabel.font = .boldSystemFont(ofSize: 16)

        amountField.placeholder = NSLocalizedString("Amount", comment: "Tax/tip amount field placeholder")
        amountField.keyboardType = .decimalPad
        amountField.borderStyle = .roundedRect

        // Default percent from Remote Config if available
        let defaultPercent = RemoteConfigManager.shared.taxDefaultPercent
        let percentValues = [5, 10, 15, 18, 20, 25]
        segControl.selectedSegmentIndex = percentValues.firstIndex(of: defaultPercent) ?? 2
        modeControl.selectedSegmentIndex = 0

        applyButton.setTitle(NSLocalizedString("Insert", comment: ""), for: .normal)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, amountField, segControl, modeControl, applyButton, closeButton])
        stack.axis = .vertical
        stack.spacing = 8

        // Wrap the controls in a scroll view so they remain reachable (and never clip) on a
        // short keyboard such as landscape iPhone, where the overlay band is only ~80pt tall.
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func applyTapped() {
        let raw = amountField.text?.replacingOccurrences(of: ",", with: ".") ?? ""
        guard let base = Double(raw), base >= 0 else {
            signalInvalidInput()
            return
        }
        let p = percents[min(max(segControl.selectedSegmentIndex, 0), percents.count - 1)]
        let total = base * (1 + p)
        let delta = total - base
        let useDelta = modeControl.selectedSegmentIndex == 1
        let value = useDelta ? delta : total
        delegate?.taxTipView(self, didCompute: String(format: "%.2f", value))
    }

    @objc private func closeTapped() {
        delegate?.taxTipViewDidRequestClose(self)
    }

    private func signalInvalidInput() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-8, 8, -6, 6, -3, 3, 0]
        animation.duration = 0.4
        amountField.layer.add(animation, forKey: "shake")
    }

    // MARK: - Keyboard passthrough helpers are implemented in the extension below
}

// MARK: - Input helpers for routing keyboard taps while overlay is visible
extension TaxTipView {
    func append(_ s: String) {
        let current = amountField.text ?? ""
        // Reject a second decimal separator so the value stays parseable.
        if s == "." && current.contains(".") { return }
        amountField.text = current + s
    }
    func deleteBackward() {
        guard var t = amountField.text, !t.isEmpty else { return }
        t.removeLast()
        amountField.text = t
    }
    func apply() { applyTapped() }
}
