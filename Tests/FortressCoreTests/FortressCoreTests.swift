import XCTest
#if SWIFT_PACKAGE
@testable import FortressCore
#endif

final class FortressCoreTests: XCTestCase {
    func testGeneratedRoomConstraintsAndVariation() {
        var directions: Set<Direction> = []
        var doors: Set<Tile> = []
        var colors: Set<Int> = []
        var playerStarts: Set<Tile> = []
        var chairStarts: Set<Tile> = []
        var floorVariants: Set<Int> = []
        for seed in 0..<200 {
            let world = World(seed: UInt64(seed)), room = world.rooms[0]
            let door = room.door, chair = room.chairs[0]
            XCTAssertEqual(world.rooms.count, 1)
            XCTAssertEqual(room.interiorTiles.count, 16)
            XCTAssertEqual(Set(room.interiorTiles.map(\.x)).count, 4)
            XCTAssertEqual(Set(room.interiorTiles.map(\.y)).count, 4)
            XCTAssertEqual(room.walls.count, 19)
            XCTAssertEqual(room.tiles.count, 36)
            XCTAssertEqual(room.chairs.count, 1)
            XCTAssertTrue(room.interiorTiles.contains(world.playerStart))
            XCTAssertTrue(chair.tile.neighbors.allSatisfy { room.interiorTiles.contains($0) })
            XCTAssertNotEqual(world.playerStart, chair.tile)
            XCTAssertTrue(world.isWalkable(chair.tile, for: .friendly))
            XCTAssertTrue(world.isWalkable(door.tile, for: .friendly))
            XCTAssertFalse(world.isWalkable(door.tile, for: .hostile))
            XCTAssertFalse(room.interiorTiles.contains(door.tile))
            XCTAssertNil(room.walls[door.tile])
            XCTAssertEqual(door.tile.neighbors.filter { room.interiorTiles.contains($0) }.count, 1)
            XCTAssertTrue(room.walls.values.allSatisfy { $0.health.hp > door.health.hp })
            XCTAssertFalse(room.definition.canBeBuiltByPlayer)
            XCTAssertFalse(room.definition.canBeDestroyedByPlayer)
            XCTAssertEqual(Set(world.enemyStarts).count, 3)
            XCTAssertTrue(world.enemyStarts.allSatisfy { world.isWalkable($0, for: .hostile) && !room.tiles.contains($0) })
            XCTAssertTrue(world.enemyStarts.allSatisfy { max(abs($0.x), abs($0.y)) == World.radius })
            XCTAssertEqual(Set(door.exteriorAttackTiles).count, 3)
            XCTAssertTrue(door.exteriorAttackTiles.allSatisfy { world.isWalkable($0, for: .hostile) && !room.tiles.contains($0) })
            directions.insert(door.outwardDirection)
            doors.insert(door.tile)
            colors.insert(chair.color)
            playerStarts.insert(world.playerStart)
            chairStarts.insert(chair.tile)
            floorVariants.formUnion(room.floorTiles.values.map(\.variant))
        }
        XCTAssertEqual(directions.count, 4)
        XCTAssertEqual(doors.count, 16)
        XCTAssertEqual(colors.count, 3)
        XCTAssertEqual(chairStarts.count, 4)
        XCTAssertEqual(playerStarts.count, 16)
        XCTAssertEqual(floorVariants.count, 4)
    }

    func testSeedIsReproducible() {
        let a = World(seed: 903)
        let b = World(seed: 903)
        XCTAssertEqual(a.rooms[0].door.tile, b.rooms[0].door.tile)
        XCTAssertEqual(a.rooms[0].chairs[0].tile, b.rooms[0].chairs[0].tile)
        XCTAssertEqual(a.enemyStarts, b.enemyStarts)
        XCTAssertEqual(a.playerStart, b.playerStart)
        XCTAssertEqual(a.walls.mapValues(\.variant), b.walls.mapValues(\.variant))
    }

