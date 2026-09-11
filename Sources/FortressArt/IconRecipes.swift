import PixelArt

enum IconRecipes {
    static func frames(_ p: ParameterValues) throws -> [ArtFrame] {
        let accent = try p.choice("accent")
        var heart = Drawing(), shine = Drawing()
        heart.rect(6, 8, 8, 5, "red_light"); heart.rect(18, 8, 8, 5, "red_light")
        heart.rect(4, 11, 24, 8, "red"); heart.rect(7, 19, 18, 3, "red")
        heart.rect(10, 22, 12, 3, "red"); heart.rect(13, 25, 6, 2, "red"); heart.rect(15, 27, 2, 1, "red_dark")
        shine.rect(7, 11, 5, 3, "red_light")
        var frames = [ArtFrame("icon_heart", [heart.part("heart"), shine.part("shine", z: 1)])]
        for name in ["bone", "stone", "moon", "new", "build", "raise", "pause", "play"] {
            var d = Drawing()
            switch name {
            case "bone":
                d.line(9, 23, 23, 9, "muted"); d.line(10, 24, 24, 10, "muted")
                for (x, y) in [(7, 21), (9, 23), (21, 7), (23, 9)] { d.rect(x, y, 4, 4, "muted") }
            case "stone", "build":
                var blocks: [ArtNode] = []
                for (i, block) in [(6, 18, 10), (17, 18, 10), (10, 10, 12)].enumerated() {
                    var fill = Drawing(), edge = Drawing()
                    fill.rect(0, 0, block.2, 7, name == "stone" ? "muted" : accent)
                    edge.line(1, 1, block.2 - 2, 1, "stone_light")
                    blocks.append(.group(Group("block\(i)", placement: Placement(Double(block.0), Double(block.1)),
                                               children: [fill.part("fill"), edge.part("highlight", z: 1)])))
                }
                frames.append(ArtFrame("icon_\(name)", blocks)); continue
            case "moon":
                for y in 6..<26 { for x in 6..<26 {
                    if (x - 16) * (x - 16) + (y - 16) * (y - 16) < 100 && (x - 21) * (x - 21) + (y - 12) * (y - 12) > 80 {
                        d.dot(x, y, "muted")
                    }
                } }
            case "new":
                for (x0, y0, x1, y1) in [(8, 9, 23, 9), (23, 9, 26, 15), (26, 15, 23, 23), (23, 23, 10, 24), (10, 24, 6, 18)] {
                    d.line(x0, y0, x1, y1, accent); d.line(x0, y0 + 1, x1, y1 + 1, accent)
                }
                d.rect(7, 6, 3, 9, accent); d.rect(7, 12, 8, 3, accent)
            case "raise":
                var face = Drawing()
                d.rect(9, 7, 14, 14, accent); d.rect(11, 5, 10, 17, accent)
                for x in [12, 16, 20] { d.rect(x, 21, 2, 4, accent) }
                face.rect(11, 11, 4, 4, "panel"); face.rect(18, 11, 4, 4, "panel")
                frames.append(ArtFrame("icon_raise", [d.part("skull"), face.part("eyes", z: 1)])); continue
            case "pause": d.rect(9, 8, 5, 17, accent); d.rect(19, 8, 5, 17, accent)
            case "play":
                for x in 11..<25 { let h = max(1, 18 - (x - 11) * 2); d.rect(x, 16 - h / 2, 1, h, accent) }
            default: break
            }
            frames.append(ArtFrame("icon_\(name)", [d.part(name)]))
        }
        return frames
    }

    static func appIcon(_ p: ParameterValues) throws -> ArtFrame {
        let towerHeight = try p.integer("towerHeight")
        var background = Drawing(), fortress = Drawing(), doorway = Drawing(), figure = Drawing()
        background.rect(0, 0, 32, 32, "void"); fortress.rect(4, 6, 24, 22, "stone_dark")
        for x in [5, 13, 21] {
            fortress.rect(x, 12 - towerHeight, 6, towerHeight, "stone")
            fortress.line(x, 12 - towerHeight, x + 5, 12 - towerHeight, "stone_light")
        }
        fortress.rect(6, 12, 20, 15, "stone")
        doorway.rect(0, 2, 8, 13, "ink"); doorway.rect(1, 0, 6, 13, "ink")
        figure.rect(0, 0, 4, 8, "purple"); figure.rect(-1, 6, 6, 3, "lilac")
        figure.dot(1, 1, "skin_light"); figure.dot(3, 1, "skin_light")
        return ArtFrame("AppIcon", [background.part("background"), fortress.part("fortress", z: 1),
            doorway.part("doorway", z: 2, placement: Placement(12, 13), anchors: ["figure": Point(2, 4)]),
            figure.part("figure", z: 3, placement: Placement(attached: Attachment(to: "doorway", anchor: "figure")))])
    }
}
