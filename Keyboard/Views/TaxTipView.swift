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
    private let modeControl = UISegmentedControl(items: ["Total", "Delta"]) // insert total value or just the delta
    private let applyButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let passthroughBottom = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        clipsToBounds = true

        titleLabel.text = "TAX/TIP"
        titleLabel.textAlignment = .center
        titleLabel.font = .boldSystemFont(ofSize: 16)

        amountField.placeholder = "Amount"
        amountField.keyboardType = .decimalPad
        amountField.borderStyle = .roundedRect

        // Default percent from Remote Config if available
        let defaultPercent = RemoteConfigManager.shared.taxDefaultPercent
        let percents = [5,10,15,18,20,25]
        let idx = percents.firstIndex(of: defaultPercent) ?? 2
        segControl.selectedSegmentIndex = idx
        modeControl.selectedSegmentIndex = 0

        applyButton.setTitle("Insert", for: .normal)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, amountField, segControl, modeControl, applyButton, closeButton])
        stack.axis = .vertical
        stack.spacing = 8
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])

        // Allow hit-testing to pass to keys below for the bottom area so keys remain reachable
        passthroughBottom.backgroundColor = .clear
        addSubview(passthroughBottom)
        passthroughBottom.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            passthroughBottom.leadingAnchor.constraint(equalTo: leadingAnchor),
            passthroughBottom.trailingAnchor.constraint(equalTo: trailingAnchor),
            passthroughBottom.bottomAnchor.constraint(equalTo: bottomAnchor),
            passthroughBottom.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.25)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func applyTapped() {
        let raw = amountField.text?.replacingOccurrences(of: ",", with: ".") ?? ""
        guard let base = Double(raw) else { return }
        let percents = [0.05, 0.10, 0.15, 0.18, 0.20, 0.25]
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

    // MARK: - Keyboard passthrough helpers are implemented in the extension below
}

// MARK: - Input helpers for routing keyboard taps while overlay is visible
extension TaxTipView {
    func append(_ s: String) {
        amountField.text = (amountField.text ?? "") + s
    }
    func deleteBackward() {
        guard var t = amountField.text, !t.isEmpty else { return }
        t.removeLast()
        amountField.text = t
    }
    func apply() { applyTapped() }
}