    func testDamageStagesAndHealthClamp() {
        var gate = Destructible(maximumHP: 45, hp: 45)
        XCTAssertEqual(gate.damageStage, 0)
        gate.damage(15)
        XCTAssertEqual(gate.damageStage, 1)
        gate.damage(15)
        XCTAssertEqual(gate.damageStage, 2)
        gate.damage(-100)
        XCTAssertEqual(gate.hp, 15)
        gate.damage(100)
        XCTAssertEqual(gate.hp, 0)
        XCTAssertTrue(gate.isDestroyed)
    }

    func testDoorPassageUsesAffiliationAndEnemiesMustDestroyIt() throws {
        var world = World(seed: 4)
        let door = world.rooms[0].door, outside = door.exteriorAttackTiles[0]
        XCTAssertEqual(ActorKind.player.affiliation, .friendly)
        XCTAssertEqual(ActorKind.enemyMeleeSword.affiliation, .hostile)
        XCTAssertTrue(door.allowsPassage(for: .friendly))
        XCTAssertFalse(door.allowsPassage(for: .hostile))
        let path = try XCTUnwrap(Pathfinder.path(from: world.playerStart, to: outside, world: world, for: .friendly))
        var previous = world.playerStart
        for tile in path {
            XCTAssertEqual(previous.distance(to: tile), 1)
            XCTAssertTrue(world.isWalkable(tile, for: .friendly))
            previous = tile
        }
        XCTAssertTrue(path.contains(door.tile))
        XCTAssertNotNil(Pathfinder.path(from: outside, to: world.playerStart, world: world, for: .friendly))
        XCTAssertNil(Pathfinder.path(from: outside, to: world.playerStart, world: world, for: .hostile))
        XCTAssertNil(Pathfinder.path(from: outside, to: door.tile, world: world, for: .hostile))
        XCTAssertNil(world.damageDoor(at: door.tile, amount: door.health.hp, by: .friendly))
        XCTAssertEqual(world.door(at: door.tile)?.health.hp, door.health.hp)
        world.damageDoor(at: door.tile, amount: door.health.hp - 1, by: .hostile)
        XCTAssertFalse(world.isWalkable(door.tile, for: .hostile))
        world.damageDoor(at: door.tile, amount: 1, by: .hostile)
        let entry = try XCTUnwrap(Pathfinder.path(from: outside, to: world.playerStart, world: world, for: .hostile))
        XCTAssertTrue(entry.contains(door.tile))
        XCTAssertNil(Pathfinder.path(from: world.playerStart, to: Tile(x: 100, y: 100), world: world, for: .friendly))
    }

    func testRoomDefinitionCanBePlacedAtAnotherOriginAlongsideTheStarterRoom() throws {
        var random = SeededRandom(seed: 9)
        let starter = Room(definition: .starter, interiorOrigin: Tile(x: -2, y: -2), random: &random)
        let workshop = RoomDefinition(id: "workshop", interiorWidth: 5, interiorHeight: 3, placesChairAwayFromEdge: true)
        let room = Room(definition: workshop, interiorOrigin: Tile(x: 6, y: 6), random: &random)
        var world = World(seed: 1, rooms: [starter, room])
        XCTAssertEqual(room.interiorTiles.count, 15)
        XCTAssertEqual(room.walls.count, 19)
        XCTAssertEqual(room.tiles.count, 35)
        XCTAssertEqual(room.interiorTiles.map(\.x).min(), 6)
        XCTAssertEqual(room.interiorTiles.map(\.y).min(), 6)
        XCTAssertTrue(room.definition.canBeBuiltByPlayer)
        XCTAssertTrue(room.definition.canBeDestroyedByPlayer)
        XCTAssertNil(room.playerStart)
        XCTAssertEqual(world.playerStart, starter.playerStart)
        XCTAssertEqual(world.doors.count, 2)
        XCTAssertEqual(world.chairs.count, 2)
        for tile in room.floorTiles.keys {
            XCTAssertEqual(world.ground[tile]?.terrain, .wood)
            XCTAssertTrue(world.isWalkable(tile, for: .friendly))
        }
        XCTAssertTrue(room.walls.keys.allSatisfy { !world.isWalkable($0, for: .friendly) })
        world.damageDoor(at: room.door.tile, amount: room.door.health.hp, by: .hostile)
        XCTAssertTrue(world.isWalkable(room.door.tile, for: .hostile))
        XCTAssertFalse(world.isWalkable(starter.door.tile, for: .hostile))
        XCTAssertEqual(world.rooms[0].door.health.hp, starter.door.health.hp)
    }

