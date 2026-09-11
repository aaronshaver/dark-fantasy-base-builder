import PixelArt

/// Appearance is resolved once for the complete set of directions and animation frames.
/// Pose-specific z and offsets live in the recipe, never in the generic renderer.
enum CharacterRecipes {
    static func frames(kind: String, parameters p: ParameterValues) throws -> [ArtFrame] {
        let swordEnemy = kind == "enemy_melee_sword"
        let headWidth = try p.integer("headWidth"), bodyWidth = try p.integer("bodyWidth")
        let eyeColor = swordEnemy ? "teal_light" : try p.choice("eyeColor")
        var frames: [ArtFrame] = []
        for direction in ["north", "east", "south", "west"] {
            for (action, count) in [("idle", 2), ("walk", 4)] + (swordEnemy ? [("attack", 3)] : []) {
                for phase in 0..<count {
                    frames.append(frame(kind, direction, action, phase, headWidth, bodyWidth, eyeColor))
                }
            }
        }
        return frames
    }

    private static func frame(_ kind: String, _ direction: String, _ action: String, _ phase: Int,
                              _ headWidth: Int, _ bodyWidth: Int, _ eyeColor: String) -> ArtFrame {
        let swordEnemy = kind == "enemy_melee_sword", walking = action == "walk", attack = action == "attack"
        let bob = (walking && phase % 2 == 1) || (action == "idle" && phase == 1) ? -1 : 0
        let stride = walking ? [-1, 0, 1, 0][phase % 4] : 0
        var shadow = Drawing(), boots = Drawing(), torso = Drawing()
        shadow.rect(9, 27, 15, 2, "grass_dark"); shadow.rect(7, 26, 19, 1, "grass_dark")
        boots.rect(10 - stride, 25, 5, 3, "ink"); boots.rect(18 + stride, 25, 5, 3, "ink")
        // Torso coordinates are local, with shared attachment anchors for the head and arms.
        if swordEnemy {
            torso.rect(0, 0, 15, 13, "ink"); torso.rect(1, 1, 13, 11, "red_dark")
            torso.rect(2, 1, 11, 7, "steel"); torso.rect(2, 1, 11, 2, "steel_light")
            torso.rect(4, 4, 7, 4, "steel_dark"); torso.rect(6, 9, 3, 5, "red")
            torso.rect(1, 9, 13, 2, "wood_dark"); torso.rect(7, 9, 2, 2, "gold")
        } else {
            torso.rect(1, 0, 13, 5, "ink"); torso.rect(0, 4, 15, 7, "ink"); torso.rect(-2, 11, 19, 4, "ink")
            torso.rect(2, 0, 11, 5, "purple"); torso.rect(1, 5, 13, 6, "purple_deep")
            torso.rect(0, 10, 15, 4, "purple_deep"); torso.line(3, 4, 1, 13, "purple")
            torso.line(11, 4, 14, 13, "purple_dark"); torso.line(7, 4, 7, 12, "lilac")
            torso.rect(2, 13, 12, 1, "purple"); torso.dot(7, 6, "gold_light")
        }
        let bodyScale = Double(15 + bodyWidth * 2) / 15
        var bodyChildren = [torso.part("clothing")]
        if direction == "north" {
            var back = Drawing()
            back.rect(2, 1, 11, 11, swordEnemy ? "red_dark" : "purple_deep")
            back.line(3, 2, 3, 11, swordEnemy ? "red" : "purple")
            bodyChildren.append(back.part("back", z: 1))
        }
        let body = Group("body", z: 2, placement: Placement(Double(9 - bodyWidth), Double(12 + bob), scaleX: bodyScale),
                         anchors: ["neck": Point(7.5, 2), "leftShoulder": Point(-2, 3), "rightShoulder": Point(13, 3)],
                         children: bodyChildren)

        // All head details transform together; eyes retain their local order above the face.
        var outline = Drawing(), covering = Drawing(), face = Drawing(), eyes = Drawing()
        outline.rect(0, 1, 11, 10, "ink"); outline.rect(2, 0, 7, 12, "ink")
        if swordEnemy {
            covering.rect(1, 2, 9, 8, "steel"); covering.rect(2, 1, 7, 3, "steel_light")
            covering.rect(4, 1, 2, 5, "steel_glint")
            if direction != "north" {
                face.rect(1, 7, 9, 2, "ink"); face.rect(4, 7, 2, 4, "steel_light")
            }
            covering.rect(2, -2, 6, 3, "red_dark"); covering.rect(4, -2, 4, 1, "red")
        } else {
            covering.rect(1, 2, 9, 9, "purple_deep"); covering.rect(2, 1, 7, 3, "purple")
            covering.rect(3, 1, 4, 1, "lilac")
            if direction != "north" {
                let x = direction == "east" ? 3 : direction == "west" ? 1 : 2
                face.rect(x, 5, 7, 5, "skin"); face.rect(x + 1, 5, 5, 2, "skin_light")
                face.rect(x + 2, 10, 3, 2, "skin_dark")
                eyes.dot(x + 1, 7, "ink"); eyes.dot(x + 5, 7, "ink")
                eyes.dot(x + 1, 8, eyeColor)
            }
        }
        let head = Group("head", z: 3,
                         placement: Placement(scaleX: Double(headWidth) / 11,
                                              attached: Attachment(to: "body", anchor: "neck", own: "neck")),
                         anchors: ["neck": Point(5.5, 11)],
                         children: [outline.part("outline"), covering.part("covering", z: 1),
                                    face.part("face", z: 2), eyes.part("eyes", z: 3)])
        var leftArm = Drawing(), rightArm = Drawing()
        for isLeft in [true, false] {
            var arm = Drawing()
            arm.rect(0, 0, 4, 6, swordEnemy ? "steel_dark" : "purple")
            arm.rect(1, 5, 3, 3, isLeft ? "skin_dark" : "skin")
            if isLeft { leftArm = arm } else { rightArm = arm }
        }
        var children: [ArtNode] = [shadow.part("shadow"), boots.part("boots", z: 1), .group(body), .group(head),
            leftArm.part("leftArm", z: 4, placement: Placement(attached: Attachment(to: "body", anchor: "leftShoulder")),
                         anchors: ["grip": Point(2, 7)]),
            rightArm.part("rightArm", z: 4, placement: Placement(attached: Attachment(to: "body", anchor: "rightShoulder")),
                          anchors: ["grip": Point(2, 7)])]
        if swordEnemy {
            var weapon = Drawing()
            if attack && (phase == 1 || phase == 2) {
                if direction == "north" {
                    weapon.line(24, 17, 24, 1, "steel_light"); weapon.line(25, 17, 25, 2, "steel_glint")
                    weapon.rect(21, 15, 7, 2, "gold")
                } else if direction == "south" {
                    weapon.line(23, 18, 13, 30, "steel_light"); weapon.line(24, 18, 14, 30, "steel_glint")
                    weapon.line(19, 18, 25, 23, "gold")
                } else {
                    let end = direction == "east" ? 31 : 0, start = direction == "east" ? 23 : 8
                    weapon.line(start, 18, end, 16, "steel_glint"); weapon.line(start, 19, end, 17, "steel")
                }
                if phase == 2 {
                    weapon.line(25, 3, 29, 7, "dust"); weapon.line(29, 7, 30, 12, "dust")
                }
                let west = direction == "west"
                children.append(weapon.part("weapon", z: 5,
                                            placement: Placement(attached: Attachment(to: west ? "leftArm" : "rightArm", anchor: "grip", own: "grip")),
                                            anchors: ["grip": Point(west ? 9 : 24, 22)]))
            } else {
                weapon.rect(2, -10, 2, 11, "ink"); weapon.rect(2, -10, 1, 9, "steel_glint")
                weapon.rect(0, -2, 6, 2, "gold"); weapon.rect(2, 0, 2, 3, "wood_light")
                children.append(weapon.part("weapon", z: 5,
                                            placement: Placement(attached: Attachment(to: "rightArm", anchor: "grip"))))
            }
        }
        return ArtFrame("\(kind)_\(direction)_\(action)_\(phase)", children)
    }
}
