import XCTest
#if SWIFT_PACKAGE
@testable import FortressCore
#endif

final class FortressCoreTests: XCTestCase {
    func testGeneratedRoomConstraintsAndVariation() {
        var directions: Set<Direction> = []
        var colors: Set<Int> = []
        var playerStarts: Set<Tile> = []
        var chairStarts: Set<Tile> = []
        var floorVariants: Set<Int> = []
        for seed in 0..<100 {
            let world = World(seed: UInt64(seed))
            XCTAssertEqual(world.walls.count, 23)
            XCTAssertEqual(world.ground.keys.filter(\.isInsideRoom).count, 25)
            XCTAssertTrue(world.playerStart.isInsideRoom)
            XCTAssertTrue(world.chair.tile.isInsideRoom)
            XCTAssertFalse(world.chair.tile.neighbors.contains { world.walls[$0] != nil || $0 == world.gateTile })
            XCTAssertTrue(world.isWalkable(world.chair.tile))
            XCTAssertFalse(world.isWalkable(world.gateTile))
            XCTAssertEqual(world.gateTile.distance(to: .zero), 3)
            XCTAssertTrue(world.walls.values.allSatisfy { $0.hp > world.gate.hp })
            XCTAssertEqual(Set(world.enemyStarts).count, 3)
            XCTAssertTrue(world.enemyStarts.allSatisfy { world.isWalkable($0) && !$0.isInsideRoom })
            XCTAssertEqual(Set(world.gateAttackTiles).count, 3)
            XCTAssertTrue(world.gateAttackTiles.allSatisfy { world.isWalkable($0) && !$0.isInsideRoom })
            directions.insert(world.gateDirection)
            colors.insert(world.chair.color)
            playerStarts.insert(world.playerStart)
            chairStarts.insert(world.chair.tile)
            floorVariants.formUnion(world.ground.values.filter { $0.terrain == .wood }.map(\.variant))
        }
        XCTAssertEqual(directions.count, 4)
        XCTAssertEqual(colors.count, 3)
        XCTAssertEqual(chairStarts.count, 9)
        XCTAssertGreaterThan(playerStarts.count, 15)
        XCTAssertEqual(floorVariants.count, 4)
    }

    func testSeedIsReproducible() {
        let a = World(seed: 903)
        let b = World(seed: 903)
        XCTAssertEqual(a.gateTile, b.gateTile)
        XCTAssertEqual(a.chair.tile, b.chair.tile)
        XCTAssertEqual(a.enemyStarts, b.enemyStarts)
        XCTAssertEqual(a.playerStart, b.playerStart)
        XCTAssertEqual(a.wallVariants, b.wallVariants)
    }

    func testDamageStagesAndHealthClamp() {
        var gate = Destructible(maximumHP: 90, hp: 90)
        XCTAssertEqual(gate.damageStage, 0)
        gate.damage(30)
        XCTAssertEqual(gate.damageStage, 1)
        gate.damage(30)
        XCTAssertEqual(gate.damageStage, 2)
        gate.damage(-100)
        XCTAssertEqual(gate.hp, 30)
        gate.damage(100)
        XCTAssertEqual(gate.hp, 0)
        XCTAssertTrue(gate.isDestroyed)
    }

    func testPathsAreOrthogonalAndGateBlocksEscapeUntilDestroyed() throws {
        var world = World(seed: 4)
        let goal = world.gateAttackTiles[0]
        XCTAssertNil(Pathfinder.path(from: world.playerStart, to: goal, world: world))
        XCTAssertNil(Pathfinder.path(from: world.playerStart, to: world.gateTile, world: world))
        XCTAssertNotNil(Pathfinder.path(from: world.playerStart, to: world.chair.tile, world: world))
        world.gate.damage(90)
        let path = try XCTUnwrap(Pathfinder.path(from: world.playerStart, to: goal, world: world))
        var previous = world.playerStart
        for tile in path {
            XCTAssertEqual(previous.distance(to: tile), 1)
            XCTAssertTrue(world.isWalkable(tile))
            previous = tile
        }
        XCTAssertTrue(path.contains(world.gateTile))
        XCTAssertNil(Pathfinder.path(from: world.playerStart, to: Tile(x: 100, y: 100), world: world))
    }

