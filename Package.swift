// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FortressCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "FortressCore", targets: ["FortressCore"]),
        .library(name: "PixelArt", targets: ["PixelArt"]),
        .library(name: "FortressArt", targets: ["FortressArt"])
    ],
    targets: [
        .target(name: "FortressCore"),
        .testTarget(name: "FortressCoreTests", dependencies: ["FortressCore"]),
        .target(name: "PixelArt"),
        .target(name: "FortressArt", dependencies: ["PixelArt"]),
        .testTarget(name: "PixelArtTests", dependencies: ["PixelArt"]),
        .testTarget(name: "FortressArtTests", dependencies: ["FortressArt"])
    ]
)
