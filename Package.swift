// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "apple-buildwatch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "buildwatch", targets: ["BuildWatchCLI"]),
        .library(name: "BuildWatch", targets: ["BuildWatch"])
    ],
    targets: [
        .target(name: "BuildWatch"),
        .executableTarget(
            name: "BuildWatchCLI",
            dependencies: ["BuildWatch"]
        ),
        .testTarget(
            name: "BuildWatchTests",
            dependencies: ["BuildWatch"]
        )
    ]
)
