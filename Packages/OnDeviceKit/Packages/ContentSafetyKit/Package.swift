// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ContentSafetyKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "ContentSafetyKit", targets: ["ContentSafetyKit"]),
    ],
    targets: [
        .target(name: "ContentSafetyKit"),
        .testTarget(name: "ContentSafetyKitTests", dependencies: ["ContentSafetyKit"]),
    ]
)
