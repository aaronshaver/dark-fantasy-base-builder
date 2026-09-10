import UIKit

final class GameHUD: UIView {
    private let health = UILabel()

    init(textures: PixelTextures) {
        super.init(frame: .zero)
        backgroundColor = GamePalette.panel
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 38),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3)
        ])
        stack.addArrangedSubview(icon("icon_heart", textures: textures))
        health.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        health.textColor = GamePalette.text
        health.accessibilityIdentifier = "playerHealth"
        health.setContentHuggingPriority(.required, for: .horizontal)
        stack.addArrangedSubview(health)
        stack.addArrangedSubview(UIView())
        for name in ["icon_bone", "icon_stone", "icon_moon"] {
            stack.addArrangedSubview(icon(name, textures: textures))
            let placeholder = UILabel()
            placeholder.text = "—"
            placeholder.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            placeholder.textColor = GamePalette.muted
            placeholder.isAccessibilityElement = false
            stack.addArrangedSubview(placeholder)
        }
        let border = UIView()
        border.backgroundColor = GamePalette.border
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)
        NSLayoutConstraint.activate([border.heightAnchor.constraint(equalToConstant: 1), border.bottomAnchor.constraint(equalTo: bottomAnchor),
                                     border.leadingAnchor.constraint(equalTo: leadingAnchor), border.trailingAnchor.constraint(equalTo: trailingAnchor)])
    }

    required init?(coder: NSCoder) { fatalError("Programmatic HUD") }

    func update(hp: Int, maximum: Int) {
        health.text = "\(hp) / \(maximum)"
        health.textColor = hp <= maximum / 3 ? GamePalette.red : GamePalette.text
        health.accessibilityLabel = "Health, \(hp) of \(maximum)"
    }

    private func icon(_ name: String, textures: PixelTextures) -> UIImageView {
        let image = UIImageView(image: textures.image(name))
        image.contentMode = .scaleAspectFit
        image.layer.magnificationFilter = .nearest
        image.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([image.widthAnchor.constraint(equalToConstant: 32), image.heightAnchor.constraint(equalToConstant: 32)])
        image.isAccessibilityElement = false
        return image
    }
}

final class GameToolbar: UIStackView {
    var onNewGame: (() -> Void)?
    var onTogglePause: (() -> Void)?
    private let textures: PixelTextures
    private var pauseButton: UIButton!

    init(textures: PixelTextures) {
        self.textures = textures
        super.init(frame: .zero)
        axis = .horizontal
        distribution = .fillEqually
        spacing = 1
        backgroundColor = GamePalette.border
        let newGame = button(title: "New Game", icon: "new", identifier: "newGame")
        newGame.addAction(UIAction { [weak self] _ in self?.onNewGame?() }, for: .touchUpInside)
        addArrangedSubview(newGame)
        let build = button(title: "Build", icon: "build", identifier: "build")
        build.isEnabled = false
        build.accessibilityLabel = "Build, coming later"
        addArrangedSubview(build)
        let raise = button(title: "Raise", icon: "raise", identifier: "raise")
        raise.isEnabled = false
        raise.accessibilityLabel = "Raise skeletons, coming later"
        addArrangedSubview(raise)
        pauseButton = button(title: "Pause", icon: "pause", identifier: "pauseToggle")
        pauseButton.addAction(UIAction { [weak self] _ in self?.onTogglePause?() }, for: .touchUpInside)
        addArrangedSubview(pauseButton)
        heightAnchor.constraint(equalToConstant: 70).isActive = true
    }

    required init(coder: NSCoder) { fatalError("Programmatic toolbar") }

    func update(isPaused: Bool, gameOver: Bool) {
        var configuration = pauseButton.configuration!
        configuration.title = isPaused ? "Play" : "Pause"
        configuration.image = textures.image(isPaused ? "icon_play" : "icon_pause")
        pauseButton.configuration = configuration
        pauseButton.accessibilityLabel = isPaused ? "Play" : "Pause"
        pauseButton.isEnabled = !gameOver
    }

    private func button(title: String, icon: String, identifier: String) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = textures.image("icon_\(icon)")
        configuration.imagePlacement = .top
        configuration.imagePadding = 1
        configuration.baseForegroundColor = GamePalette.purple
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var result = incoming
            result.font = .systemFont(ofSize: 11, weight: .semibold)
            return result
        }
        let button = UIButton(configuration: configuration)
        button.backgroundColor = GamePalette.panel
        button.accessibilityIdentifier = identifier
        button.imageView?.layer.magnificationFilter = .nearest
        button.configurationUpdateHandler = { button in
            button.alpha = 1
            var updated = button.configuration!
            updated.baseForegroundColor = button.isEnabled ? GamePalette.purple : GamePalette.muted
            button.configuration = updated
            button.backgroundColor = button.isHighlighted ? GamePalette.darkPurple : GamePalette.panel
        }
        return button
    }
}
