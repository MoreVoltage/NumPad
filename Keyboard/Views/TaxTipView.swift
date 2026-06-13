import UIKit

protocol TaxTipViewDelegate: AnyObject {
    func taxTipView(_ view: TaxTipView, didCompute value: String)
    func taxTipViewDidRequestClose(_ view: TaxTipView)
}

class TaxTipView: UIView {
    weak var delegate: TaxTipViewDelegate?

    private let titleLabel = UILabel()
    private let amountField = UITextField()
    private let taxControl = UISegmentedControl(items: ["0%", "5%", "8%", "10%", "13%", "15%"])
    private let tipControl = UISegmentedControl(items: ["0%", "10%", "15%", "18%", "20%", "25%"])
    private let modeControl = UISegmentedControl(items: [
        NSLocalizedString("Total", comment: "Tax/tip result mode: full total"),
        NSLocalizedString("Tip only", comment: "Tax/tip result mode: just the tip amount")
    ])
    private let applyButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let scrollView = UIScrollView()

    private let taxPercents = [0.0, 0.05, 0.08, 0.10, 0.13, 0.15]
    private let tipPercents = [0.0, 0.10, 0.15, 0.18, 0.20, 0.25]

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

        // Tax defaults to 0% so the overlay behaves exactly like the previous tip-only version
        // until the user opts into a tax rate. Tip default comes from Remote Config if available.
        taxControl.selectedSegmentIndex = 0
        let defaultPercent = RemoteConfigManager.shared.taxDefaultPercent
        let tipPercentValues = [0, 10, 15, 18, 20, 25]
        tipControl.selectedSegmentIndex = tipPercentValues.firstIndex(of: defaultPercent) ?? 2
        modeControl.selectedSegmentIndex = 0

        applyButton.setTitle(NSLocalizedString("Insert", comment: ""), for: .normal)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let taxRow = TaxTipView.labeledRow(NSLocalizedString("Tax", comment: "Tax percent row label"), control: taxControl)
        let tipRow = TaxTipView.labeledRow(NSLocalizedString("Tip", comment: "Tip percent row label"), control: tipControl)

        let stack = UIStackView(arrangedSubviews: [titleLabel, amountField, taxRow, tipRow, modeControl, applyButton, closeButton])
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
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            // ≥44pt tap targets (Apple's HIG minimum) for the action buttons.
            applyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// A horizontal row pairing a short fixed-width label ("Tax"/"Tip") with a segmented control,
    /// so the two percent rows stay visually aligned.
    private static func labeledRow(_ title: String, control: UISegmentedControl) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        let row = UIStackView(arrangedSubviews: [label, control])
        row.axis = .horizontal
        row.spacing = 8
        return row
    }

    @objc private func applyTapped() {
        let raw = amountField.text?.replacingOccurrences(of: ",", with: ".") ?? ""
        guard let base = Double(raw), base >= 0 else {
            signalInvalidInput()
            return
        }
        let tax = taxPercents[min(max(taxControl.selectedSegmentIndex, 0), taxPercents.count - 1)]
        let tip = tipPercents[min(max(tipControl.selectedSegmentIndex, 0), tipPercents.count - 1)]
        let useTipOnly = modeControl.selectedSegmentIndex == 1
        let value = useTipOnly
            ? TaxTipMath.tipOnly(amount: base, tipRate: tip)
            : TaxTipMath.total(amount: base, taxRate: tax, tipRate: tip)
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
