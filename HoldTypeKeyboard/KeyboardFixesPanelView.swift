import UIKit

final class KeyboardFixesPanelView: UIView {
    var onActionRequested: ((String) -> Void)?

    private let statusLabel = UILabel()
    private let collectionView: UICollectionView
    private var presentation = KeyboardFixExtensionPresentation.unavailable

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(
            top: 2,
            left: 2,
            bottom: 2,
            right: 2
        )
        collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        super.init(frame: frame)
        configureHierarchy()
        registerForTraitChanges([
            UITraitUserInterfaceStyle.self,
            UITraitVerticalSizeClass.self,
            UITraitPreferredContentSizeCategory.self,
        ]) { (view: KeyboardFixesPanelView, _) in
            view.applyAppearance()
            view.collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func render(_ presentation: KeyboardFixExtensionPresentation) {
        self.presentation = presentation
        let message = presentation.status.message
        statusLabel.text = message
        statusLabel.isHidden = message == nil
        statusLabel.accessibilityLabel = message
        collectionView.reloadData()
        applyAppearance()
    }

    private func configureHierarchy() {
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityIdentifier = "keyboard.brand-stage.fixes"

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.numberOfLines = 2
        statusLabel.textAlignment = .center
        statusLabel.isHidden = true
        statusLabel.accessibilityIdentifier =
            "keyboard.brand-stage.fixes.status"

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.isDirectionalLockEnabled = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            KeyboardFixTileCell.self,
            forCellWithReuseIdentifier: KeyboardFixTileCell.reuseIdentifier
        )
        collectionView.accessibilityIdentifier =
            "keyboard.brand-stage.fixes.actions"

        let stack = UIStackView(arrangedSubviews: [
            statusLabel,
            collectionView,
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 4
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        applyAppearance()
    }

    private func applyAppearance() {
        switch presentation.status {
        case .failure:
            statusLabel.textColor = .systemRed
        case .applied:
            statusLabel.textColor = .systemGreen
        case .ready, .unavailable, .processing, .cancelling:
            statusLabel.textColor = .secondaryLabel
        }
        collectionView.reloadData()
    }
}

extension KeyboardFixesPanelView:
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        presentation.enabledActions.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: KeyboardFixTileCell.reuseIdentifier,
            for: indexPath
        )
        guard let cell = cell as? KeyboardFixTileCell else {
            return cell
        }
        let action = presentation.enabledActions[indexPath.item]
        let isProcessing: Bool
        switch presentation.status {
        case .processing(let identifier),
             .cancelling(let identifier):
            isProcessing = identifier == action.identifier
        case .ready, .unavailable, .failure, .applied:
            isProcessing = false
        }
        cell.render(
            action: action,
            isEnabled: presentation.isActionEnabled(action.identifier),
            isProcessing: isProcessing
        )
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let action = presentation.enabledActions[indexPath.item]
        guard presentation.isActionEnabled(action.identifier) else {
            return
        }
        onActionRequested?(action.identifier)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let compact = traitCollection.verticalSizeClass == .compact
        return CGSize(width: compact ? 112 : 132, height: compact ? 44 : 50)
    }
}

private final class KeyboardFixTileCell: UICollectionViewCell {
    static let reuseIdentifier = "KeyboardFixTileCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func render(
        action: KeyboardFixMetadataAction,
        isEnabled: Bool,
        isProcessing: Bool
    ) {
        iconView.image = UIImage(systemName: action.icon.systemImageName)
        titleLabel.text = action.title
        activityIndicator.isHidden = !isProcessing
        iconView.isHidden = isProcessing
        if isProcessing {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
        contentView.alpha = isEnabled || isProcessing ? 1 : 0.48
        isAccessibilityElement = true
        accessibilityTraits = isEnabled ? [.button] : [.button, .notEnabled]
        accessibilityLabel = action.title
        accessibilityValue = isProcessing ? "Applying" : nil
        accessibilityIdentifier =
            "keyboard.brand-stage.fixes.action.\(action.identifier)"
    }

    private func configureHierarchy() {
        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor =
            UIColor.separator.withAlphaComponent(0.25).cgColor
        contentView.backgroundColor = .secondarySystemBackground

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        titleLabel.font = .preferredFont(forTextStyle: .callout)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.72
        titleLabel.lineBreakMode = .byTruncatingTail
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [
            iconView,
            titleLabel,
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 7
        contentView.addSubview(stack)
        contentView.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 10
            ),
            stack.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -10
            ),
            stack.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 7
            ),
            stack.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -7
            ),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            activityIndicator.centerXAnchor.constraint(
                equalTo: iconView.centerXAnchor
            ),
            activityIndicator.centerYAnchor.constraint(
                equalTo: iconView.centerYAnchor
            ),
        ])
    }
}
