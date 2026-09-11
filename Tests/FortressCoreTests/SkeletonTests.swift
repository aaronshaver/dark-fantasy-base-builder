import XCTest
#if SWIFT_PACKAGE
@testable import FortressCore
#endif

final class SkeletonTests: XCTestCase {
    private func actor(_ id: Int, _ kind: ActorKind, _ tile: Tile, hp: Int? = nil) -> Actor {
        let health = hp ?? (kind == .allySkeletonMelee ? GameBalance.skeletonHP : GameBalance.enemyHP)
        return Actor(id: id, kind: kind, tile: tile, health: Destructible(maximumHP: health, hp: health))
    }

    private func advance(_ simulation: Simulation, steps: Int) {
        for _ in 0..<steps { simulation.advance(by: GameBalance.simulationStep) }
    }

    func testFiveAlliesSpawnInDistinctRandomSpotsInsideAndBesideHome() {
        var interiorSpawns: Set<Tile> = [], exteriorSpawns: Set<Tile> = []
        for seed in 0..<200 {
            let simulation = Simulation(seed: UInt64(seed)), home = simulation.world.rooms[0]
            XCTAssertEqual(home.definition.id, "home")
            XCTAssertEqual(home.definition.displayName, "Home")
            XCTAssertEqual(simulation.allies.count, 5)
            XCTAssertEqual(simulation.allies.filter { home.interiorTiles.contains($0.tile) }.count, 1)
            XCTAssertEqual(Set(simulation.actors.map(\.tile)).count, simulation.actors.count)
            for skeleton in simulation.allies {
                XCTAssertEqual(skeleton.affiliation, .friendly)
                XCTAssertEqual(skeleton.health.hp, 20)
                XCTAssertEqual(skeleton.kind.tilesPerSecond, 3)
                XCTAssertEqual(skeleton.kind.meleeDamage, 4)
                XCTAssertEqual(skeleton.kind.meleeReach, ActorKind.enemyMeleeSword.meleeReach)
                XCTAssertTrue(simulation.world.isWalkable(skeleton.tile, for: .friendly))
                XCTAssertFalse(home.chairs.contains { $0.tile == skeleton.tile })
                if home.interiorTiles.contains(skeleton.tile) { interiorSpawns.insert(skeleton.tile) }
                else {
                    exteriorSpawns.insert(skeleton.tile)
                    XCTAssertFalse(home.tiles.contains(skeleton.tile))
                    XCTAssertTrue(skeleton.tile.neighbors.contains { home.walls[$0] != nil })
                }
            }
            XCTAssertEqual(simulation.world.allyStarts, Simulation(seed: UInt64(seed)).world.allyStarts)
        }
        XCTAssertGreaterThan(interiorSpawns.count, 8)
        XCTAssertGreaterThan(exteriorSpawns.count, 12)
    }

    func testThirteenTileSensingInterruptsIdlingAndMovementMatchesEnemySpeed() throws {
        for distance in [13, 14] {
            let player = actor(0, .player, Tile(x: -2, y: -2))
            let skeleton = actor(1, .allySkeletonMelee, Tile(x: -2, y: 6))
            var enemy = actor(2, .enemyMeleeSword, Tile(x: distance - 2, y: 6))
            enemy.decisionDelay = 100
            let simulation = Simulation(world: World(seed: 14), actors: [player, skeleton, enemy])
            simulation.advance(by: GameBalance.simulationStep)
            if distance == 13 {
                XCTAssertEqual(simulation.allies[0].skeletonBehavior, .attacking(targetID: 2))
                let movement = try XCTUnwrap(simulation.allies[0].movement)
                XCTAssertEqual(movement.duration, 1.0 / 3, accuracy: 0.000001)
                XCTAssertEqual(movement.to, Tile(x: -1, y: 6))
                advance(simulation, steps: 20)
                XCTAssertEqual(simulation.allies[0].tile, Tile(x: -1, y: 6))
            } else {
                XCTAssertEqual(simulation.allies[0].skeletonBehavior, .idling)
                XCTAssertNil(simulation.allies[0].movement)
            }
        }
    }

    func testChosenTargetPersistsBeyondSensingRadiusAndPastCloserEnemies() {
        let player = actor(0, .player, Tile(x: -2, y: -2))
        var skeleton = actor(1, .allySkeletonMelee, Tile(x: -2, y: 6))
        skeleton.skeletonBehavior = .attacking(targetID: 2)
        var target = actor(2, .enemyMeleeSword, Tile(x: 12, y: 6))
        var closer = actor(3, .enemyMeleeSword, Tile(x: 0, y: 9))
        target.decisionDelay = 100; closer.decisionDelay = 100
        let simulation = Simulation(world: World(seed: 14), actors: [player, skeleton, target, closer])
        advance(simulation, steps: 30)
        XCTAssertEqual(simulation.allies[0].skeletonBehavior, .attacking(targetID: 2))
        XCTAssertGreaterThan(simulation.allies[0].tile.x, -2)
        XCTAssertEqual(simulation.allies[0].tile.y, 6)
    }

