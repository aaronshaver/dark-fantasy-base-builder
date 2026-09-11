import XCTest
#if SWIFT_PACKAGE
@testable import FortressCore
#endif

final class SkeletonHomeTests: XCTestCase {
    private func actor(_ id: Int, _ kind: ActorKind, at tile: Tile) -> Actor {
        var actor = Actor(id: id, kind: kind, tile: tile, health: Destructible(maximumHP: 1000, hp: 1000))
        // Keep the formation in place long enough to exercise pursuit under sustained congestion.
        actor.cooldown = 60
        actor.decisionDelay = 60
        return actor
    }

    private func scenario(seed: UInt64, surroundedTarget: Bool = false, playerInDoor: Bool = false) -> Simulation {
        let world = World(seed: seed), room = world.rooms[0], door = room.door
        let interiorEntry = door.tile - door.outwardDirection.offset
        let start = room.interiorTiles.sorted().max { $0.distance(to: door.tile) < $1.distance(to: door.tile) }!
        let playerTile = playerInDoor ? door.tile : room.interiorTiles.sorted().first { $0 != start && $0 != interiorEntry }!
        let normal = door.outwardDirection.offset
        let target = door.tile + normal + normal + normal
        var skeleton = actor(10, .allySkeletonMelee, at: start)
        skeleton.decisionDelay = 0
        var actors = [actor(0, .player, at: playerTile), skeleton, actor(20, .enemyMeleeSword, at: target)]
        if surroundedTarget {
            actors += target.neighbors.enumerated().map { actor(30 + $0.offset, .allySkeletonMelee, at: $0.element) }
        }
        return Simulation(world: world, actors: actors)
    }

    private func advance(_ simulation: Simulation, steps: Int) {
        for _ in 0..<steps {
            simulation.advance(by: GameBalance.simulationStep)
            var occupied: Set<Tile> = []
            for actor in simulation.actors where actor.isAlive {
                XCTAssertTrue(occupied.isDisjoint(with: actor.reservedTiles))
                occupied.formUnion(actor.reservedTiles)
                XCTAssertTrue(actor.reservedTiles.allSatisfy { simulation.world.isWalkable($0, for: actor.affiliation) })
            }
        }
    }

    func testSkeletonLeavesHomeThroughEveryDoorPlacement() throws {
        var doors: Set<Tile> = []
        for seed in 0..<200 {
            let simulation = scenario(seed: UInt64(seed)), room = simulation.world.rooms[0]
            guard doors.insert(room.door.tile).inserted else { continue }
            advance(simulation, steps: 240)
            let skeleton = try XCTUnwrap(simulation.actors.first { $0.id == 10 })
            XCTAssertFalse(room.tiles.contains(skeleton.tile), "Failed to leave through door \(room.door.tile)")
            XCTAssertEqual(skeleton.skeletonBehavior, .attacking(targetID: 20))
            XCTAssertEqual(simulation.world.doors[0].health.hp, room.door.health.hp)
        }
        XCTAssertEqual(doors.count, 16)
    }

    func testSurroundedEnemyDoesNotMakeSkeletonWaitInsideHome() throws {
        let simulation = scenario(seed: 14, surroundedTarget: true), room = simulation.world.rooms[0]
        simulation.advance(by: GameBalance.simulationStep)
        let skeleton = try XCTUnwrap(simulation.actors.first { $0.id == 10 })
        XCTAssertEqual(skeleton.skeletonBehavior, .attacking(targetID: 20))
        XCTAssertNotNil(skeleton.movement, "A clear exit should be used even when the final attack positions are occupied")
        advance(simulation, steps: 240)
        let approaching = try XCTUnwrap(simulation.actors.first { $0.id == 10 })
        XCTAssertFalse(room.tiles.contains(approaching.tile))
        XCTAssertLessThanOrEqual(approaching.tile.distance(to: simulation.enemies[0].tile), 2)
        XCTAssertEqual(approaching.skeletonBehavior, .attacking(targetID: 20))
        XCTAssertEqual(simulation.world.doors[0].health.hp, room.door.health.hp)
    }

    func testPlayerBlockingDoorMustMoveBeforeSkeletonCanLeave() throws {
        let simulation = scenario(seed: 14, playerInDoor: true), room = simulation.world.rooms[0]
        advance(simulation, steps: 120)
        let waiting = try XCTUnwrap(simulation.actors.first { $0.id == 10 })
        XCTAssertTrue(room.interiorTiles.contains(waiting.tile))
        XCTAssertEqual(simulation.player.tile, room.door.tile)
        let normal = room.door.outwardDirection.offset, tangent = Tile(x: -normal.y, y: normal.x)
        XCTAssertTrue(simulation.movePlayer(to: room.door.tile + normal + tangent))
        advance(simulation, steps: 240)
        let leaving = try XCTUnwrap(simulation.actors.first { $0.id == 10 })
        XCTAssertFalse(room.tiles.contains(leaving.tile))
        XCTAssertEqual(leaving.skeletonBehavior, .attacking(targetID: 20))
        XCTAssertEqual(simulation.world.doors[0].health.hp, room.door.health.hp)
    }
}
