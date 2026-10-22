// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "aether",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure geometry, no AppKit, so it can be unit tested.
        .target(name: "AetherCore"),
        .testTarget(name: "AetherCoreTests", dependencies: ["AetherCore"]),
    ],
    swiftLanguageModes: [.v5]
)
