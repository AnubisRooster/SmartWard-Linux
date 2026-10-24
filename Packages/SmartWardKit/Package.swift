// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

// Platform floors are SwiftData's minimums, not the app's (the app targets
// iOS 26). OnDeviceKit declares iOS only, so tests run on the iOS Simulator
// (see .github/workflows/ci.yml), not with `swift test` on the macOS host.
// Off Apple platforms SwiftData doesn't exist: `LinuxSwiftData` provides a
// module of the same name (macros + SQLite) so `import SwiftData` keeps working.
#if os(Linux)
let swiftDataDependency: [Target.Dependency] = [
    .target(name: "SwiftData"),
    .product(name: "Crypto", package: "swift-crypto"),
]
let linuxSwiftDataPackages: [Package.Dependency] = [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "602.0.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
]
let linuxSwiftDataTargets: [Target] = [
    .macro(name: "SwiftDataMacros",
           dependencies: [
               .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
               .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
           ]),
    .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3",
                   providers: [.apt(["libsqlite3-dev"])]),
    .target(name: "SwiftData", dependencies: ["SwiftDataMacros", "CSQLite"], path: "Sources/LinuxSwiftData"),
    .testTarget(name: "LinuxSwiftDataTests", dependencies: ["SwiftData"]),
    .target(name: "SmartWardCore",
            dependencies: [
                "KnowledgeStore", "IngestKit", "Pipeline", "StrategistCore", "SwiftData",
                .product(name: "RetrievalKit", package: "OnDeviceKit"),
            ]),
    .executableTarget(name: "smartward",
                      dependencies: [
                          "SmartWardCore", "KnowledgeStore", "Pipeline", "SwiftData",
                          .product(name: "ArgumentParser", package: "swift-argument-parser"),
                      ]),
    .testTarget(name: "SmartWardCoreTests", dependencies: ["SmartWardCore", "Pipeline", "KnowledgeStore", "SwiftData"]),
]
#else
let swiftDataDependency: [Target.Dependency] = []
let linuxSwiftDataPackages: [Package.Dependency] = []
let linuxSwiftDataTargets: [Target] = []
#endif

let package = Package(
    name: "SmartWardKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "KnowledgeStore", targets: ["KnowledgeStore"]),
        .library(name: "StrategistCore", targets: ["StrategistCore"]),
        .library(name: "IngestKit", targets: ["IngestKit"]),
        .library(name: "AppLock", targets: ["AppLock"]),
        .library(name: "Pipeline", targets: ["Pipeline"]),
        .library(name: "ShareInbox", targets: ["ShareInbox"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AnubisRooster/OnDeviceKit", branch: "linux-support"),
        // HTML parsing for article extraction (MIT).
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
    ] + linuxSwiftDataPackages,
    targets: [
        .target(name: "KnowledgeStore", dependencies: swiftDataDependency),
        .target(name: "StrategistCore",
                dependencies: [
                    "KnowledgeStore",
                    .product(name: "BYOKLLMKit", package: "OnDeviceKit"),
                    .product(name: "ModelCatalogKit", package: "OnDeviceKit"),
                ] + swiftDataDependency),
        // The share extension links only this; keep it dependency-free.
        .target(name: "ShareInbox"),
        .target(name: "IngestKit",
                dependencies: [
                    "KnowledgeStore",
                    "ShareInbox",
                    .product(name: "SwiftSoup", package: "SwiftSoup"),
                ] + swiftDataDependency),
        .target(name: "Pipeline",
                dependencies: [
                    "KnowledgeStore",
                    "IngestKit",
                    "StrategistCore",
                    .product(name: "RetrievalKit", package: "OnDeviceKit"),
                    .product(name: "BYOKLLMKit", package: "OnDeviceKit"),
                    .product(name: "GraphKit", package: "OnDeviceKit"),
                ] + swiftDataDependency),
        .target(name: "AppLock",
                dependencies: [
                    .product(name: "PINLockKit", package: "OnDeviceKit"),
                    .product(name: "BiometricLockKit", package: "OnDeviceKit"),
                ]),
        .testTarget(name: "KnowledgeStoreTests", dependencies: ["KnowledgeStore"] + swiftDataDependency),
        .testTarget(name: "StrategistCoreTests",
                    dependencies: [
                        "StrategistCore",
                        "KnowledgeStore",
                        .product(name: "BYOKLLMKit", package: "OnDeviceKit"),
                        .product(name: "ModelCatalogKit", package: "OnDeviceKit"),
                    ] + swiftDataDependency),
        .testTarget(name: "IngestKitTests",
                    dependencies: ["IngestKit", "KnowledgeStore", "ShareInbox"] + swiftDataDependency),
        .testTarget(name: "PipelineTests",
                    dependencies: [
                        "Pipeline",
                        "KnowledgeStore",
                        "IngestKit",
                        "StrategistCore",
                        .product(name: "RetrievalKit", package: "OnDeviceKit"),
                        .product(name: "BYOKLLMKit", package: "OnDeviceKit"),
                        .product(name: "GraphKit", package: "OnDeviceKit"),
                    ] + swiftDataDependency),
        .testTarget(name: "AppLockTests",
                    dependencies: [
                        "AppLock",
                        .product(name: "PINLockKit", package: "OnDeviceKit"),
                        .product(name: "BiometricLockKit", package: "OnDeviceKit"),
                    ] + swiftDataDependency),
    ] + linuxSwiftDataTargets
).filteredForPortingBringUp()

extension Package {
    /// While Linux support is brought up, `SMARTWARD_SKIP=Pipeline,PipelineTests`
    /// drops targets that don't build yet, so the rest can be built and tested.
    func filteredForPortingBringUp() -> Package {
        #if os(Linux)
        if let skip = Context.environment["SMARTWARD_SKIP"] {
            let names = Set(skip.split(separator: ",").map(String.init))
            targets = targets.filter { !names.contains($0.name) }
            products = products.filter { !names.contains($0.name) }
        }
        #endif
        return self
    }
}
