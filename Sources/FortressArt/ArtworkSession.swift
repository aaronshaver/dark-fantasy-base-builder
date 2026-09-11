import PixelArt

/// Preview state only. Generating or discarding a candidate never writes files or changes accepted art.
public struct ArtworkSession {
    public private(set) var accepted: RenderedArtwork
    public private(set) var candidate: RenderedArtwork?
    public private(set) var candidateIntensity: Double?

    public init(accepted: RenderedArtwork) { self.accepted = accepted }

    public mutating func generate(intensity: Double, seed: UInt64) throws {
        guard intensity != 0 else { throw ArtError.invalid("Increase intensity to generate a variation.") }
        guard let definition = ArtCatalog.definitions.first(where: { $0.id == accepted.state.id }) else {
            throw ArtError.invalid("Unknown artwork")
        }
        var random = SeededRandom(seed: seed, stream: "candidate")
        var fallback: RenderedArtwork?
        for _ in 0..<16 {
            var state = accepted.state
            state.parameters = try VariationEngine.vary(schema: definition.parameters, baseline: state.parameters,
                                                       intensity: intensity, seed: random.next())
            let artwork = try ArtExporter.render(state)
            guard artwork.frames != accepted.frames else { continue }
            fallback = artwork
            if artwork.frames != candidate?.frames { break }
        }
        guard let artwork = fallback else {
            throw ArtError.invalid(intensity == 0 ? "Increase intensity to generate a variation." : "No different variation was produced. Try a higher intensity.")
        }
        candidate = artwork
        candidateIntensity = intensity
    }

    public mutating func acceptSavedCandidate() {
        guard let candidate else { return }
        accepted = candidate
        self.candidate = nil
        candidateIntensity = nil
    }
}
