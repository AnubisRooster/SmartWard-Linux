// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GraphViewKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "GraphViewKit", targets: ["GraphViewKit"]),
    ],
    targets: [
        .target(name: "GraphViewKit", resources: [
            .copy("Resources/graph.html"),
            .copy("Resources/cytoscape.min.js"),
        ]),
        .testTarget(name: "GraphViewKitTests", dependencies: ["GraphViewKit"]),
    ]
)
