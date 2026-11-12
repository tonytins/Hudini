// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Hudini",
    products: [
        .library(name: "Hudini", targets: ["Hudini"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tonytins/raylib-swift", branch: "main"),
        .package(url: "https://github.com/tonytins/swift-cst.git", from: "0.3.2"),
    ],
    targets: [
        .target(
            name: "Hudini",
            dependencies: [
                .product(name: "Raylib", package: "raylib-swift"),
                .product(name: "SwiftCST", package: "swift-cst"),
            ]
        ),
        .testTarget(
            name: "HudiniTests",
            dependencies: [
                "Hudini",
                .product(name: "Raylib", package: "raylib-swift"),
                .product(name: "SwiftCST", package: "swift-cst"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
