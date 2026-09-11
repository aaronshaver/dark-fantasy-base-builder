import Foundation

enum Pathfinder {
    /// Uniform-cost, orthogonal grid; breadth-first search returns a shortest path.
    /// The source is omitted and the destination is included.
    static func path(from start: Tile, to goal: Tile, world: World, for affiliation: Affiliation,
                     blocked: Set<Tile> = [], preferStaircase: Bool = false) -> [Tile]? {
        path(from: start, to: goal, blocked: blocked, preferStaircase: preferStaircase) { world.isWalkable($0, for: affiliation) }
    }

    static func path(from start: Tile, to goal: Tile, blocked: Set<Tile> = [],
                     preferStaircase: Bool = false,
                     isWalkable: (Tile) -> Bool) -> [Tile]? {
        guard isWalkable(goal), !blocked.contains(goal) else { return nil }
        if start == goal { return [] }
        var queue = [start]
        var head = 0
        var visited: Set<Tile> = [start]
        var predecessor: [Tile: Tile] = [:]
        let direction = goal - start
        func lineDeviation(_ tile: Tile) -> Int {
            let offset = tile - start
            return abs(offset.x * direction.y - offset.y * direction.x)
        }
        while head < queue.count {
            let current = queue[head]
            head += 1
            var neighbors = current.neighbors
            if preferStaircase {
                // Break equal-length route ties toward the straight line between the endpoints.
                // Alternating axes forms a staircase; breadth-first search still guarantees shortest paths.
                neighbors.sort {
                    let lhs = lineDeviation($0), rhs = lineDeviation($1)
                    if lhs != rhs { return lhs < rhs }
                    let lhsDistance = $0.distance(to: goal), rhsDistance = $1.distance(to: goal)
                    if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                    return $0 < $1
                }
            }
            for neighbor in neighbors where !visited.contains(neighbor) {
                guard isWalkable(neighbor), !blocked.contains(neighbor) else { continue }
                visited.insert(neighbor)
                predecessor[neighbor] = current
                if neighbor == goal {
                    var result = [goal]
                    var cursor = goal
                    while let parent = predecessor[cursor], parent != start {
                        result.append(parent)
                        cursor = parent
                    }
                    return result.reversed()
                }
                queue.append(neighbor)
            }
        }
        return nil
    }
}
