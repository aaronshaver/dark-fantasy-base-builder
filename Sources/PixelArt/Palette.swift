import Foundation

public struct Palette: Equatable {
    public struct Entry: Equatable {
        public let name: String
        public let rgb: UInt32
        public init(_ name: String, _ rgb: UInt32) { self.name = name; self.rgb = rgb }
    }
    public let entries: [Entry]
    private let indices: [String: UInt8]

    /// Index zero is always transparent. Opaque colors may share its RGB value.
    public init(_ entries: [Entry]) throws {
        guard (2...256).contains(entries.count), Set(entries.map(\.name)).count == entries.count,
              entries.allSatisfy({ $0.rgb <= 0xffffff }) else { throw ArtError.invalid("Invalid palette") }
        self.entries = entries
        indices = Dictionary(uniqueKeysWithValues: entries.enumerated().map { ($0.element.name, UInt8($0.offset)) })
    }

    public func index(_ name: String) throws -> UInt8 {
        guard let index = indices[name] else { throw ArtError.invalid("Unknown palette color: \(name)") }
        return index
    }

    public var rgbBytes: [UInt8] {
        entries.flatMap { [UInt8(($0.rgb >> 16) & 255), UInt8(($0.rgb >> 8) & 255), UInt8($0.rgb & 255)] }
    }

    /// Preserve palette index order in the existing runtime palette file.
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        let lines = try entries.map {
            let name = String(decoding: try encoder.encode($0.name), as: UTF8.self)
            return "  \(name): \"\(String(format: "%06x", $0.rgb))\""
        }
        return Data(("{\n" + lines.joined(separator: ",\n") + "\n}\n").utf8)
    }
}
