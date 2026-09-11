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
        ArtworkDefinition(id: "ground_grass", name: "Ground: Grass", parameters: [
            Parameter("tuftAdjustment", "Tuft count adjustment", value: 0, range: -4...8),
            Parameter("bladeHeight", "Blade height adjustment", value: 0, range: -1...2),
            Parameter("patchSize", "Patch size adjustment", value: 0, range: -2...2)
        ]),
        ArtworkDefinition(id: "floor_wood", name: "Floor: Wood", parameters: [
            Parameter("jointOffset", "Plank joint offset", value: 0, range: -3...3),
            Parameter("grainCount", "Grain lines per plank", value: 3, range: 1...6),
            Parameter("knotSize", "Knot size adjustment", value: 0, range: -1...2)
        ]),
        ArtworkDefinition(id: "wall_stone", name: "Wall: Stone", parameters: [
            Parameter("jointOffset", "Stone joint offset", value: 0, range: -2...2),
            Parameter("pitCount", "Pits per stone", value: 3, range: 0...7)
        ]),
        ArtworkDefinition(id: "door_metal_gate", name: "Door: Metal Gate", parameters: [
            Parameter("barWidth", "Bar width", value: 2, range: 1...3),
            Parameter("lockWidth", "Lock width", value: 6, range: 4...8)
        ]),
        ArtworkDefinition(id: "furniture_chair", name: "Furniture: Chair", parameters: [
            Parameter("backHeight", "Back height", value: 12, range: 10...14),
            Parameter("seatWidth", "Seat width", value: 19, range: 17...21)
        ]),
        ArtworkDefinition(id: "player", name: "Player", parameters: characterParameters),
        ArtworkDefinition(id: "enemy_melee_sword", name: "Enemy: Melee: Sword", parameters: characterParameters.filter { $0.id != "eyeColor" }),
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
        case "ground_grass", "floor_wood", "wall_stone": return try GroundRecipes.frames(kind: state.id, parameters: parameters, seed: state.seed)
        case "door_metal_gate": return try PropRecipes.metalGates(parameters)
        case "furniture_chair": return try PropRecipes.chairs(parameters)
        case "player", "enemy_melee_sword": return try CharacterRecipes.frames(kind: state.id, parameters: parameters)
        case "effects": return try EffectRecipes.frames(parameters)
        case "appIcon": return [try AppIconRecipe.frame(parameters)]
        default: throw ArtError.invalid("Missing recipe")
        }
    }
}
