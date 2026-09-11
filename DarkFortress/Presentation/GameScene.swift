import SpriteKit

final class GameScene: SKScene {
    let simulation: Simulation
    private let textures: PixelTextures
    private let worldNode = SKNode()
    private let followCamera = SKCameraNode()
    private var pathOverlay: PathOverlay
    private var actorNodes: [Int: ActorNode] = [:]
    private var doorNodes: [Tile: SKSpriteNode] = [:]
    private var doorGroundNodes: [Tile: [SKSpriteNode]] = [:]
    private var lastUpdate: TimeInterval?
    private var cameraReady = false
    private var doorStages: [Tile: Int] = [:]
    private var shownHP = -1
    private var didShowDeath = false
    private var pixelsPerArtPixel: CGFloat = 5
    private var normalCameraScale: CGFloat = 0.6
    private(set) var zoomLevel = 0
    private var zoomMultiplier: CGFloat { [1, 2, 4][zoomLevel] }
    var zoomPercentage: Int { [100, 50, 25][zoomLevel] }
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
        normalCameraScale = displayScale / pixelsPerArtPixel
        updateCameraScale()
        synchronize()
    }

    func toggleZoom() {
        zoomLevel = (zoomLevel + 1) % 3
        updateCameraScale()
        synchronize()
    }

    private func updateCameraScale() {
        // Cycle through normal, half-size, and quarter-size artwork.
        followCamera.setScale(normalCameraScale * zoomMultiplier)
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
        let walls = world.walls
        for (tile, ground) in world.ground {
            // Every static tile starts with grass. Walk down from the top layer
            // only while transparency can expose the next layer.
            var layers = [(name: "ground_grass_\(ground.variant)", z: CGFloat(0))]
            if ground.terrain == .wood { layers.append(("floor_wood_\(ground.variant)", 1)) }
            if let wall = walls[tile], !wall.health.isDestroyed { layers.append(("wall_stone_\(wall.variant)", 10)) }
            for layer in layers.reversed() {
                let node = sprite(layer.name, at: tile, z: layer.z)
                if world.door(at: tile) != nil { doorGroundNodes[tile, default: []].append(node) }
                if !textures.hasTransparentPixels(layer.name) { break }
            }
        }
        for room in world.rooms {
            guard let name = room.definition.displayName else { continue }
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = name
            label.fontSize = 24
            label.fontColor = GamePalette.text
            label.alpha = 0.75
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: (Double(room.interiorOrigin.x) + Double(room.definition.interiorWidth - 1) / 2) * 32,
                                     y: Double(room.interiorOrigin.y) * 32)
            label.zPosition = 2
            worldNode.addChild(label)
        }
        for chair in world.chairs {
            _ = sprite("furniture_chair_\(chair.color)", at: chair.tile, z: 12)
        }
        for door in world.doors where !door.health.isDestroyed {
            // Friendly actors walk above the unchanged door sprite, just like furniture.
            doorNodes[door.tile] = sprite("door_metal_gate_0", at: door.tile, z: 10)
        }
        worldNode.addChild(pathOverlay)
        for actor in simulation.actors {
            let node = ActorNode(textures: textures)
            actorNodes[actor.id] = node
            worldNode.addChild(node)
        }
    }

    func setPaused(_ paused: Bool) {
        simulation.isPaused = paused
        worldNode.isPaused = paused
        lastUpdate = nil
    }

    /// Rebuild presentation after an asset replacement, preserving simulation, camera, zoom, and pause state.
    func reloadTextures() {
        worldNode.removeAllChildren()
        actorNodes.removeAll()
        doorNodes.removeAll()
        doorGroundNodes.removeAll()
        doorStages.removeAll()
        pathOverlay = PathOverlay(textures: textures)
        buildWorld()
        synchronize()
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate.map { currentTime - $0 } ?? 0
        lastUpdate = currentTime
        simulation.advance(by: delta)
        synchronize()
        for event in simulation.events {
            switch event {
            case .doorDamaged(let tile, _): flash(at: tile)
            case .doorDestroyed(let tile): destroyDoor(at: tile)
            case .playerDamaged: actorNodes[simulation.player.id]?.flashDamage()
            case .actorDamaged(let id, _): actorNodes[id]?.flashDamage()
            case .actorDied: break
            case .actorDespawned(let id):
                let node = actorNodes.removeValue(forKey: id)
                node?.removeAllActions()
                node?.removeAllChildren()
                node?.removeFromParent()
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
        for door in simulation.world.doors where !door.health.isDestroyed {
            let stage = door.health.damageStage
            if stage != doorStages[door.tile] {
                let name = "door_metal_gate_\(stage)"
                doorNodes[door.tile]?.texture = textures.texture(name)
                // Preserve the underlayer for destruction while opaque doors cover it.
                doorGroundNodes[door.tile]?.forEach { $0.isHidden = !textures.hasTransparentPixels(name) }
                doorStages[door.tile] = stage
            }
        }
        let player = simulation.player.position
        let target = CGPoint(x: player.x * 32, y: player.y * 32)
        // Exact follow and physical-pixel alignment preserve crisp scenery during movement.
        let cameraPixelsPerArtPixel = pixelsPerArtPixel / zoomMultiplier
        followCamera.position = CGPoint(x: (target.x * cameraPixelsPerArtPixel).rounded() / cameraPixelsPerArtPixel,
                                        y: (target.y * cameraPixelsPerArtPixel).rounded() / cameraPixelsPerArtPixel)
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

    private func destroyDoor(at tile: Tile) {
        doorNodes.removeValue(forKey: tile)?.removeFromParent()
        doorGroundNodes[tile]?.forEach { $0.isHidden = false }
        for index in 0..<8 {
            let fragment = sprite("debris_\(index % 4)", at: tile, z: 40)
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
