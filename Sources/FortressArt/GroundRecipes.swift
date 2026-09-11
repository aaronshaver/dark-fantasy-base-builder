import PixelArt

/// Material recipes assemble repeated groups from drawing primitives and declared parameters.
enum GroundRecipes {
    static func frames(kind: String, parameters p: ParameterValues, seed: UInt64) throws -> [ArtFrame] {
        try (0..<4).map { variant in
            switch kind {
            case "floor_wood": return try woodFloor(variant, p, seed)
            case "wall_stone": return try stoneWall(variant, p, seed)
            default: return try grassGround(variant, p, seed)
            }
        }
    }

    private static func woodFloor(_ v: Int, _ p: ParameterValues, _ seed: UInt64) throws -> ArtFrame {
        let joints = [[21, 8, 27, 13], [6, 25, 12, 29], [14, 30, 5, 22], [28, 13, 23, 7]]
        let boards = [["wood", "wood_mid", "wood", "wood_mid"],
                      ["wood_mid", "wood_light", "wood", "wood_mid"],
                      ["wood", "wood", "wood_mid", "wood"],
                      ["wood_mid", "wood", "wood_light", "wood"]]
        let knots = [[(25, 20, 2)], [(10, 12, 4)], [(22, 5, 3), (8, 27, 2)], [(20, 20, 4)]]
        let jointOffset = try p.integer("jointOffset"), grainCount = try p.integer("grainCount")
        let knotSize = try p.integer("knotSize")
        var children: [ArtNode] = []
        for row in 0..<4 {
            var board = Drawing(), grain = Drawing(), joint = Drawing()
            board.rect(0, 0, 32, 8, boards[v][row])
            board.line(0, 0, 31, 0, "wood_dark")
            board.line(0, 1, 31, 1, "wood_light")
            let seam = joints[v][row] + jointOffset
            joint.line(seam, 0, seam, 7, "wood_seam")
            joint.dot(seam + 2, 2, "wood_dark"); joint.dot(seam - 2, 6, "wood_dark")
            var rng = SeededRandom(seed: seed, stream: "wood/\(v)/board/\(row)")
            for _ in 0..<grainCount {
                let x = rng.integer(0..<27), y = rng.integer(3..<7)
                grain.line(x, y, min(31, x + rng.integer(6..<15)), y,
                           rng.choose(["wood_seam", "wood_light", "wood_glint"]))
            }
            children.append(.group(Group("plank\(row)", placement: Placement(0, Double(row * 8)),
                                         children: [board.part("surface"), joint.part("joint", z: 1), grain.part("grain", z: 2)])))
        }
        for (i, knot) in knots[v].enumerated() {
            let radius = knot.2 + knotSize
            var d = Drawing()
            d.line(-radius, 0, radius, 0, "wood_dark")
            d.line(-radius + 1, -1, radius - 1, -1, "wood_seam")
            d.line(-radius, 1, radius, 1, "wood_glint"); d.dot(0, 0, "ink")
            children.append(d.part("knot\(i)", z: 10, placement: Placement(Double(knot.0), Double(knot.1))))
        }
        var splits = Drawing()
        if v == 1 {
            splits.line(18, 26, 29, 26, "wood_dark"); splits.line(14, 27, 21, 27, "wood_dark")
        } else if v == 2 {
            splits.line(2, 12, 20, 12, "wood_seam"); splits.line(7, 11, 15, 11, "wood_dark")
        } else if v == 3 {
            splits.line(4, 4, 24, 4, "wood_dark"); splits.line(13, 5, 28, 5, "wood_dark")
            splits.line(12, 18, 23, 18, "wood_glint")
        }
        children.append(splits.part("splits", z: 11))
        return ArtFrame("floor_wood_\(v)", children)
    }

