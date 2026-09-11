import Foundation
import PixelArt

/// Repository persistence for developer artwork. It is never read by gameplay at startup.
public struct ArtworkStore {
    public let root: URL
    private let writeFile: (Data, URL) throws -> Void

    public init(root: URL) {
        self.init(root: root, writeFile: { try $0.write(to: $1, options: .atomic) })
    }

    // Injection lets tests exercise write failures without touching the real repository.
    init(root: URL, writeFile: @escaping (Data, URL) throws -> Void) {
        self.root = root
        self.writeFile = writeFile
    }

    public func load(id: String) throws -> RenderedArtwork {
        let states = try readStates()
        guard let state = states.first(where: { $0.id == id }) else { throw ArtError.invalid("Unknown artwork: \(id)") }
        let frames = try ArtCatalog.frames(for: state).map {
            ArtworkImage(name: $0.name, png: try Data(contentsOf: imageURL($0.name)))
        }
        return RenderedArtwork(state: state, frames: frames)
    }

    /// Writes the exact previewed PNGs. All frames succeed together; normal write failures restore prior files.
    public func save(_ candidate: RenderedArtwork, replacing accepted: RenderedArtwork) throws {
        guard candidate.state.id == accepted.state.id else { throw ArtError.invalid("Candidate belongs to another artwork") }
        var states = try readStates()
        let latest = try load(id: accepted.state.id)
        guard latest == accepted else { throw ArtError.invalid("This artwork changed on disk. Select it again before saving.") }
        let expected = try ArtCatalog.frames(for: candidate.state).map(\.name)
        guard candidate.frames.map(\.name) == expected else { throw ArtError.invalid("Save requires the entire artwork frame set") }
        guard let index = states.firstIndex(where: { $0.id == candidate.state.id }) else { throw ArtError.invalid("Missing accepted recipe") }
        states[index] = candidate.state
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let writes = candidate.frames.map { (imageURL($0.name), $0.png) } + [(recipeURL, try encoder.encode(states))]
        try commit(writes)
    }

    public func regenerate() throws -> Int {
        let output = try ArtExporter.generate(states: readStates())
        let writes = output.pngs.sorted(by: { $0.key < $1.key }).map { (imageURL($0.key), $0.value) }
            + [(root.appendingPathComponent("DarkFortress/Resources/palette.json"), output.palette), (recipeURL, output.recipes)]
        try commit(writes)
        return output.pngs.count - 1
    }

    private var recipeURL: URL { root.appendingPathComponent("Art/recipes.json") }
    private func imageURL(_ name: String) -> URL {
        if name == "AppIcon" { return root.appendingPathComponent("DarkFortress/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png") }
        return root.appendingPathComponent("DarkFortress/Resources/Pixel.atlas/" + name + ".png")
    }

    private func readStates() throws -> [RecipeState] {
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("DarkFortress.xcodeproj/project.pbxproj").path) else {
            throw ArtError.invalid("Project directory not found: \(root.path)")
        }
        let saved = FileManager.default.fileExists(atPath: recipeURL.path)
            ? try JSONDecoder().decode([RecipeState].self, from: Data(contentsOf: recipeURL)) : []
        guard Set(saved.map(\.id)).count == saved.count,
              Set(saved.map(\.id)).isSubset(of: Set(ArtCatalog.definitions.map(\.id))) else {
            throw ArtError.invalid("Duplicate or unknown artwork recipes")
        }
        return try ArtCatalog.definitions.map { definition in
            let state = saved.first { $0.id == definition.id } ?? definition.baseline
            guard state.generatorVersion == ArtCatalog.generatorVersion else { throw ArtError.invalid("Unsupported generator version: \(state.id)") }
            let values = try ParameterValues(schema: definition.parameters, overrides: state.parameters)
            return RecipeState(id: state.id, generatorVersion: state.generatorVersion, seed: state.seed, parameters: values.values)
        }
    }

    private func commit(_ writes: [(URL, Data)]) throws {
        let files = FileManager.default
        // Read every original first, so a read/permission error cannot leave a partly accepted entity.
        let originals: [(URL, Data?)] = try writes.map { url, _ in
            try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            return (url, files.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil)
        }
        var attempted = 0
        do {
            for (url, data) in writes {
                attempted += 1
                try writeFile(data, url)
            }
        } catch {
            let originalError = error
            var restorationErrors: [String] = []
            for (url, original) in originals.prefix(attempted).reversed() {
                do {
                    if let original { try writeFile(original, url) }
                    else if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
                } catch { restorationErrors.append("\(url.path): \(error)") }
            }
            if !restorationErrors.isEmpty {
                throw ArtError.invalid("Save failed: \(originalError). Could not restore: \(restorationErrors.joined(separator: "; "))")
            }
            throw originalError
        }
    }
}
