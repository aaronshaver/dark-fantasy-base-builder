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

    func testSkeletonWaitsInsideHomeWhenEnemyIsSurrounded() throws {
        let simulation = scenario(seed: 14, surroundedTarget: true), room = simulation.world.rooms[0]
        simulation.advance(by: GameBalance.simulationStep)
        let skeleton = try XCTUnwrap(simulation.actors.first { $0.id == 10 })
        XCTAssertEqual(skeleton.skeletonBehavior, .attacking(targetID: 20))
        XCTAssertNil(skeleton.movement)
        advance(simulation, steps: 180)
        let approaching = try XCTUnwrap(simulation.actors.first { $0.id == 10 })
        XCTAssertTrue(room.interiorTiles.contains(approaching.tile))
        XCTAssertEqual(approaching.tile, skeleton.tile)
        XCTAssertNil(approaching.movement)
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
        advance(simulation, steps: 480)
        let leaving = try XCTUnwrap(simulation.actors.first { $0.id == 10 })
        XCTAssertFalse(room.tiles.contains(leaving.tile))
        XCTAssertEqual(leaving.skeletonBehavior, .attacking(targetID: 20))
        XCTAssertEqual(simulation.world.doors[0].health.hp, room.door.health.hp)
    }
}

final class PlayerRouteRetryTests: XCTestCase {
    private func actor(_ id: Int, _ kind: ActorKind, at tile: Tile) -> Actor {
        Actor(id: id, kind: kind, tile: tile, health: Destructible(maximumHP: 1000, hp: 1000))
    }

    private func tripBlockedAfterTap(world: World, start: Tile, destination: Tile,
                                     blockerTile: Tile, enemyTile: Tile, blockerMovesAfter: Double,
                                     startsMoving: Bool = true) throws -> Simulation {
        let original = Simulation(world: world, actors: [actor(0, .player, at: start)])
        XCTAssertTrue(original.movePlayer(to: destination))
        if startsMoving { original.advance(by: 0.1) }
        // Capture an accepted trip, then supply the state after an ally enters its route.
        // Its decision timer controls when the obstruction clears, independently of random wandering.
        var blocker = actor(7, .allySkeletonMelee, at: blockerTile)
        blocker.skeletonBehavior = .attacking(targetID: 99)
        blocker.decisionDelay = blockerMovesAfter
        blocker.cooldown = 60
        var enemy = actor(99, .enemyMeleeSword, at: enemyTile)
        enemy.decisionDelay = 60
        enemy.cooldown = 60
        return Simulation(world: world, actors: [original.player, blocker, enemy])
    }

