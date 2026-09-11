import XCTest
import PixelArt
@testable import FortressArt

final class ArtworkWorkflowTests: XCTestCase {
    private func baseline(_ id: String) -> RecipeState { ArtCatalog.definitions.first { $0.id == id }!.baseline }
    private func candidate(for artwork: RenderedArtwork, seed: UInt64 = 9) throws -> RenderedArtwork {
        var session = ArtworkSession(accepted: artwork)
        try session.generate(intensity: 1, seed: seed)
        return try XCTUnwrap(session.candidate)
    }

    func testCandidateContainsAllEnemyFramesAndGenerationDoesNotAcceptIt() throws {
        let original = try ArtExporter.render(baseline("enemy_melee_sword"))
        var session = ArtworkSession(accepted: original)
        try session.generate(intensity: 0.25, seed: 14)
        let candidate = try XCTUnwrap(session.candidate)
        XCTAssertEqual(candidate.frames.count, 36)
        XCTAssertEqual(candidate.frames.map(\.name), original.frames.map(\.name))
        XCTAssertEqual(candidate.state.seed, original.state.seed)
        XCTAssertNotEqual(candidate.frames, original.frames)
        XCTAssertEqual(session.accepted, original)
        let repeatCandidate = candidate
        var repeated = ArtworkSession(accepted: original)
        try repeated.generate(intensity: 0.25, seed: 14)
        XCTAssertEqual(repeated.candidate, repeatCandidate)
        session.acceptSavedCandidate()
        XCTAssertEqual(session.accepted, candidate); XCTAssertNil(session.candidate)
        try session.generate(intensity: 0.25, seed: 15)
        XCTAssertEqual(session.accepted, candidate)
        XCTAssertEqual(session.candidate?.state.seed, candidate.state.seed)
    }

    func testZeroIntensityAndBadInputKeepTheAcceptedSet() throws {
        let artwork = try ArtExporter.render(baseline("floor_wood"))
        var session = ArtworkSession(accepted: artwork)
        for intensity in [0, -1, 2, Double.nan] { XCTAssertThrowsError(try session.generate(intensity: intensity, seed: 0)) }
        XCTAssertEqual(session.accepted, artwork); XCTAssertNil(session.candidate)
    }

    func testAllArtworkKindsGenerateCompleteReproducibleCandidates() throws {
        for definition in ArtCatalog.definitions {
            let accepted = try ArtExporter.render(definition.baseline)
            let result = try candidate(for: accepted)
            XCTAssertEqual(result.frames.map(\.name), accepted.frames.map(\.name))
            XCTAssertEqual(try ArtExporter.render(result.state), result)
            XCTAssertNotEqual(result.frames, accepted.frames)
        }
    }

    func testOnePercentGeneratesACompleteChangedCandidateForEveryArtworkKind() throws {
        for definition in ArtCatalog.definitions {
            let accepted = try ArtExporter.render(definition.baseline)
            var session = ArtworkSession(accepted: accepted)
            try session.generate(intensity: 0.01, seed: 14)
            let candidate = try XCTUnwrap(session.candidate, definition.name)
            XCTAssertEqual(candidate.frames.map(\.name), accepted.frames.map(\.name))
            XCTAssertNotEqual(candidate.frames, accepted.frames, definition.name)
            XCTAssertEqual(session.accepted, accepted)
        }
    }

    func testSavePersistsExactEntireSetAndLeavesUnrelatedArtAlone() throws {
        let root = try fixture()
        let store = ArtworkStore(root: root)
        let original = try store.load(id: "enemy_melee_sword"), wood = try store.load(id: "floor_wood")
        let before = try snapshot(root)
        let next = try candidate(for: original)
        XCTAssertEqual(try snapshot(root), before, "Generating must not write files")
        try store.save(next, replacing: original)
        XCTAssertEqual(try ArtworkStore(root: root).load(id: "enemy_melee_sword"), next)
        XCTAssertEqual(try store.load(id: "floor_wood"), wood)
        XCTAssertEqual(try ArtExporter.render(next.state), next)
    }

    func testSavePreservesOtherRecentlySavedRecipesAndRejectsStaleCandidates() throws {
        let root = try fixture(), store = ArtworkStore(root: root)
        let swordEnemy = try store.load(id: "enemy_melee_sword"), wood = try store.load(id: "floor_wood")
        let newSwordEnemy = try candidate(for: swordEnemy), newWood = try candidate(for: wood)
        try store.save(newWood, replacing: wood)
        try store.save(newSwordEnemy, replacing: swordEnemy)
        XCTAssertEqual(try store.load(id: "floor_wood"), newWood)
        let after = try snapshot(root)
        XCTAssertThrowsError(try store.save(newSwordEnemy, replacing: swordEnemy))
        XCTAssertEqual(try snapshot(root), after)
    }

    func testPartialFrameSetsAndWrongEntityCannotBeSaved() throws {
        let root = try fixture(), store = ArtworkStore(root: root)
        let swordEnemy = try store.load(id: "enemy_melee_sword"), wood = try store.load(id: "floor_wood")
        let next = try candidate(for: swordEnemy)
        let partial = RenderedArtwork(state: next.state, frames: Array(next.frames.dropLast()))
        let before = try snapshot(root)
        XCTAssertThrowsError(try store.save(partial, replacing: swordEnemy))
        XCTAssertThrowsError(try store.save(next, replacing: wood))
        XCTAssertEqual(try snapshot(root), before)
    }

    func testWriteFailureRestoresEveryPNGAndRecipe() throws {
        let root = try fixture(), store = ArtworkStore(root: root)
        let accepted = try store.load(id: "enemy_melee_sword"), next = try candidate(for: accepted)
        let before = try snapshot(root)
        for failureIndex in [3, 37] { // Mid-animation and final recipe write.
            var count = 0
            let failing = ArtworkStore(root: root) { data, url in
                count += 1
                if count == failureIndex { throw CocoaError(.fileWriteNoPermission) }
                try data.write(to: url, options: .atomic)
            }
            XCTAssertThrowsError(try failing.save(next, replacing: accepted))
            XCTAssertEqual(try snapshot(root), before)
            XCTAssertEqual(try store.load(id: "enemy_melee_sword"), accepted)
        }
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("artwork-test-" + UUID().uuidString)
        let files = FileManager.default
        try files.createDirectory(at: root.appendingPathComponent("DarkFortress.xcodeproj"), withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent("DarkFortress.xcodeproj/project.pbxproj"))
        try files.createDirectory(at: root.appendingPathComponent("DarkFortress/Resources/Pixel.atlas"), withIntermediateDirectories: true)
        try files.createDirectory(at: root.appendingPathComponent("Art"), withIntermediateDirectories: true)
        try JSONEncoder().encode(ArtCatalog.definitions.map(\.baseline)).write(to: root.appendingPathComponent("Art/recipes.json"))
        for id in ["enemy_melee_sword", "floor_wood"] {
            for frame in try ArtExporter.render(baseline(id)).frames {
                try frame.png.write(to: root.appendingPathComponent("DarkFortress/Resources/Pixel.atlas/" + frame.name + ".png"))
            }
        }
        addTeardownBlock { try files.removeItem(at: root) }
        return root
    }

    private func snapshot(_ root: URL) throws -> [String: Data] {
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]))
        var result: [String: Data] = [:]
        for case let url as URL in enumerator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            result[url.path] = try Data(contentsOf: url)
        }
        return result
    }
}