    func testSkeletonCrossesFriendlyGateWithoutDamagingIt() {
        let world = World(seed: 14), door = world.rooms[0].door
        let skeleton = actor(1, .allySkeletonMelee, door.tile - door.outwardDirection.offset)
        var enemy = actor(2, .enemyMeleeSword, door.tile + door.outwardDirection.offset)
        enemy.decisionDelay = 100
        let playerTile = world.rooms[0].interiorTiles.sorted().first { $0 != skeleton.tile }!
        let simulation = Simulation(world: world, actors: [actor(0, .player, playerTile), skeleton, enemy])
        var crossedGate = false
        for _ in 0..<50 {
            simulation.advance(by: GameBalance.simulationStep)
            crossedGate = crossedGate || simulation.allies[0].movement?.to == door.tile
            XCTAssertEqual(simulation.world.door(at: door.tile)?.health.hp, door.health.hp)
            if let attack = simulation.allies[0].attack { XCTAssertEqual(attack.target, .actor(2)) }
        }
        XCTAssertTrue(crossedGate)
        XCTAssertLessThan(simulation.enemies[0].health.hp, 20)
    }

    func testSkeletonHandsDamageEnemyAndEnemyCanKillSkeletonWithoutPosthumousHit() {
        let player = actor(0, .player, Tile(x: -2, y: -2))
        let enemy = actor(2, .enemyMeleeSword, Tile(x: 1, y: 6))
        let skeleton = actor(7, .allySkeletonMelee, Tile(x: 0, y: 6))
        let simulation = Simulation(world: World(seed: 14), actors: [player, enemy, skeleton])
        simulation.advance(by: GameBalance.simulationStep)
        XCTAssertEqual(simulation.allies[0].attack?.animationFrame, 0)
        advance(simulation, steps: 11)
        XCTAssertEqual(simulation.allies[0].health.hp, 20)
        XCTAssertEqual(simulation.enemies[0].health.hp, 20)
        simulation.advance(by: GameBalance.simulationStep)
        XCTAssertEqual(simulation.allies[0].health.hp, 16)
        XCTAssertEqual(simulation.enemies[0].health.hp, 16)
        XCTAssertEqual(simulation.events, [.actorDamaged(7, 16), .actorDamaged(2, 16)])
        var deaths = 0
        for _ in 0..<300 {
            simulation.advance(by: GameBalance.simulationStep)
            deaths += simulation.events.filter { $0 == .actorDied(7) }.count
        }
        XCTAssertEqual(deaths, 1)
        XCTAssertFalse(simulation.allies[0].isAlive)
        XCTAssertNil(simulation.allies[0].attack)
        XCTAssertNil(simulation.allies[0].movement)
        XCTAssertEqual(simulation.enemies[0].health.hp, 4, "A killed skeleton must not finish its pending swing")
        XCTAssertFalse(simulation.occupiedTiles(excluding: 2).contains(skeleton.tile))
        XCTAssertFalse(simulation.isGameOver)
    }

    func testKillingTargetReturnsToIdlingAndDeadEnemiesNeverAttackAgain() {
        let player = actor(0, .player, Tile(x: -2, y: -2))
        let skeleton = actor(1, .allySkeletonMelee, Tile(x: 0, y: 6))
        let enemy = actor(2, .enemyMeleeSword, Tile(x: 1, y: 6), hp: 4)
        let simulation = Simulation(world: World(seed: 14), actors: [player, skeleton, enemy])
        advance(simulation, steps: 13)
        XCTAssertFalse(simulation.enemies[0].isAlive)
        XCTAssertEqual(simulation.allies[0].skeletonBehavior, .idling)
        XCTAssertTrue(simulation.events.contains(.actorDied(2)))
        XCTAssertEqual(simulation.allies[0].health.hp, 20)
        advance(simulation, steps: 360)
        XCTAssertEqual(simulation.allies[0].health.hp, 20)
        XCTAssertTrue(simulation.enemies.isEmpty)
        XCTAssertEqual(simulation.player.health.hp, player.health.hp)
    }

