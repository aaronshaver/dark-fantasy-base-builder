import Foundation

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
    let direction: Direction
    var health = Destructible(maximumHP: 40, hp: 40)
}

struct World {
    static let radius = 12
    let seed: UInt64
    let ground: [Tile: GroundTile]
    var walls: [Tile: Destructible]
    let wallVariants: [Tile: Int]
    let gateTile: Tile
    let gateDirection: Direction
    var gate: Destructible
    var chair: Chair
    let playerStart: Tile
    let enemyStarts: [Tile]

    /// Only the three exterior positions can attack the intact gate, including its diagonals.
    var gateAttackTiles: [Tile] {
        let normal = gateDirection.offset
        let tangent = Tile(x: -normal.y, y: normal.x)
        let center = gateTile + normal
        return [center, center + tangent, center - tangent]
    }

    func isWalkable(_ tile: Tile) -> Bool {
        ground[tile] != nil && walls[tile] == nil && (tile != gateTile || gate.isDestroyed)
    }

    init(seed: UInt64) {
        self.seed = seed
        var random = SeededRandom(seed: seed)
        let direction = Direction.allCases.randomElement(using: &random)!
        gateDirection = direction
        gateTile = Tile(x: direction.offset.x * 3, y: direction.offset.y * 3)
        gate = Destructible(maximumHP: GameBalance.gateHP, hp: GameBalance.gateHP)
        var tiles: [Tile: GroundTile] = [:]
        var stone: [Tile: Destructible] = [:]
        var variants: [Tile: Int] = [:]
        for y in -Self.radius...Self.radius {
            for x in -Self.radius...Self.radius {
                let tile = Tile(x: x, y: y)
                let perimeter = max(abs(x), abs(y)) == 3
                tiles[tile] = GroundTile(terrain: tile.isInsideRoom || tile == gateTile ? .wood : .grass,
                                         variant: Int.random(in: 0..<4, using: &random))
                if perimeter && tile != gateTile {
                    stone[tile] = Destructible(maximumHP: 500, hp: 500)
                    variants[tile] = Int.random(in: 0..<4, using: &random)
                }
            }
        }
        ground = tiles
        walls = stone
        wallVariants = variants
        let chairTile = Tile(x: Int.random(in: -1...1, using: &random), y: Int.random(in: -1...1, using: &random))
        chair = Chair(tile: chairTile, color: Int.random(in: 0..<3, using: &random),
                      direction: Direction.allCases.randomElement(using: &random)!)
        let indoor = tiles.keys.filter { $0.isInsideRoom && $0 != chairTile }.sorted()
        playerStart = indoor.randomElement(using: &random)!
        let outside = tiles.keys.filter { (4...6).contains(max(abs($0.x), abs($0.y))) }.sorted()
        enemyStarts = Array(outside.shuffled(using: &random).prefix(GameBalance.enemyCount))
    }
}

enum GameBalance {
    static let enemyCount = 3
    static let playerHP = 30
    static let gateHP = 90
    static let playerTilesPerSecond = 2.0
    static let enemyTilesPerSecond = playerTilesPerSecond * 1.05
    static let attackInterval = 1.0
    static let attackWindup = 1.0 / 3.0
    static let gateDamage = 3  // Three attackers × 3 damage × 10 volleys = 90 HP.
    static let playerDamage = 4
    static let simulationStep = 1.0 / 60.0
}
