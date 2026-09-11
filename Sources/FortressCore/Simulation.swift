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
    private var random: SeededRandom

    var player: Actor { actors[0] }
    var enemies: [Actor] { actors.filter { $0.affiliation == .hostile } }
    var allies: [Actor] { actors.filter { $0.kind == .allySkeletonMelee } }

    convenience init(seed: UInt64 = UInt64.random(in: .min ... .max), scenario: NewGameScenario = .standard) {
        let world = World(seed: seed, scenario: scenario)
        var actors = [Actor(id: 0, kind: .player, tile: world.playerStart,
                        health: Destructible(maximumHP: GameBalance.playerHP, hp: GameBalance.playerHP))]
        actors += world.enemyStarts.enumerated().map { offset, tile in
            Actor(id: offset + 1, kind: .enemyMeleeSword, tile: tile,
                  health: Destructible(maximumHP: GameBalance.enemyHP, hp: GameBalance.enemyHP))
        }
        let firstAllyID = actors.count
        actors += world.allyStarts.enumerated().map { offset, tile in
            Actor(id: firstAllyID + offset, kind: .allySkeletonMelee, tile: tile,
                  health: Destructible(maximumHP: GameBalance.skeletonHP, hp: GameBalance.skeletonHP))
        }
        self.init(world: world, actors: actors)
    }

    /// Explicit initial state supports deterministic scenarios as well as generated worlds.
    init(world: World, actors: [Actor]) {
        precondition(actors.first?.kind == .player)
        precondition(Set(actors.map(\.id)).count == actors.count)
        self.world = world
        self.actors = actors
        random = SeededRandom(seed: world.seed)
        for index in self.actors.indices where self.actors[index].kind == .allySkeletonMelee {
            self.actors[index].idleDecisionDelay = Double(Int.random(in: GameBalance.skeletonIdleInterval, using: &random))
        }
    }

    @discardableResult
    func movePlayer(to destination: Tile) -> Bool {
        guard !isGameOver, !isPaused else { return false }
        // Every tap supersedes the old command, including taps on invalid terrain.
        stopPlayerRoute()
        guard world.isWalkable(destination, for: player.affiliation) else { return false }
        actors[0].destination = destination
        planPlayerRoute(from: player.movement?.to ?? player.tile)
        return true
    }

    private func planPlayerRoute(from start: Tile) {
        guard let destination = player.destination else { return }
        if let route = Pathfinder.path(from: start, to: destination, world: world, for: player.affiliation,
                                       blocked: occupiedTiles(excluding: 0), preferStaircase: true) {
            actors[0].route = route
            actors[0].resetPathRetry()
        } else {
            actors[0].route = []
            actors[0].recordPathFailure()
            if player.failedPathSearches >= 5 { stopPlayerRoute() }
        }
    }

    func advance(by delta: Double) {
        events.removeAll(keepingCapacity: true)
        guard !isPaused, delta.isFinite, delta > 0 else { return }
        // Limit catch-up after interruptions; the app also pauses when backgrounded.
        accumulator += min(delta, 0.25)
        while accumulator + 0.0000001 >= GameBalance.simulationStep {
            accumulator -= GameBalance.simulationStep
            if isGameOver {
                // Gameplay stays frozen after player death; existing corpses still finish despawning.
                advanceCorpses(GameBalance.simulationStep)
            } else {
                step(GameBalance.simulationStep)
            }
        }
    }

    private func step(_ delta: Double) {
        elapsed += delta
        advanceCorpses(delta)
        // All tile arrivals resolve before any unit may reserve its next tile.
        for index in actors.indices where actors[index].isAlive {
            actors[index].cooldown = max(0, actors[index].cooldown - delta)
            actors[index].decisionDelay = max(0, actors[index].decisionDelay - delta)
            actors[index].idleDecisionDelay = max(0, actors[index].idleDecisionDelay - delta)
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
        for index in actors.indices {
            switch actors[index].kind {
            case .player: break
            case .enemyMeleeSword: updateEnemy(index)
            case .allySkeletonMelee: updateSkeleton(index)
            }
            if isGameOver { return }
        }
    }

    private func advanceCorpses(_ delta: Double) {
        for index in actors.indices where !actors[index].isAlive && actors[index].kind != .player {
            actors[index].corpse?.elapsed += delta
        }
        // Remove only between actor-update loops, so array indices remain valid during combat.
        actors.removeAll { actor in
            guard actor.kind != .player, actor.corpse?.hasExpired == true else { return false }
            events.append(.actorDespawned(actor.id))
            return true
        }
    }

    func occupiedTiles(excluding id: Int) -> Set<Tile> {
        actors.filter { $0.id != id && $0.isAlive }.reduce(into: Set<Tile>()) { $0.formUnion($1.reservedTiles) }
    }

    private func beginMove(_ index: Int, to tile: Tile) -> Bool {
        guard actors[index].isAlive, actors[index].movement == nil, actors[index].attack == nil,
              actors[index].tile.distance(to: tile) == 1, world.isWalkable(tile, for: actors[index].affiliation),
              !occupiedTiles(excluding: actors[index].id).contains(tile) else { return false }
        let speed = actors[index].kind.tilesPerSecond
        actors[index].facing = .facing(from: actors[index].tile, to: tile)
        actors[index].movement = Movement(from: actors[index].tile, to: tile, duration: 1 / speed)
        return true
    }

    private func updatePlayer() {
        guard player.movement == nil, let destination = player.destination else { return }
        if player.tile == destination {
            stopPlayerRoute()
            return
        }
        let blocked = occupiedTiles(excluding: 0)
        if player.route.isEmpty || player.route.contains(where: {
            blocked.contains($0) || !world.isWalkable($0, for: player.affiliation)
        }) {
            actors[0].route = []
            guard player.decisionDelay <= 0.0000001 else { return }
            planPlayerRoute(from: player.tile)
        }
        if let next = player.route.first, beginMove(0, to: next) { actors[0].route.removeFirst() }
    }

    private func stopPlayerRoute() {
        actors[0].route = []
        actors[0].destination = nil
        actors[0].resetPathRetry()
    }

    /// All targetable destructibles enter the same affiliation-based selection path.
    private struct CombatTarget {
        let reference: AttackTarget
        let tile: Tile
        let attackTiles: [Tile]
    }

    private func opponents(to index: Int, within radius: Int? = nil) -> [CombatTarget] {
        let source = actors[index]
        var targets = actors.filter { $0.isAlive && $0.affiliation != source.affiliation }.map {
            CombatTarget(reference: .actor($0.id), tile: $0.movement?.to ?? $0.tile,
                         attackTiles: ($0.movement?.to ?? $0.tile).neighbors)
        }
        targets += world.doors.filter { !$0.health.isDestroyed && $0.affiliation != source.affiliation }.map {
            CombatTarget(reference: .door($0.tile), tile: $0.tile, attackTiles: $0.attackTiles)
        }
        return targets.enumerated().filter {
            radius == nil || source.tile.distance(to: $0.element.tile) <= radius!
        }.sorted {
            let a = source.tile.distance(to: $0.element.tile), b = source.tile.distance(to: $1.element.tile)
            return a == b ? $0.offset < $1.offset : a < b
        }.map(\.element)
    }

    private func updateEnemy(_ index: Int) {
        guard actors[index].isAlive, actors[index].movement == nil, actors[index].attack == nil,
              actors[index].decisionDelay <= 0.0000001 else { return }
        let targets = opponents(to: index)
        guard !targets.isEmpty else { return }
        for target in targets {
            if pursue(index, target: target) { return }
        }
        actors[index].recordPathFailure()
    }

    private func targetIsAlive(_ target: AttackTarget) -> Bool {
        switch target {
        case .actor(let id): return actors.contains { $0.id == id && $0.isAlive }
        case .door(let tile): return world.door(at: tile).map { !$0.health.isDestroyed } ?? false
        }
    }

    private func updateSkeleton(_ index: Int) {
        guard actors[index].isAlive else { return }
        if actors[index].mustWanderBeforeSensing {
            guard actors[index].movement == nil, actors[index].attack == nil else { return }
            // Suppress sensing until exactly one wander choice completes or fails.
            if actors[index].destination != nil && actors[index].route.isEmpty {
                actors[index].destination = nil
                actors[index].mustWanderBeforeSensing = false
                return
            }
            let attempted = actors[index].destination != nil || actors[index].idleDecisionDelay <= 0
            wander(index)
            if attempted && actors[index].destination == nil {
                actors[index].mustWanderBeforeSensing = false
            }
            return
        }
        if let selected = actors[index].skeletonBehavior.target,
           targetIsAlive(selected), (actors[index].movement != nil || actors[index].attack != nil
                                    || actors[index].decisionDelay > 0.0000001) { return }
        let allTargets = opponents(to: index)
        if let selected = actors[index].skeletonBehavior.target,
           !allTargets.contains(where: { $0.reference == selected }) {
            actors[index].skeletonBehavior = .idling
            actors[index].attack = nil
            actors[index].resetPathRetry()
        }
        if actors[index].skeletonBehavior == .idling,
           let target = allTargets.first(where: { actors[index].tile.distance(to: $0.tile) <= GameBalance.skeletonSenseRadius }) {
            actors[index].skeletonBehavior = .attacking(target: target.reference)
            actors[index].route = []
            actors[index].destination = nil
            actors[index].resetPathRetry()
        }
        guard actors[index].movement == nil, actors[index].attack == nil else { return }
        guard let selected = actors[index].skeletonBehavior.target else { wander(index); return }
        guard actors[index].decisionDelay <= 0.0000001 else { return }
        // Keep a successfully chosen target, even after it leaves sensing range.
        var candidates = allTargets.filter { $0.reference == selected }
        candidates += allTargets.filter {
            $0.reference != selected && actors[index].tile.distance(to: $0.tile) <= GameBalance.skeletonSenseRadius
        }.prefix(3)
        for target in candidates {
            if pursue(index, target: target) {
                actors[index].skeletonBehavior = .attacking(target: target.reference)
                return
            }
        }
        actors[index].recordPathFailure()
        if actors[index].failedPathSearches >= 5 {
            actors[index].resetPathRetry()
            actors[index].skeletonBehavior = .idling
            actors[index].mustWanderBeforeSensing = true
            actors[index].route = []
            actors[index].destination = nil
            actors[index].idleDecisionDelay = Double(Int.random(in: GameBalance.skeletonIdleInterval, using: &random))
        }
    }

    private func wander(_ index: Int) {
        if actors[index].route.isEmpty {
            actors[index].destination = nil
            guard actors[index].idleDecisionDelay <= 0 else { return }
            actors[index].idleDecisionDelay = Double(Int.random(in: GameBalance.skeletonIdleInterval, using: &random))
            let radius = GameBalance.skeletonWanderRadius
            let offsets = (-radius...radius).flatMap { y in
                (-radius...radius).map { Tile(x: $0, y: y) }
            }.filter { $0 != .zero && $0.distance(to: .zero) <= radius }
            let destination = actors[index].tile + offsets.randomElement(using: &random)!
            // Sample before checking access: an inaccessible choice consumes this turn.
            guard let route = Pathfinder.path(from: actors[index].tile, to: destination, world: world,
                                               for: .friendly, blocked: occupiedTiles(excluding: actors[index].id)) else { return }
            actors[index].destination = destination
            actors[index].route = route
        }
        if let next = actors[index].route.first {
            if beginMove(index, to: next) { actors[index].route.removeFirst() }
            else {
                actors[index].route = []
                actors[index].destination = nil
            }
        }
    }

    /// Returns success only for an attack position or a complete route to one.
    private func pursue(_ index: Int, target: CombatTarget) -> Bool {
        let inRange: Bool
        switch target.reference {
        case .actor(let id):
            inRange = actors.firstIndex { $0.id == id }.map { inMeleeRange(index, targetIndex: $0) } ?? false
        case .door:
            inRange = target.attackTiles.contains(actors[index].tile)
        }
        if inRange {
            actors[index].resetPathRetry()
            beginAttack(index, target: target.reference, tile: target.tile)
            return true
        }
        let blocked = occupiedTiles(excluding: actors[index].id)
        guard let route = Pathfinder.path(from: actors[index].tile, toAny: target.attackTiles,
                                           world: world, for: actors[index].affiliation, blocked: blocked),
              let next = route.first, beginMove(index, to: next) else { return false }
        actors[index].resetPathRetry()
        return true
    }

    private func beginAttack(_ index: Int, target: AttackTarget, tile: Tile) {
        guard !isGameOver, actors[index].isAlive, actors[index].movement == nil,
              actors[index].attack == nil, actors[index].cooldown <= 0 else { return }
        switch target {
        case .actor(let id):
            guard let targetIndex = actors.firstIndex(where: { $0.id == id && $0.isAlive }),
                  actors[targetIndex].affiliation != actors[index].affiliation,
                  inMeleeRange(index, targetIndex: targetIndex) else { return }
        case .door(let tile):
            guard let door = world.door(at: tile), !door.health.isDestroyed,
                  door.affiliation != actors[index].affiliation,
                  door.attackTiles.contains(actors[index].tile) else { return }
        }
        actors[index].facing = .facing(from: actors[index].tile, to: tile)
        actors[index].attack = Attack(target: target)
        actors[index].cooldown = GameBalance.attackInterval
    }

    private func advanceAttack(_ index: Int, delta: Double) {
        guard actors[index].isAlive, var attack = actors[index].attack else { return }
        attack.elapsed += delta
        if attack.hasReachedContact && !attack.delivered {
            // Resolve exactly once, including misses. Recovery never queues another hit.
            attack.delivered = true
            switch attack.target {
            case .door(let tile):
                if let door = world.door(at: tile), !door.health.isDestroyed,
                   door.affiliation != actors[index].affiliation,
                   door.attackTiles.contains(actors[index].tile),
                   let damaged = world.damageDoor(at: tile, amount: GameBalance.gateDamage, by: actors[index].affiliation) {
                    events.append(.doorDamaged(tile, damaged.health.hp))
                    if damaged.health.isDestroyed { events.append(.doorDestroyed(tile)) }
                }
            case .actor(let id):
                if let targetIndex = actors.firstIndex(where: { $0.id == id && $0.isAlive }),
                   actors[targetIndex].affiliation != actors[index].affiliation,
                   inMeleeRange(index, targetIndex: targetIndex, reach: actors[index].kind.meleeReach) {
                    damageActor(targetIndex, amount: actors[index].kind.meleeDamage)
                }
            }
        }
        // Preserve the fatal swing's contact pose when the game freezes.
        actors[index].attack = !isGameOver && attack.elapsed >= GameBalance.attackInterval ? nil : attack
    }

    private func damageActor(_ index: Int, amount: Int) {
        actors[index].health.damage(amount)
        if actors[index].kind == .player {
            events.append(.playerDamaged(player.health.hp))
            if !player.isAlive { endGame() }
        } else {
            events.append(.actorDamaged(actors[index].id, actors[index].health.hp))
            if !actors[index].isAlive {
                actors[index].corpse = Corpse(position: actors[index].position)
                actors[index].movement = nil
                actors[index].attack = nil
                actors[index].route = []
                actors[index].destination = nil
                actors[index].skeletonBehavior = .idling
                events.append(.actorDied(actors[index].id))
            }
        }
    }

    private func inMeleeRange(_ index: Int, targetIndex: Int, reach: Double = GameBalance.meleeEngagementRange) -> Bool {
        let target = actors[targetIndex].position
        let source = actors[index].tile
        return abs(target.x - Double(source.x)) + abs(target.y - Double(source.y)) <= reach + 0.0000001
    }

    private func endGame() {
        isGameOver = true
        actors[0].resetPathRetry()
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
