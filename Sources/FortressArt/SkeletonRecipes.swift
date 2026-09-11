import PixelArt

/// Bare bone parts share anchors and proportions across every pose. Hands are the attack.
enum SkeletonRecipes {
    static func frames(parameters p: ParameterValues) throws -> [ArtFrame] {
        let headWidth = try p.integer("headWidth"), bodyWidth = try p.integer("bodyWidth")
        let eyeColor = try p.choice("eyeColor")
        var frames: [ArtFrame] = []
        for direction in ["north", "east", "south", "west"] {
            for (action, count) in [("idle", 2), ("walk", 4), ("attack", 3)] {
                for phase in 0..<count {
                    frames.append(frame(direction, action, phase, headWidth, bodyWidth, eyeColor))
                }
            }
        }
        return frames
    }

    private static func frame(_ direction: String, _ action: String, _ phase: Int,
                              _ headWidth: Int, _ bodyWidth: Int, _ eyeColor: String) -> ArtFrame {
        let walking = action == "walk", attacking = action == "attack"
        let bob = (walking && phase.isMultiple(of: 2) == false) || (action == "idle" && phase == 1) ? -1 : 0
        let stride = walking ? [-1, 0, 1, 0][phase] : 0
        let lift = walking ? [0, -1, 0, 1][phase] : 0
        var shadow = Drawing(), ribs = Drawing(), pelvis = Drawing()
        shadow.rect(9, 28, 15, 1, "grass_dark"); shadow.rect(7, 27, 19, 1, "grass_dark")
        ribs.rect(3, 0, 3, 10, "ink"); ribs.rect(4, 0, 1, 9, "skin")
        ribs.line(0, 1, 8, 1, "skin_dark"); ribs.line(1, 0, 7, 0, "skin_light")
        for y in [2, 5] {
            ribs.rect(0, y, 9, 2, "ink")
            ribs.line(1, y, 7, y, "skin_light")
            ribs.dot(0, y + 1, "skin"); ribs.dot(8, y + 1, "skin_dark")
        }
        if direction == "north" {
            ribs.rect(3, 0, 3, 9, "skin_dark")
            for y in Swift.stride(from: 0, to: 9, by: 2) { ribs.dot(4, y, "skin_light") }
        }
        pelvis.rect(0, 8, 9, 3, "ink"); pelvis.rect(1, 8, 7, 2, "skin")
        pelvis.dot(1, 8, "skin_light"); pelvis.dot(7, 8, "skin_light")
        pelvis.rect(3, 9, 3, 2, "ink"); pelvis.dot(4, 10, "skin_dark")
        let body = Group("body", z: 2,
                         placement: Placement(Double(12 - bodyWidth), Double(13 + bob),
                                              scaleX: Double(9 + bodyWidth * 2) / 9),
                         anchors: ["neck": Point(4.5, 0), "leftShoulder": Point(-2, 1),
                                   "rightShoulder": Point(9, 1), "leftHip": Point(1, 10), "rightHip": Point(6, 10)],
                         children: [ribs.part("ribcage"), pelvis.part("pelvis", z: 1)])

        var outline = Drawing(), skull = Drawing(), face = Drawing(), eyes = Drawing()
        outline.rect(1, 0, 9, 9, "ink"); outline.rect(0, 2, 11, 5, "ink")
        outline.rect(2, 7, 7, 4, "ink")
        skull.rect(2, 1, 7, 7, "skin"); skull.rect(1, 2, 9, 4, "skin_light")
        skull.rect(3, 1, 5, 2, "skin_light"); skull.rect(3, 8, 5, 2, "skin")
        skull.line(2, 2, 6, 2, "white")
        if direction == "north" {
            face.line(6, 2, 5, 4, "skin_dark"); face.line(5, 4, 6, 5, "skin_dark")
            face.rect(3, 8, 5, 1, "skin_dark")
        } else {
            let sockets = direction == "east" ? [6] : direction == "west" ? [2] : [2, 6]
            for x in sockets {
                face.rect(x, 4, 3, 3, "ink")
                eyes.dot(x + 1, 5, eyeColor)
            }
            let nose = direction == "east" ? 9 : direction == "west" ? 1 : 5
            face.dot(nose, 7, "ink")
            face.line(3, 8, 7, 8, "ink")
            for x in [3, 5, 7] { face.dot(x, 9, "skin_light") }
        }
        let head = Group("head", z: 5,
                         placement: Placement(scaleX: Double(headWidth) / 11,
                                              attached: Attachment(to: "body", anchor: "neck", own: "neck")),
                         anchors: ["neck": Point(5.5, 10)],
                         children: [outline.part("outline"), skull.part("skull", z: 1),
                                    face.part("face", z: 2), eyes.part("eyes", z: 3)])
        var children: [ArtNode] = [shadow.part("shadow"), .group(body), .group(head)]
        for left in [true, false] {
            let side = left ? "left" : "right"
            var leg = Drawing()
            leg.rect(0, 0, 3, 6, "ink"); leg.line(1, 0, 1, 5, "skin_light")
            leg.dot(1, 3, "skin_dark"); leg.rect(left ? -1 : 0, 6, 4, 2, "ink")
            leg.line(left ? -1 : 1, 6, left ? 1 : 3, 6, "skin")
            children.append(leg.part(side + "Leg", z: 1,
                placement: Placement(Double(left ? -stride : stride), Double(left ? lift : -lift),
                                     attached: Attachment(to: "body", anchor: side + "Hip"))))

            let contact = attacking && phase == 1
            let recovery = attacking && phase == 2
            let sideways = direction == "east" || direction == "west"
            let extensionLength = contact ? (sideways ? 6 : 9) : recovery ? 4 : 0
            let dx = direction == "east" ? extensionLength : direction == "west" ? -extensionLength : 0
            let dy = direction == "north" ? -extensionLength : direction == "south" ? extensionLength : 0
            let handX = 1 + dx
            let handY = attacking ? (contact || recovery ? 3 + dy : 1) : 7 + (left ? stride : -stride)
            var arm = Drawing(), hand = Drawing()
            arm.line(1, 0, handX, handY, "ink"); arm.line(0, 0, handX - 1, handY, "ink")
            arm.line(1, 1, handX, handY - 1, "skin_light")
            arm.dot(handX / 2, handY / 2, "skin_dark")
            hand.rect(-1, -1, 4, 3, "ink"); hand.rect(0, -1, 2, 2, "skin_light")
            hand.dot(-1, 1, "skin"); hand.dot(1, 1, "skin")
            let limb = Group(side + "Arm", z: direction == "north" && attacking ? 1 : 6,
                placement: Placement(attached: Attachment(to: "body", anchor: side + "Shoulder")),
                children: [arm.part("bones"), hand.part("hand", z: 1, placement: Placement(Double(handX), Double(handY)))])
            children.append(.group(limb))
        }
        return ArtFrame("ally_skeleton_melee_\(direction)_\(action)_\(phase)", children)
    }
}
