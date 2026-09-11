import Foundation
import PixelArt

public struct ArtworkDefinition {
    public let id: String
    public let name: String
    public let parameters: [Parameter]
    public var baseline: RecipeState {
        RecipeState(id: id, generatorVersion: ArtCatalog.generatorVersion, seed: 170,
                    parameters: Dictionary(uniqueKeysWithValues: parameters.map { ($0.id, $0.baseline) }))
    }
}

public struct ArtFrame {
    public let name: String
    public let root: Group
    init(_ name: String, _ children: [ArtNode]) { self.name = name; root = Group(name, children: children) }
}

/// Only authoring code knows these recipes. The game continues consuming named PNG assets.
public enum ArtCatalog {
    public static let generatorVersion = 1
    public static let definitions: [ArtworkDefinition] = [
        ArtworkDefinition(id: "grass", name: "Grass", parameters: [
            Parameter("tuftAdjustment", "Tuft count adjustment", value: 0, range: -4...8),
            Parameter("bladeHeight", "Blade height adjustment", value: 0, range: -1...2),
            Parameter("patchSize", "Patch size adjustment", value: 0, range: -2...2)
        ]),
        ArtworkDefinition(id: "wood", name: "Wooden Floor", parameters: [
            Parameter("jointOffset", "Plank joint offset", value: 0, range: -3...3),
            Parameter("grainCount", "Grain lines per plank", value: 3, range: 1...6),
            Parameter("knotSize", "Knot size adjustment", value: 0, range: -1...2)
        ]),
        ArtworkDefinition(id: "wall", name: "Stone Wall", parameters: [
            Parameter("jointOffset", "Stone joint offset", value: 0, range: -2...2),
            Parameter("pitCount", "Pits per stone", value: 3, range: 0...7)
        ]),
        ArtworkDefinition(id: "gate", name: "Gate", parameters: [
            Parameter("barWidth", "Bar width", value: 2, range: 1...3),
            Parameter("lockWidth", "Lock width", value: 6, range: 4...8)
        ]),
        ArtworkDefinition(id: "chair", name: "Chairs", parameters: [
            Parameter("backHeight", "Back height", value: 12, range: 10...14),
            Parameter("seatWidth", "Seat width", value: 19, range: 17...21)
        ]),
        ArtworkDefinition(id: "necromancer", name: "Necromancer", parameters: characterParameters),
        ArtworkDefinition(id: "human", name: "Human Soldier", parameters: characterParameters.filter { $0.id != "eyeColor" }),
        ArtworkDefinition(id: "icons", name: "Interface Icons", parameters: [
            Parameter("accent", "Accent color", value: "lilac", choices: ["lilac", "purple_light", "teal_light"])
        ]),
        ArtworkDefinition(id: "effects", name: "Effects and Markers", parameters: [
            Parameter("markerLength", "Marker corner length", value: 5, range: 3...7),
            Parameter("debrisLength", "Debris length adjustment", value: 0, range: -1...2)
        ]),
        ArtworkDefinition(id: "appIcon", name: "App Icon", parameters: [
            Parameter("towerHeight", "Tower height", value: 8, range: 6...10)
        ])
    ]
    private static let characterParameters = [
        Parameter("headWidth", "Head width", value: 11, range: 9...13),
        Parameter("bodyWidth", "Body width adjustment", value: 0, range: -1...1),
        Parameter("eyeColor", "Eye highlight", value: "teal_light", choices: ["teal_light", "gold_light", "lilac"])
    ]

    public static func frames(for state: RecipeState) throws -> [ArtFrame] {
        guard state.generatorVersion == generatorVersion else { throw ArtError.invalid("Unsupported generator version") }
        guard let definition = definitions.first(where: { $0.id == state.id }) else { throw ArtError.invalid("Unknown artwork: \(state.id)") }
        let parameters = try ParameterValues(schema: definition.parameters, overrides: state.parameters)
        switch state.id {
        case "grass", "wood", "wall": return try GroundRecipes.frames(kind: state.id, parameters: parameters, seed: state.seed)
        case "gate": return try PropRecipes.gates(parameters)
        case "chair": return try PropRecipes.chairs(parameters)
        case "necromancer", "human": return try CharacterRecipes.frames(kind: state.id, parameters: parameters)
        case "icons": return try IconRecipes.frames(parameters)
        case "effects": return try EffectRecipes.frames(parameters)
        case "appIcon": return [try IconRecipes.appIcon(parameters)]
        default: throw ArtError.invalid("Missing recipe")
        }
    }
}
