// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GraphKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "GraphKit", targets: ["GraphKit"]),
    ],
    targets: [
        .target(name: "GraphKit"),
        .testTarget(name: "GraphKitTests", dependencies: ["GraphKit"]),
    ]
)
