// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FortressCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.library(name: "FortressCore", targets: ["FortressCore"])],
    targets: [
        .target(name: "FortressCore"),
        .testTarget(name: "FortressCoreTests", dependencies: ["FortressCore"])
    ]
)
