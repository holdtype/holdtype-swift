// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "HoldTypePersistence",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "HoldTypePersistence",
            targets: ["HoldTypePersistence"]
        ),
    ],
    dependencies: [
        .package(path: "../HoldTypeDomain"),
    ],
    targets: [
        .target(
            name: "HoldTypePersistence",
            dependencies: [
                .product(name: "HoldTypeDomain", package: "HoldTypeDomain"),
            ]
        ),
        .testTarget(
            name: "HoldTypePersistenceTests",
            dependencies: [
                "HoldTypePersistence",
                .product(name: "HoldTypeDomain", package: "HoldTypeDomain"),
            ]
        ),
    ]
)
