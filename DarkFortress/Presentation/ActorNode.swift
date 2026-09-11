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
        let kind: String
        switch actor.kind {
        case .player: kind = "player"
        case .enemyMeleeSword: kind = "enemy_melee_sword"
        case .allySkeletonMelee: kind = "ally_skeleton_melee"
        }
        let animation = actor.animation(at: time)
        let next = "\(kind)_\(actor.facing.rawValue)_\(animation.action)_\(animation.frame)"
        if next != frameName {
            texture = textures.texture(next)
            frameName = next
        }
        zRotation = actor.isAlive ? 0 : .pi / 2
        alpha = CGFloat(actor.corpse?.opacity ?? 1)
    }
}
