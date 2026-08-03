//
//  StoreViewController+Hero.swift
//  NumPad
//
//  The Store screen's sales-facing hero header: context-aware headline/subtitle, a premium-theme
//  preview strip, the benefits checklist, a price-anchoring line, a Free-vs-Pro comparison, and
//  the "Unlock NumPad Pro" CTA button. Split out of StoreViewController.swift to keep each file
//  focused (that file owns the table's rows/actions; this one owns the tableHeaderView).
//

import UIKit
import StoreKit

extension StoreViewController {

    /// Insets used to lay out the hero content inside its container — shared between the layout
    /// pass in `makeHeroHeader()` and the height recomputation in `heroHeaderHeight(width:)`.
    private enum HeroMetrics {
        static let horizontalInset: CGFloat = 24
        static let topInset: CGFloat = 24
        static let bottomInset: CGFloat = 8
    }

    /// Hero header: app icon, a context-aware headline + pitch, a premium-theme preview strip, a
    /// "what's included" checklist, and — while Pro is still locked — a price-anchoring line, a
    /// Free-vs-Pro comparison, and a prominent CTA button. Once Pro is owned, the sell-focused
    /// pieces are replaced with a simple thank-you line.
    func makeHeroHeader() -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 0))

        let icon = UIImageView(image: UIImage(named: "star"))
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .primary

        let copy = heroCopy(for: source)

        let headline = UILabel()
        headline.text = copy.title
        headline.font = .preferredFont(for: .title1, weight: .bold)
        headline.adjustsFontForContentSizeCategory = true
        headline.textAlignment = .center
        headline.numberOfLines = 0

        let pitch = UILabel()
        pitch.text = copy.subtitle
        pitch.font = .preferredFont(forTextStyle: .subheadline)
        pitch.adjustsFontForContentSizeCategory = true
        pitch.textColor = .secondaryLabel
        pitch.textAlignment = .center
        pitch.numberOfLines = 0

        let benefits = UIStackView(arrangedSubviews: [
            makeBenefitRow(NSLocalizedString("Every keyboard pack — finance, symbols, code, dates, units, cooking", comment: "Paywall benefit: packs")),
            makeBenefitRow(NSLocalizedString("Every premium theme", comment: "Paywall benefit: themes")),
            makeBenefitRow(NSLocalizedString("The custom keyboard, iCloud sync, and every future pack", comment: "Paywall benefit: features")),
        ])
        benefits.axis = .vertical
        benefits.alignment = .leading
        benefits.spacing = 8

        var arranged: [UIView] = [icon, headline, pitch, makeThemePreviewStrip(), benefits]
        var fullWidthViews: [UIView] = []

        let reassurance = UILabel()
        reassurance.font = .preferredFont(for: .footnote, weight: .semibold)
        reassurance.adjustsFontForContentSizeCategory = true
        reassurance.textColor = .primary
        reassurance.textAlignment = .center
        reassurance.numberOfLines = 0

        if isProUnlocked {
            // Nothing left to sell — a thank-you, not another pitch.
            reassurance.text = NSLocalizedString("You own NumPad Pro — thank you for supporting indie development.", comment: "Reassurance shown in the Store hero once Pro is unlocked")
            arranged.append(reassurance)
        } else {
            if let anchoringText = priceAnchoringLine() {
                let anchoring = UILabel()
                anchoring.text = anchoringText
                anchoring.font = .preferredFont(forTextStyle: .footnote)
                anchoring.adjustsFontForContentSizeCategory = true
                anchoring.textColor = .secondaryLabel
                anchoring.textAlignment = .center
                anchoring.numberOfLines = 0
                arranged.append(anchoring)
            }

            let comparisonTable = makeComparisonTable()
            arranged.append(comparisonTable)
            fullWidthViews.append(comparisonTable)

            let cta = makeCTAButton()
            arranged.append(cta)
            fullWidthViews.append(cta)

            reassurance.text = NSLocalizedString("One-time purchase. No subscription, ever.", comment: "Reassurance under the paywall hero")
            arranged.append(reassurance)
        }

        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(16, after: pitch)
        stack.setCustomSpacing(16, after: benefits)
        heroStackView = stack

        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.heightAnchor.constraint(equalToConstant: 56),
            icon.widthAnchor.constraint(equalToConstant: 56),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: HeroMetrics.topInset),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: HeroMetrics.horizontalInset),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -HeroMetrics.horizontalInset),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -HeroMetrics.bottomInset)
        ])
        // `.center` alignment still bounds each arranged view's width to the stack's own width
        // (it hugs its intrinsic size up to that bound), except views that must span the full
        // width regardless of their own content — pin those explicitly.
        for view in fullWidthViews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        // Self-size the header now; `resizeHeroHeaderIfNeeded()` keeps it correct across rotation
        // and Dynamic Type changes (tableHeaderView ignores Auto Layout, so this can't just be
        // left to constraints).
        container.frame.size.height = heroHeaderHeight(width: tableView.bounds.width)
        return container
    }

    /// Table header views ignore Auto Layout, so the header is resized manually here whenever the
    /// layout width changes (rotation, size class) or Dynamic Type changes the required text
    /// height. Reassigning `tableHeaderView` is what makes the table pick up the new height.
    func resizeHeroHeaderIfNeeded() {
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width
        guard width > 0 else { return }
        let newSize = CGSize(width: width, height: heroHeaderHeight(width: width))
        guard header.frame.size != newSize else { return }
        header.frame = CGRect(origin: .zero, size: newSize)
        tableView.tableHeaderView = header
    }

    /// Computes the hero container's required height for its content at `width`, honoring Dynamic
    /// Type. Measuring `heroStackView` (not the container) is essential: the container keeps
    /// `translatesAutoresizingMaskIntoConstraints = true` so `tableHeaderView` can size it via
    /// `.frame`, and calling `systemLayoutSizeFitting` on a view with that flag set just echoes
    /// its current frame back instead of computing from its constraints — which is what silently
    /// truncated the hero to a near-zero height before this fix.
    private func heroHeaderHeight(width: CGFloat) -> CGFloat {
        guard let stack = heroStackView else { return 0 }
        let contentWidth = max(width - HeroMetrics.horizontalInset * 2, 0)
        let stackHeight = stack.systemLayoutSizeFitting(
            CGSize(width: contentWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        return HeroMetrics.topInset + stackHeight + HeroMetrics.bottomInset
    }

    /// A single checklist row: a tinted checkmark and a wrapping label.
    private func makeBenefitRow(_ text: String) -> UIView {
        let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        check.tintColor = .primary
        check.contentMode = .scaleAspectFit
        check.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [check, label])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 8
        NSLayoutConstraint.activate([
            check.widthAnchor.constraint(equalToConstant: 20),
            check.heightAnchor.constraint(equalToConstant: 20),
        ])
        return row
    }

    /// Context-aware hero copy keyed off the funnel `source`. Defaults to the Remote-Config pitch
    /// line for the settings entry point, otherwise a benefit-led message matched to the entry point.
    private func heroCopy(for source: String) -> (title: String, subtitle: String) {
        switch source {
        case "key_lock":
            return (NSLocalizedString("Unlock every key", comment: "Paywall hero title from a locked key"),
                    NSLocalizedString("That key is part of NumPad Pro — unlock every pack, theme, and future feature with one purchase.", comment: "Paywall hero subtitle from a locked key"))
        case "pack_picker", "packs":
            // Option C: packs stay à la carte; Pro is not sold as a pack-discount bundle.
            return (NSLocalizedString("Packs add keys. Pro changes what the keyboard is.", comment: "Paywall hero title from a locked pack — category frame, not Save%"),
                    NSLocalizedString("Get every pack, plus what packs cannot add: custom layout, themes, iCloud sync, and Kiosk height. One purchase, no subscription.", comment: "Paywall hero subtitle from a locked pack"))
        case "conversion_lock":
            return (NSLocalizedString("Unlock the full converter", comment: "Paywall hero title from a locked conversion category"),
                    NSLocalizedString("That converter category is in a pack you can buy alone — or get NumPad Pro for every pack and the Pro-only tools packs never include.", comment: "Paywall hero subtitle from a locked conversion category"))
        case "first_run":
            return (NSLocalizedString("Packs add keys. Pro changes what the keyboard is.", comment: "Paywall hero title for the first-run upsell"),
                    NSLocalizedString("Every pack, plus build your own layout, premium themes, sync across devices, and Kiosk size for iPad. One purchase, no subscription.", comment: "Paywall hero subtitle for the first-run upsell"))
        case "theme_lock":
            return (NSLocalizedString("Unlock every theme", comment: "Paywall hero title from a locked theme"),
                    NSLocalizedString("That theme is part of NumPad Pro — unlock every theme, every pack, custom layout, and Kiosk height with one purchase.", comment: "Paywall hero subtitle from a locked theme"))
        case "kiosk_preset":
            return (NSLocalizedString("Unlock the Kiosk height", comment: "Paywall hero title from the Kiosk keyboard height preset"),
                    NSLocalizedString("Kiosk height is Pro-only — not sold as a pack. Pro also includes every pack, custom layout, themes, and iCloud sync.", comment: "Paywall hero subtitle from the Kiosk keyboard height preset"))
        case "session_milestone":
            return (NSLocalizedString("Packs add keys. Pro changes what the keyboard is.", comment: "Paywall hero title for the session-milestone upsell"),
                    NSLocalizedString("Every pack, plus the tools packs never sell: custom layout, themes, iCloud sync, and Kiosk height. One purchase, no subscription.", comment: "Paywall hero subtitle for the session-milestone upsell"))
        case "customize":
            return (NSLocalizedString("Six packs add keys to the numpad. Pro lets you rebuild it.", comment: "Paywall hero title from the custom keyboard editor"),
                    NSLocalizedString("Add a top row and side columns around the number pad — Pro-only, along with every pack, themes, and Kiosk height.", comment: "Paywall hero subtitle from the custom keyboard editor"))
        case "features_guide":
            return (NSLocalizedString("Everything, and everything packs don't cover.", comment: "Paywall hero title from the Features & Guide Pro row"),
                    NSLocalizedString("Every pack, plus custom layout, premium themes, iCloud sync, and Kiosk height — one purchase, no subscription.", comment: "Paywall hero subtitle from the Features & Guide Pro row"))
        default:
            let rcCopy = RemoteConfigManager.shared.priceCopy
            // Prefer Honey §7 category frame when RC is empty — not a pack-sum pitch.
            let subtitle = rcCopy.isEmpty
                ? NSLocalizedString("Every pack, plus what packs can't add: custom layout, themes, iCloud sync, and Kiosk height.", comment: "Store hero default Pro pitch under option C")
                : rcCopy
            return (NSLocalizedString("Packs add keys. Pro changes what the keyboard is.", comment: "Store screen default Pro hero title under option C"), subtitle)
        }
    }

    /// A compact strip of small rounded swatches previewing the premium themes Pro unlocks — an
    /// asset-free stand-in for a screenshot.
    private func makeThemePreviewStrip() -> UIView {
        let swatchSize: CGFloat = 28
        let swatches: [UIView] = KeyboardTheme.premiumThemes.map { theme in
            let swatch = UIView()
            swatch.backgroundColor = theme.color
            swatch.layer.cornerRadius = 8
            swatch.layer.borderWidth = 1
            swatch.layer.borderColor = UIColor.separator.cgColor
            swatch.isAccessibilityElement = true
            swatch.accessibilityLabel = theme.name
            NSLayoutConstraint.activate([
                swatch.widthAnchor.constraint(equalToConstant: swatchSize),
                swatch.heightAnchor.constraint(equalToConstant: swatchSize),
            ])
            return swatch
        }
        let row = UIStackView(arrangedSubviews: swatches)
        row.axis = .horizontal
        row.spacing = 8
        row.accessibilityLabel = NSLocalizedString("Premium theme preview", comment: "Accessibility label for the Store hero's premium theme swatch strip")
        return row
    }

    /// "All packs separately: $X.XX. Pro has every pack, plus the custom keyboard, premium themes,
    /// and iCloud sync." — computed from live StoreKit prices; returns `nil` (never a
    /// partial/guessed total) until every à la carte product has finished loading. With six à la
    /// carte packs at $1.99 the summed total lands within a few cents of Pro's own price, so the
    /// line is deliberately framed around what Pro adds *beyond* the packs rather than a discount —
    /// the near-parity total wouldn't sell Pro on price alone.
    private func priceAnchoringLine() -> String? {
        let packProducts = alaCartePacks.compactMap { StoreManager.shared.product(for: $0) }
        guard packProducts.count == alaCartePacks.count, let anchorProduct = packProducts.first else { return nil }
        guard let sum = PriceAnchoring.sum(of: packProducts.map { $0.price }) else { return nil }
        let formatted = anchorProduct.priceFormatStyle.format(sum)
        // No "Save X%" — pack total is near Pro and a discount claim would be false (option C).
        return String(format: NSLocalizedString("All packs separately: %@. Pro includes every pack — and custom layout, themes, iCloud sync, and Kiosk height packs never sell.", comment: "Store hero price-anchoring line under option C; %@ is the summed à la carte pack price, not a discount claim"), formatted)
    }

    /// A short Free-vs-Pro comparison, in its own rounded card, so a shopper learns what they're
    /// missing before ever reaching the purchase rows below.
    private func makeComparisonTable() -> UIView {
        let freeThemeCount = KeyboardTheme.allCases.count - KeyboardTheme.premiumThemes.count
        let rows: [(feature: String, free: String, pro: String)] = [
            (NSLocalizedString("Keyboard packs", comment: "Free vs Pro comparison row: packs"),
             NSLocalizedString("Math only", comment: "Free vs Pro comparison value: packs, free tier"),
             NSLocalizedString("All 7 packs", comment: "Free vs Pro comparison value: packs, Pro tier")),
            (NSLocalizedString("Themes", comment: "Free vs Pro comparison row: themes"),
             String(format: NSLocalizedString("%d themes", comment: "Free vs Pro comparison value: themes, free tier"), freeThemeCount),
             NSLocalizedString("All themes", comment: "Free vs Pro comparison value: themes, Pro tier")),
            (NSLocalizedString("Custom keyboard", comment: "Free vs Pro comparison row: custom keyboard"), "—", "✓"),
            (NSLocalizedString("iCloud sync", comment: "Free vs Pro comparison row: iCloud sync"), "—", "✓"),
        ]

        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true

        let header = makeComparisonRow(
            feature: nil,
            free: NSLocalizedString("Free", comment: "Free vs Pro comparison column header"),
            pro: NSLocalizedString("Pro", comment: "Free vs Pro comparison column header")
        )
        let table = UIStackView(arrangedSubviews: [header] + rows.map { makeComparisonRow(feature: $0.feature, free: $0.free, pro: $0.pro) })
        table.axis = .vertical
        table.spacing = 8

        container.addSubview(table)
        table.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            table.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            table.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            table.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])
        return container
    }

    /// One row of the comparison table: a leading feature label plus two fixed-minimum-width
    /// value columns, so Free/Pro line up across rows without ever truncating at larger Dynamic
    /// Type sizes (the columns grow instead).
    private func makeComparisonRow(feature: String?, free: String, pro: String) -> UIView {
        let isHeader = feature == nil

        let featureLabel = UILabel()
        featureLabel.text = feature ?? " "
        featureLabel.font = .preferredFont(forTextStyle: .footnote)
        featureLabel.textColor = .label
        featureLabel.numberOfLines = 0
        featureLabel.adjustsFontForContentSizeCategory = true
        featureLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        featureLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let freeLabel = comparisonValueLabel(free, color: .secondaryLabel, bold: isHeader)
        let proLabel = comparisonValueLabel(pro, color: .primary, bold: true)
        for label in [freeLabel, proLabel] {
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        let row = UIStackView(arrangedSubviews: [featureLabel, freeLabel, proLabel])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 12
        return row
    }

    private func comparisonValueLabel(_ text: String, color: UIColor, bold: Bool) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = bold ? .preferredFont(for: .footnote, weight: .bold) : .preferredFont(forTextStyle: .footnote)
        label.textColor = color
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    /// The hero's primary call to action: a full-width filled button that buys Pro directly,
    /// titled with the live StoreKit price (falling back to the last-known list price if products
    /// haven't loaded yet).
    private func makeCTAButton() -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .primary
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        let priceText = price(for: StoreManager.shared.proProduct, fallback: "$11.99")
        config.title = String(format: NSLocalizedString("Unlock NumPad Pro — %@", comment: "Store hero CTA button title; %@ is the live Pro price"), priceText)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .preferredFont(for: .headline, weight: .bold)
            return outgoing
        }

        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.buy(StoreManager.shared.proProduct)
        })
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        return button
    }
}
