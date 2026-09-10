import Foundation

enum ActorKind { case necromancer, human }

struct Movement {
    let from: Tile
    let to: Tile
    let duration: Double
    var elapsed: Double = 0
    var fraction: Double { min(1, elapsed / duration) }
}

enum AttackTarget: Equatable { case gate, player }

struct Attack {
    let target: AttackTarget
    var elapsed: Double = 0
    var delivered = false
}

struct Actor {
    let id: Int
    let kind: ActorKind
    var tile: Tile
    var facing: Direction = .south
    var health: Destructible
    var movement: Movement?
    var attack: Attack?
    var route: [Tile] = []
    var destination: Tile?
    var cooldown: Double = 0
    var decisionDelay: Double = 0
    var isAlive: Bool { !health.isDestroyed }
    var reservedTiles: Set<Tile> {
        if let movement { return [movement.from, movement.to] }
        return [tile]
    }
    var position: (x: Double, y: Double) {
        guard let movement else { return (Double(tile.x), Double(tile.y)) }
        return (Double(movement.from.x) + Double(movement.to.x - movement.from.x) * movement.fraction,
                Double(movement.from.y) + Double(movement.to.y - movement.from.y) * movement.fraction)
    }
}

enum GameEvent: Equatable {
    case gateDamaged(Int)
    case gateDestroyed
    case playerDamaged(Int)
    case playerDied
}
