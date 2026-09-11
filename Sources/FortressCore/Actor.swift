import Foundation

enum ActorKind {
    case player, enemyMeleeSword, allySkeletonMelee
    var affiliation: Affiliation {
        switch self {
        case .player, .allySkeletonMelee: return .friendly
        case .enemyMeleeSword: return .hostile
        }
    }

    var tilesPerSecond: Double {
        switch self {
        case .player: return GameBalance.playerTilesPerSecond
        case .enemyMeleeSword: return GameBalance.enemyTilesPerSecond
        case .allySkeletonMelee: return GameBalance.skeletonTilesPerSecond
        }
    }

    var meleeDamage: Int {
        switch self {
        case .player: return 0
        case .enemyMeleeSword: return GameBalance.enemyMeleeDamage
        case .allySkeletonMelee: return GameBalance.skeletonDamage
        }
    }

    var meleeReach: Double {
        self == .player ? GameBalance.meleeEngagementRange : GameBalance.swordReach
    }
}

struct Corpse {
    let position: (x: Double, y: Double)
    var elapsed: Double = 0

    var opacity: Double {
        min(1, max(0, (GameBalance.corpseLifetime - elapsed) / GameBalance.corpseFadeDuration))
    }

    var hasExpired: Bool { elapsed + 0.0000001 >= GameBalance.corpseLifetime }
}

struct Movement {
    let from: Tile
    let to: Tile
    let duration: Double
    var elapsed: Double = 0
    var fraction: Double { min(1, elapsed / duration) }
}

enum AttackTarget: Equatable { case door(Tile), actor(Int) }

enum SkeletonBehavior: Equatable {
    case idling
    case attacking(targetID: Int)
}

struct Attack {
    let target: AttackTarget
    var elapsed: Double = 0
    var delivered = false

    var contactTime: Double {
        switch target {
        case .actor: return GameBalance.meleeAttackWindup
        case .door: return GameBalance.attackWindup
        }
    }

    var hasReachedContact: Bool { elapsed + 0.0000001 >= contactTime }

    var animationFrame: Int {
        // The renderer and damage resolution share the exact same contact boundary.
        if !hasReachedContact { return 0 }
        if elapsed < contactTime + GameBalance.attackContactDuration { return 1 }
        return 2
    }
}

struct Actor {
    let id: Int
    let kind: ActorKind
    var tile: Tile
    var facing: Direction = .south
    var health: Destructible
    var movement: Movement?
    var attack: Attack?
    var corpse: Corpse?
    var route: [Tile] = []
    var destination: Tile?
    var cooldown: Double = 0
    var decisionDelay: Double = 0
    var skeletonBehavior: SkeletonBehavior = .idling
    var idleDecisionDelay: Double = 0
    var affiliation: Affiliation { kind.affiliation }
    var isAlive: Bool { !health.isDestroyed }
    var reservedTiles: Set<Tile> {
        if let movement { return [movement.from, movement.to] }
        return [tile]
    }
    var position: (x: Double, y: Double) {
        if let corpse { return corpse.position }
        guard let movement else { return (Double(tile.x), Double(tile.y)) }
        return (Double(movement.from.x) + Double(movement.to.x - movement.from.x) * movement.fraction,
                Double(movement.from.y) + Double(movement.to.y - movement.from.y) * movement.fraction)
    }

    /// Pure pose selection lets unit tests enforce that dead actors never animate.
    func animation(at time: Double) -> (action: String, frame: Int) {
        guard isAlive else { return ("idle", 0) }
        if let attack { return ("attack", attack.animationFrame) }
        if movement != nil { return ("walk", Int(time / 0.18) % 4) }
        return ("idle", Int((time + Double(id) * 0.2) / 0.7) % 2)
    }
}

enum GameEvent: Equatable {
    case doorDamaged(Tile, Int)
    case doorDestroyed(Tile)
    case playerDamaged(Int)
    case playerDied
    case actorDamaged(Int, Int)
    case actorDied(Int)
    case actorDespawned(Int)
}