    func testPlayerWalksAcrossIntactDoorWithoutChangingIt() throws {
        let world = World(seed: 4), door = world.rooms[0].door
        let player = Actor(id: 0, kind: .player, tile: door.tile - door.outwardDirection.offset,
                           health: Destructible(maximumHP: 30, hp: 30))
        let simulation = Simulation(world: world, actors: [player])
        let outside = door.tile + door.outwardDirection.offset
        XCTAssertTrue(simulation.movePlayer(to: outside))
        XCTAssertTrue(simulation.player.route.contains(door.tile))
        for _ in 0..<120 { simulation.advance(by: GameBalance.simulationStep) }
        XCTAssertEqual(simulation.player.tile, outside)
        XCTAssertEqual(simulation.world.door(at: door.tile)?.health.hp, door.health.hp)
        XCTAssertTrue(simulation.movePlayer(to: player.tile))
        for _ in 0..<120 { simulation.advance(by: GameBalance.simulationStep) }
        XCTAssertEqual(simulation.player.tile, player.tile)
        XCTAssertEqual(simulation.world.door(at: door.tile)?.health.hp, door.health.hp)
    }

    func testEnemyPursuesPlayerOutsideWithoutAttackingAnUnrelatedDoor() {
        let world = World(seed: 4), door = world.rooms[0].door
        let player = Actor(id: 0, kind: .player, tile: Tile(x: 0, y: 8),
                           health: Destructible(maximumHP: 30, hp: 30))
        let enemy = Actor(id: 1, kind: .enemyMeleeSword, tile: Tile(x: 0, y: 11),
                          health: Destructible(maximumHP: 20, hp: 20))
        let simulation = Simulation(world: world, actors: [player, enemy])
        for _ in 0..<180 { simulation.advance(by: GameBalance.simulationStep) }
        XCTAssertLessThan(simulation.player.health.hp, 30)
        XCTAssertEqual(simulation.world.door(at: door.tile)?.health.hp, door.health.hp)
    }

    func testInvalidTapKeepsExistingRouteAndMovingTapReplansAtNextTile() throws {
        let simulation = Simulation(seed: 10)
        let target = Tile(x: simulation.player.tile.x == -2 ? 1 : -2, y: simulation.player.tile.y)
        XCTAssertTrue(simulation.movePlayer(to: target))
        simulation.advance(by: 0.1)
        let movement = try XCTUnwrap(simulation.player.movement)
        let route = simulation.player.route
        XCTAssertFalse(simulation.movePlayer(to: simulation.world.walls.keys.sorted()[0]))
        XCTAssertEqual(simulation.player.route, route)
        XCTAssertEqual(simulation.player.movement?.to, movement.to)
        let newTarget = simulation.world.rooms[0].chairs[0].tile
        XCTAssertTrue(simulation.movePlayer(to: newTarget))
        XCTAssertEqual(simulation.player.movement?.to, movement.to)
        XCTAssertEqual(simulation.player.movement?.from, movement.from)
        let expected = Pathfinder.path(from: movement.to, to: newTarget, world: simulation.world, for: .friendly, preferStaircase: true)
        XCTAssertEqual(simulation.player.route, expected)
        for _ in 0..<240 { simulation.advance(by: 1.0 / 60) }
        XCTAssertEqual(simulation.player.tile, newTarget)
        XCTAssertNil(simulation.player.movement)
        XCTAssertTrue(simulation.player.route.isEmpty)
    }

