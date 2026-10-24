// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BYOKLLMKit",
    platforms: [
        .iOS(.v17),
        // async URLSession.data(for:) needs macOS 12+ runtime support.
        // BYOKLLMKit has no iOS-only APIs, so it's genuinely portable —
        // unlike VoiceLoopKit/GraphViewKit/LocalLLMKit, which stay iOS-only.
        .macOS(.v12),
    ],
    products: [
        .library(name: "BYOKLLMKit", targets: ["BYOKLLMKit"]),
    ],
    targets: [
        .target(name: "BYOKLLMKit"),
        .testTarget(name: "BYOKLLMKitTests", dependencies: ["BYOKLLMKit"]),
    ]
)
