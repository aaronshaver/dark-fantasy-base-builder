import SpriteKit

final class PathOverlay: SKNode {
    private let textures: PixelTextures
    private var lastTiles: [Tile] = []
    private var dots: [(node: SKSpriteNode, distance: CGFloat)] = []
    private let target: SKSpriteNode

    init(textures: PixelTextures) {
        self.textures = textures
        target = SKSpriteNode(texture: textures.texture("destination"), size: CGSize(width: 32, height: 32))
        super.init()
        zPosition = 20
        addChild(target)
        target.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("Programmatic scene") }

    func synchronize(_ player: Actor) {
        var tiles = [player.movement?.from ?? player.tile]
        if let movement = player.movement { tiles.append(movement.to) }
        tiles += player.route
        if tiles != lastTiles {
            lastTiles = tiles
            dots.forEach { $0.node.removeFromParent() }
            dots.removeAll(keepingCapacity: true)
            if tiles.count > 1 {
                for index in 0..<(tiles.count - 1) {
                    let start = tiles[index]
                    let end = tiles[index + 1]
                    for offset in 1...4 {
                        let fraction = CGFloat(offset) / 4
                        let dot = SKSpriteNode(texture: textures.texture("path_dot"), size: CGSize(width: 32, height: 32))
                        dot.position = CGPoint(x: (CGFloat(start.x) + CGFloat(end.x - start.x) * fraction) * 32,
                                               y: (CGFloat(start.y) + CGFloat(end.y - start.y) * fraction) * 32)
                        addChild(dot)
                        dots.append((dot, CGFloat(index) + fraction))
                    }
                }
            }
        }
        let progress = CGFloat(player.movement?.fraction ?? 0)
        for dot in dots { dot.node.isHidden = dot.distance <= progress }
        target.isHidden = tiles.count < 2
        if let destination = tiles.last {
            target.position = CGPoint(x: destination.x * 32, y: destination.y * 32)
        }
    }
}
