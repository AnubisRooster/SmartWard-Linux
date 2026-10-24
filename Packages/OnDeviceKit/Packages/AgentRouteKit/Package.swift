// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentRouteKit",
    platforms: [
        .iOS(.v17),
        // Router's `any Handler<Context, Output>` existential (primary
        // associated types) needs macOS 13+ runtime metadata support.
        // AgentRouteKit has no iOS-only APIs, so it's genuinely portable —
        // unlike VoiceLoopKit/GraphViewKit/LocalLLMKit, which stay iOS-only.
        .macOS(.v13),
    ],
    products: [
        .library(name: "AgentRouteKit", targets: ["AgentRouteKit"]),
    ],
    targets: [
        .target(name: "AgentRouteKit"),
        .testTarget(name: "AgentRouteKitTests", dependencies: ["AgentRouteKit"]),
    ]
)
