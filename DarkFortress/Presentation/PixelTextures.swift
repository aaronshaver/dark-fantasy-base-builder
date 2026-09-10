import SpriteKit

final class PixelTextures {
    private let atlas = SKTextureAtlas(named: "Pixel")
    private var cache: [String: SKTexture] = [:]
    private var transparency: [String: Bool] = [:]

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

    func hasTransparentPixels(_ name: String) -> Bool {
        if let result = transparency[name] { return result }
        let image = texture(name).cgImage()
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let result = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return true
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] < 255 }
        }
        // Scan each texture once, never per frame or per tile.
        transparency[name] = result
        return result
    }
}
