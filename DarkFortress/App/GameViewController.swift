import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private let textures = PixelTextures()
    private let gameView = SKView()
    private lazy var hud = GameHUD(textures: textures)
    private lazy var toolbar = GameToolbar(textures: textures)
    private let message = UILabel()
    private let hint = UILabel()
    private let situation = UILabel()
    private var gameScene: GameScene?
    private var hasStarted = false

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var shouldAutorotate: Bool { false }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GamePalette.panel
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
        hint.text = "TAP A TILE TO MOVE"
        hint.textColor = GamePalette.text
        hint.backgroundColor = GamePalette.background
        hint.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        hint.textAlignment = .center
        hint.layer.borderColor = GamePalette.border.cgColor
        hint.layer.borderWidth = 1
        situation.textColor = GamePalette.text
        situation.backgroundColor = GamePalette.background
        situation.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        situation.textAlignment = .center
        situation.accessibilityIdentifier = "gateStatus"
        for label in [situation, hint] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.isUserInteractionEnabled = false
            gameView.addSubview(label)
        }
        // Screen-centered, independent of camera movement and the safe-area game viewport.
        message.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(message)
        NSLayoutConstraint.activate([
            message.centerXAnchor.constraint(equalTo: view.centerXAnchor), message.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            message.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -24),
            situation.topAnchor.constraint(equalTo: gameView.topAnchor, constant: 12),
            situation.centerXAnchor.constraint(equalTo: gameView.centerXAnchor), situation.widthAnchor.constraint(equalToConstant: 230),
            situation.heightAnchor.constraint(equalToConstant: 26),
            hint.centerXAnchor.constraint(equalTo: gameView.centerXAnchor), hint.bottomAnchor.constraint(equalTo: gameView.bottomAnchor, constant: -16),
            hint.widthAnchor.constraint(equalToConstant: 192), hint.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func startNewGame() {
        guard gameView.bounds.width > 0 else { return }
        message.isHidden = true
        hint.isHidden = false
        hint.text = "TAP A TILE TO MOVE"
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
        scene.onPlayerMove = { [weak self] in self?.hint.isHidden = true }
        gameScene = scene
        gameView.presentScene(scene)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--paused") { scene.setPaused(true) }
        #endif
        updateHUD(scene.simulation)
        updatePausePresentation()
    }

    private func updateHUD(_ simulation: Simulation) {
        hud.update(hp: simulation.player.health.hp, maximum: simulation.player.health.maximumHP)
        situation.text = simulation.world.gate.isDestroyed ? "GATE BREACHED · THEY ARE INSIDE" : "IRON GATE  \(simulation.world.gate.hp) / \(simulation.world.gate.maximumHP)"
        situation.textColor = simulation.world.gate.isDestroyed ? GamePalette.red : GamePalette.text
        toolbar.update(isPaused: simulation.isPaused, gameOver: simulation.isGameOver)
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
        if simulation.isPaused { setMessage("Paused", size: 36) }
    }

    private func showDeath() {
        setMessage("You died", size: 48)
        message.isHidden = false
        hint.text = "NEW GAME TO BEGIN AGAIN"
        hint.isHidden = false
        if let simulation = gameScene?.simulation { updateHUD(simulation) }
        UIAccessibility.post(notification: .announcement, argument: "You died. Start a new game to try again.")
    }

    private func setMessage(_ text: String, size: CGFloat) {
        message.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: .heavy),
            .foregroundColor: GamePalette.purple,
            .strokeColor: GamePalette.white,
            .strokeWidth: -3.5
        ])
    }
}
