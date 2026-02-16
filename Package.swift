// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "luketn-wellness",
    platforms: [
        .macOS(.v26),
    ],
    targets: [
        .executableTarget(
            name: "luketn-wellness"
        ),
        .testTarget(
            name: "luketn-wellnessTests",
            dependencies: ["luketn-wellness"]
        ),
        .testTarget(
            name: "luketn-wellnessUITests",
            dependencies: ["luketn-wellness"]
        ),
    ]
)
