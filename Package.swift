// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacTile",
    platforms: [.macOS(.v13)],
    targets: [
        .systemLibrary(
            name: "CGSPrivate",
            path: "Sources/CGSPrivate"
        ),
        .executableTarget(
            name: "MacTile",
            dependencies: ["CGSPrivate"],
            path: "Sources/MacTile",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
    ]
)
