// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "HoldTypeOpenAI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "HoldTypeOpenAI",
            targets: ["HoldTypeOpenAI"]
        ),
    ],
    targets: [
        .target(name: "HoldTypeOpenAI"),
        .testTarget(
            name: "HoldTypeOpenAITests",
            dependencies: ["HoldTypeOpenAI"]
        ),
    ]
)