    private func blockedDoor(moveAfter: Double, startsAtEntry: Bool = false) throws -> Simulation {
        let world = World(seed: 14), room = world.rooms[0], door = room.door
        let normal = door.outwardDirection.offset
        let start = startsAtEntry ? door.tile - normal : room.interiorTiles.sorted().max {
            $0.distance(to: door.tile) < $1.distance(to: door.tile)
        }!
        let destination = door.tile + normal + normal + normal
        let enemy = destination + normal + normal + normal
        return try tripBlockedAfterTap(world: world, start: start, destination: destination,
                                        blockerTile: door.tile, enemyTile: enemy, blockerMovesAfter: moveAfter,
                                        startsMoving: !startsAtEntry)
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

    func testBlockedTripStopsAfterInflightTileAndCancelsAfterFiveFailures() throws {
        let simulation = try blockedDoor(moveAfter: 60)
        let stop = try XCTUnwrap(simulation.player.movement?.to)
        let destination = simulation.player.destination
        advance(simulation, steps: 30)
        XCTAssertEqual(simulation.player.tile, stop)
        XCTAssertNil(simulation.player.movement)
        XCTAssertTrue(simulation.player.route.isEmpty)
        XCTAssertEqual(simulation.player.destination, destination)
        XCTAssertEqual(simulation.player.failedPathSearches, 1)
        advance(simulation, steps: 240)
        XCTAssertEqual(simulation.player.tile, stop)
        XCTAssertNil(simulation.player.destination)
        advance(simulation, steps: 240)
        XCTAssertEqual(simulation.player.tile, stop)
    }

    func testRetryResumesWhenDoorClearsAndResetsBackoff() throws {
        let simulation = try blockedDoor(moveAfter: 1)
        let destination = try XCTUnwrap(simulation.player.destination)
        advance(simulation, steps: 30)
        XCTAssertNil(simulation.player.movement)
        advance(simulation, steps: 600)
        XCTAssertEqual(simulation.player.tile, destination)
        XCTAssertNil(simulation.player.destination)
        XCTAssertEqual(simulation.player.failedPathSearches, 0)
        XCTAssertEqual(simulation.player.decisionDelay, 0)
    }

    func testBlockedTapCountsInitialAttemptAndUsesExactBackoff() throws {
        let simulation = try blockedDoor(moveAfter: 60, startsAtEntry: true)
        let destination = try XCTUnwrap(simulation.player.destination)
        XCTAssertTrue(simulation.movePlayer(to: destination))
        XCTAssertEqual(simulation.player.failedPathSearches, 1)
        XCTAssertEqual(simulation.player.decisionDelay, 0.25)
        for (ticks, failures, delay) in [(15, 2, 0.5), (30, 3, 1.0), (60, 4, 2.0)] {
            advance(simulation, steps: ticks - 1)
            XCTAssertEqual(simulation.player.failedPathSearches, failures - 1)
            advance(simulation, steps: 1)
            XCTAssertEqual(simulation.player.failedPathSearches, failures)
            XCTAssertEqual(simulation.player.decisionDelay, delay, accuracy: 0.000001)
            XCTAssertNil(simulation.player.movement)
        }
        advance(simulation, steps: 119)
        XCTAssertNotNil(simulation.player.destination)
        advance(simulation, steps: 1)
        XCTAssertNil(simulation.player.destination)
    }

    func testNewTapReplacesPendingRetryAndNeverResumesOldDestination() throws {
        let simulation = try blockedDoor(moveAfter: 1), room = simulation.world.rooms[0]
        let oldDestination = try XCTUnwrap(simulation.player.destination)
        advance(simulation, steps: 30)
        let entry = room.door.tile - room.door.outwardDirection.offset
        let newDestination = try XCTUnwrap(room.interiorTiles.sorted().first {
            !simulation.player.reservedTiles.contains($0) && $0 != entry
        })
        XCTAssertTrue(simulation.movePlayer(to: newDestination))
        XCTAssertEqual(simulation.player.destination, newDestination)
        advance(simulation, steps: 600)
        XCTAssertEqual(simulation.player.tile, newDestination)
        XCTAssertNotEqual(simulation.player.tile, oldDestination)
        XCTAssertNil(simulation.player.destination)
        XCTAssertNil(simulation.player.movement)
    }

    func testInvalidTapCancelsPendingRetry() throws {
        let simulation = try blockedDoor(moveAfter: 1)
        advance(simulation, steps: 30)
        let stop = simulation.player.tile
        XCTAssertFalse(simulation.movePlayer(to: simulation.world.walls.keys.sorted()[0]))
        XCTAssertNil(simulation.player.destination)
        XCTAssertEqual(simulation.player.failedPathSearches, 0)
        advance(simulation, steps: 600)
        XCTAssertEqual(simulation.player.tile, stop)
    }

    func testPausePreservesPendingRetry() throws {
        let simulation = try blockedDoor(moveAfter: 1)
        let destination = try XCTUnwrap(simulation.player.destination)
        advance(simulation, steps: 30)
        let position = simulation.player.position, route = simulation.player.route
        simulation.isPaused = true
        advance(simulation, steps: 600)
        XCTAssertEqual(simulation.player.position.x, position.x)
        XCTAssertEqual(simulation.player.position.y, position.y)
        XCTAssertEqual(simulation.player.route, route)
        XCTAssertEqual(simulation.player.destination, destination)
        simulation.isPaused = false
        advance(simulation, steps: 600)
        XCTAssertEqual(simulation.player.tile, destination)
    }

    func testBlockedDestinationDoesNotApproachOccupiedTile() throws {
        let world = World(seed: 14), destination = Tile(x: 3, y: 6)
        let simulation = try tripBlockedAfterTap(world: world, start: Tile(x: 0, y: 6), destination: destination,
                                                 blockerTile: destination, enemyTile: Tile(x: 9, y: 6),
                                                 blockerMovesAfter: 60)
        let stop = try XCTUnwrap(simulation.player.movement?.to)
        advance(simulation, steps: 300)
        XCTAssertEqual(simulation.player.tile, stop)
        XCTAssertNil(simulation.player.destination)
        XCTAssertNil(simulation.player.movement)
    }

    func testOpenDetourStillReplansDirectlyToOriginalDestination() throws {
        let world = World(seed: 14), destination = Tile(x: 6, y: 6)
        let simulation = try tripBlockedAfterTap(world: world, start: Tile(x: 0, y: 6), destination: destination,
                                                 blockerTile: Tile(x: 3, y: 6), enemyTile: Tile(x: 10, y: 6),
                                                 blockerMovesAfter: 60)
        advance(simulation, steps: 30)
        XCTAssertEqual(simulation.player.route.last, destination)
        XCTAssertTrue(simulation.player.route.contains { $0.y != 6 })
        advance(simulation, steps: 360)
        XCTAssertEqual(simulation.player.tile, destination)
        XCTAssertNil(simulation.player.destination)
    }
}

final class TargetSearchTests: XCTestCase {
    private func actor(_ id: Int, _ kind: ActorKind, _ tile: Tile, frozen: Bool = false) -> Actor {
        var result = Actor(id: id, kind: kind, tile: tile, health: Destructible(maximumHP: 1000, hp: 1000))
        if frozen {
            result.decisionDelay = 1000
            result.cooldown = 1000
            result.skeletonBehavior = .attacking(targetID: 10)
        }
        return result
    }
    private func advance(_ simulation: Simulation, _ ticks: Int) {
        for _ in 0..<ticks { simulation.advance(by: GameBalance.simulationStep) }
    }

