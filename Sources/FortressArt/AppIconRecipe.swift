import PixelArt

enum AppIconRecipe {
    static func frame(_ p: ParameterValues) throws -> ArtFrame {
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
