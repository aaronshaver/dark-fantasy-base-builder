import XCTest
import ImageIO
import FortressArt
import PixelArt

final class FortressArtTests: XCTestCase {
    private let renderer = PixelRenderer(palette: FortressPalette.shared)

    private func pixels(_ state: RecipeState) throws -> [PixelCanvas] {
        try ArtCatalog.frames(for: state).map { try renderer.render($0.root) }
    }

    func testCatalogPreservesGameAssetNamesDimensionsAndPaletteContract() throws {
        var expected: Set<String> = ["AppIcon", "path_dot", "destination", "damage_flash"]
        for kind in ["grass", "wood", "wall", "debris"] { for i in 0..<4 { expected.insert("\(kind)_\(i)") } }
        for kind in ["gate", "chair"] { for i in 0..<3 { expected.insert("\(kind)_\(i)") } }
        for icon in ["heart", "bone", "stone", "moon", "new", "build", "raise", "pause", "play"] { expected.insert("icon_\(icon)") }
        for kind in ["human", "necromancer"] {
            for direction in ["north", "east", "south", "west"] {
                for (action, count) in [("idle", 2), ("walk", 4)] + (kind == "human" ? [("attack", 3)] : []) {
                    for i in 0..<count { expected.insert("\(kind)_\(direction)_\(action)_\(i)") }
                }
            }
        }
        var names: [String] = []
        for definition in ArtCatalog.definitions {
            for frame in try ArtCatalog.frames(for: definition.baseline) {
                names.append(frame.name)
                let canvas = try renderer.render(frame.root)
                XCTAssertEqual(canvas.width, 32); XCTAssertEqual(canvas.height, 32)
                XCTAssertTrue(canvas.pixels.allSatisfy { Int($0) < FortressPalette.shared.entries.count })
            }
        }
        XCTAssertEqual(Set(names), expected); XCTAssertEqual(names.count, 95)
        XCTAssertLessThanOrEqual(FortressPalette.shared.entries.count, 256)
    }

    func testWallCornersStayTransparentAndOpaqueFloorsCoverTheirUnderlayer() throws {
        let wall = ArtCatalog.definitions.first { $0.id == "wall" }!
        let floors = ArtCatalog.definitions.filter { ["grass", "wood"].contains($0.id) }
        var corners: Set<Int> = []
        for (x, y, dx, dy) in [(0, 0, 1, 1), (31, 0, -1, 1), (0, 31, 1, -1), (31, 31, -1, -1)] {
            corners.formUnion([y * 32 + x, y * 32 + x + dx, (y + dy) * 32 + x])
        }
        for image in try pixels(wall.baseline) {
            XCTAssertEqual(Set(image.pixels.indices.filter { image.pixels[$0] == 0 }), corners)
        }
        for floor in floors { for image in try pixels(floor.baseline) { XCTAssertFalse(image.pixels.contains(0)) } }
    }

    func testParameterBoundsRenderAndEveryDeclaredParameterAffectsItsArtwork() throws {
        for definition in ArtCatalog.definitions {
            for parameter in definition.parameters {
                let values: [ParameterValue]
                switch parameter.domain {
                case .integer(let range): values = [.integer(range.lowerBound), .integer(range.upperBound)]
                case .choice(let choices): values = choices.map(ParameterValue.choice)
                }
                var rendered: [[PixelCanvas]] = []
                for value in values {
                    var state = definition.baseline
                    state.parameters[parameter.id] = value
                    rendered.append(try pixels(state))
                }
                XCTAssertTrue(rendered.dropFirst().contains { $0 != rendered[0] }, "Unused parameter: \(definition.id).\(parameter.id)")
            }
        }
    }

    func testAppearanceParametersAreSharedAcrossAnimationFrames() throws {
        for kind in ["human", "necromancer"] {
            let definition = ArtCatalog.definitions.first { $0.id == kind }!
            var state = definition.baseline; state.parameters["headWidth"] = .integer(13)
            let frames = try ArtCatalog.frames(for: state)
            for frame in frames {
                let head = try XCTUnwrap(frame.root.children.first { $0.id == "head" })
                XCTAssertEqual(head.placement.scale.x, 13.0 / 11)
                XCTAssertEqual(head.placement.attachment?.sibling, "body")
                guard case .group(let group) = head else { return XCTFail("Head must group all face details") }
                XCTAssertGreaterThan(try XCTUnwrap(group.children.first { $0.id == "eyes" }).z,
                                     try XCTUnwrap(group.children.first { $0.id == "face" }).z)
            }
        }
    }

    func testSavedRecipesReproducePNGsAndExporterUsesStandardDecodablePNG() throws {
        let first = try ArtExporter.generate(states: ArtCatalog.definitions.map(\.baseline))
        let states = try JSONDecoder().decode([RecipeState].self, from: first.recipes)
        let again = try ArtExporter.generate(states: states)
        XCTAssertEqual(first.pngs, again.pngs); XCTAssertEqual(first.recipes, again.recipes)
        for (name, data) in first.pngs {
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(image.width, name == "AppIcon" ? 1024 : 32)
            XCTAssertEqual(image.height, image.width)
        }
    }

    func testInvalidRecipeSetsAndGeneratorVersionsFail() throws {
        var states = ArtCatalog.definitions.map(\.baseline)
        XCTAssertThrowsError(try ArtExporter.generate(states: Array(states.dropLast())))
        states[1] = states[0]
        XCTAssertThrowsError(try ArtExporter.generate(states: states))
        XCTAssertThrowsError(try ArtCatalog.frames(for: RecipeState(id: "grass", generatorVersion: -1, seed: 0, parameters: [:])))
        XCTAssertThrowsError(try ArtCatalog.frames(for: RecipeState(id: "unknown", generatorVersion: 1, seed: 0, parameters: [:])))
    }
}
