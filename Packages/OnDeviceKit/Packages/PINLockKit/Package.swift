// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PINLockKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "PINLockKit", targets: ["PINLockKit"]),
    ],
    targets: [
        .target(name: "PINLockKit"),
        .testTarget(name: "PINLockKitTests", dependencies: ["PINLockKit"]),
    ]
)