    func testPlayerTakesSixAlternatingStepsBetweenOppositeRoomCorners() throws {
        let world = World(seed: 4)
        for start in [Tile(x: -2, y: 1), Tile(x: 1, y: 1), Tile(x: -2, y: -2), Tile(x: 1, y: -2)] {
            let goal = Tile(x: -1 - start.x, y: -1 - start.y)
            let player = Actor(id: 0, kind: .player, tile: start, health: Destructible(maximumHP: 30, hp: 30))
            let simulation = Simulation(world: world, actors: [player])
            XCTAssertTrue(simulation.movePlayer(to: goal))
            let route = simulation.player.route
            XCTAssertEqual(route.count, 6)
            XCTAssertEqual(route.last, goal)
            var previous = start
            var previousStep: Tile?
            for tile in route {
                let step = tile - previous
                XCTAssertEqual(tile.distance(to: previous), 1)
                XCTAssertTrue(world.rooms[0].interiorTiles.contains(tile))
                if let previousStep { XCTAssertNotEqual(step.x == 0, previousStep.x == 0) }
                previousStep = step
                previous = tile
            }
            for _ in 0...180 { simulation.advance(by: GameBalance.simulationStep) }
            XCTAssertEqual(simulation.player.tile, goal)
            XCTAssertNil(simulation.player.movement)
            XCTAssertEqual(simulation.elapsed, 6 / GameBalance.playerTilesPerSecond, accuracy: GameBalance.simulationStep + 0.000001)
        }
    }

    func testStaircaseRoutesStayDirectForUnequalDistancesAndStraightForSingleAxis() throws {
        let start = Tile.zero
        let walkable: (Tile) -> Bool = { (-6...6).contains($0.x) && (-6...6).contains($0.y) }
        for goal in [Tile(x: 6, y: 2), Tile(x: -2, y: 6), Tile(x: -6, y: -2), Tile(x: 2, y: -6),
                     Tile(x: 5, y: 0), Tile(x: 0, y: -5)] {
            let route = try XCTUnwrap(Pathfinder.path(from: start, to: goal, preferStaircase: true, isWalkable: walkable))
            XCTAssertEqual(route.count, start.distance(to: goal))
            var previous = start
            for tile in route {
                XCTAssertEqual(previous.distance(to: tile), 1)
                XCTAssertLessThan(tile.distance(to: goal), previous.distance(to: goal))
                XCTAssertLessThanOrEqual(abs(tile.x * goal.y - tile.y * goal.x), max(abs(goal.x), abs(goal.y)))
                previous = tile
            }
            if goal.x == 0 { XCTAssertTrue(route.allSatisfy { $0.x == 0 }) }
            if goal.y == 0 { XCTAssertTrue(route.allSatisfy { $0.y == 0 }) }
        }
    }

    func testStaircasePreferencePreservesShortestDetoursAndRespectsBlockedTiles() throws {
        let start = Tile.zero, goal = Tile(x: 5, y: 2)
        let walkable: (Tile) -> Bool = {
            (0...6).contains($0.x) && (0...4).contains($0.y) && !($0.x == 2 && $0.y < 4)
        }
        let blocked: Set<Tile> = [Tile(x: 4, y: 3)]
        let ordinary = try XCTUnwrap(Pathfinder.path(from: start, to: goal, blocked: blocked, isWalkable: walkable))
        let staircase = try XCTUnwrap(Pathfinder.path(from: start, to: goal, blocked: blocked, preferStaircase: true, isWalkable: walkable))
        XCTAssertGreaterThan(ordinary.count, start.distance(to: goal))
        XCTAssertEqual(staircase.count, ordinary.count)
        var previous = start
        for tile in staircase {
            XCTAssertEqual(previous.distance(to: tile), 1)
            XCTAssertTrue(walkable(tile))
            XCTAssertFalse(blocked.contains(tile))
            previous = tile
        }
        XCTAssertEqual(staircase.last, goal)
        XCTAssertNil(Pathfinder.path(from: start, to: goal, blocked: [goal], preferStaircase: true, isWalkable: walkable))
        XCTAssertNil(Pathfinder.path(from: start, to: goal, blocked: [Tile(x: 2, y: 4)], preferStaircase: true, isWalkable: walkable))
        XCTAssertEqual(Pathfinder.path(from: start, to: start, preferStaircase: true, isWalkable: walkable), [])
    }

