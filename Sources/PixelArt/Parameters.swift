import Foundation

public enum ArtError: Error, Equatable {
    case invalid(String)
}

public enum ParameterValue: Codable, Equatable {
    case integer(Int)
    case choice(String)
}

/// These declarations belong to a recipe; the engine has no artwork-specific knobs.
public struct Parameter: Codable, Equatable {
    public enum Domain: Codable, Equatable {
        case integer(ClosedRange<Int>)
        case choice([String])
    }

    public let id: String
    public let label: String
    public let baseline: ParameterValue
    public let domain: Domain

    public init(_ id: String, _ label: String, value: Int, range: ClosedRange<Int>) {
        self.id = id; self.label = label; baseline = .integer(value); domain = .integer(range)
    }

    public init(_ id: String, _ label: String, value: String, choices: [String]) {
        self.id = id; self.label = label; baseline = .choice(value); domain = .choice(choices)
    }

    public func accepts(_ value: ParameterValue) -> Bool {
        switch (domain, value) {
        case let (.integer(range), .integer(number)): return range.contains(number)
        case let (.choice(options), .choice(choice)): return options.contains(choice)
        default: return false
        }
    }
}

public struct ParameterValues {
    public let values: [String: ParameterValue]

    public init(schema: [Parameter], overrides: [String: ParameterValue] = [:]) throws {
        guard Set(schema.map(\.id)).count == schema.count else { throw ArtError.invalid("Duplicate parameter ID") }
        guard Set(overrides.keys).isSubset(of: Set(schema.map(\.id))) else {
            throw ArtError.invalid("Unknown parameter override")
        }
        var result: [String: ParameterValue] = [:]
        for parameter in schema {
            guard parameter.accepts(parameter.baseline) else { throw ArtError.invalid("Invalid baseline: \(parameter.id)") }
            let value = overrides[parameter.id] ?? parameter.baseline
            guard parameter.accepts(value) else { throw ArtError.invalid("Invalid value: \(parameter.id)") }
            result[parameter.id] = value
        }
        values = result
    }

    public func integer(_ id: String) throws -> Int {
        guard case let .integer(value) = values[id] else { throw ArtError.invalid("Expected integer: \(id)") }
        return value
    }

    public func choice(_ id: String) throws -> String {
        guard case let .choice(value) = values[id] else { throw ArtError.invalid("Expected choice: \(id)") }
        return value
    }
}

/// The accepted recipe state is separate from the drawing code and supports exact regeneration.
public struct RecipeState: Codable, Equatable {
    public let id: String
    public let generatorVersion: Int
    public var seed: UInt64
    public var parameters: [String: ParameterValue]

    public init(id: String, generatorVersion: Int, seed: UInt64, parameters: [String: ParameterValue]) {
        self.id = id; self.generatorVersion = generatorVersion; self.seed = seed; self.parameters = parameters
    }
}
