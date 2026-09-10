import SpriteKit

final class ActorNode: SKSpriteNode {
    private var frameName = ""
    private let textures: PixelTextures

    init(textures: PixelTextures) {
        self.textures = textures
        super.init(texture: nil, color: .clear, size: CGSize(width: 32, height: 32))
    }

    required init?(coder: NSCoder) { fatalError("Programmatic scene") }

    func flashDamage() {
        childNode(withName: "damageFlash")?.removeFromParent()
        let flash = SKSpriteNode(texture: textures.texture("damage_flash"), size: CGSize(width: 32, height: 32))
        flash.name = "damageFlash"
        flash.zPosition = 20
        // Local coordinates keep the feedback on the actor throughout its movement.
        addChild(flash)
        flash.run(.sequence([.wait(forDuration: 0.10), .removeFromParent()]))
    }

    func synchronize(_ actor: Actor, time: Double) {
        let location = actor.position
        position = CGPoint(x: location.x * 32, y: location.y * 32)
        zPosition = 30 - CGFloat(location.y) * 0.01
        let kind = actor.kind == .necromancer ? "necromancer" : "human"
        let action: String
        let frame: Int
        if let attack = actor.attack {
            action = "attack"
            frame = attack.animationFrame
        } else if actor.movement != nil {
            action = "walk"
            frame = Int(time / 0.18) % 4
        } else {
            action = "idle"
            frame = Int((time + Double(actor.id) * 0.2) / 0.7) % 2
        }
        let next = "\(kind)_\(actor.facing.rawValue)_\(action)_\(frame)"
        if next != frameName {
            texture = textures.texture(next)
            frameName = next
        }
        if !actor.isAlive { zRotation = .pi / 2 }
    }
}
