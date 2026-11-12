// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Hudini",
    products: [
        .library(name: "Hudini", targets: ["Hudini"]),
        .executable(name: "hudini-demo", targets: ["hudini-demo"]),
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
        .executableTarget(
            name: "hudini-demo",
            dependencies: [
                "Hudini",
                .product(name: "Raylib", package: "raylib-swift"),
                .product(name: "SwiftCST", package: "swift-cst"),
            ],
            resources: [
                .copy("Resources/chatdialog.uix"),
                .copy("Resources/city"),
                .copy("Resources/debugbar.uis"),
                .copy("Resources/lemonadestand.uis"),
                .copy("Resources/livepanel1024.uix"),
                .copy("Resources/menu.uix"),
                .copy("Resources/movelot.uix"),
                .copy("Resources/optionspanel.uix"),
                .copy("Resources/statspanel.uix"),
                .copy("Resources/uitext")
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