    func testIdleChoicesStayWithinTwoTilesAndUseIntegerOneToFiveSecondIntervals() throws {
        var intervals: Set<Int> = [], destinations: Set<Tile> = []
        for seed in 0..<20 {
            let simulation = Simulation(world: World(seed: UInt64(seed)), actors: [
                actor(0, .player, Tile(x: -2, y: -2)), actor(1, .allySkeletonMelee, Tile(x: 7, y: 7))
            ])
            let initial = simulation.allies[0].idleDecisionDelay
            XCTAssertTrue((1...5).contains(Int(initial)))
            XCTAssertEqual(initial.rounded(), initial)
            intervals.insert(Int(initial))
            for _ in 0..<900 {
                let before = simulation.allies[0]
                simulation.advance(by: GameBalance.simulationStep)
                let after = simulation.allies[0]
                if after.idleDecisionDelay > before.idleDecisionDelay {
                    XCTAssertEqual(after.idleDecisionDelay.rounded(), after.idleDecisionDelay)
                    XCTAssertTrue((1...5).contains(Int(after.idleDecisionDelay)))
                    intervals.insert(Int(after.idleDecisionDelay))
                    if let destination = after.destination {
                        XCTAssertTrue((1...2).contains(before.tile.distance(to: destination)))
                        destinations.insert(destination)
                    }
                }
                XCTAssertEqual(after.skeletonBehavior, .idling)
                XCTAssertNil(after.attack)
            }
        }
        XCTAssertEqual(intervals, Set(1...5))
        XCTAssertGreaterThan(destinations.count, 10)
    }

    func testInaccessibleWanderChoiceConsumesTurnAndNeverOverlapsPlayerOrWalls() {
        var random = SeededRandom(seed: 14)
        let room = Room(definition: RoomDefinition(id: "cell", interiorWidth: 1, interiorHeight: 1, spawnsPlayer: true),
                        interiorOrigin: .zero, random: &random)
        let world = World(seed: 14, rooms: [room])
        let simulation = Simulation(world: world, actors: [
            actor(0, .player, room.door.tile), actor(1, .allySkeletonMelee, .zero)
        ])
        var cancelledTurns = 0
        for _ in 0..<900 {
            let delay = simulation.allies[0].idleDecisionDelay
            simulation.advance(by: GameBalance.simulationStep)
            let skeleton = simulation.allies[0]
            if skeleton.idleDecisionDelay > delay { cancelledTurns += 1 }
            XCTAssertEqual(skeleton.tile, .zero)
            XCTAssertNil(skeleton.movement)
            XCTAssertNil(skeleton.destination)
            XCTAssertTrue(skeleton.route.isEmpty)
            XCTAssertGreaterThan(skeleton.idleDecisionDelay, 0, "Do not retry every tick after a blocked choice")
        }
        XCTAssertGreaterThan(cancelledTurns, 1)
        XCTAssertLessThanOrEqual(cancelledTurns, 15)
        XCTAssertEqual(simulation.world.doors[0].health.hp, room.door.health.hp)
    }

    func testAllLivingActorsReserveSeparateWalkableTilesAcrossBattles() {
        var sawEnemyDamage = false, sawSkeletonDamage = false
        for seed in 0..<12 {
            let simulation = Simulation(seed: UInt64(seed))
            for _ in 0..<3600 {
                simulation.advance(by: GameBalance.simulationStep)
                var occupied: Set<Tile> = []
                for actor in simulation.actors where actor.isAlive {
                    XCTAssertTrue(occupied.isDisjoint(with: actor.reservedTiles), "Overlap for seed \(seed)")
                    occupied.formUnion(actor.reservedTiles)
                    XCTAssertTrue(actor.reservedTiles.allSatisfy { simulation.world.isWalkable($0, for: actor.affiliation) })
                    if actor.movement != nil { XCTAssertNil(actor.attack) }
                }
                sawEnemyDamage = sawEnemyDamage || simulation.enemies.contains { $0.health.hp < $0.health.maximumHP }
                sawSkeletonDamage = sawSkeletonDamage || simulation.allies.contains { $0.health.hp < $0.health.maximumHP }
                if simulation.isGameOver { break }
            }
        }
        XCTAssertTrue(sawEnemyDamage)
        XCTAssertTrue(sawSkeletonDamage)
    }

    func testPauseFreezesWanderingAndResumingPreservesSeededDecisions() {
        let first = Simulation(seed: 7), second = Simulation(seed: 7)
        advance(first, steps: 120); advance(second, steps: 120)
        first.isPaused = true
        advance(first, steps: 300)
        first.isPaused = false
        advance(first, steps: 240); advance(second, steps: 240)
        XCTAssertEqual(first.elapsed, second.elapsed)
        for (lhs, rhs) in zip(first.actors, second.actors) {
            XCTAssertEqual(lhs.tile, rhs.tile)
            XCTAssertEqual(lhs.movement?.to, rhs.movement?.to)
            XCTAssertEqual(lhs.health.hp, rhs.health.hp)
            XCTAssertEqual(lhs.skeletonBehavior, rhs.skeletonBehavior)
            XCTAssertEqual(lhs.idleDecisionDelay, rhs.idleDecisionDelay)
        }
    }
}
