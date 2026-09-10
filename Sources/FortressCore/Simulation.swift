import Foundation

/// Game rules are independent of SpriteKit. Rendering never decides movement or damage.
final class Simulation {
    private(set) var world: World
    private(set) var actors: [Actor]
    private(set) var elapsed: Double = 0
    private(set) var isGameOver = false
    private(set) var events: [GameEvent] = []
    var isPaused = false
    private var accumulator: Double = 0

    var player: Actor { actors[0] }
    var enemies: ArraySlice<Actor> { actors.dropFirst() }

    convenience init(seed: UInt64 = UInt64.random(in: .min ... .max)) {
        let world = World(seed: seed)
        var actors = [Actor(id: 0, kind: .necromancer, tile: world.playerStart,
                        health: Destructible(maximumHP: GameBalance.playerHP, hp: GameBalance.playerHP))]
        actors += world.enemyStarts.enumerated().map { offset, tile in
            Actor(id: offset + 1, kind: .human, tile: tile, health: Destructible(maximumHP: 20, hp: 20))
        }
        self.init(world: world, actors: actors)
    }

    /// Explicit initial state supports deterministic scenarios as well as generated worlds.
    init(world: World, actors: [Actor]) {
        precondition(actors.first?.kind == .necromancer)
        precondition(Set(actors.map(\.id)).count == actors.count)
        self.world = world
        self.actors = actors
    }

    @discardableResult
    func movePlayer(to destination: Tile) -> Bool {
        guard !isGameOver, !isPaused, world.isWalkable(destination) else { return false }
        let start = player.movement?.to ?? player.tile
        let blocked = occupiedTiles(excluding: 0)
        guard let route = Pathfinder.path(from: start, to: destination, world: world, blocked: blocked) else { return false }
        actors[0].route = route
        actors[0].destination = destination
        return true
    }

    func advance(by delta: Double) {
        events.removeAll(keepingCapacity: true)
        guard !isPaused, !isGameOver, delta.isFinite, delta > 0 else { return }
        // Limit catch-up after interruptions; the app also pauses when backgrounded.
        accumulator += min(delta, 0.25)
        while accumulator + 0.0000001 >= GameBalance.simulationStep && !isGameOver {
            accumulator -= GameBalance.simulationStep
            step(GameBalance.simulationStep)
        }
    }

    private func step(_ delta: Double) {
        elapsed += delta
        // All tile arrivals resolve before any unit may reserve its next tile.
        for index in actors.indices {
            actors[index].cooldown = max(0, actors[index].cooldown - delta)
            actors[index].decisionDelay = max(0, actors[index].decisionDelay - delta)
            if var movement = actors[index].movement {
                movement.elapsed += delta
                if movement.elapsed + 0.0000001 >= movement.duration {
                    actors[index].tile = movement.to
                    actors[index].movement = nil
                } else {
                    actors[index].movement = movement
                }
            }
        }
        for index in actors.indices {
            advanceAttack(index, delta: delta)
            if isGameOver { return }
        }
        updatePlayer()
        for index in actors.indices.dropFirst() {
            updateEnemy(index)
            if isGameOver { return }
        }
    }

    func occupiedTiles(excluding id: Int) -> Set<Tile> {
        actors.filter { $0.id != id && $0.isAlive }.reduce(into: Set<Tile>()) { $0.formUnion($1.reservedTiles) }
    }

    private func beginMove(_ index: Int, to tile: Tile) -> Bool {
        guard actors[index].movement == nil, actors[index].attack == nil,
              actors[index].tile.distance(to: tile) == 1, world.isWalkable(tile),
              !occupiedTiles(excluding: actors[index].id).contains(tile) else { return false }
        let speed = index == 0 ? GameBalance.playerTilesPerSecond : GameBalance.enemyTilesPerSecond
        actors[index].facing = .facing(from: actors[index].tile, to: tile)
        actors[index].movement = Movement(from: actors[index].tile, to: tile, duration: 1 / speed)
        return true
    }

