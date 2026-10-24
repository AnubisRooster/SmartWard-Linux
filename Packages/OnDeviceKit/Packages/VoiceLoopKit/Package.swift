// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceLoopKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "VoiceLoopKit", targets: ["VoiceLoopKit"]),
    ],
    targets: [
        .target(name: "VoiceLoopKit"),
        .testTarget(name: "VoiceLoopKitTests", dependencies: ["VoiceLoopKit"]),
    ]
)