    func testGateHasHalfHealthAndThreeEnemiesBreachInAboutFiveSeconds() {
        let world = World(seed: 14)
        XCTAssertEqual(world.rooms[0].door.health.hp, 45)
        let simulation = gateScenario(world)
        var firstDamage: Double?
        var destroyedEvents = 0
        for _ in 0..<360 {
            simulation.advance(by: 1.0 / 60)
            if simulation.world.rooms[0].door.health.hp < world.rooms[0].door.health.hp && firstDamage == nil { firstDamage = simulation.elapsed }
            destroyedEvents += simulation.events.filter { $0 == .doorDestroyed(world.rooms[0].door.tile) }.count
            if simulation.world.rooms[0].door.health.isDestroyed { break }
        }
        XCTAssertTrue(simulation.world.rooms[0].door.health.isDestroyed)
        XCTAssertEqual(destroyedEvents, 1)
        XCTAssertEqual(simulation.elapsed, 5, accuracy: 1)
        XCTAssertNotNil(firstDamage)
        XCTAssertTrue(simulation.world.isWalkable(world.rooms[0].door.tile, for: .friendly))
    }

    func testEnemiesNeverOverlapAndEventuallyKillPlayerAcrossSeeds() {
        for seed in 0..<12 {
            let simulation = Simulation(seed: UInt64(seed))
            var sawGateTransit = false
            var sawPlayerDamage = false
            for _ in 0..<4200 {
                simulation.advance(by: 1.0 / 60)
                var occupied: Set<Tile> = []
                for actor in simulation.actors {
                    XCTAssertTrue(occupied.isDisjoint(with: actor.reservedTiles), "Overlap for seed \(seed)")
                    occupied.formUnion(actor.reservedTiles)
                    if let movement = actor.movement {
                        XCTAssertEqual(movement.from.distance(to: movement.to), 1)
                        XCTAssertTrue(simulation.world.isWalkable(movement.to, for: actor.affiliation))
                        XCTAssertNil(actor.attack)
                        if actor.id != 0 && movement.to == simulation.world.rooms[0].door.tile { sawGateTransit = true }
                    }
                    if actor.attack != nil { XCTAssertNil(actor.movement) }
                }
                if simulation.player.health.hp < GameBalance.playerHP { sawPlayerDamage = true }
                if simulation.isGameOver { break }
            }
            XCTAssertTrue(sawGateTransit, "Never entered gate for seed \(seed)")
            XCTAssertTrue(sawPlayerDamage, "Never attacked player for seed \(seed)")
            XCTAssertTrue(simulation.isGameOver, "Did not finish for seed \(seed)")
            XCTAssertEqual(simulation.player.health.hp, 0)
            XCTAssertTrue(simulation.actors.allSatisfy { $0.movement == nil })
            XCTAssertTrue(simulation.player.route.isEmpty)
        }
    }

    func testPauseFreezesMovementCombatAndClockAndNewGameResetsEverything() {
        let simulation = gateScenario(World(seed: 91))
        simulation.advance(by: 0.2)
        simulation.isPaused = true
        let time = simulation.elapsed
        let hp = simulation.world.rooms[0].door.health.hp
        for _ in 0..<90 { simulation.advance(by: 0.2) }
        XCTAssertEqual(simulation.elapsed, time)
        XCTAssertEqual(simulation.world.rooms[0].door.health.hp, hp)
        XCTAssertFalse(simulation.movePlayer(to: .zero))
        simulation.isPaused = false
        for _ in 0..<300 { simulation.advance(by: 0.2) }
        XCTAssertTrue(simulation.isGameOver)
        let reset = Simulation(seed: 92)
        XCTAssertEqual(reset.elapsed, 0)
        XCTAssertEqual(reset.player.health.hp, GameBalance.playerHP)
        XCTAssertEqual(reset.world.rooms[0].door.health.hp, GameBalance.gateHP)
        XCTAssertFalse(reset.isGameOver)
        XCTAssertFalse(reset.isPaused)
        XCTAssertTrue(reset.events.isEmpty)
    }