    private func updatePlayer() {
        guard player.movement == nil, let destination = player.destination else { return }
        if player.tile == destination {
            actors[0].route = []
            actors[0].destination = nil
            return
        }
        let blocked = occupiedTiles(excluding: 0)
        // Replan when units obstruct the route. Stop on a tile if no safe route remains.
        if player.route.isEmpty || player.route.contains(where: { blocked.contains($0) }) {
            guard let route = Pathfinder.path(from: player.tile, to: destination, world: world, blocked: blocked) else {
                actors[0].route = []
                actors[0].destination = nil
                return
            }
            actors[0].route = route
        }
        if let next = player.route.first, beginMove(0, to: next) { actors[0].route.removeFirst() }
    }

    private func updateEnemy(_ index: Int) {
        guard actors[index].isAlive, actors[index].movement == nil, actors[index].attack == nil else { return }
        let tile = actors[index].tile
        let goals: [Tile]
        if !world.gate.isDestroyed {
            if world.gateAttackTiles.contains(tile) {
                beginAttack(index, target: .gate, tile: world.gateTile)
                return
            }
            goals = world.gateAttackTiles
        } else {
            if inMeleeRange(index) {
                beginAttack(index, target: .player, tile: player.tile)
                return
            }
            let target = player.movement?.to ?? player.tile
            goals = target.neighbors.filter { world.isWalkable($0) }
        }
        guard actors[index].decisionDelay <= 0 else { return }
        actors[index].decisionDelay = 0.18
        let blocked = occupiedTiles(excluding: actors[index].id)
        let routes = goals.compactMap { Pathfinder.path(from: tile, to: $0, world: world, blocked: blocked) }
        if let route = routes.filter({ !$0.isEmpty }).min(by: { $0.count < $1.count }), let next = route.first {
            _ = beginMove(index, to: next)
        }
    }

    private func beginAttack(_ index: Int, target: AttackTarget, tile: Tile) {
        guard !isGameOver, actors[index].isAlive, actors[index].movement == nil,
              actors[index].attack == nil, actors[index].cooldown <= 0 else { return }
        if target == .player {
            guard player.isAlive, inMeleeRange(index) else { return }
        }
        actors[index].facing = .facing(from: actors[index].tile, to: tile)
        actors[index].attack = Attack(target: target)
        actors[index].cooldown = GameBalance.attackInterval
    }

    private func advanceAttack(_ index: Int, delta: Double) {
        guard var attack = actors[index].attack else { return }
        attack.elapsed += delta
        if attack.hasReachedContact && !attack.delivered {
            // Resolve exactly once, including misses. Recovery never queues another hit.
            attack.delivered = true
            switch attack.target {
            case .gate:
                if !world.gate.isDestroyed && world.gateAttackTiles.contains(actors[index].tile) {
                    world.gate.damage(GameBalance.gateDamage)
                    events.append(.gateDamaged(world.gate.hp))
                    if world.gate.isDestroyed { events.append(.gateDestroyed) }
                }
            case .player:
                if player.isAlive && inMeleeRange(index, reach: GameBalance.swordReach) {
                    actors[0].health.damage(GameBalance.playerDamage)
                    events.append(.playerDamaged(player.health.hp))
                    if !player.isAlive { endGame() }
                }
            }
        }
        // Preserve the fatal swing's contact pose when the game freezes.
        actors[index].attack = !isGameOver && attack.elapsed >= GameBalance.attackInterval ? nil : attack
    }

    private func inMeleeRange(_ index: Int, reach: Double = GameBalance.meleeEngagementRange) -> Bool {
        let target = player.position
        let source = actors[index].tile
        return abs(target.x - Double(source.x)) + abs(target.y - Double(source.y)) <= reach + 0.0000001
    }

    private func endGame() {
        isGameOver = true
        events.append(.playerDied)
        // Resolve in-flight units onto their exclusively reserved destination before freezing.
        for index in actors.indices {
            if let movement = actors[index].movement { actors[index].tile = movement.to }
            actors[index].movement = nil
            actors[index].route = []
            actors[index].destination = nil
            actors[index].attack = nil
        }
    }
}
