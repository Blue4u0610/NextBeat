// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NextBeatCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "NextBeatCore", targets: ["NextBeatCore"])],
    targets: [
        .target(name: "NextBeatCore", path: "Shared"),
        .testTarget(name: "NextBeatCoreTests", dependencies: ["NextBeatCore"], path: "Tests/Core")
    ]
)
