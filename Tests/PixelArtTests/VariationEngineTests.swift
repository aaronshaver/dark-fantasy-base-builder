import XCTest
@testable import PixelArt

final class VariationEngineTests: XCTestCase {
    private let schema = (0..<10).map { Parameter("p\($0)", "Size", value: 50, range: 0...100) }

    func testZeroIntensityIsAnExactNoOpAndSeedMakesGenerationRepeatable() throws {
        let baseline = try ParameterValues(schema: schema).values
        XCTAssertEqual(try VariationEngine.vary(schema: schema, baseline: baseline, intensity: 0, seed: 4), baseline)
        let first = try VariationEngine.vary(schema: schema, baseline: baseline, intensity: 0.5, seed: 99)
        XCTAssertEqual(first, try VariationEngine.vary(schema: schema, baseline: baseline, intensity: 0.5, seed: 99))
        XCTAssertNotEqual(first, try VariationEngine.vary(schema: schema, baseline: baseline, intensity: 0.5, seed: 100))
    }

    func testIntensityControlsBothParameterCountAndDistanceFromSavedValues() throws {
        let baseline = try ParameterValues(schema: schema).values
        for seed in 0..<100 {
            let tiny = try VariationEngine.vary(schema: schema, baseline: baseline, intensity: 0.01, seed: UInt64(seed))
            let big = try VariationEngine.vary(schema: schema, baseline: baseline, intensity: 1, seed: UInt64(seed))
            XCTAssertEqual(tiny.filter { baseline[$0.key] != $0.value }.count, 1)
            XCTAssertEqual(big.filter { baseline[$0.key] != $0.value }.count, 10)
            for value in tiny.values {
                guard case .integer(let number) = value else { return XCTFail("Expected integer") }
                XCTAssertLessThanOrEqual(abs(number - 50), 1)
            }
        }
        let shifted = [Parameter("width", "Width", value: 5, range: 0...100)]
        let result = try VariationEngine.vary(schema: shifted, baseline: ["width": .integer(90)], intensity: 0.01, seed: 4)
        guard case .integer(let number) = result["width"] else { return XCTFail("Expected width") }
        XCTAssertTrue([89, 91].contains(number))
    }

    func testBoundsChoicesAndFixedParameters() throws {
        let schema = [Parameter("low", "Low", value: 0, range: 0...3),
                      Parameter("high", "High", value: 3, range: 0...3),
                      Parameter("fixed", "Fixed", value: 7, range: 7...7),
                      Parameter("color", "Color", value: "red", choices: ["red", "blue"])]
        for seed in 0..<100 {
            let result = try VariationEngine.vary(schema: schema, baseline: [:], intensity: 1, seed: UInt64(seed))
            for parameter in schema { XCTAssertTrue(parameter.accepts(try XCTUnwrap(result[parameter.id]))) }
            XCTAssertEqual(result["fixed"], .integer(7)); XCTAssertEqual(result["color"], .choice("blue"))
            XCTAssertNotEqual(result["low"], .integer(0)); XCTAssertNotEqual(result["high"], .integer(3))
        }
        for amount in [-0.1, 1.1, Double.nan, Double.infinity] {
            XCTAssertThrowsError(try VariationEngine.vary(schema: schema, baseline: [:], intensity: amount, seed: 0))
        }
    }

    func testIntegerLimitsDoNotOverflow() throws {
        for range in [Int.min...(Int.min + 2), (Int.max - 2)...Int.max] {
            let parameter = Parameter("edge", "Edge", value: range.lowerBound, range: range)
            let values = try VariationEngine.vary(schema: [parameter], baseline: [:], intensity: 1, seed: 0)
            XCTAssertTrue(parameter.accepts(try XCTUnwrap(values["edge"])))
        }
        XCTAssertThrowsError(try VariationEngine.vary(schema: [Parameter("bad", "Bad", value: 0, range: Int.min...Int.max)],
                                                    baseline: [:], intensity: 1, seed: 0))
    }
}