    private func crowdedBattle(blockedTargets: Int) -> Simulation {
        var actors = [actor(0, .player, Tile(x: -2, y: -2)),
                      actor(1, .allySkeletonMelee, Tile(x: -10, y: 8))]
        for i in 0..<5 {
            let tile = Tile(x: -6 + i * 4, y: 8)
            actors.append(actor(10 + i, .enemyMeleeSword, tile, frozen: true))
            if i < blockedTargets {
                for (j, neighbor) in tile.neighbors.enumerated() {
                    actors.append(actor(100 + i * 4 + j, .allySkeletonMelee, neighbor, frozen: true))
                }
            }
        }
        return Simulation(world: World(seed: 14), actors: actors)
    }

    func testAllyChoosesNextClosestReachableHostile() {
        let simulation = crowdedBattle(blockedTargets: 1)
        advance(simulation, 1)
        XCTAssertEqual(simulation.actors[1].skeletonBehavior, .attacking(targetID: 11))
        XCTAssertNotNil(simulation.actors[1].movement)
        XCTAssertEqual(simulation.actors[1].failedPathSearches, 0)
    }

    func testAllySearchStopsAfterFourCandidatesThenWandersAfterFiveSearches() {
        let simulation = crowdedBattle(blockedTargets: 4)
        advance(simulation, 1)
        XCTAssertEqual(simulation.actors[1].failedPathSearches, 1)
        XCTAssertNil(simulation.actors[1].movement) // Fifth target is reachable but outside the search budget.
        for (ticks, failures) in [(15, 2), (30, 3), (60, 4)] {
            advance(simulation, ticks)
            XCTAssertEqual(simulation.actors[1].failedPathSearches, failures)
        }
        advance(simulation, 120)
        XCTAssertTrue(simulation.actors[1].mustWanderBeforeSensing)
        XCTAssertEqual(simulation.actors[1].skeletonBehavior, .idling)
        var finished = false
        for _ in 0..<480 {
            advance(simulation, 1)
            let skeleton = simulation.actors[1]
            if skeleton.mustWanderBeforeSensing {
                XCTAssertEqual(skeleton.skeletonBehavior, .idling)
            } else { finished = true; break }
        }
        XCTAssertTrue(finished)
        // Whether the random destination succeeds or fails, sensing resumes after just one attempt.
        advance(simulation, 1)
        XCTAssertNotEqual(simulation.actors[1].skeletonBehavior, .idling)
    }

