// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TerracottaiOS",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "TerracottaCore",
            targets: ["TerracottaCore"]),
        .library(
            name: "TerracottaUI",
            targets: ["TerracottaUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-combine-extensions.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "TerracottaCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "CombineExtensions", package: "swift-combine-extensions"),
            ],
            path: "Sources/TerracottaCore",
            linkerSettings: [
                .linkedFramework("NetworkExtension"),
                .linkedFramework("SystemConfiguration"),
            ]),
        .target(
            name: "TerracottaUI",
            dependencies: [
                "TerracottaCore",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/TerracottaUI"),
        .testTarget(
            name: "TerracottaCoreTests",
            dependencies: ["TerracottaCore"],
            path: "Tests/TerracottaCoreTests"),
        .testTarget(
            name: "TerracottaUITests",
            dependencies: ["TerracottaUI"],
            path: "Tests/TerracottaUITests"),
    ]
)
