import SpriteKit

final class GameScene: SKScene {
    let simulation: Simulation
    private let textures: PixelTextures
    private let worldNode = SKNode()
    private let followCamera = SKCameraNode()
    private let pathOverlay: PathOverlay
    private var actorNodes: [Int: ActorNode] = [:]
    private var gateNode = SKSpriteNode()
    private var lastUpdate: TimeInterval?
    private var cameraReady = false
    private var gateStage = -1
    private var shownHP = -1
    private var didShowDeath = false
    private var pixelsPerArtPixel: CGFloat = 5
    var onStateChange: ((Simulation) -> Void)?
    var onDeath: (() -> Void)?

    init(size: CGSize, textures: PixelTextures, seed: UInt64? = nil) {
        self.textures = textures
        simulation = seed.map(Simulation.init(seed:)) ?? Simulation()
        pathOverlay = PathOverlay(textures: textures)
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = GamePalette.background
        addChild(worldNode)
        addChild(followCamera)
        camera = followCamera
        buildWorld()
    }

    required init?(coder: NSCoder) { fatalError("Programmatic scene") }

    override func didMove(to view: SKView) {
        let displayScale = view.window?.screen.scale ?? UIScreen.main.scale
        pixelsPerArtPixel = (displayScale * 1.65).rounded()
        followCamera.setScale(displayScale / pixelsPerArtPixel)
        synchronize()
    }

    private func sprite(_ name: String, at tile: Tile, z: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(texture: textures.texture(name), size: CGSize(width: 32, height: 32))
        node.position = CGPoint(x: tile.x * 32, y: tile.y * 32)
        node.zPosition = z
        worldNode.addChild(node)
        return node
    }

    private func buildWorld() {
        let world = simulation.world
        for (tile, ground) in world.ground {
            let name = ground.terrain == .wood ? "wood" : "grass"
            _ = sprite("\(name)_\(ground.variant)", at: tile, z: 0)
        }
        for (tile, variant) in world.wallVariants { _ = sprite("wall_\(variant)", at: tile, z: 10) }
        let chair = sprite("chair_\(world.chair.color)", at: world.chair.tile, z: 12)
        chair.zRotation = rotation(world.chair.direction)
        gateNode = sprite("gate_0", at: world.gateTile, z: 10)
        if world.gateDirection == .east || world.gateDirection == .west { gateNode.zRotation = .pi / 2 }
        worldNode.addChild(pathOverlay)
        for actor in simulation.actors {
            let node = ActorNode(textures: textures)
            actorNodes[actor.id] = node
            worldNode.addChild(node)
        }
    }

    private func rotation(_ direction: Direction) -> CGFloat {
        switch direction {
        case .south: return 0
        case .east: return .pi / 2
        case .north: return .pi
        case .west: return -.pi / 2
        }
    }

    func setPaused(_ paused: Bool) {
        simulation.isPaused = paused
        worldNode.isPaused = paused
        lastUpdate = nil
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate.map { currentTime - $0 } ?? 0
        lastUpdate = currentTime
        simulation.advance(by: delta)
        synchronize()
        for event in simulation.events {
            switch event {
            case .gateDamaged: flash(at: simulation.world.gateTile)
            case .gateDestroyed: destroyGate()
            case .playerDamaged: flash(at: simulation.player.tile)
            case .playerDied:
                if !didShowDeath {
                    didShowDeath = true
                    onDeath?()
                }
            }
        }
    }

    private func synchronize() {
        for actor in simulation.actors { actorNodes[actor.id]?.synchronize(actor, time: simulation.elapsed) }
        pathOverlay.synchronize(simulation.player)
        let stage = simulation.world.gate.damageStage
        if stage != gateStage && !simulation.world.gate.isDestroyed {
            gateNode.texture = textures.texture("gate_\(stage)")
            gateStage = stage
        }
        let player = simulation.player.position
        let target = CGPoint(x: player.x * 32, y: player.y * 32)
        // Exact follow and physical-pixel alignment preserve crisp scenery during movement.
        followCamera.position = CGPoint(x: (target.x * pixelsPerArtPixel).rounded() / pixelsPerArtPixel,
                                        y: (target.y * pixelsPerArtPixel).rounded() / pixelsPerArtPixel)
        if shownHP != simulation.player.health.hp || !cameraReady {
            shownHP = simulation.player.health.hp
            cameraReady = true
            onStateChange?(simulation)
        }
    }

    private func flash(at tile: Tile) {
        let key = "flash_\(tile.x)_\(tile.y)"
        worldNode.childNode(withName: key)?.removeFromParent()
        let node = sprite("damage_flash", at: tile, z: 50)
        node.name = key
        node.run(.sequence([.wait(forDuration: 0.09), .hide(), .wait(forDuration: 0.05), .unhide(),
                            .wait(forDuration: 0.07), .removeFromParent()]))
    }

    private func destroyGate() {
        gateNode.removeFromParent()
        for index in 0..<8 {
            let fragment = sprite("debris_\(index % 4)", at: simulation.world.gateTile, z: 40)
            let angle = CGFloat(index) * .pi / 4
            let distance: CGFloat = index.isMultiple(of: 2) ? 20 : 14
            fragment.run(.sequence([
                .group([.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.28),
                        .rotate(byAngle: .pi / 2, duration: 0.28)]),
                .wait(forDuration: 0.18), .removeFromParent()
            ]))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: worldNode)
        let tile = Tile(x: Int(floor((point.x + 16) / 32)), y: Int(floor((point.y + 16) / 32)))
        if simulation.movePlayer(to: tile) {
            pathOverlay.synchronize(simulation.player)
        }
    }
}