    func testEnemyRetriesForeverAtTwoSecondCapAndSuccessResetsBackoff() {
        let center = Tile(x: 7, y: 7)
        var actors = [actor(0, .player, Tile(x: 11, y: 7)), actor(1, .enemyMeleeSword, center)]
        actors += center.neighbors.enumerated().map { actor(2 + $0.offset, .enemyMeleeSword, $0.element, frozen: true) }
        let simulation = Simulation(world: World(seed: 14), actors: actors)
        advance(simulation, 1)
        for (ticks, count, delay) in [(15, 2, 0.5), (30, 3, 1.0), (60, 4, 2.0), (120, 5, 2.0), (120, 5, 2.0)] {
            advance(simulation, ticks)
            XCTAssertEqual(simulation.actors[1].failedPathSearches, count)
            XCTAssertEqual(simulation.actors[1].decisionDelay, delay, accuracy: 0.000001)
            XCTAssertNil(simulation.actors[1].movement)
        }
        // Remove the obstruction from the captured state while preserving the retry clock.
        let clear = Simulation(world: simulation.world, actors: Array(simulation.actors.prefix(2)))
        advance(clear, 119)
        XCTAssertNil(clear.actors[1].movement)
        advance(clear, 1)
        XCTAssertNotNil(clear.actors[1].movement)
        XCTAssertEqual(clear.actors[1].failedPathSearches, 0)
        XCTAssertEqual(clear.actors[1].decisionDelay, 0)
    }

    func testEnemyTargetsCloserDoorEvenWithReachablePlayerOutside() {
        let world = World(seed: 14), door = world.doors[0], normal = door.outwardDirection.offset
        let simulation = Simulation(world: world, actors: [
            actor(0, .player, door.tile + normal + normal + normal + normal),
            actor(1, .enemyMeleeSword, door.tile + normal)
        ])
        advance(simulation, 1)
        XCTAssertEqual(simulation.enemies[0].attack?.target, .door(door.tile))
        advance(simulation, 20)
        XCTAssertLessThan(simulation.world.doors[0].health.hp, door.health.hp)
    }

    func testEnemyChoosesReachableDoorWhenNearerPlayerIsBehindWall() throws {
        let world = World(seed: 14), room = world.rooms[0]
        let pairs = room.interiorTiles.sorted().flatMap { playerTile in
            world.ground.keys.sorted().filter {
                !room.tiles.contains($0) && $0.distance(to: playerTile) == 2
                    && $0.distance(to: room.door.tile) > 2
            }.map { (playerTile, $0) }
        }
        let (playerTile, enemyTile) = try XCTUnwrap(pairs.first)
        let simulation = Simulation(world: world, actors: [actor(0, .player, playerTile), actor(1, .enemyMeleeSword, enemyTile)])
        advance(simulation, 1)
        XCTAssertNotNil(simulation.enemies[0].movement)
        XCTAssertEqual(simulation.enemies[0].failedPathSearches, 0)
        var attackedDoor = false
        for _ in 0..<720 {
            advance(simulation, 1)
            if simulation.enemies[0].attack?.target == .door(room.door.tile) { attackedDoor = true }
        }
        XCTAssertTrue(attackedDoor)
        XCTAssertLessThan(simulation.world.doors[0].health.hp, room.door.health.hp)
        advance(simulation, 1200)
        XCTAssertTrue(simulation.world.doors[0].health.isDestroyed)
        XCTAssertLessThan(simulation.player.health.hp, 1000)
    }

