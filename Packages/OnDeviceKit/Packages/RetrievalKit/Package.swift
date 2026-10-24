// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RetrievalKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "RetrievalKit", targets: ["RetrievalKit"]),
    ],
    targets: [
        .target(name: "RetrievalKit"),
        .testTarget(name: "RetrievalKitTests", dependencies: ["RetrievalKit"]),
    ]
)
