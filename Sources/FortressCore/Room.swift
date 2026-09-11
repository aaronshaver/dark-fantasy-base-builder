import Foundation

/// Shared access category: allies use the same affiliation as the player.
enum Affiliation: Hashable { case friendly, hostile }

struct Door {
    let tile: Tile
    let outwardDirection: Direction
    let allowedAffiliations: Set<Affiliation>
    var health: Destructible

    func allowsPassage(for affiliation: Affiliation) -> Bool {
        health.isDestroyed || allowedAffiliations.contains(affiliation)
    }

    var exteriorAttackTiles: [Tile] {
        let normal = outwardDirection.offset
        let tangent = Tile(x: -normal.y, y: normal.x)
        let center = tile + normal
        return [center, center + tangent, center - tangent]
    }

    /// Attack from either side; the world filters out walls and occupied positions.
    var attackTiles: [Tile] {
        exteriorAttackTiles + exteriorAttackTiles.map { tile + (tile - $0) }
    }
}

struct Wall {
    let variant: Int
    var health: Destructible
}

/// A reusable room recipe, independent of where an instance is placed in the world.
struct RoomDefinition {
    let id: String
    let interiorWidth: Int
    let interiorHeight: Int
    var displayName: String? = nil
    var floor: Terrain = .wood
    var wallHP: Int = 500
    var doorHP: Int = GameBalance.gateHP
    var doorAccess: Set<Affiliation> = [.friendly]
    var placesChairAwayFromEdge = false
    var spawnsPlayer = false
    var canBeDestroyedByPlayer = true
    var canBeBuiltByPlayer = true

    static let home = RoomDefinition(id: "home", interiorWidth: 4, interiorHeight: 4, displayName: "Home",
                                       placesChairAwayFromEdge: true, spawnsPlayer: true,
                                       canBeDestroyedByPlayer: false, canBeBuiltByPlayer: false)
}

/// One placed room owns its floor, wall, door, furniture, and spawn tiles.
struct Room {
    let definition: RoomDefinition
    let interiorOrigin: Tile
    let interiorTiles: Set<Tile>
    let floorTiles: [Tile: GroundTile]
    var walls: [Tile: Wall]
    var door: Door
    let chairs: [Chair]
    let playerStart: Tile?

    var tiles: Set<Tile> { Set(floorTiles.keys).union(walls.keys) }

    init(definition: RoomDefinition, interiorOrigin: Tile, random: inout SeededRandom) {
        precondition(definition.interiorWidth > 0 && definition.interiorHeight > 0)
        precondition(!definition.placesChairAwayFromEdge || (definition.interiorWidth >= 3 && definition.interiorHeight >= 3))
        self.definition = definition
        self.interiorOrigin = interiorOrigin
        let minX = interiorOrigin.x - 1, minY = interiorOrigin.y - 1
        let maxX = interiorOrigin.x + definition.interiorWidth
        let maxY = interiorOrigin.y + definition.interiorHeight
        var interior: Set<Tile> = [], perimeter: [Tile] = []
        for y in minY...maxY {
            for x in minX...maxX {
                let tile = Tile(x: x, y: y)
                if x == minX || x == maxX || y == minY || y == maxY { perimeter.append(tile) }
                else { interior.insert(tile) }
            }
        }
        interiorTiles = interior
        let doorCandidates = perimeter.filter {
            !(($0.x == minX || $0.x == maxX) && ($0.y == minY || $0.y == maxY))
        }
        let doorTile = doorCandidates.randomElement(using: &random)!
        let direction: Direction = doorTile.y == minY ? .south : doorTile.y == maxY ? .north : doorTile.x == minX ? .west : .east
        door = Door(tile: doorTile, outwardDirection: direction, allowedAffiliations: definition.doorAccess,
                    health: Destructible(maximumHP: definition.doorHP, hp: definition.doorHP))
        floorTiles = Dictionary(uniqueKeysWithValues: interior.union([doorTile]).sorted().map {
            ($0, GroundTile(terrain: definition.floor, variant: Int.random(in: 0..<4, using: &random)))
        })
        walls = Dictionary(uniqueKeysWithValues: perimeter.filter { $0 != doorTile }.map {
            ($0, Wall(variant: Int.random(in: 0..<4, using: &random),
                      health: Destructible(maximumHP: definition.wallHP, hp: definition.wallHP)))
        })
        if definition.placesChairAwayFromEdge {
            let candidates = interior.sorted().filter { $0.neighbors.allSatisfy { interior.contains($0) } }
            chairs = [Chair(tile: candidates.randomElement(using: &random)!, color: Int.random(in: 0..<3, using: &random))]
        } else { chairs = [] }
        let furnitureTiles = Set(chairs.map(\.tile))
        playerStart = definition.spawnsPlayer
            ? interior.subtracting(furnitureTiles).sorted().randomElement(using: &random)! : nil
    }
}