    func testPlayerCannotAttackAndEnemiesAreFiftyPercentFaster() {
        let simulation = Simulation(seed: 1)
        XCTAssertNil(simulation.player.attack)
        XCTAssertEqual(GameBalance.enemyTilesPerSecond / GameBalance.playerTilesPerSecond, 1.5, accuracy: 0.0001)
        for _ in 0..<2000 {
            simulation.advance(by: 1.0 / 60)
            XCTAssertNil(simulation.player.attack)
            XCTAssertTrue(simulation.enemies.allSatisfy { $0.health.hp == $0.health.maximumHP })
        }
    }

    func testMeleeWindupPrecedesDamageAndContactPoseAndHitShareOneTick() {
        var world = World(seed: 14)
        world.damageDoor(at: world.rooms[0].door.tile, amount: world.rooms[0].door.health.hp, by: .hostile)
        let player = Actor(id: 0, kind: .player, tile: .zero,
                           health: Destructible(maximumHP: 30, hp: 30))
        let enemy = Actor(id: 1, kind: .enemyMeleeSword, tile: Tile(x: 0, y: -1),
                          health: Destructible(maximumHP: 20, hp: 20))
        let simulation = Simulation(world: world, actors: [player, enemy])
        simulation.advance(by: GameBalance.simulationStep)
        XCTAssertNotNil(simulation.enemies.first?.attack)
        let windupSteps = Int((GameBalance.meleeAttackWindup / GameBalance.simulationStep).rounded())
        for _ in 0..<(windupSteps - 1) {
            XCTAssertEqual(simulation.player.health.hp, 30)
            XCTAssertTrue(simulation.events.isEmpty)
            XCTAssertEqual(simulation.enemies.first?.attack?.animationFrame, 0)
            simulation.advance(by: GameBalance.simulationStep)
        }
        XCTAssertEqual(simulation.player.health.hp, 30)
        XCTAssertTrue(simulation.events.isEmpty)
        simulation.advance(by: GameBalance.simulationStep)
        XCTAssertEqual(simulation.player.health.hp, 30 - GameBalance.playerDamage)
        XCTAssertEqual(simulation.events, [.playerDamaged(30 - GameBalance.playerDamage)])
        XCTAssertEqual(simulation.enemies.first?.attack?.animationFrame, 1)
        XCTAssertTrue(simulation.movePlayer(to: Tile(x: 1, y: 1)))
        for _ in 0..<22 {
            simulation.advance(by: GameBalance.simulationStep)
            XCTAssertTrue(simulation.events.isEmpty, "Recovery must not emit a delayed hit")
        }
        XCTAssertNotNil(simulation.player.movement)
        XCTAssertEqual(simulation.player.health.hp, 30 - GameBalance.playerDamage)
        XCTAssertEqual(simulation.enemies.first?.tile, enemy.tile)
        XCTAssertNil(simulation.enemies.first?.movement)
    }

    func testPursuitOnlyDamagesMovingPlayerWhileActuallyInReach() {
        var world = World(seed: 14)
        world.damageDoor(at: world.rooms[0].door.tile, amount: world.rooms[0].door.health.hp, by: .hostile)
        let player = Actor(id: 0, kind: .player, tile: Tile(x: 0, y: 5),
                           health: Destructible(maximumHP: 100, hp: 100))
        let enemy = Actor(id: 1, kind: .enemyMeleeSword, tile: Tile(x: 0, y: 4),
                          health: Destructible(maximumHP: 20, hp: 20))
        let simulation = Simulation(world: world, actors: [player, enemy])
        XCTAssertTrue(simulation.movePlayer(to: Tile(x: 0, y: 11)))
        var hits = 0
        for _ in 0..<360 {
            simulation.advance(by: GameBalance.simulationStep)
            for event in simulation.events {
                guard case .playerDamaged = event else { continue }
                hits += 1
                let position = simulation.player.position
                let attacker = simulation.actors[1]
                let distance = abs(position.x - Double(attacker.tile.x)) + abs(position.y - Double(attacker.tile.y))
                XCTAssertLessThanOrEqual(distance, GameBalance.swordReach + 0.0000001)
                XCTAssertNil(attacker.movement)
                XCTAssertEqual(attacker.attack?.animationFrame, 1)
            }
        }
        XCTAssertGreaterThan(hits, 1)
    }

