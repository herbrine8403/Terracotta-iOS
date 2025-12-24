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
            targets: ["TerracottaCoreWrapper"]),
        .library(
            name: "TerracottaUI",
            targets: ["TerracottaUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "TerracottaCoreC",
            path: "Sources/TerracottaCore/Native",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("../"),
            ]
        ),
        .target(
            name: "TerracottaCoreWrapper",
            dependencies: [
                "TerracottaCoreC",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/TerracottaCore",
            exclude: ["Native"],
            linkerSettings: [
                .linkedFramework("NetworkExtension"),
                .linkedFramework("SystemConfiguration"),
            ]
        ),
        .target(
            name: "TerracottaUI",
            dependencies: [
                "TerracottaCoreWrapper",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/TerracottaUI"),
    ]
)
