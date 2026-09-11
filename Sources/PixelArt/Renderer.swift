import Foundation

public struct PixelCanvas: Equatable {
    public let width: Int
    public let height: Int
    public private(set) var pixels: [UInt8]

    public init(width: Int = 32, height: Int = 32) throws {
        guard (1...4096).contains(width), (1...4096).contains(height) else { throw ArtError.invalid("Invalid canvas size") }
        self.width = width; self.height = height; pixels = Array(repeating: 0, count: width * height)
    }
    public subscript(_ x: Int, _ y: Int) -> UInt8 { pixels[y * width + x] }
    mutating func put(_ x: Int, _ y: Int, _ color: UInt8) {
        if x >= 0, y >= 0, x < width, y < height { pixels[y * width + x] = color }
    }
    public func enlarged(by factor: Int) throws -> PixelCanvas {
        guard factor > 0, factor <= 4096 / max(width, height) else { throw ArtError.invalid("Invalid enlargement") }
        var result = try PixelCanvas(width: width * factor, height: height * factor)
        for y in 0..<result.height { for x in 0..<result.width { result.put(x, y, self[x / factor, y / factor]) } }
        return result
    }
}

private struct Transform {
    var x: Double = 0, y: Double = 0, sx: Double = 1, sy: Double = 1
    func apply(_ point: Point) -> Point { Point(x + point.x * sx, y + point.y * sy) }
    func child(_ t: Transform) -> Transform {
        Transform(x: x + t.x * sx, y: y + t.y * sy, sx: sx * t.sx, sy: sy * t.sy)
    }
    func validate() throws {
        guard [x, y, sx, sy].allSatisfy(\.isFinite), abs(x) <= 1_000_000, abs(y) <= 1_000_000,
              (0.001...1024).contains(abs(sx)), (0.001...1024).contains(abs(sy)) else {
            throw ArtError.invalid("Invalid transform")
        }
    }
}

public struct PixelRenderer {
    public let palette: Palette
    public init(palette: Palette) { self.palette = palette }

    public func render(_ group: Group, width: Int = 32, height: Int = 32) throws -> PixelCanvas {
        var canvas = try PixelCanvas(width: width, height: height)
        try renderSiblings([.group(group)], parent: Transform(), canvas: &canvas, depth: 0)
        return canvas
    }

    private func renderSiblings(_ nodes: [ArtNode], parent: Transform, canvas: inout PixelCanvas, depth: Int) throws {
        guard depth < 64, Set(nodes.map(\.id)).count == nodes.count else {
            throw ArtError.invalid("Duplicate sibling IDs or excessive nesting")
        }
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var resolved: [String: Transform] = [:]
        var visiting: Set<String> = []
        func resolve(_ node: ArtNode) throws -> Transform {
            if let transform = resolved[node.id] { return transform }
            guard visiting.insert(node.id).inserted else { throw ArtError.invalid("Attachment cycle at \(node.id)") }
            let placement = node.placement
            var result = Transform(x: placement.position.x, y: placement.position.y,
                                   sx: placement.scale.x, sy: placement.scale.y)
            if let attachment = placement.attachment {
                guard let target = byID[attachment.sibling] else { throw ArtError.invalid("Missing sibling: \(attachment.sibling)") }
                let targetPoint = try resolve(target).apply(target.anchor(attachment.targetAnchor))
                let ownPoint = try node.anchor(attachment.ownAnchor)
                result.x += targetPoint.x - ownPoint.x * result.sx
                result.y += targetPoint.y - ownPoint.y * result.sy
            }
            try result.validate()
            resolved[node.id] = result
            visiting.remove(node.id)
            return result
        }
        // Resolve attachments before sorting: geometry must not depend on paint order.
        for node in nodes { _ = try resolve(node) }
        let ordered = nodes.enumerated().sorted {
            $0.element.z == $1.element.z ? $0.offset < $1.offset : $0.element.z < $1.element.z
        }
        for (_, node) in ordered {
            let transform = try parent.child(resolve(node))
            try transform.validate()
            switch node {
            case .part(let part):
                for primitive in part.drawing { try paint(primitive, transform, canvas: &canvas) }
            case .group(let group):
                // A group's children finish together; their local z never escapes into siblings.
                try renderSiblings(group.children, parent: transform, canvas: &canvas, depth: depth + 1)
            }
        }
    }

    private func paint(_ primitive: Primitive, _ t: Transform, canvas: inout PixelCanvas) throws {
        func pixel(_ x: Int, _ y: Int, _ color: UInt8, _ target: inout PixelCanvas) {
            let a = t.apply(Point(Double(x), Double(y)))
            let b = t.apply(Point(Double(x + 1), Double(y + 1)))
            let x0 = max(0, min(target.width, Int(min(a.x, b.x).rounded())))
            let x1 = max(0, min(target.width, Int(max(a.x, b.x).rounded())))
            let y0 = max(0, min(target.height, Int(min(a.y, b.y).rounded())))
            let y1 = max(0, min(target.height, Int(max(a.y, b.y).rounded())))
            for yy in y0..<y1 { for xx in x0..<x1 { target.put(xx, yy, color) } }
        }
        switch primitive {
        case let .dot(x, y, name):
            guard abs(Double(x)) <= 8192, abs(Double(y)) <= 8192 else { throw ArtError.invalid("Drawing coordinate out of bounds") }
            pixel(x, y, try palette.index(name), &canvas)
        case let .rectangle(x, y, width, height, name):
            guard [x, y, width, height].allSatisfy({ abs(Double($0)) <= 8192 }), width >= 0, height >= 0 else {
                throw ArtError.invalid("Invalid rectangle")
            }
            let color = try palette.index(name)
            for yy in y..<(y + height) { for xx in x..<(x + width) { pixel(xx, yy, color, &canvas) } }
        case let .line(x0, y0, x1, y1, name):
            guard [x0, y0, x1, y1].allSatisfy({ abs(Double($0)) <= 8192 }) else { throw ArtError.invalid("Invalid line") }
            let color = try palette.index(name)
            let steps = max(abs(x1 - x0), abs(y1 - y0), 1)
            for n in 0...steps {
                let fraction = Double(n) / Double(steps)
                pixel(Int((Double(x0) + Double(x1 - x0) * fraction).rounded(.toNearestOrEven)),
                      Int((Double(y0) + Double(y1 - y0) * fraction).rounded(.toNearestOrEven)), color, &canvas)
            }
        }
    }
}
