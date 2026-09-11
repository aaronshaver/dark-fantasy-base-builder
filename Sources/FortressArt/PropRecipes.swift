import PixelArt

enum PropRecipes {
    static func gates(_ p: ParameterValues) throws -> [ArtFrame] {
        let barWidth = try p.integer("barWidth"), lockWidth = try p.integer("lockWidth")
        return (0..<3).map { stage in
            var surround = Drawing(), rail = Drawing(), lock = Drawing(), damage = Drawing()
            surround.rect(0, 0, 32, 32, "ink"); surround.rect(1, 1, 30, 29, "steel_dark")
            surround.rect(3, 3, 26, 25, "stone_dark")
            var children = [surround.part("surround")]
            var bar = Drawing()
            bar.rect(0, 0, barWidth, 25, "steel"); bar.line(0, 0, 0, 23, "steel_light")
            for (i, x) in [4, 10, 16, 22, 28].enumerated() {
                children.append(bar.part("bar\(i)", z: 1, placement: Placement(Double(x), 3)))
            }
            rail.rect(0, 0, 28, 4, "steel"); rail.rect(0, 0, 28, 1, "steel_light")
            for x in [2, 9, 18, 25] { rail.dot(x, 2, "gold") }
            for (i, y) in [5, 22].enumerated() {
                children.append(rail.part("rail\(i)", z: 2, placement: Placement(2, Double(y))))
            }
            lock.rect(0, 0, lockWidth, 7, "ink"); lock.rect(1, 0, lockWidth - 2, 5, "gold")
            lock.rect(lockWidth / 2 - 1, 2, 2, 2, "wood_dark")
            children.append(lock.part("lock", z: 3, placement: Placement(Double(17 - lockWidth / 2), 13)))
            if stage >= 1 {
                damage.line(7, 4, 14, 13, "ink"); damage.line(8, 4, 15, 13, "rust_light")
                damage.rect(9, 12, 4, 4, "ink"); damage.line(21, 20, 27, 27, "rust")
            }
            if stage == 2 {
                damage.rect(10, 15, 14, 6, "ink"); damage.line(23, 9, 18, 18, "steel_glint")
                damage.line(5, 21, 13, 25, "ink"); damage.rect(16, 22, 7, 4, "ink")
            }
            children.append(damage.part("damage", z: 10))
            return ArtFrame("gate_\(stage)", children)
        }
    }

    static func chairs(_ p: ParameterValues) throws -> [ArtFrame] {
        let backHeight = try p.integer("backHeight"), seatWidth = try p.integer("seatWidth")
        let colors = [("red_dark", "red", "red_light"), ("teal_dark", "teal", "teal_light"), ("purple_deep", "purple", "lilac")]
        return colors.enumerated().map { v, colors in
            var shadow = Drawing(), legs = Drawing(), back = Drawing(), seat = Drawing()
            shadow.rect(6, 8, 21, 22, "grass_dark")
            for x in [7, 23] { legs.rect(x, 17, 3, 12, "wood_dark"); legs.rect(x, 17, 2, 10, "wood_glint") }
            back.rect(0, 0, 21, backHeight, "wood_dark"); back.rect(1, 0, 19, 2, "wood_glint")
            back.rect(3, 3, 15, backHeight - 5, colors.0); back.rect(4, 3, 13, backHeight - 7, colors.1)
            back.rect(4, 3, 13, 1, colors.2)
            seat.rect(0, 0, seatWidth, 8, "wood_dark"); seat.rect(2, 0, seatWidth - 4, 6, colors.1)
            seat.rect(2, 0, seatWidth - 4, 1, colors.2); seat.rect(1, 7, seatWidth - 2, 2, "wood_light")
            return ArtFrame("chair_\(v)", [shadow.part("shadow"), legs.part("legs", z: 1),
                back.part("back", z: 2, placement: Placement(6, Double(18 - backHeight)),
                          anchors: ["seat": Point(10.5, Double(backHeight - 1))]),
                seat.part("seat", z: 3, placement: Placement(attached: Attachment(to: "back", anchor: "seat", own: "center")),
                          anchors: ["center": Point(Double(seatWidth) / 2, 0)])])
        }
    }
}
