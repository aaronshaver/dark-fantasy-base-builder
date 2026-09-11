import PixelArt

enum EffectRecipes {
    static func frames(_ p: ParameterValues) throws -> [ArtFrame] {
        let length = try p.integer("markerLength"), debrisLength = try p.integer("debrisLength")
        var dot = Drawing(), corner = Drawing(), flash = Drawing()
        dot.rect(15, 15, 2, 2, "purple_light")
        var frames = [ArtFrame("path_dot", [dot.part("dot")])]
        corner.line(0, 0, length, 0, "purple_light"); corner.line(0, 0, 0, length, "purple_light")
        let corners = [(3.0, 3.0, 1.0, 1.0), (29.0, 3.0, -1.0, 1.0),
                       (3.0, 29.0, 1.0, -1.0), (29.0, 29.0, -1.0, -1.0)]
        frames.append(ArtFrame("destination", corners.enumerated().map { i, c in
            corner.part("corner\(i)", placement: Placement(c.0, c.1, scaleX: c.2, scaleY: c.3))
        }))
        for y in 0..<32 { for x in 0..<32 where (x + y) % 3 == 0 { flash.dot(x, y, "red_light") } }
        frames.append(ArtFrame("damage_flash", [flash.part("flash")]))
        for n in 0..<4 {
            var body = Drawing(), glint = Drawing()
            body.rect(0, 0, 3 + n + debrisLength, 3, n % 2 == 0 ? "steel" : "rust")
            glint.line(0, 0, 2 + n + debrisLength, 0, "steel_light")
            frames.append(ArtFrame("debris_\(n)", [.group(Group("fragment", placement: Placement(13, 13),
                                                                              children: [body.part("body"), glint.part("glint", z: 1)]))]))
        }
        return frames
    }
}
