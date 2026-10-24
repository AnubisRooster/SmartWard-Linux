// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BiometricLockKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "BiometricLockKit", targets: ["BiometricLockKit"]),
    ],
    targets: [
        .target(name: "BiometricLockKit"),
        .testTarget(name: "BiometricLockKitTests", dependencies: ["BiometricLockKit"]),
    ]
)