    private static func grassGround(_ v: Int, _ p: ParameterValues, _ seed: UInt64) throws -> ArtFrame {
        let patches: [[(Int, Int, Int, Int, String)]] = [
            [(9, 22, 7, 4, "grass_mid")],
            [(12, 12, 9, 6, "grass_mid"), (23, 24, 5, 3, "grass_light")],
            [(14, 20, 9, 5, "grass_dark"), (21, 9, 5, 3, "grass_mid")],
            [(10, 11, 7, 5, "grass_light"), (21, 23, 8, 5, "grass_mid")]
        ]
        let patchSize = try p.integer("patchSize"), bladeHeight = try p.integer("bladeHeight")
        let tuftCount = [11, 18, 7, 14][v] + (try p.integer("tuftAdjustment"))
        var base = Drawing(); base.rect(0, 0, 32, 32, "grass")
        var children = [base.part("ground")]
        for (i, patch) in patches[v].enumerated() {
            let rx = patch.2 + patchSize, ry = patch.3 + patchSize
            var rng = SeededRandom(seed: seed, stream: "grass/\(v)/patch/\(i)")
            var d = Drawing()
            for y in -ry...ry { for x in -rx...rx {
                let distance = pow2(Double(x) / Double(rx)) + pow2(Double(y) / Double(ry))
                if distance < 0.65 + rng.unit() * 0.45 {
                    // Keep the material's edge uniform so adjacent tiles blend.
                    if (1..<31).contains(x + patch.0), (1..<31).contains(y + patch.1) { d.dot(x, y, patch.4) }
                }
            } }
            children.append(d.part("patch\(i)", z: 1, placement: Placement(Double(patch.0), Double(patch.1))))
        }
        var texture = Drawing(), rng = SeededRandom(seed: seed, stream: "grass/\(v)/texture")
        for _ in 0..<25 {
            texture.rect(rng.integer(0..<32), rng.integer(0..<32), rng.integer(1..<4), 1,
                         rng.choose(["grass_dark", "grass_mid"]))
        }
        children.append(texture.part("texture", z: 2))
        for i in 0..<tuftCount {
            var rng = SeededRandom(seed: seed, stream: "grass/\(v)/tuft/\(i)")
            let x = rng.integer(2..<29), y = rng.integer(8..<31)
            let height = rng.integer((v == 1 || v == 3) ? 3..<7 : 2..<5) + bladeHeight
            var d = Drawing()
            d.line(0, 0, 0, -height, "grass_light")
            d.line(-1, 0, -2, -height + 1, "grass_mid")
            d.line(1, 0, 2, -height + 2, "grass_tip")
            d.dot(0, -height, v == 3 ? "moss" : "grass_tip")
            children.append(.group(Group("tuft\(i)", z: 3, placement: Placement(Double(x), Double(y)),
                                         children: [d.part("blades")])) )
        }
        if v == 2 {
            var d = Drawing()
            for (x, y) in [(10, 19), (17, 22), (20, 17)] { d.line(x, y, x + 2, y, "moss") }
            children.append(d.part("moss", z: 4))
        }
        return ArtFrame("ground_grass_\(v)", children)
    }

    private static func pow2(_ x: Double) -> Double { x * x }

    private static func stoneWall(_ v: Int, _ p: ParameterValues, _ seed: UInt64) throws -> ArtFrame {
        let courses: [[(Int, Int, [Int])]] = [
            [(0, 10, [-5, 13, 32]), (10, 20, [-1, 8, 25, 36]), (20, 30, [-7, 18, 36])],
            [(0, 15, [-2, 21, 35]), (15, 30, [-8, 10, 33])],
            [(0, 8, [-5, 9, 25, 37]), (8, 20, [-1, 18, 34]), (20, 30, [-5, 6, 22, 36])],
            [(0, 12, [-7, 16, 34]), (12, 23, [-2, 7, 28, 38]), (23, 30, [-9, 20, 36])]
        ]
        let offset = try p.integer("jointOffset"), pits = try p.integer("pitCount")
        var mortar = Drawing(); mortar.rect(0, 0, 32, 32, "stone_dark")
        var children = [mortar.part("mortar")]
        for (row, course) in courses[v].enumerated() {
            let cuts = course.2.map { $0 + offset }, height = course.1 - course.0
            for (block, edges) in zip(cuts, cuts.dropFirst()).enumerated() {
                let width = edges.1 - edges.0
                var stone = Drawing(), wear = Drawing()
                stone.rect(1, 1, width - 2, height - 2, ["stone", "stone_mid", "stone_light"][(v + row + block) % 3])
                stone.line(2, 1, width - 3, 1, "stone_top")
                stone.line(1, 2, 1, height - 3, "stone_light")
                stone.line(2, height - 2, width - 2, height - 2, "stone")
                var rng = SeededRandom(seed: seed, stream: "wall/\(v)/\(row)/\(block)")
                for _ in 0..<pits { wear.dot(rng.integer(2..<(width - 1)), rng.integer(2..<(height - 1)), v == 2 ? "stone_dark" : "stone_mid") }
                children.append(.group(Group("stone\(row)_\(block)", z: 1,
                                             placement: Placement(Double(edges.0), Double(course.0)),
                                             children: [stone.part("surface"), wear.part("wear", z: 1)])))
            }
        }
        var marks = Drawing()
        if v == 1 {
            marks.line(11, 3, 14, 7, "stone_dark"); marks.line(14, 7, 12, 12, "stone_dark"); marks.dot(15, 7, "stone_top")
        } else if v == 2 {
            marks.rect(20, 11, 3, 2, "stone_dark"); marks.line(3, 22, 6, 25, "stone_dark")
        } else if v == 3 {
            for (x, y) in [(3, 9), (5, 10), (7, 10), (26, 21), (28, 20)] { marks.rect(x, y, 2, 1, "grass_tip") }
        }
        children.append(marks.part("marks", z: 2))
        var border = Drawing()
        border.line(2, 0, 29, 0, "stone_dark"); border.line(2, 31, 29, 31, "stone_dark")
        border.line(0, 2, 0, 29, "stone_dark"); border.line(31, 2, 31, 29, "stone_dark")
        for (x, y, dx, dy) in [(0, 0, 1, 1), (31, 0, -1, 1), (0, 31, 1, -1), (31, 31, -1, -1)] {
            // Explicit clear strokes cut through earlier parts; undrawn pixels never erase anything.
            border.dot(x, y, "clear"); border.dot(x + dx, y, "clear"); border.dot(x, y + dy, "clear")
            border.dot(x + dx, y + dy, "stone_dark")
        }
        children.append(border.part("roundedBorder", z: 100))
        return ArtFrame("wall_stone_\(v)", children)
    }
}
