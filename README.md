# Hudini 🪄

Hudini (HUD + Houdini) is a Swift interface library for games built with
[raylib-swift](https://github.com/tonytins/raylib-swift). It provides reusable
window frames, text controls, modal panels, a 2D viewport camera, and lightweight
form layout.

## Features

- Draggable windows with merged title bars and selectable toolbar items
- Bottom-left icon toolbar with host-owned selection and custom icon drawing
- Editable window titles with optional validation
- Single-line and multiline text fields
- Confirmation and notice panels
- Button rows with hit testing and enabled states
- A 2D camera with pointer-centered zoom and coordinate conversion
- Declarative, vertically stacked form layout
- Per-interface color themes
- Initial JSON UIScript decoding for named resources, styles, visuals, and controls

## Requirements

- Swift 6.2 or later
- [raylib-swift](https://github.com/tonytins/raylib-swift)

Building raylib-swift requires the native development libraries for raylib's
selected platform backend.

## Installation

Add Hudini and raylib-swift to your package dependencies. Add both products to
the target that uses the library:

```swift
let package = Package(
    name: "Game",
    dependencies: [
        .package(url: "https://github.com/tonytins/Hudini.git", branch: "main"),
        .package(url: "https://github.com/tonytins/raylib-swift", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "Game",
            dependencies: [
                .product(name: "Hudini", package: "hudini"),
                .product(name: "Raylib", package: "raylib-swift"),
            ]
        ),
    ]
)
```

Once Hudini publishes versioned releases, prefer a version requirement over
tracking the `main` branch.

## Example

Create the raylib window before constructing or drawing the interface. Use one
theme value across the components in a screen, then lay out fields against the
window's content bounds:

```swift
import Hudini
import Raylib

InitWindow(800, 600, "Game")

let theme = InterfaceTheme(
    accent: Color(r: 190, g: 145, b: 255, a: 255)
)
let window = WindowFrame(title: "Settings", theme: theme)
let playerName = TextField(
    text: "Player",
    maximumLength: 24,
    theme: theme
)
let layout = FormLayout(
    fields: [
        .init(label: "Player name", control: playerName),
    ]
)

while !WindowShouldClose() {
    let bounds = window.place(
        size: Vector2(x: 360, y: 180),
        at: Vector2(x: 40, y: 40)
    )
    let content = WindowFrame.content(in: bounds)
    layout.layout(in: content)

    _ = window.followPointer(in: bounds)
    _ = playerName.update()

    BeginDrawing()
    ClearBackground(Color(r: 54, g: 84, b: 120, a: 255))
    window.draw(in: bounds)
    layout.drawLabels(theme: theme)
    playerName.draw(isFocused: true)
    EndDrawing()
}

CloseWindow()
```

See [`Sources/hudini-demo`](Sources/hudini-demo) for a runnable, JSON-driven
chat-window preview. It demonstrates basic rendering from the initial UIScript
model with placeholder content; it is not yet a full UIScript renderer or a
TSO `.uis` compatibility implementation.

The demo also includes an unwired [`livepanel1024.json`](Sources/hudini-demo/Resources/livepanel1024.json)
draft based on the TSO live mode panel. It is a broader format example, not
currently loaded or rendered by the demo.

## Supported Versions

| Hudini | Minimum Swift version |
| --- | --- |
| Current | 6.2 |

## License

I license the source code under the BSD-3-Clause license. See [LICENSE](LICENSE)
for details.
