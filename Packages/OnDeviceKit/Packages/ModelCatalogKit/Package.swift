// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ModelCatalogKit",
    platforms: [
        .iOS(.v17),
        // async URLSession.data(for:) needs macOS 12+ runtime support.
        .macOS(.v12),
    ],
    products: [
        .library(name: "ModelCatalogKit", targets: ["ModelCatalogKit"]),
    ],
    targets: [
        .target(name: "ModelCatalogKit"),
        .testTarget(name: "ModelCatalogKitTests", dependencies: ["ModelCatalogKit"]),
    ]
)
