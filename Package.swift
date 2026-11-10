// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StickySideNote",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "StickyCore"),
        .executableTarget(name: "StickySideNote", dependencies: ["StickyCore"]),
        .testTarget(name: "StickyCoreTests", dependencies: ["StickyCore"]),
    ],
    swiftLanguageModes: [.v5]
)
