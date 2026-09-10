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

final class GameToolbar: UIToolbar {
    var onNewGame: (() -> Void)?
    var onToggleZoom: (() -> Void)?
    var onTogglePause: (() -> Void)?
    private var zoomButton: UIBarButtonItem!
    private var pauseButton: UIBarButtonItem!

    init() {
        super.init(frame: .zero)
        let newGame = item(title: "New Game", symbol: "arrow.clockwise", identifier: "newGame", action: #selector(newGameTapped))
        zoomButton = item(title: "Zoom Out", symbol: "minus.magnifyingglass", identifier: "zoomToggle", action: #selector(zoomTapped))
        let raise = item(title: "Raise", symbol: "person.badge.plus", identifier: "raise")
        raise.isEnabled = false
        pauseButton = item(title: "Pause", symbol: "pause.fill", identifier: "pauseToggle", action: #selector(pauseTapped))
        setItems([newGame, .flexibleSpace(), zoomButton, .flexibleSpace(), raise, .flexibleSpace(), pauseButton], animated: false)
        heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("Programmatic toolbar") }

    func update(isPaused: Bool, gameOver: Bool) {
        pauseButton.image = UIImage(systemName: isPaused ? "play.fill" : "pause.fill")
        pauseButton.title = isPaused ? "Play" : "Pause"
        pauseButton.accessibilityLabel = pauseButton.title
        pauseButton.isEnabled = !gameOver
    }

    func updateZoom(isZoomedOut: Bool) {
        zoomButton.image = UIImage(systemName: isZoomedOut ? "plus.magnifyingglass" : "minus.magnifyingglass")
        zoomButton.title = isZoomedOut ? "Zoom In" : "Zoom Out"
        zoomButton.accessibilityLabel = zoomButton.title
        zoomButton.accessibilityValue = isZoomedOut ? "50%" : "100%"
    }

    @objc private func newGameTapped() { onNewGame?() }
    @objc private func zoomTapped() { onToggleZoom?() }
    @objc private func pauseTapped() { onTogglePause?() }

    private func item(title: String, symbol: String, identifier: String, action: Selector? = nil) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: UIImage(systemName: symbol), style: .plain, target: self, action: action)
        item.title = title
        item.accessibilityLabel = title
        item.accessibilityIdentifier = identifier
        return item
    }
}
