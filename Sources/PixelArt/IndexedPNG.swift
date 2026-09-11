import Foundation
import zlib

/// PNG framing around the system zlib compressor keeps every asset indexed to exactly one palette.
public enum IndexedPNG {
    public static func encode(_ canvas: PixelCanvas, palette: Palette, transparent: Bool = true) throws -> Data {
        guard canvas.pixels.allSatisfy({ Int($0) < palette.entries.count }),
              transparent || !canvas.pixels.contains(0) else { throw ArtError.invalid("Invalid PNG palette indices or opaque image") }
        var raw = [UInt8]()
        raw.reserveCapacity((canvas.width + 1) * canvas.height)
        for y in 0..<canvas.height {
            raw.append(0) // PNG filter: None
            raw.append(contentsOf: canvas.pixels[(y * canvas.width)..<((y + 1) * canvas.width)])
        }
        var length = compressBound(uLong(raw.count))
        var compressed = [UInt8](repeating: 0, count: Int(length))
        let status = compress2(&compressed, &length, raw, uLong(raw.count), Z_BEST_COMPRESSION)
        guard status == Z_OK else { throw ArtError.invalid("PNG compression failed: \(status)") }
        var result = Data([137, 80, 78, 71, 13, 10, 26, 10])
        result.append(chunk("IHDR", bigEndian(UInt32(canvas.width)) + bigEndian(UInt32(canvas.height)) + [8, 3, 0, 0, 0]))
        result.append(chunk("PLTE", palette.rgbBytes))
        if transparent { result.append(chunk("tRNS", [0] + Array(repeating: 255, count: palette.entries.count - 1))) }
        result.append(chunk("IDAT", Array(compressed.prefix(Int(length)))))
        result.append(chunk("IEND", []))
        return result
    }

    private static func bigEndian(_ value: UInt32) -> [UInt8] {
        [UInt8((value >> 24) & 255), UInt8((value >> 16) & 255), UInt8((value >> 8) & 255), UInt8(value & 255)]
    }
    private static func chunk(_ name: String, _ payload: [UInt8]) -> Data {
        let bytes = Array(name.utf8) + payload
        let checksum = bytes.withUnsafeBufferPointer { UInt32(crc32(0, $0.baseAddress, uInt($0.count))) }
        return Data(bigEndian(UInt32(payload.count)) + bytes + bigEndian(checksum))
    }
}
