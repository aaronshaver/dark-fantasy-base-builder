import Foundation

/// Mutates declared values around an accepted baseline. Drawing structure and detail seeds stay fixed.
public enum VariationEngine {
    public static func vary(schema: [Parameter], baseline: [String: ParameterValue], intensity: Double,
                            seed: UInt64) throws -> [String: ParameterValue] {
        guard intensity.isFinite, (0...1).contains(intensity) else { throw ArtError.invalid("Intensity must be between zero and one") }
        var values = try ParameterValues(schema: schema, overrides: baseline).values
        guard intensity > 0 else { return values }
        var adjustable = schema.filter {
            switch $0.domain {
            case .integer(let range): return range.lowerBound != range.upperBound
            case .choice(let options): return Set(options).count > 1
            }
        }
        var random = SeededRandom(seed: seed, stream: "parameters")
        if adjustable.count > 1 {
            for index in stride(from: adjustable.count - 1, through: 1, by: -1) {
                adjustable.swapAt(index, random.integer(0..<(index + 1)))
            }
        }
        let count = Int(ceil(Double(adjustable.count) * intensity))
        for parameter in adjustable.prefix(count) {
            switch (parameter.domain, values[parameter.id]) {
            case let (.integer(range), .integer(current)):
                // Pixel dimensions are discrete: the smallest supported step is one pixel.
                let (span, overflow) = range.upperBound.subtractingReportingOverflow(range.lowerBound)
                guard !overflow, span <= 1_000_000 else { throw ArtError.invalid("Parameter range is too large: \(parameter.id)") }
                let radius = max(1, Int(ceil(Double(span) * intensity)))
                let lower = current - min(radius, current - range.lowerBound)
                let upper = current + min(radius, range.upperBound - current)
                // Sample all available values except the current value, including at range endpoints.
                let index = random.integer(0..<(upper - lower))
                let value = lower + index
                values[parameter.id] = .integer(value >= current ? value + 1 : value)
            case let (.choice(options), .choice(current)):
                values[parameter.id] = .choice(random.choose(options.filter { $0 != current }))
            default: throw ArtError.invalid("Invalid parameter: \(parameter.id)")
            }
        }
        return values
    }
}
