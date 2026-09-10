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
        toolbar.onNewGame = { [weak self] in self?.startNewGame() }
        toolbar.onToggleZoom = { [weak self] in self?.toggleZoom() }
        toolbar.onTogglePause = { [weak self] in self?.togglePause() }
        NotificationCenter.default.addObserver(self, selector: #selector(pauseForInterruption),
                                               name: UIApplication.willResignActiveNotification, object: nil)
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
        message.numberOfLines = 0
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
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--paused") { scene.setPaused(true) }
        #endif
        updateHUD(scene.simulation)
        updatePausePresentation()
    }

    private func updateHUD(_ simulation: Simulation) {
        hud.update(hp: simulation.player.health.hp)
        toolbar.update(isPaused: simulation.isPaused, gameOver: simulation.isGameOver)
        toolbar.updateZoom(isZoomedOut: gameScene?.isZoomedOut ?? false)
    }

    private func toggleZoom() {
        guard let scene = gameScene else { return }
        scene.toggleZoom()
        toolbar.updateZoom(isZoomedOut: scene.isZoomedOut)
    }

    private func togglePause() {
        guard let scene = gameScene, !scene.simulation.isGameOver else { return }
        scene.setPaused(!scene.simulation.isPaused)
        updatePausePresentation()
    }

    @objc private func pauseForInterruption() {
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
            message.font = .systemFont(ofSize: 36, weight: .semibold)
            message.textColor = .label
            message.text = "Paused"
        }
    }

    private func showDeath() {
        message.attributedText = nil
        message.font = .systemFont(ofSize: 48, weight: .bold)
        message.textColor = .white
        message.text = "You died"
        message.isHidden = false
        if let simulation = gameScene?.simulation { updateHUD(simulation) }
        UIAccessibility.post(notification: .announcement, argument: "You died")
    }
}
