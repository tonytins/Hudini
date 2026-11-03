// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Hudini",
    products: [
        .library(name: "Hudini", targets: ["Hudini"]),
        .executable(name: "hudini-demo", targets: ["hudini-demo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tonytins/raylib-swift", branch: "main"),
    ],
    targets: [
        .target(name: "Hudini", dependencies: [.product(name: "Raylib", package: "raylib-swift")]),
        .executableTarget(
            name: "hudini-demo",
            dependencies: ["Hudini", .product(name: "Raylib", package: "raylib-swift")],
            resources: [
                .copy("Resources/chatdialog.json"),
                .copy("Resources/livepanel1024.json")
            ]
        ),
        .testTarget(name: "HudiniTests", dependencies: ["Hudini", .product(name: "Raylib", package: "raylib-swift")]),
    ],
    swiftLanguageModes: [.v6]
)
