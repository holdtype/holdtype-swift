// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "HoldTypeIOSCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "HoldTypeIOSCore",
            targets: ["HoldTypeIOSCore"]
        ),
    ],
    dependencies: [
        .package(path: "../HoldTypeDomain"),
        .package(path: "../HoldTypeOpenAI"),
        .package(path: "../HoldTypePersistence"),
    ],
    targets: [
        .target(
            name: "HoldTypeIOSCore",
            dependencies: [
                .product(name: "HoldTypeDomain", package: "HoldTypeDomain"),
                .product(name: "HoldTypeOpenAI", package: "HoldTypeOpenAI"),
                .product(
                    name: "HoldTypePersistence",
                    package: "HoldTypePersistence"
                ),
            ]
        ),
        .testTarget(
            name: "HoldTypeIOSCoreTests",
            dependencies: [
                "HoldTypeIOSCore",
                .product(name: "HoldTypeDomain", package: "HoldTypeDomain"),
                .product(name: "HoldTypeOpenAI", package: "HoldTypeOpenAI"),
                .product(
                    name: "HoldTypePersistence",
                    package: "HoldTypePersistence"
                ),
            ]
        ),
    ]
)
