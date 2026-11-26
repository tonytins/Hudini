// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Hudini",
    products: [
        .library(name: "Hudini", targets: ["Hudini"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tonytins/raylib-swift", branch: "main"),
    ],
    targets: [
        .target(
            name: "Hudini",
            dependencies: [
                .product(name: "Raylib", package: "raylib-swift"),
            ]
        ),
        .testTarget(
            name: "HudiniTests",
            dependencies: [
                "Hudini",
                .product(name: "Raylib", package: "raylib-swift"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
