import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private let textures = PixelTextures()
    private let gameView = SKView()
    private let hud = GameHUD()
    private let toolbar = GameToolbar()
    private let message = UILabel()
    private var gameScene: GameScene?
    private var hasStarted = false

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var shouldAutorotate: Bool { false }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        gameView.preferredFramesPerSecond = 60
        gameView.ignoresSiblingOrder = true
        gameView.shouldCullNonVisibleNodes = true
        gameView.isMultipleTouchEnabled = false
        gameView.accessibilityIdentifier = "gameWorld"
        // Children remain discoverable for the pause/death overlays.
        gameView.isAccessibilityElement = false
        for subview in [gameView, hud, toolbar] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            hud.topAnchor.constraint(equalTo: safe.topAnchor),
            hud.leadingAnchor.constraint(equalTo: view.leadingAnchor), hud.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor), toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            gameView.topAnchor.constraint(equalTo: hud.bottomAnchor), gameView.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -1),
            gameView.leadingAnchor.constraint(equalTo: view.leadingAnchor), gameView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        configureOverlays()
        configureDevButton()
        toolbar.onToggleZoom = { [weak self] in self?.toggleZoom() }
        toolbar.onTogglePause = { [weak self] in self?.togglePause() }
        textures.preload { [weak self] in
            DispatchQueue.main.async { self?.startIfReady() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        startIfReady()
    }

    private func startIfReady() {
        guard !hasStarted, gameView.bounds.width > 0 else { return }
        hasStarted = true
        startNewGame()
    }

    private func configureOverlays() {
        message.textAlignment = .center
        message.numberOfLines = 1
        message.font = .systemFont(ofSize: 88, weight: .bold)
        message.textColor = UIColor(white: 0.5, alpha: 0.75)
        message.adjustsFontSizeToFitWidth = true
        message.minimumScaleFactor = 0.5
        message.isHidden = true
        message.isUserInteractionEnabled = false
        message.accessibilityIdentifier = "gameMessage"
        // Screen-centered, independent of camera movement and the safe-area game viewport.
        message.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(message)
        NSLayoutConstraint.activate([
            message.centerXAnchor.constraint(equalTo: view.centerXAnchor), message.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            message.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -24)
        ])
    }

    private func configureDevButton() {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Dev"
        configuration.image = UIImage(systemName: "ladybug")
        configuration.imagePadding = 6
        configuration.baseBackgroundColor = .secondarySystemBackground
        configuration.baseForegroundColor = .label
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.pauseForInterruption()
            let menu = DevViewController()
            menu.onNewGame = { [weak self] in self?.startNewGame() }
            self.present(UINavigationController(rootViewController: menu), animated: true)
        })
        button.alpha = 0.75
        button.accessibilityIdentifier = "dev"
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: gameView.topAnchor, constant: 8),
            button.trailingAnchor.constraint(equalTo: gameView.trailingAnchor, constant: -8),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func startNewGame() {
        guard gameView.bounds.width > 0 else { return }
        message.isHidden = true
        let seed: UInt64?
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--seed"), arguments.indices.contains(index + 1) {
            seed = UInt64(arguments[index + 1])
        } else { seed = nil }
        #else
        seed = nil
        #endif
        let scene = GameScene(size: gameView.bounds.size, textures: textures, seed: seed)
        scene.onStateChange = { [weak self] simulation in self?.updateHUD(simulation) }
        scene.onDeath = { [weak self] in self?.showDeath() }
        gameScene = scene
        gameView.presentScene(scene)
        updateHUD(scene.simulation)
        updatePausePresentation()
    }

    private func updateHUD(_ simulation: Simulation) {
        hud.update(hp: simulation.player.health.hp)
        toolbar.update(isPaused: simulation.isPaused, gameOver: simulation.isGameOver)
        toolbar.updateZoom(percentage: gameScene?.zoomPercentage ?? 100)
    }

    private func toggleZoom() {
        guard let scene = gameScene else { return }
        scene.toggleZoom()
        toolbar.updateZoom(percentage: scene.zoomPercentage)
    }

    private func togglePause() {
        guard let scene = gameScene, !scene.simulation.isGameOver else { return }
        scene.setPaused(!scene.simulation.isPaused)
        updatePausePresentation()
    }

    func pauseForInterruption() {
        guard let scene = gameScene, !scene.simulation.isGameOver else { return }
        scene.setPaused(true)
        updatePausePresentation()
    }

    private func updatePausePresentation() {
        guard let simulation = gameScene?.simulation else { return }
        toolbar.update(isPaused: simulation.isPaused, gameOver: simulation.isGameOver)
        guard !simulation.isGameOver else { return }
        message.isHidden = !simulation.isPaused
        if simulation.isPaused {
            message.attributedText = nil
            message.text = "Paused"
        }
    }

    private func showDeath() {
        message.attributedText = nil
        message.text = "You died"
        message.isHidden = false
        if let simulation = gameScene?.simulation { updateHUD(simulation) }
        UIAccessibility.post(notification: .announcement, argument: "You died")
    }
}
