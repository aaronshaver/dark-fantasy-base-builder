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
        let savedText = UILabel()
        savedText.font = .preferredFont(forTextStyle: .caption1)
        savedText.adjustsFontForContentSizeCategory = true
        savedText.textColor = .secondaryLabel
        savedText.numberOfLines = 0
        savedText.accessibilityIdentifier = "bundledWriteProbe"
        // Read only the installed bundle, once. Saving in Debug cannot change this label.
        if let file = Bundle.main.url(forResource: "repository-write-test", withExtension: "txt", subdirectory: "WriteProbe") {
            do {
                savedText.text = try String(contentsOf: file, encoding: .utf8)
            } catch {
                savedText.text = "Could not read text file: \(error.localizedDescription)"
            }
        } else {
            savedText.text = "no text file found"
        }
        let stack = UIStackView(arrangedSubviews: [heart, health])
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = UIStackView(arrangedSubviews: [savedText, stack])
        content.axis = .vertical
        content.alignment = .leading
        content.spacing = 2
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
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
    var onNewGame: (() -> Void)?
    var onToggleZoom: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onDebug: (() -> Void)?
    private var zoomButton: UIButton!
    private var pauseButton: UIButton!

    init() {
        super.init(frame: .zero)
        let newGame = item(title: "New Game", symbol: "arrow.clockwise", identifier: "newGame", action: #selector(newGameTapped))
        zoomButton = item(title: "Zoom Out", symbol: "minus.magnifyingglass", identifier: "zoomToggle", action: #selector(zoomTapped))
        let raise = item(title: "Raise", symbol: "person.badge.plus", identifier: "raise")
        raise.isEnabled = false
        pauseButton = item(title: "Pause", symbol: "pause.fill", identifier: "pauseToggle", action: #selector(pauseTapped))
        let debug = item(title: "Debug", symbol: "ladybug", identifier: "debug", action: #selector(debugTapped))
        let stack = UIStackView(arrangedSubviews: [newGame, zoomButton, raise, pauseButton, debug])
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

    func updateZoom(isZoomedOut: Bool) {
        zoomButton.configuration?.image = UIImage(systemName: isZoomedOut ? "plus.magnifyingglass" : "minus.magnifyingglass")
        zoomButton.configuration?.title = isZoomedOut ? "Zoom In" : "Zoom Out"
        zoomButton.accessibilityLabel = zoomButton.configuration?.title
        zoomButton.accessibilityValue = isZoomedOut ? "50%" : "100%"
    }

    @objc private func newGameTapped() { onNewGame?() }
    @objc private func zoomTapped() { onToggleZoom?() }
    @objc private func pauseTapped() { onTogglePause?() }

    @objc private func debugTapped() { onDebug?() }

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
