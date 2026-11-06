// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Convx",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Convx",
            targets: ["Convx"]
        ),
    ],
    targets: [
        .target(
            name: "Convx",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
