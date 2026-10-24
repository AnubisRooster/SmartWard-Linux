// swift-tools-version: 5.9
import PackageDescription

// This is the umbrella manifest: it re-exposes every module below as a
// product so remote consumers can `.package(url: "...")` once and pick
// whichever product(s) they need, exactly as before the restructure.
//
// Each module's actual source of truth now lives in its own standalone
// package under Packages/<Name>/ (own Package.swift, own Sources/, own
// Tests/) — that's what makes each module independently buildable/testable
// with only its own dependencies, and trivially extractable into its own
// repo later. This manifest's targets just point `path:` at those same
// source/test directories so the two views (umbrella vs. standalone
// subpackage) compile the identical files without ever coexisting in one
// build graph.
// Linux builds skip the modules that are Apple-framework UI/audio/biometrics
// or wrap llama.cpp via LLM.swift (LocalAuthentication, AVFoundation, Speech,
// WebKit, SwiftUI).
#if os(Linux)
let appleOnlyProducts: Set<String> = ["VoiceLoopKit", "GraphViewKit", "LocalLLMKit"]
#else
let appleOnlyProducts: Set<String> = []
#endif

let package = Package(
    name: "OnDeviceKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "BYOKLLMKit", targets: ["BYOKLLMKit"]),
        .library(name: "VoiceLoopKit", targets: ["VoiceLoopKit"]),
        .library(name: "PINLockKit", targets: ["PINLockKit"]),
        .library(name: "BiometricLockKit", targets: ["BiometricLockKit"]),
        .library(name: "ContentSafetyKit", targets: ["ContentSafetyKit"]),
        .library(name: "GraphKit", targets: ["GraphKit"]),
        .library(name: "AgentRouteKit", targets: ["AgentRouteKit"]),
        .library(name: "GraphViewKit", targets: ["GraphViewKit"]),
        .library(name: "LocalLLMKit", targets: ["LocalLLMKit"]),
        .library(name: "ModelCatalogKit", targets: ["ModelCatalogKit"]),
        .library(name: "RetrievalKit", targets: ["RetrievalKit"]),
        .library(name: "GraphRetrievalKit", targets: ["GraphRetrievalKit"]),
    ].filter { !appleOnlyProducts.contains($0.name) },
    dependencies: [
        .package(url: "https://github.com/eastriverlee/LLM.swift", exact: "1.8.0"),
    ],
    targets: [
        .target(name: "BYOKLLMKit", path: "Packages/BYOKLLMKit/Sources/BYOKLLMKit"),
        .testTarget(name: "BYOKLLMKitTests", dependencies: ["BYOKLLMKit"],
                   path: "Packages/BYOKLLMKit/Tests/BYOKLLMKitTests"),

        .target(name: "VoiceLoopKit", path: "Packages/VoiceLoopKit/Sources/VoiceLoopKit"),
        .testTarget(name: "VoiceLoopKitTests", dependencies: ["VoiceLoopKit"],
                   path: "Packages/VoiceLoopKit/Tests/VoiceLoopKitTests"),

        .target(name: "PINLockKit", path: "Packages/PINLockKit/Sources/PINLockKit"),
        .testTarget(name: "PINLockKitTests", dependencies: ["PINLockKit"],
                   path: "Packages/PINLockKit/Tests/PINLockKitTests"),

        .target(name: "BiometricLockKit", path: "Packages/BiometricLockKit/Sources/BiometricLockKit"),
        .testTarget(name: "BiometricLockKitTests", dependencies: ["BiometricLockKit"],
                   path: "Packages/BiometricLockKit/Tests/BiometricLockKitTests"),

        .target(name: "ContentSafetyKit", path: "Packages/ContentSafetyKit/Sources/ContentSafetyKit"),
        .testTarget(name: "ContentSafetyKitTests", dependencies: ["ContentSafetyKit"],
                   path: "Packages/ContentSafetyKit/Tests/ContentSafetyKitTests"),

        .target(name: "GraphKit", path: "Packages/GraphKit/Sources/GraphKit"),
        .testTarget(name: "GraphKitTests", dependencies: ["GraphKit"],
                   path: "Packages/GraphKit/Tests/GraphKitTests"),

        .target(name: "AgentRouteKit", path: "Packages/AgentRouteKit/Sources/AgentRouteKit"),
        .testTarget(name: "AgentRouteKitTests", dependencies: ["AgentRouteKit"],
                   path: "Packages/AgentRouteKit/Tests/AgentRouteKitTests"),

        .target(name: "GraphViewKit",
                path: "Packages/GraphViewKit/Sources/GraphViewKit",
                resources: [
                    .copy("Resources/graph.html"),
                    .copy("Resources/cytoscape.min.js"),
                ]),
        .testTarget(name: "GraphViewKitTests", dependencies: ["GraphViewKit"],
                   path: "Packages/GraphViewKit/Tests/GraphViewKitTests"),

        .target(name: "LocalLLMKit",
                dependencies: [
                    "BYOKLLMKit",
                    .product(name: "LLM", package: "LLM.swift"),
                ],
                path: "Packages/LocalLLMKit/Sources/LocalLLMKit"),
        .testTarget(name: "LocalLLMKitTests", dependencies: ["LocalLLMKit", "BYOKLLMKit"],
                   path: "Packages/LocalLLMKit/Tests/LocalLLMKitTests"),

        .target(name: "ModelCatalogKit", path: "Packages/ModelCatalogKit/Sources/ModelCatalogKit"),
        .testTarget(name: "ModelCatalogKitTests", dependencies: ["ModelCatalogKit"],
                   path: "Packages/ModelCatalogKit/Tests/ModelCatalogKitTests"),

        .target(name: "RetrievalKit", path: "Packages/RetrievalKit/Sources/RetrievalKit"),
        .testTarget(name: "RetrievalKitTests", dependencies: ["RetrievalKit"],
                   path: "Packages/RetrievalKit/Tests/RetrievalKitTests"),

        .target(name: "GraphRetrievalKit",
                dependencies: ["RetrievalKit", "GraphKit"],
                path: "Packages/GraphRetrievalKit/Sources/GraphRetrievalKit"),
        .testTarget(name: "GraphRetrievalKitTests", dependencies: ["GraphRetrievalKit", "RetrievalKit", "GraphKit"],
                   path: "Packages/GraphRetrievalKit/Tests/GraphRetrievalKitTests"),
    ].filter { target in !appleOnlyProducts.contains(where: { target.name == $0 || target.name == $0 + "Tests" }) }
)
