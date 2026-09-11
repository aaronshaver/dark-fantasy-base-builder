import XCTest
import ImageIO
@testable import PixelArt

final class PixelArtTests: XCTestCase {
    private var palette: Palette { try! Palette([.init("clear", 0), .init("red", 0xff0000), .init("blue", 0x0000ff)]) }
    private func block(_ id: String, _ color: String, z: Int = 0, placement: Placement = Placement(),
                       anchors: [String: Point] = [:]) -> ArtNode {
        var d = Drawing(); d.rect(0, 0, 2, 2, color)
        return d.part(id, z: z, placement: placement, anchors: anchors)
    }
    private func render(_ children: [ArtNode], placement: Placement = Placement()) throws -> PixelCanvas {
        try PixelRenderer(palette: palette).render(Group("root", placement: placement, children: children), width: 16, height: 16)
    }

    func testLocalZCannotEscapeItsGroupAndTiesUseDeclarationOrder() throws {
        let head = Group("head", z: 0, children: [block("eye", "blue", z: 900), block("face", "red", z: 0)])
        XCTAssertEqual(try render([.group(head)])[0, 0], 2)
        XCTAssertEqual(try render([block("foreground", "red", z: 1), .group(head)])[0, 0], 1)
        XCTAssertEqual(try render([block("first", "red"), block("second", "blue")])[0, 0], 2)
    }

    func testAttachmentsResolveForwardReferencesAndFollowScaledAnchors() throws {
        let body = block("body", "red", z: 1, placement: Placement(3, 4, scaleX: 2), anchors: ["shoulder": Point(2, 0)])
        let hand = block("hand", "blue", placement: Placement(1, 0, attached: Attachment(to: "body", anchor: "shoulder")))
        let result = try render([hand, body])
        XCTAssertEqual(result[8, 4], 2)
        XCTAssertEqual(result[3, 4], 1)
        XCTAssertEqual(result[7, 4], 0)
    }

    func testOwnAnchorsAndNestedTransformsMoveAllPartsTogether() throws {
        let body = block("body", "red", placement: Placement(2, 2), anchors: ["neck": Point(1, 0)])
        let head = Group("head", z: 2, placement: Placement(attached: Attachment(to: "body", anchor: "neck", own: "neck")),
                         anchors: ["neck": Point(1, 2)], children: [block("face", "blue")])
        let result = try render([body, .group(head)], placement: Placement(2, 3, scaleX: 2, scaleY: 2))
        XCTAssertEqual(result[6, 3], 2)
        XCTAssertEqual(result[6, 7], 1)
        XCTAssertEqual(result[10, 3], 0)
    }

    func testMirroringPaintsWholePixelsAroundTheAttachment() throws {
        var d = Drawing(); d.dot(0, 0, "red"); d.dot(1, 0, "blue")
        let result = try render([d.part("mirror", placement: Placement(5, 2, scaleX: -1))])
        XCTAssertEqual(result[4, 2], 1)
        XCTAssertEqual(result[3, 2], 2)
        XCTAssertEqual(result[5, 2], 0)
    }

    func testUndrawnPixelsPreserveLowerPartsAndExplicitClearErases() throws {
        var d = Drawing(); d.dot(0, 0, "clear"); d.dot(1, 0, "blue")
        let result = try render([block("base", "red"), d.part("top", z: 1)])
        XCTAssertEqual(result[0, 0], 0)
        XCTAssertEqual(result[1, 0], 2)
        XCTAssertEqual(result[0, 1], 1)
    }

    func testInvalidAttachmentGraphsAreRejected() throws {
        let a = block("a", "red", placement: Placement(attached: Attachment(to: "b", anchor: "origin")))
        let b = block("b", "red", placement: Placement(attached: Attachment(to: "a", anchor: "origin")))
        XCTAssertThrowsError(try render([a, b]))
        XCTAssertThrowsError(try render([a]))
        XCTAssertThrowsError(try render([block("same", "red"), block("same", "blue")]))
        XCTAssertThrowsError(try render([block("a", "red"), block("b", "red", placement: Placement(attached: Attachment(to: "a", anchor: "missing")))]))
        XCTAssertThrowsError(try render([block("a", "red", placement: Placement(scaleX: 0))]))
    }

