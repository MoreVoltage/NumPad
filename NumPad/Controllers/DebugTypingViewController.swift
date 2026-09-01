//
//  DebugTypingViewController.swift
//  NumPad
//
//  DEBUG-only host screen (`numpad://debug/typing`) for simulator screenshot automation: a
//  first-responder text field that raises the keyboard extension. Optional `scene` values paint a
//  simple host (invoice, checkout, dinner bill, code) above the field so App Store raws look like
//  NumPad in a real document, not an empty debug chrome.
//

#if DEBUG
import UIKit

final class DebugTypingViewController: UIViewController {
    /// Set by `handleDebugDeepLink` from `typing?scene=`.
    static var scene: String = "plain"

    private let textField = UITextField()
    private let scroll = UIScrollView()
    private let content = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        let scene = Self.scene
        let dark = scene == "code"
        view.backgroundColor = dark ? UIColor(red: 13 / 255, green: 17 / 255, blue: 23 / 255, alpha: 1) : .systemBackground
        overrideUserInterfaceStyle = dark ? .dark : .light

        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])

        textField.borderStyle = .roundedRect
        textField.font = .monospacedDigitSystemFont(ofSize: 22, weight: .regular)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.accessibilityIdentifier = "debugTypingField"
        textField.heightAnchor.constraint(equalToConstant: 52).isActive = true

        switch scene {
        case "hero":
            textField.placeholder = "Type a number"
            layoutLabeledHost(
                kicker: "Notes",
                title: "Quarterly numbers",
                rows: [
                    ("Revenue", "1,248,900.00"),
                    ("Units sold", "48,210"),
                    ("Growth", "12.4%"),
                ]
            )
        case "checkout":
            textField.placeholder = "0000 0000 0000"
            layoutCheckout()
        case "dinner":
            textField.placeholder = "Amount"
            layoutLabeledHost(
                kicker: "Notes",
                title: "Dinner total",
                rows: [
                    ("Subtotal", "$80.00"),
                    ("Tax", "8%"),
                    ("Tip", "18%"),
                ]
            )
        case "invoice":
            textField.placeholder = "Paste a number"
            layoutLabeledHost(
                kicker: "Notes",
                title: "Invoice notes",
                rows: [
                    ("Invoice", "1,249.99"),
                    ("Phone", "555-867-5309"),
                    ("Order", "1249-4912-4218"),
                ]
            )
        case "code":
            textField.placeholder = "0x"
            textField.keyboardAppearance = .dark
            layoutCode()
        default:
            textField.placeholder = "NumPad debug typing surface"
            content.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                textField.topAnchor.constraint(equalTo: content.topAnchor, constant: 120),
                textField.widthAnchor.constraint(equalTo: content.widthAnchor, multiplier: 0.8),
                textField.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -40),
            ])
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }

    // MARK: - Host layouts

    private func layoutLabeledHost(kicker: String, title: String, rows: [(String, String)]) {
        let kickerLabel = UILabel()
        kickerLabel.text = kicker
        kickerLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        kickerLabel.textColor = .systemBlue

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label

        let rule = UIView()
        rule.backgroundColor = UIColor.separator
        rule.translatesAutoresizingMaskIntoConstraints = false
        rule.heightAnchor.constraint(equalToConstant: 1).isActive = true

        var arranged: [UIView] = [kickerLabel, titleLabel, rule]
        for (label, value) in rows {
            arranged.append(rowView(label: label, value: value))
        }
        arranged.append(textField)

        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.spacing = 18
        stack.setCustomSpacing(8, after: kickerLabel)
        stack.setCustomSpacing(16, after: titleLabel)
        stack.setCustomSpacing(28, after: rule)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -36),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -40),
        ])
    }

    private func rowView(label: String, value: String) -> UIView {
        let left = UILabel()
        left.text = label
        left.font = .systemFont(ofSize: 20, weight: .regular)
        left.textColor = .secondaryLabel
        let right = UILabel()
        right.text = value
        right.font = .monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        right.textColor = .label
        right.textAlignment = .right
        let row = UIStackView(arrangedSubviews: [left, right])
        row.axis = .horizontal
        row.distribution = .fill
        return row
    }

    private func layoutCheckout() {
        let title = UILabel()
        title.text = "Checkout"
        title.font = .systemFont(ofSize: 32, weight: .bold)
        title.textAlignment = .center

        let muted = UILabel()
        muted.text = "Secure payment"
        muted.font = .systemFont(ofSize: 16)
        muted.textColor = .secondaryLabel
        muted.textAlignment = .center

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false

        let totalLab = UILabel()
        totalLab.text = "Order total"
        totalLab.font = .systemFont(ofSize: 16)
        totalLab.textColor = .secondaryLabel
        let totalAmt = UILabel()
        totalAmt.text = "$128.40"
        totalAmt.font = .systemFont(ofSize: 22, weight: .bold)
        let totalRow = UIStackView(arrangedSubviews: [totalLab, totalAmt])
        totalRow.axis = .horizontal
        totalRow.distribution = .equalSpacing

        let cardLab = UILabel()
        cardLab.text = "Account Number"
        cardLab.font = .systemFont(ofSize: 13, weight: .semibold)

        let expLab = UILabel()
        expLab.text = "Expiry"
        expLab.font = .systemFont(ofSize: 13, weight: .semibold)
        let expField = Self.inertField(placeholder: "MM / YY")

        let cvcLab = UILabel()
        cvcLab.text = "CVC"
        cvcLab.font = .systemFont(ofSize: 13, weight: .semibold)
        let cvcField = Self.inertField(placeholder: "123")

        let expStack = UIStackView(arrangedSubviews: [expLab, expField])
        expStack.axis = .vertical
        expStack.spacing = 6
        let cvcStack = UIStackView(arrangedSubviews: [cvcLab, cvcField])
        cvcStack.axis = .vertical
        cvcStack.spacing = 6
        let half = UIStackView(arrangedSubviews: [expStack, cvcStack])
        half.axis = .horizontal
        half.spacing = 14
        half.distribution = .fillEqually

        let pay = UIButton(type: .system)
        pay.setTitle("Pay $128.40", for: .normal)
        pay.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        pay.backgroundColor = UIColor.systemGray3
        pay.setTitleColor(.white, for: .normal)
        pay.layer.cornerRadius = 12
        pay.translatesAutoresizingMaskIntoConstraints = false
        pay.heightAnchor.constraint(equalToConstant: 50).isActive = true
        pay.isUserInteractionEnabled = false

        let cardStack = UIStackView(arrangedSubviews: [totalRow, cardLab, textField, half, pay])
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.setCustomSpacing(18, after: totalRow)
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
        ])

        let outer = UIStackView(arrangedSubviews: [title, muted, card])
        outer.axis = .vertical
        outer.spacing = 8
        outer.setCustomSpacing(20, after: muted)
        outer.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: content.topAnchor, constant: 36),
            outer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 48),
            outer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -48),
            outer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -40),
        ])
    }

    /// Placeholder-looking box that is not a `UITextField`, so XCUI's `textFields.firstMatch`
    /// always resolves to the live typing field.
    private static func inertField(placeholder: String) -> UIView {
        let box = UIView()
        box.backgroundColor = .secondarySystemBackground
        box.layer.cornerRadius = 8
        box.layer.borderWidth = 1
        box.layer.borderColor = UIColor.separator.cgColor
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let label = UILabel()
        label.text = placeholder
        label.textColor = .placeholderText
        label.font = .systemFont(ofSize: 17)
        label.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        return box
    }

    private func layoutCode() {
        let file = UILabel()
        file.text = "main.swift"
        file.font = .monospacedSystemFont(ofSize: 16, weight: .semibold)
        file.textColor = UIColor(white: 0.62, alpha: 1)

        let lines = [
            "let mask = 0xFF00",
            "let flags = a << 3",
            "total += items * 1.08",
            "price = (net) & 0x7F",
        ]
        var arranged: [UIView] = [file]
        for (i, line) in lines.enumerated() {
            let row = UILabel()
            row.text = "\(i + 1)    \(line)"
            row.font = .monospacedSystemFont(ofSize: 20, weight: .regular)
            row.textColor = UIColor(white: 0.86, alpha: 1)
            arranged.append(row)
        }
        arranged.append(textField)
        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(28, after: file)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 36),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -36),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -40),
        ])
    }
}
#endif
