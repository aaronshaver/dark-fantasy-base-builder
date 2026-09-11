import Foundation
import PixelArt

public struct ArtworkImage: Equatable {
    public let name: String
    public let png: Data
}

/// A complete entity, including every direction and animation frame, is the unit of acceptance.
public struct RenderedArtwork: Equatable {
    public let state: RecipeState
    public let frames: [ArtworkImage]
    public var pngs: [String: Data] { Dictionary(uniqueKeysWithValues: frames.map { ($0.name, $0.png) }) }
}

public struct GeneratedArtwork {
    /// PNGs keyed by their existing asset names. AppIcon is the only 1024×1024 image.
    public let pngs: [String: Data]
    public let recipes: Data
    public let palette: Data
}

public enum ArtExporter {
    public static func render(_ state: RecipeState) throws -> RenderedArtwork {
        guard let definition = ArtCatalog.definitions.first(where: { $0.id == state.id }) else {
            throw ArtError.invalid("Unknown artwork: \(state.id)")
        }
        let values = try ParameterValues(schema: definition.parameters, overrides: state.parameters)
        let resolved = RecipeState(id: state.id, generatorVersion: state.generatorVersion,
                                   seed: state.seed, parameters: values.values)
        let renderer = PixelRenderer(palette: FortressPalette.shared)
        let frames = try ArtCatalog.frames(for: resolved).map { frame in
            let pixels = try renderer.render(frame.root)
            let icon = frame.name == "AppIcon"
            let png = try IndexedPNG.encode(icon ? pixels.enlarged(by: 32) : pixels,
                                            palette: FortressPalette.shared, transparent: !icon)
            return ArtworkImage(name: frame.name, png: png)
        }
        return RenderedArtwork(state: resolved, frames: frames)
    }

    public static func generate(states: [RecipeState]) throws -> GeneratedArtwork {
        guard Set(states.map(\.id)) == Set(ArtCatalog.definitions.map(\.id)),
              states.count == ArtCatalog.definitions.count else { throw ArtError.invalid("Incomplete or duplicate recipe set") }
        let palette = FortressPalette.shared
        var pngs: [String: Data] = [:]
        var accepted: [RecipeState] = []
        for definition in ArtCatalog.definitions {
            let state = states.first { $0.id == definition.id }!
            let artwork = try render(state)
            for frame in artwork.frames {
                guard pngs[frame.name] == nil else { throw ArtError.invalid("Duplicate asset: \(frame.name)") }
                pngs[frame.name] = frame.png
            }
            accepted.append(artwork.state)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return GeneratedArtwork(pngs: pngs, recipes: try encoder.encode(accepted), palette: try palette.jsonData())
    }
}
