// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SampleBot",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SampleBot", targets: ["SampleBot"])
    ],
    targets: [
        .executableTarget(
            name: "SampleBot",
            dependencies: [],
            path: "Sources/SampleBot"
        )
    ]
)
