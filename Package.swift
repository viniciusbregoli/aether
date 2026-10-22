// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "aether",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/dduan/TOMLDecoder", from: "0.4.4"),
    ],
    targets: [
        // Pure logic, no AppKit, so it can be unit tested.
        .target(name: "AetherCore", dependencies: ["TOMLDecoder"]),
        .executableTarget(name: "aether", dependencies: ["AetherCore"]),
        .testTarget(name: "AetherCoreTests", dependencies: ["AetherCore"]),
    ],
    swiftLanguageModes: [.v5]
)
