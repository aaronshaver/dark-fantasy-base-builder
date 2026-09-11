import Foundation

enum NewGameScenario: Int, CaseIterable {
    case standard, manyAllies, manyEnemies, fiftyEach, hundredEach
    var counts: (allies: Int, enemies: Int) {
        switch self {
        case .standard: return (5, 3)
        case .manyAllies: return (20, 3)
        case .manyEnemies: return (3, 20)
        case .fiftyEach: return (50, 50)
        case .hundredEach: return (100, 100)
        }
    }
    var title: String { "\(counts.allies) skellies, \(counts.enemies) enemies" }
}

enum Terrain { case wood, grass }

struct GroundTile {
    let terrain: Terrain
    let variant: Int
}

struct Destructible {
    let maximumHP: Int
    var hp: Int
    var isDestroyed: Bool { hp <= 0 }
    var damageStage: Int {
        if hp * 3 <= maximumHP { return 2 }
        if hp * 3 <= maximumHP * 2 { return 1 }
        return 0
    }
    mutating func damage(_ amount: Int) { hp = max(0, hp - max(0, amount)) }
}

struct Chair {
    let tile: Tile
    let color: Int
    var health = Destructible(maximumHP: 40, hp: 40)
}

struct World {
    static let radius = 12
    let seed: UInt64
    let ground: [Tile: GroundTile]
    private(set) var rooms: [Room]
    private let roomIndices: [Tile: Int]
    let playerStart: Tile
    let enemyStarts: [Tile]
    let allyStarts: [Tile]

    var doors: [Door] { rooms.map(\.door) }
    var walls: [Tile: Wall] { rooms.reduce(into: [:]) { $0.merge($1.walls) { current, _ in current } } }
    var chairs: [Chair] { rooms.flatMap(\.chairs) }

    func door(at tile: Tile) -> Door? {
        guard let index = roomIndices[tile], rooms[index].door.tile == tile else { return nil }
        return rooms[index].door
    }

    func isWalkable(_ tile: Tile, for affiliation: Affiliation) -> Bool {
        guard ground[tile] != nil else { return false }
        guard let index = roomIndices[tile] else { return true }
        let room = rooms[index]
        if let wall = room.walls[tile], !wall.health.isDestroyed { return false }
        return room.door.tile != tile || room.door.allowsPassage(for: affiliation)
    }

    @discardableResult
    mutating func damageDoor(at tile: Tile, amount: Int, by affiliation: Affiliation) -> Door? {
        guard let index = roomIndices[tile], rooms[index].door.tile == tile else { return nil }
        guard affiliation != rooms[index].door.affiliation || rooms[index].definition.canBeDestroyedByPlayer else { return nil }
        rooms[index].door.health.damage(amount)
        return rooms[index].door
    }

    init(seed: UInt64, rooms suppliedRooms: [Room]? = nil, scenario: NewGameScenario = .standard) {
        self.seed = seed
        var random = SeededRandom(seed: seed)
        rooms = suppliedRooms ?? [Room(definition: .home, interiorOrigin: Tile(x: -2, y: -2), random: &random)]
        let playerStarts = rooms.compactMap(\.playerStart)
        precondition(playerStarts.count == 1, "The world must contain exactly one player spawn")
        playerStart = playerStarts[0]
        var tiles: [Tile: GroundTile] = [:]
        for y in -Self.radius...Self.radius {
            for x in -Self.radius...Self.radius {
                tiles[Tile(x: x, y: y)] = GroundTile(terrain: .grass, variant: Int.random(in: 0..<4, using: &random))
            }
        }
        var indices: [Tile: Int] = [:]
        for (index, room) in rooms.enumerated() {
            for tile in room.tiles {
                precondition(tiles[tile] != nil && indices[tile] == nil, "Rooms must fit the map without overlapping")
                indices[tile] = index
            }
            tiles.merge(room.floorTiles) { _, floor in floor }
        }
        roomIndices = indices
        ground = tiles
        // Fill outer rings first; shuffling before the stable distance tie-break randomizes each ring.
        let exteriorTiles = tiles.keys.filter { indices[$0] == nil }.sorted().shuffled(using: &random)
        let enemyCandidates = exteriorTiles.enumerated().sorted {
            let a = max(abs($0.element.x), abs($0.element.y))
            let b = max(abs($1.element.x), abs($1.element.y))
            return a == b ? $0.offset < $1.offset : a > b
        }.map(\.element)
        enemyStarts = Array(enemyCandidates.prefix(scenario.counts.enemies))
        let home = rooms.first { $0.playerStart != nil }!
        let occupied = Set([playerStart] + home.chairs.map(\.tile) + enemyStarts)
        let interior = home.interiorTiles.subtracting(occupied).sorted()
        var rankedExterior: [(order: Int, tile: Tile, distance: Int)] = []
        for (order, tile) in exteriorTiles.enumerated() where !occupied.contains(tile) {
            let distance = home.walls.keys.map { $0.distance(to: tile) }.min()!
            rankedExterior.append((order, tile, distance))
        }
        rankedExterior.sort { lhs, rhs in
            if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
            return lhs.order < rhs.order
        }
        let exterior = rankedExterior.map(\.tile)
        allyStarts = Array(interior.shuffled(using: &random).prefix(1))
            + Array(exterior.prefix(scenario.counts.allies - 1))

    }
}

enum GameBalance {
    static let enemyCount = 3
    static let playerHP = 30
    static let enemyHP = 20
    static let skeletonHP = enemyHP
    static let exteriorSkeletonCount = 4
    static let gateHP = 45
    static let playerTilesPerSecond = 2.0
    static let enemyTilesPerSecond = playerTilesPerSecond * 1.5
    static let skeletonTilesPerSecond = enemyTilesPerSecond
    static let skeletonSenseRadius = 20
    static let skeletonWanderRadius = 2
    static let skeletonIdleInterval = 1...5
    static let attackInterval = 1.0
    static let attackWindup = 1.0 / 3.0
    static let meleeAttackWindup = 0.20
    static let meleeEngagementRange = 1.15
    static let swordReach = 1.5
    static let attackContactDuration = 0.15
    static let gateDamage = 3  // Three attackers × 3 damage × 5 volleys = 45 HP.
    static let enemyMeleeDamage = 4
    static let skeletonDamage = enemyMeleeDamage
    static let corpseLifetime = 5.0
    static let corpseFadeDuration = 0.5
    static let simulationStep = 1.0 / 60.0
}
