// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WardrobeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WardrobeCore", targets: ["WardrobeCore"]),
    ],
    targets: [
        .target(
            name: "WardrobeCore",
            resources: [.copy("Resources/color-dictionary.json")]
        ),
        .testTarget(name: "WardrobeCoreTests", dependencies: ["WardrobeCore"]),
    ]
)
