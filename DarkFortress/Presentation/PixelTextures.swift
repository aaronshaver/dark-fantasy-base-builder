import SpriteKit

final class PixelTextures {
    private let atlas = SKTextureAtlas(named: "Pixel")
    private var cache: [String: SKTexture] = [:]

    init() {
        for filename in atlas.textureNames {
            let name = (filename as NSString).deletingPathExtension
            let texture = atlas.textureNamed(filename)
            texture.filteringMode = .nearest
            cache[name] = texture
        }
    }

    func texture(_ name: String) -> SKTexture {
        guard let texture = cache[name] else { preconditionFailure("Missing pixel sprite: \(name)") }
        return texture
    }

    func preload(completion: @escaping () -> Void) {
        atlas.preload(completionHandler: completion)
    }
}