    func testPaletteAndParameterValidation() throws {
        XCTAssertThrowsError(try Palette([.init("clear", 0), .init("clear", 1)]))
        XCTAssertThrowsError(try render([block("bad", "not-in-palette")]))
        let schema = [Parameter("size", "Size", value: 3, range: 1...5),
                      Parameter("style", "Style", value: "a", choices: ["a", "b"])]
        let values = try ParameterValues(schema: schema, overrides: ["size": .integer(5)])
        XCTAssertEqual(try values.integer("size"), 5)
        XCTAssertEqual(try values.choice("style"), "a")
        for overrides: [String: ParameterValue] in [["size": .integer(6)], ["size": .choice("a")], ["style": .choice("c")], ["unknown": .integer(1)]] {
            XCTAssertThrowsError(try ParameterValues(schema: schema, overrides: overrides))
        }
        XCTAssertThrowsError(try ParameterValues(schema: [schema[0], schema[0]]))
        XCTAssertThrowsError(try ParameterValues(schema: [Parameter("bad", "Bad", value: 0, range: 1...5)]))
    }

    func testTreeAndRecipeStateRoundTripPreserveRendering() throws {
        let tree = Group("root", children: [block("base", "red"), .group(Group("details", z: 2, children: [block("eye", "blue")]))])
        let restored = try JSONDecoder().decode(Group.self, from: JSONEncoder().encode(tree))
        XCTAssertEqual(tree, restored)
        XCTAssertEqual(try PixelRenderer(palette: palette).render(tree), try PixelRenderer(palette: palette).render(restored))
        let state = RecipeState(id: "example", generatorVersion: 1, seed: 42, parameters: ["size": .integer(4), "style": .choice("b")])
        XCTAssertEqual(state, try JSONDecoder().decode(RecipeState.self, from: JSONEncoder().encode(state)))
    }

    func testStableIndependentRandomStreams() {
        var first = SeededRandom(seed: 7, stream: "head"), second = first
        let expected = (0..<100).map { _ in first.next() }
        var unrelated = SeededRandom(seed: 7, stream: "body")
        for _ in 0..<1000 { _ = unrelated.next() }
        XCTAssertEqual(expected, (0..<100).map { _ in second.next() })
        var different = SeededRandom(seed: 8, stream: "head")
        XCTAssertNotEqual(expected, (0..<100).map { _ in different.next() })
    }

    func testPNGDecodesWithSystemImageIOAndPreservesTransparency() throws {
        let canvas = try render([block("red", "red", placement: Placement(1, 1))])
        let png = try IndexedPNG.encode(canvas, palette: palette)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, 16); XCTAssertEqual(image.height, 16)
        var bytes = [UInt8](repeating: 0, count: 16 * 16 * 4)
        try bytes.withUnsafeMutableBytes { storage in
            let context = try XCTUnwrap(CGContext(data: storage.baseAddress, width: 16, height: 16,
                                                 bitsPerComponent: 8, bytesPerRow: 64,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        XCTAssertEqual(bytes[3], 0)
        XCTAssertEqual(bytes[(1 * 16 + 1) * 4], 255)
        XCTAssertEqual(bytes[(1 * 16 + 1) * 4 + 3], 255)
        XCTAssertThrowsError(try IndexedPNG.encode(canvas, palette: palette, transparent: false))
        let enlarged = try canvas.enlarged(by: 2)
        XCTAssertEqual(enlarged[2, 2], 1); XCTAssertEqual(enlarged[3, 3], 1)
        XCTAssertEqual(enlarged[4, 4], 1); XCTAssertEqual(enlarged[6, 6], 0)
    }
}
