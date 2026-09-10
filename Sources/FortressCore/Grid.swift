import Foundation

struct Tile: Hashable, Codable, Comparable {
    var x: Int
    var y: Int

    static let zero = Tile(x: 0, y: 0)
    static func + (lhs: Tile, rhs: Tile) -> Tile { Tile(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: Tile, rhs: Tile) -> Tile { Tile(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func < (lhs: Tile, rhs: Tile) -> Bool { lhs.y == rhs.y ? lhs.x < rhs.x : lhs.y < rhs.y }
    var neighbors: [Tile] { Direction.allCases.map { self + $0.offset } }
    var isInsideRoom: Bool { abs(x) < 3 && abs(y) < 3 }
    func distance(to other: Tile) -> Int { abs(x - other.x) + abs(y - other.y) }
}

enum Direction: String, CaseIterable, Codable {
    case north, east, south, west

    var offset: Tile {
        switch self {
        case .north: return Tile(x: 0, y: 1)
        case .east: return Tile(x: 1, y: 0)
        case .south: return Tile(x: 0, y: -1)
        case .west: return Tile(x: -1, y: 0)
        }
    }

    static func facing(from start: Tile, to end: Tile) -> Direction {
        let delta = end - start
        if abs(delta.x) > abs(delta.y) { return delta.x > 0 ? .east : .west }
        return delta.y > 0 ? .north : .south
    }
}

/// Seeded generation makes bugs and tests reproducible without affecting new-game randomness.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}
