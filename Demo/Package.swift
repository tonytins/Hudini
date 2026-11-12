// swift-tools-version: 6.3

// Hudini's demos, a package of their own so that games depending on Hudini never see or build them.
// It uses the Hudini checkout it sits in. Run it from the repository's root with
// `swift run --package-path Demo hudini-demo`.

import PackageDescription

let package = Package(
    name: "HudiniDemo",
    dependencies: [
        // The name keeps the product reference below working whatever the checkout's folder is called.
        .package(name: "Hudini", path: ".."),
        .package(url: "https://github.com/tonytins/raylib-swift", branch: "main"),
        .package(url: "https://github.com/tonytins/swift-cst.git", from: "0.3.2"),
    ],
    targets: [
        .executableTarget(
            name: "hudini-demo",
            dependencies: [
                .product(name: "Hudini", package: "Hudini"),
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
    ],
    swiftLanguageModes: [.v6]
)
