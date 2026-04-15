// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "mac-uninstall",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite3",
            path: "Sources/CSQLite3"
        ),
        .executableTarget(
            name: "mac-uninstall",
            dependencies: ["CSQLite3"],
            path: "Sources/mac-uninstall"
        ),
    ]
)
