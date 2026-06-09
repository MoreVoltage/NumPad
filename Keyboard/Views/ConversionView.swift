import UIKit

protocol ConversionViewDelegate: AnyObject {
    func conversionView(_ view: ConversionView, didCompute value: String)
    func conversionViewDidRequestClose(_ view: ConversionView)
}

/// Offline unit-conversion overlay (conversion-overlay feature). Routes numpad taps into its amount
/// field — the same passthrough pattern as TaxTipView — and converts length/mass/temperature via the
/// pure `UnitConverter`. Currency is intentionally absent (it needs live rates).
class ConversionView: UIView {
    weak var delegate: ConversionViewDelegate?

    private let titleLabel = UILabel()
    private let amountField = UITextField()
    private let categoryControl = UISegmentedControl(items: UnitConverter.Category.allCases.map { $0.displayName })
    private let fromControl = UISegmentedControl()
    private let toControl = UISegmentedControl()
    private let applyButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let scrollView = UIScrollView()

    private var category: UnitConverter.Category = .length

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        clipsToBounds = true

        titleLabel.text = NSLocalizedString("Convert", comment: "Conversion overlay title")
        titleLabel.textAlignment = .center
        titleLabel.font = .boldSystemFont(ofSize: 16)

        amountField.placeholder = NSLocalizedString("Amount", comment: "Conversion amount field placeholder")
        amountField.keyboardType = .decimalPad
        amountField.borderStyle = .roundedRect

        categoryControl.selectedSegmentIndex = 0
        categoryControl.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)
        rebuildUnitControls()

        applyButton.setTitle(NSLocalizedString("Insert", comment: ""), for: .normal)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, amountField, categoryControl, fromControl, toControl, applyButton, closeButton])
        stack.axis = .vertical
        stack.spacing = 8

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

    private func rebuildUnitControls() {
        let units = category.units
        fromControl.removeAllSegments()
        toControl.removeAllSegments()
        for (i, unit) in units.enumerated() {
            fromControl.insertSegment(withTitle: unit, at: i, animated: false)
            toControl.insertSegment(withTitle: unit, at: i, animated: false)
        }
        fromControl.selectedSegmentIndex = 0
        toControl.selectedSegmentIndex = min(1, units.count - 1)
    }

    @objc private func categoryChanged() {
        category = UnitConverter.Category.allCases[categoryControl.selectedSegmentIndex]
        rebuildUnitControls()
    }

    @objc private func applyTapped() {
        let raw = amountField.text?.replacingOccurrences(of: ",", with: ".") ?? ""
        let units = category.units
        guard let value = Double(raw),
              units.indices.contains(fromControl.selectedSegmentIndex),
              units.indices.contains(toControl.selectedSegmentIndex),
              let result = UnitConverter.convert(value,
                                                 from: units[fromControl.selectedSegmentIndex],
                                                 to: units[toControl.selectedSegmentIndex]) else {
            signalInvalidInput()
            return
        }
        delegate?.conversionView(self, didCompute: Calculator.format(result))
    }

    @objc private func closeTapped() {
        delegate?.conversionViewDidRequestClose(self)
    }

    private func signalInvalidInput() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-8, 8, -6, 6, -3, 3, 0]
        animation.duration = 0.4
        amountField.layer.add(animation, forKey: "shake")
    }
}

// MARK: - Input helpers for routing keyboard taps while the overlay is visible
extension ConversionView {
    func append(_ s: String) {
        let current = amountField.text ?? ""
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