    func testLeavingSwordReachDuringWindupMissesWithoutDelayedDamage() {
        var world = World(seed: 14)
        world.damageDoor(at: world.rooms[0].door.tile, amount: world.rooms[0].door.health.hp, by: .hostile)
        var player = Actor(id: 0, kind: .player, tile: .zero,
                           health: Destructible(maximumHP: 30, hp: 30))
        // Start just inside engagement range, then move beyond sword reach during wind-up.
        player.movement = Movement(from: .zero, to: Tile(x: 0, y: 1), duration: 0.5, elapsed: 0.05)
        let enemy = Actor(id: 1, kind: .enemyMeleeSword, tile: Tile(x: 0, y: -1),
                          health: Destructible(maximumHP: 20, hp: 20))
        let simulation = Simulation(world: world, actors: [player, enemy])
        simulation.advance(by: GameBalance.simulationStep)
        XCTAssertEqual(simulation.enemies.first?.attack?.animationFrame, 0)
        let windupSteps = Int((GameBalance.meleeAttackWindup / GameBalance.simulationStep).rounded())
        for _ in 0..<windupSteps {
            simulation.advance(by: GameBalance.simulationStep)
            XCTAssertEqual(simulation.player.health.hp, 30)
            XCTAssertTrue(simulation.events.isEmpty)
        }
        XCTAssertGreaterThan(simulation.player.position.y + 1, GameBalance.swordReach)
        XCTAssertEqual(simulation.enemies.first?.attack?.animationFrame, 1)
        XCTAssertEqual(simulation.enemies.first?.attack?.delivered, true)
        // Re-enter reach during recovery: the missed swing must remain a miss.
        XCTAssertTrue(simulation.movePlayer(to: .zero))
        for _ in 0..<40 {
            simulation.advance(by: GameBalance.simulationStep)
            XCTAssertEqual(simulation.player.health.hp, 30)
            XCTAssertTrue(simulation.events.isEmpty)
            XCTAssertNil(simulation.enemies.first?.movement)
        }
    }

    func testLethalContactStopsOtherAttackersInTheSameTick() {
        var world = World(seed: 14)
        world.damageDoor(at: world.rooms[0].door.tile, amount: world.rooms[0].door.health.hp, by: .hostile)
        let player = Actor(id: 0, kind: .player, tile: .zero,
                           health: Destructible(maximumHP: 4, hp: 4))
        let enemies = [Tile(x: 0, y: -1), Tile(x: -1, y: 0), Tile(x: 1, y: 0)].enumerated().map { index, tile in
            Actor(id: index + 1, kind: .enemyMeleeSword, tile: tile, health: Destructible(maximumHP: 20, hp: 20))
        }
        let simulation = Simulation(world: world, actors: [player] + enemies)
        simulation.advance(by: GameBalance.simulationStep)
        XCTAssertFalse(simulation.isGameOver)
        let windupSteps = Int((GameBalance.meleeAttackWindup / GameBalance.simulationStep).rounded())
        for _ in 0..<windupSteps { simulation.advance(by: GameBalance.simulationStep) }
        XCTAssertTrue(simulation.isGameOver)
        XCTAssertEqual(simulation.events, [.playerDamaged(0), .playerDied])
        XCTAssertEqual(simulation.actors[1].attack?.animationFrame, 1)
        XCTAssertTrue(simulation.actors.allSatisfy { $0.movement == nil })
        XCTAssertTrue(simulation.actors.dropFirst(2).allSatisfy { $0.attack == nil })
    }

    private func gateScenario(_ world: World) -> Simulation {
        let player = Actor(id: 0, kind: .player, tile: .zero,
                           health: Destructible(maximumHP: GameBalance.playerHP, hp: GameBalance.playerHP))
        let enemies = world.rooms[0].door.exteriorAttackTiles.enumerated().map { index, tile in
            Actor(id: index + 1, kind: .enemyMeleeSword, tile: tile, health: Destructible(maximumHP: 20, hp: 20))
        }
        return Simulation(world: world, actors: [player] + enemies)
    }
}
