import XCTest
#if SWIFT_PACKAGE
@testable import FortressCore
#endif

final class CorpseTests: XCTestCase {
    private func actor(_ id: Int, _ kind: ActorKind, _ tile: Tile, hp: Int = 20) -> Actor {
        Actor(id: id, kind: kind, tile: tile, health: Destructible(maximumHP: max(20, hp), hp: hp))
    }

    private func advance(_ simulation: Simulation, steps: Int) {
        for _ in 0..<steps { simulation.advance(by: GameBalance.simulationStep) }
    }

    private func duel(victimKind: ActorKind, movingVictim: Bool = false) -> Simulation {
        let player = actor(0, .player, Tile(x: -10, y: -10))
        let killerKind: ActorKind = victimKind == .enemyMeleeSword ? .allySkeletonMelee : .enemyMeleeSword
        let killer = actor(51, killerKind, Tile(x: 0, y: 6))
        var victim = actor(17, victimKind, Tile(x: 1, y: 6), hp: 4)
        if movingVictim {
            victim.movement = Movement(from: victim.tile, to: Tile(x: 2, y: 6), duration: 0.5, elapsed: 0.01)
        }
        return Simulation(world: World(seed: 14), actors: [player, killer, victim])
    }

    func testBothKindsLieStillForFourAndAHalfSecondsThenFadeAndDespawnAtFive() throws {
        for kind in [ActorKind.enemyMeleeSword, .allySkeletonMelee] {
            let simulation = duel(victimKind: kind)
            advance(simulation, steps: 13)
            let dead = try XCTUnwrap(simulation.actors.first { $0.id == 17 })
            XCTAssertFalse(dead.isAlive)
            XCTAssertEqual(try XCTUnwrap(dead.corpse).elapsed, 0)
            XCTAssertEqual(dead.corpse?.opacity, 1)
            XCTAssertTrue(simulation.events.contains(.actorDied(17)))
            XCTAssertFalse(simulation.occupiedTiles(excluding: 51).contains(dead.tile))

            advance(simulation, steps: 270)
            let resting = try XCTUnwrap(simulation.actors.first { $0.id == 17 })
            XCTAssertEqual(try XCTUnwrap(resting.corpse).elapsed, 4.5, accuracy: 0.000001)
            XCTAssertEqual(try XCTUnwrap(resting.corpse).opacity, 1, accuracy: 0.000001)
            XCTAssertEqual(resting.position.x, dead.position.x)
            XCTAssertEqual(resting.position.y, dead.position.y)
            XCTAssertNil(resting.movement)
            XCTAssertNil(resting.attack)

            advance(simulation, steps: 15)
            let fading = try XCTUnwrap(simulation.actors.first { $0.id == 17 })
            XCTAssertEqual(try XCTUnwrap(fading.corpse).opacity, 0.5, accuracy: 0.000001)
            advance(simulation, steps: 14)
            XCTAssertTrue(simulation.actors.contains { $0.id == 17 })
            simulation.advance(by: GameBalance.simulationStep)
            XCTAssertEqual(simulation.events.filter { $0 == .actorDespawned(17) }.count, 1)
            XCTAssertEqual(simulation.actors.map(\.id), [0, 51])
            XCTAssertFalse((simulation.allies + simulation.enemies).contains { $0.id == 17 })
            XCTAssertTrue(simulation.actors.allSatisfy { $0.attack?.target != .actor(17) })
            XCTAssertTrue(simulation.actors.allSatisfy { $0.skeletonBehavior != .attacking(targetID: 17) })

            // Removing earlier array entries must not change the remaining actors' identities or player control.
            XCTAssertTrue(simulation.movePlayer(to: Tile(x: -9, y: -10)))
            var repeatedDespawns = 0
            for _ in 0..<31 {
                simulation.advance(by: GameBalance.simulationStep)
                repeatedDespawns += simulation.events.filter { $0 == .actorDespawned(17) }.count
            }
            XCTAssertEqual(repeatedDespawns, 0)
            XCTAssertEqual(simulation.player.id, 0)
            XCTAssertEqual(simulation.player.tile, Tile(x: -9, y: -10))
        }
    }

    func testDeathDuringMovementKeepsExactPositionThroughoutCorpseLifetime() throws {
        for kind in [ActorKind.enemyMeleeSword, .allySkeletonMelee] {
            let simulation = duel(victimKind: kind, movingVictim: true)
            advance(simulation, steps: 13)
            let corpse = try XCTUnwrap(simulation.actors.first { $0.id == 17 })
            XCTAssertFalse(corpse.isAlive)
            XCTAssertGreaterThan(corpse.position.x, 1)
            XCTAssertLessThan(corpse.position.x, 1.5)
            XCTAssertNil(corpse.movement)
            for _ in 0..<299 {
                simulation.advance(by: GameBalance.simulationStep)
                let current = try XCTUnwrap(simulation.actors.first { $0.id == 17 })
                XCTAssertEqual(current.position.x, corpse.position.x)
                XCTAssertEqual(current.position.y, corpse.position.y)
                XCTAssertEqual(current.facing, corpse.facing)
                XCTAssertEqual(current.animation(at: simulation.elapsed).action, "idle")
                XCTAssertEqual(current.animation(at: simulation.elapsed).frame, 0)
            }
        }
    }

