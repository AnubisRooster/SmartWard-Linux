// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalLLMKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "LocalLLMKit", targets: ["LocalLLMKit"]),
    ],
    dependencies: [
        .package(path: "../BYOKLLMKit"),
        .package(url: "https://github.com/eastriverlee/LLM.swift", exact: "1.8.0"),
    ],
    targets: [
        .target(name: "LocalLLMKit", dependencies: [
            "BYOKLLMKit",
            .product(name: "LLM", package: "LLM.swift"),
        ]),
        .testTarget(name: "LocalLLMKitTests", dependencies: ["LocalLLMKit", "BYOKLLMKit"]),
    ]
)
