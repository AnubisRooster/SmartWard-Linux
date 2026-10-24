// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GraphRetrievalKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "GraphRetrievalKit", targets: ["GraphRetrievalKit"]),
    ],
    dependencies: [
        .package(path: "../RetrievalKit"),
        .package(path: "../GraphKit"),
    ],
    targets: [
        .target(name: "GraphRetrievalKit", dependencies: ["RetrievalKit", "GraphKit"]),
        .testTarget(name: "GraphRetrievalKitTests", dependencies: ["GraphRetrievalKit", "RetrievalKit", "GraphKit"]),
    ]
)