    func testDeadActorsUseOneStaticFrameRegardlessOfClockOrStaleMovementAndAttack() {
        for kind in [ActorKind.enemyMeleeSword, .allySkeletonMelee, .player] {
            var dead = actor(5, kind, .zero, hp: 0)
            dead.movement = Movement(from: .zero, to: Tile(x: 1, y: 0), duration: 1)
            dead.attack = Attack(target: .actor(9), elapsed: 0.3)
            for time in [0, 0.18, 0.7, 1.4, 4.5, 4.75, 100] {
                XCTAssertEqual(dead.animation(at: time).action, "idle")
                XCTAssertEqual(dead.animation(at: time).frame, 0)
            }
        }
    }

    func testLiveAnimationsStillWalkIdleAndUseAttackContactFrames() {
        var living = actor(0, .allySkeletonMelee, .zero)
        XCTAssertEqual(living.animation(at: 0).frame, 0)
        XCTAssertEqual(living.animation(at: 0.7).frame, 1)
        living.movement = Movement(from: .zero, to: Tile(x: 1, y: 0), duration: 1)
        for frame in 0..<4 {
            let pose = living.animation(at: Double(frame) * 0.18 + 0.001)
            XCTAssertEqual(pose.action, "walk")
            XCTAssertEqual(pose.frame, frame)
        }
        living.movement = nil
        for (elapsed, frame) in [(0.0, 0), (0.2, 1), (0.5, 2)] {
            living.attack = Attack(target: .actor(9), elapsed: elapsed)
            XCTAssertEqual(living.animation(at: 12).action, "attack")
            XCTAssertEqual(living.animation(at: 12).frame, frame)
        }
    }

    func testPauseFreezesCorpseTimerAndFadeUntilResume() throws {
        let player = actor(0, .player, .zero)
        var dead = actor(12, .allySkeletonMelee, Tile(x: 8, y: 8), hp: 0)
        dead.corpse = Corpse(position: dead.position, elapsed: 4.75)
        let simulation = Simulation(world: World(seed: 14), actors: [player, dead])
        simulation.isPaused = true
        advance(simulation, steps: 600)
        XCTAssertEqual(simulation.elapsed, 0)
        XCTAssertEqual(try XCTUnwrap(simulation.allies.first?.corpse).elapsed, 4.75)
        XCTAssertEqual(try XCTUnwrap(simulation.allies.first?.corpse).opacity, 0.5)
        simulation.isPaused = false
        advance(simulation, steps: 14)
        XCTAssertEqual(simulation.allies.count, 1)
        simulation.advance(by: GameBalance.simulationStep)
        XCTAssertTrue(simulation.allies.isEmpty)
        XCTAssertEqual(simulation.events, [.actorDespawned(12)])
    }

    func testMultipleDespawnsDoNotShiftAttackTargetsToTheWrongActors() {
        let player = actor(0, .player, Tile(x: -10, y: -10))
        var first = actor(5, .allySkeletonMelee, .zero, hp: 0)
        var second = actor(9, .enemyMeleeSword, Tile(x: 1, y: 0), hp: 0)
        first.corpse = Corpse(position: first.position, elapsed: 5 - GameBalance.simulationStep)
        second.corpse = Corpse(position: second.position, elapsed: 5 - GameBalance.simulationStep)
        let enemy = actor(22, .enemyMeleeSword, Tile(x: 9, y: 6))
        let skeleton = actor(66, .allySkeletonMelee, Tile(x: 8, y: 6))
        let simulation = Simulation(world: World(seed: 14), actors: [player, first, enemy, second, skeleton])
        simulation.advance(by: GameBalance.simulationStep)
        XCTAssertEqual(simulation.actors.map(\.id), [0, 22, 66])
        XCTAssertEqual(simulation.events, [.actorDespawned(5), .actorDespawned(9)])
        advance(simulation, steps: 12)
        XCTAssertEqual(simulation.events, [.actorDamaged(66, 16), .actorDamaged(22, 16)])
        XCTAssertEqual(simulation.player.health.hp, player.health.hp)
    }

    func testExistingCorpsesFinishDespawningAfterGameOverWithoutAdvancingGameplay() {
        let player = actor(0, .player, .zero, hp: 4)
        let enemy = actor(8, .enemyMeleeSword, Tile(x: 0, y: -1))
        var dead = actor(12, .allySkeletonMelee, Tile(x: 8, y: 8), hp: 0)
        dead.corpse = Corpse(position: dead.position, elapsed: 3)
        let simulation = Simulation(world: World(seed: 14), actors: [player, enemy, dead])
        advance(simulation, steps: 13)
        XCTAssertTrue(simulation.isGameOver)
        let time = simulation.elapsed, enemyTile = simulation.enemies[0].tile
        var despawns = 0
        for _ in 0..<300 {
            simulation.advance(by: GameBalance.simulationStep)
            despawns += simulation.events.filter { $0 == .actorDespawned(12) }.count
        }
        XCTAssertEqual(despawns, 1)
        XCTAssertTrue(simulation.allies.isEmpty)
        XCTAssertEqual(simulation.actors.map(\.id), [0, 8])
        XCTAssertEqual(simulation.elapsed, time)
        XCTAssertEqual(simulation.enemies[0].tile, enemyTile)
        XCTAssertEqual(simulation.player.health.hp, 0)
        XCTAssertFalse(simulation.movePlayer(to: Tile(x: 1, y: 0)))
    }
}
