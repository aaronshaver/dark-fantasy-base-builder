import Foundation

public struct Point: Codable, Equatable {
    public var x: Double
    public var y: Double
    public init(_ x: Double = 0, _ y: Double = 0) { self.x = x; self.y = y }
}

/// Named anchors reference siblings, independently of declaration order and z-order.
public struct Attachment: Codable, Equatable {
    public var sibling: String
    public var targetAnchor: String
    public var ownAnchor: String
    public init(to sibling: String, anchor: String, own: String = "origin") {
        self.sibling = sibling; targetAnchor = anchor; ownAnchor = own
    }
}

public struct Placement: Codable, Equatable {
    public var position: Point
    public var scale: Point
    public var attachment: Attachment?

    /// Negative scale mirrors around the local origin. Position also serves as attachment offset.
    public init(_ x: Double = 0, _ y: Double = 0, scaleX: Double = 1, scaleY: Double = 1,
                attached: Attachment? = nil) {
        position = Point(x, y); scale = Point(scaleX, scaleY); attachment = attached
    }
}

public enum Primitive: Codable, Equatable {
    case rectangle(x: Int, y: Int, width: Int, height: Int, color: String)
    case line(x0: Int, y0: Int, x1: Int, y1: Int, color: String)
    case dot(x: Int, y: Int, color: String)
}

public struct Part: Codable, Equatable {
    public var id: String
    public var z: Int
    public var placement: Placement
    public var anchors: [String: Point]
    public var drawing: [Primitive]

    public init(_ id: String, z: Int = 0, placement: Placement = Placement(),
                anchors: [String: Point] = [:], drawing: [Primitive]) {
        self.id = id; self.z = z; self.placement = placement; self.anchors = anchors; self.drawing = drawing
    }
}

public struct Group: Codable, Equatable {
    public var id: String
    public var z: Int
    public var placement: Placement
    public var anchors: [String: Point]
    public var children: [ArtNode]

    public init(_ id: String, z: Int = 0, placement: Placement = Placement(),
                anchors: [String: Point] = [:], children: [ArtNode]) {
        self.id = id; self.z = z; self.placement = placement; self.anchors = anchors; self.children = children
    }
}

public indirect enum ArtNode: Codable, Equatable {
    case part(Part)
    case group(Group)

    public var id: String { switch self { case .part(let p): return p.id; case .group(let g): return g.id } }
    public var z: Int { switch self { case .part(let p): return p.z; case .group(let g): return g.z } }
    public var placement: Placement {
        switch self { case .part(let p): return p.placement; case .group(let g): return g.placement }
    }
    public func anchor(_ name: String) throws -> Point {
        if name == "origin" { return Point() }
        let anchors: [String: Point]
        switch self { case .part(let p): anchors = p.anchors; case .group(let g): anchors = g.anchors }
        guard let value = anchors[name] else { throw ArtError.invalid("Missing anchor \(id).\(name)") }
        return value
    }
}

/// Authoring convenience: records primitives into a Part, never draws directly into game textures.
public struct Drawing {
    public var primitives: [Primitive] = []
    public init() {}
    public mutating func dot(_ x: Int, _ y: Int, _ color: String) { primitives.append(.dot(x: x, y: y, color: color)) }
    public mutating func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: String) {
        primitives.append(.rectangle(x: x, y: y, width: w, height: h, color: color))
    }
    public mutating func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ color: String) {
        primitives.append(.line(x0: x0, y0: y0, x1: x1, y1: y1, color: color))
    }
    public func part(_ id: String, z: Int = 0, placement: Placement = Placement(),
                     anchors: [String: Point] = [:]) -> ArtNode {
        .part(Part(id, z: z, placement: placement, anchors: anchors, drawing: primitives))
    }
}