    func testInvalidTapKeepsExistingRouteAndMovingTapReplansAtNextTile() throws {
        let simulation = Simulation(seed: 10)
        let target = Tile(x: simulation.player.tile.x > 0 ? -2 : 2, y: 0)
        XCTAssertTrue(simulation.movePlayer(to: target))
        simulation.advance(by: 0.1)
        let movement = try XCTUnwrap(simulation.player.movement)
        let route = simulation.player.route
        XCTAssertFalse(simulation.movePlayer(to: simulation.world.gateTile))
        XCTAssertEqual(simulation.player.route, route)
        XCTAssertEqual(simulation.player.movement?.to, movement.to)
        let newTarget = simulation.world.chair.tile
        XCTAssertTrue(simulation.movePlayer(to: newTarget))
        XCTAssertEqual(simulation.player.movement?.to, movement.to)
        XCTAssertEqual(simulation.player.movement?.from, movement.from)
        let expected = Pathfinder.path(from: movement.to, to: newTarget, world: simulation.world)
        XCTAssertEqual(simulation.player.route, expected)
        for _ in 0..<240 { simulation.advance(by: 1.0 / 60) }
        XCTAssertEqual(simulation.player.tile, newTarget)
        XCTAssertNil(simulation.player.movement)
        XCTAssertTrue(simulation.player.route.isEmpty)
    }

    func testThreeStationaryEnemiesBreachInTenSeconds() {
        let world = World(seed: 14)
        let simulation = gateScenario(world)
        var firstDamage: Double?
        var destroyedEvents = 0
        for _ in 0..<660 {
            simulation.advance(by: 1.0 / 60)
            if simulation.world.gate.hp < 90 && firstDamage == nil { firstDamage = simulation.elapsed }
            destroyedEvents += simulation.events.filter { $0 == .gateDestroyed }.count
            if simulation.world.gate.isDestroyed { break }
        }
        XCTAssertTrue(simulation.world.gate.isDestroyed)
        XCTAssertEqual(destroyedEvents, 1)
        XCTAssertEqual(simulation.elapsed, 10, accuracy: 1)
        XCTAssertNotNil(firstDamage)
        XCTAssertTrue(simulation.world.isWalkable(world.gateTile))
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
                        XCTAssertTrue(simulation.world.isWalkable(movement.to))
                        XCTAssertNil(actor.attack)
                        if actor.id != 0 && movement.to == simulation.world.gateTile { sawGateTransit = true }
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
        let hp = simulation.world.gate.hp
        for _ in 0..<90 { simulation.advance(by: 0.2) }
        XCTAssertEqual(simulation.elapsed, time)
        XCTAssertEqual(simulation.world.gate.hp, hp)
        XCTAssertFalse(simulation.movePlayer(to: .zero))
        simulation.isPaused = false
        for _ in 0..<300 { simulation.advance(by: 0.2) }
        XCTAssertTrue(simulation.isGameOver)
        let reset = Simulation(seed: 92)
        XCTAssertEqual(reset.elapsed, 0)
        XCTAssertEqual(reset.player.health.hp, GameBalance.playerHP)
        XCTAssertEqual(reset.world.gate.hp, GameBalance.gateHP)
        XCTAssertFalse(reset.isGameOver)
        XCTAssertFalse(reset.isPaused)
        XCTAssertTrue(reset.events.isEmpty)
    }

    func testPlayerCannotAttackAndEnemiesAreFivePercentFaster() {
        let simulation = Simulation(seed: 1)
        XCTAssertNil(simulation.player.attack)
        XCTAssertEqual(GameBalance.enemyTilesPerSecond / GameBalance.playerTilesPerSecond, 1.05, accuracy: 0.0001)
        for _ in 0..<2000 {
            simulation.advance(by: 1.0 / 60)
            XCTAssertNil(simulation.player.attack)
            XCTAssertTrue(simulation.enemies.allSatisfy { $0.health.hp == $0.health.maximumHP })
        }
    }

    private func gateScenario(_ world: World) -> Simulation {
        let player = Actor(id: 0, kind: .necromancer, tile: .zero,
                           health: Destructible(maximumHP: GameBalance.playerHP, hp: GameBalance.playerHP))
        let enemies = world.gateAttackTiles.enumerated().map { index, tile in
            Actor(id: index + 1, kind: .human, tile: tile, health: Destructible(maximumHP: 20, hp: 20))
        }
        return Simulation(world: world, actors: [player] + enemies)
    }
}
