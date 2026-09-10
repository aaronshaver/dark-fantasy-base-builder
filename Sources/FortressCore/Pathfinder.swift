import Foundation

enum Pathfinder {
    /// Uniform-cost, orthogonal grid; breadth-first search returns a shortest path.
    /// The source is omitted and the destination is included.
    static func path(from start: Tile, to goal: Tile, world: World, blocked: Set<Tile> = []) -> [Tile]? {
        guard world.isWalkable(goal), !blocked.contains(goal) else { return nil }
        if start == goal { return [] }
        var queue = [start]
        var head = 0
        var visited: Set<Tile> = [start]
        var predecessor: [Tile: Tile] = [:]
        while head < queue.count {
            let current = queue[head]
            head += 1
            for neighbor in current.neighbors where !visited.contains(neighbor) {
                guard world.isWalkable(neighbor), !blocked.contains(neighbor) else { continue }
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