    func testEnemyFallsBackToReachableSkeletonWhenPlayerIsSurrounded() {
        let playerTile = Tile(x: 6, y: 7)
        var actors = [actor(0, .player, playerTile), actor(1, .enemyMeleeSword, Tile(x: 3, y: 7)),
                      actor(20, .allySkeletonMelee, Tile(x: 3, y: 12), frozen: true)]
        actors[2].skeletonBehavior = .attacking(targetID: 1)
        actors += playerTile.neighbors.enumerated().map {
            actor(30 + $0.offset, .enemyMeleeSword, $0.element, frozen: true)
        }
        let simulation = Simulation(world: World(seed: 14), actors: actors)
        advance(simulation, 120)
        XCTAssertEqual(simulation.actors[1].attack?.target, .actor(20))
        XCTAssertEqual(simulation.actors[1].failedPathSearches, 0)
    }

    func testRequiredWanderDoesNotGetInterruptedBySensingAndBlockedStepEndsIt() {
        var skeleton = actor(1, .allySkeletonMelee, Tile(x: 0, y: 8))
        skeleton.mustWanderBeforeSensing = true
        skeleton.route = [Tile(x: 1, y: 8)]
        skeleton.destination = Tile(x: 1, y: 8)
        let simulation = Simulation(world: World(seed: 14), actors: [
            actor(0, .player, Tile(x: 1, y: 8)), skeleton,
            actor(10, .enemyMeleeSword, Tile(x: 4, y: 8), frozen: true)
        ])
        advance(simulation, 1)
        XCTAssertEqual(simulation.allies[0].skeletonBehavior, .idling)
        XCTAssertFalse(simulation.allies[0].mustWanderBeforeSensing)
        XCTAssertNil(simulation.allies[0].destination)
        XCTAssertNil(simulation.allies[0].movement)
        advance(simulation, 1)
        XCTAssertEqual(simulation.allies[0].skeletonBehavior, .attacking(targetID: 10))
        XCTAssertNotNil(simulation.allies[0].movement)
    }

    func testHostileStructureIsAnAllyTargetButFriendlyDoorIsNot() {
        var random = SeededRandom(seed: 14)
        var home = Room(definition: .home, interiorOrigin: Tile(x: -2, y: -2), random: &random)
        home.door.affiliation = .hostile
        let world = World(seed: 14, rooms: [home]), door = home.door
        let simulation = Simulation(world: world, actors: [
            actor(0, .player, world.playerStart),
            actor(1, .allySkeletonMelee, door.tile + door.outwardDirection.offset)
        ])
        advance(simulation, 1)
        XCTAssertEqual(simulation.allies[0].attack?.target, .door(door.tile))
        advance(simulation, 20)
        XCTAssertLessThan(simulation.world.doors[0].health.hp, door.health.hp)
    }

    func testAllScenariosSpawnExactCountsOnDistinctValidTiles() {
        for scenario in NewGameScenario.allCases {
            for seed in 0..<10 {
                let simulation = Simulation(seed: UInt64(seed), scenario: scenario)
                XCTAssertEqual(simulation.allies.count, scenario.counts.allies)
                XCTAssertEqual(simulation.enemies.count, scenario.counts.enemies)
                XCTAssertEqual(Set(simulation.actors.map(\.tile)).count, simulation.actors.count)
                XCTAssertEqual(Set(simulation.actors.map(\.id)).count, simulation.actors.count)
                XCTAssertEqual(simulation.allies.filter { simulation.world.rooms[0].interiorTiles.contains($0.tile) }.count, 1)
                XCTAssertTrue(simulation.actors.allSatisfy { simulation.world.isWalkable($0.tile, for: $0.affiliation) })
                XCTAssertEqual(simulation.world.enemyStarts, Simulation(seed: UInt64(seed), scenario: scenario).world.enemyStarts)
                XCTAssertEqual(simulation.world.allyStarts, Simulation(seed: UInt64(seed), scenario: scenario).world.allyStarts)
            }
        }
    }

    func testHundredEachRemainsCollisionFreeDuringCombat() {
        let simulation = Simulation(seed: 14, scenario: .hundredEach)
        for _ in 0..<180 {
            advance(simulation, 1)
            var occupied: Set<Tile> = []
            for actor in simulation.actors where actor.isAlive {
                XCTAssertTrue(occupied.isDisjoint(with: actor.reservedTiles))
                occupied.formUnion(actor.reservedTiles)
            }
        }
    }
}
