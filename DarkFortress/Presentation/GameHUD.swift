import UIKit

final class GameHUD: UIView {
    private let health = UILabel()

    init() {
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        let heart = UIImageView(image: UIImage(systemName: "heart.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)))
        heart.tintColor = .systemRed
        heart.contentMode = .center
        heart.isAccessibilityElement = false
        health.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        health.textColor = .label
        health.accessibilityIdentifier = "playerHealth"
        let stack = UIStackView(arrangedSubviews: [heart, health])
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 38),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heart.widthAnchor.constraint(equalToConstant: 32),
            heart.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    required init?(coder: NSCoder) { fatalError("Programmatic HUD") }

    func update(hp: Int) {
        health.text = "\(hp)"
        health.accessibilityLabel = "Health, \(hp)"
    }
}

final class GameToolbar: UIView {
    var onToggleZoom: (() -> Void)?
    var onTogglePause: (() -> Void)?
    private var zoomButton: UIButton!
    private var pauseButton: UIButton!

    init() {
        super.init(frame: .zero)
        zoomButton = item(title: "Zoom", symbol: "magnifyingglass", identifier: "zoomToggle", action: #selector(zoomTapped))
        pauseButton = item(title: "Pause", symbol: "pause.fill", identifier: "pauseToggle", action: #selector(pauseTapped))
        let stack = UIStackView(arrangedSubviews: [zoomButton, pauseButton])
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 64),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("Programmatic toolbar") }

    func update(isPaused: Bool, gameOver: Bool) {
        pauseButton.configuration?.image = UIImage(systemName: isPaused ? "play.fill" : "pause.fill")
        pauseButton.configuration?.title = isPaused ? "Play" : "Pause"
        pauseButton.accessibilityLabel = pauseButton.configuration?.title
        pauseButton.isEnabled = !gameOver
    }

    func updateZoom(percentage: Int) {
        zoomButton.accessibilityValue = "\(percentage)%"
    }

    @objc private func zoomTapped() { onToggleZoom?() }
    @objc private func pauseTapped() { onTogglePause?() }


    private func item(title: String, symbol: String, identifier: String, action: Selector? = nil) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePlacement = .top
        configuration.imagePadding = 4
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = .systemFont(ofSize: 11, weight: .medium)
            return result
        }
        let button = UIButton(configuration: configuration)
        button.titleLabel?.numberOfLines = 1
        button.accessibilityLabel = title
        button.accessibilityIdentifier = identifier
        if let action { button.addTarget(self, action: action, for: .touchUpInside) }
        return button
    }
}
