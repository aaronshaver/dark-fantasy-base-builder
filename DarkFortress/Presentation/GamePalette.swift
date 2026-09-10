import UIKit

/// These colors are entries in Resources/palette.json, shared with every sprite.
enum GamePalette {
    static let background = color(0x181b26)
    static let panel = color(0x202330)
    static let border = color(0x363747)
    static let muted = color(0x79798e)
    static let text = color(0xd8d4df)
    static let white = color(0xf3edf7)
    static let purple = color(0xa580bd)
    static let darkPurple = color(0x302840)
    static let red = color(0xd16a78)
    static let green = color(0x79aa93)

    private static func color(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}
