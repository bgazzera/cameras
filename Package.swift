// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HikvisionViewer",
    platforms: [
        .macOS(.v13),
    ],
    targets: [
        .binaryTarget(
            name: "VLCKit",
            path: "Vendor/VLCKit/VLCKit.xcframework"
        ),
        .executableTarget(
            name: "HikvisionViewer",
            dependencies: [
                "VLCKit",
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "@executable_path/../../../Vendor/VLCKit/VLCKit.xcframework/macos-arm64_x86_64",
                ]),
            ]
        ),
    ]
)
