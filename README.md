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
- Scrollable plain-text lists
- Tooltips, draggable sliders, and progress bars
- Panels that swap by mode, sit inside each other, or open in their own window
- Confirmation and notice panels
- Button rows with hit testing and enabled states
- A 2D camera with pointer-centered zoom and coordinate conversion
- Declarative, vertically stacked form layout
- Per-interface themes with colors, a font, text sizes, rounded corners, and glossy title bars
- [UIScript](doc/UISCRIPT.md), an XML format describing resources, styles, visuals, and controls
- `UIScriptView`, which builds, updates, and draws a document's controls
- Readers for Maxis' `.uis` interface files and `.cst` text tables

## Requirements

- Swift 6.2 or later
- [raylib-swift](https://github.com/tonytins/raylib-swift)

Building raylib-swift requires the native development libraries for raylib's
selected platform backend. On Linux, running a program that uses UIScript also
requires `libxml2.so.2`, which `FoundationXML` links at runtime.

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

Prefer describing screens in [UIScript](doc/UISCRIPT.md) over hardcoding them. The
layout stays out of your game code, so moving a control means changing one
attribute in one file, and your code only deals with what the controls mean.

Describe the screen in an XML file, such as `settings.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<UIScript version="1">
  <Window width="360" height="130"/>

  <Text name="nameLabel" x="12" y="14" width="336" height="14" text="Player name"/>
  <TextField name="playerName" x="12" y="34" width="336" height="32"
             text="Player" maximumLength="24" placeholder="Your name"/>
  <Button name="save" x="268" y="84" width="80" height="30" text="Save"/>
</UIScript>
```

Then load it and handle what it reports. Create the raylib window before
constructing or drawing the interface, and use one theme value across the
components in a screen:

```swift
import Foundation
import Hudini
import Raylib

InitWindow(800, 600, "Game")
SetExitKey(.null)

let theme = InterfaceTheme(
    accent: Color(r: 120, g: 180, b: 240, a: 255)
)
let script = try UIScript(contentsOf: URL(fileURLWithPath: "settings.xml"))
let view = UIScriptView(script: script, theme: theme)
let window = WindowFrame(title: "Settings", theme: theme)

// Open ready for typing, without a click on the field first.
view.textField(named: "playerName")?.setFocused(true)

while !WindowShouldClose() {
    let bounds = window.place(
        size: Vector2(
            x: script.window.size.width,
            y: script.window.size.height + Float(WindowFrame.titleHeight)
        ),
        at: Vector2(x: 40, y: 40)
    )
    let content = WindowFrame.content(in: bounds)
    let origin = Vector2(x: content.x, y: content.y)

    _ = window.followPointer(in: bounds)
    if window.update(in: bounds) == .close {
        break
    }
    for event in view.update(at: origin) {
        if event == .pressed(control: "save") {
            print("Saved \(view.text(named: "playerName") ?? "")")
        }
    }

    BeginDrawing()
    ClearBackground(Color(r: 54, g: 84, b: 120, a: 255))
    window.draw(in: bounds)
    view.draw(at: origin)
    EndDrawing()
}

CloseWindow()
```

raylib closes the window on Escape by default. `SetExitKey(.null)` turns that off
so Escape can cancel title edits and dismiss panels instead of quitting the game.

### Fonts and text sizes

A theme draws in raylib's default font unless you give it another. Your game owns the
font, so load it after `InitWindow` and unload it before `CloseWindow`:

```swift
let font = LoadFontEx("ui.ttf", 32, nil, 0)
guard IsFontValid(font) else {
    fatalError("Couldn't load ui.ttf")
}
SetTextureFilter(font.texture, .bilinear)
let theme = InterfaceTheme(
    font: font,
    textSizes: .init(title: 18, button: 16, input: 16)
)
// ...
UnloadFont(font)
CloseWindow()
```

A theme given a font that failed to load draws in the default font instead, so check
it with `IsFontValid` as above. A different font changes text widths, so check your
layouts after switching. Use one theme for every component in a screen.

### Corners and title bars

Controls have square corners and flat title bars unless the theme says otherwise:

```swift
SetConfigFlags(.msaa4xHint) // Before InitWindow, for smooth curves.
InitWindow(800, 600, "Game")

let theme = InterfaceTheme(
    titleBar: Color(r: 92, g: 112, b: 142, a: 245),
    titleBarBottom: Color(r: 30, g: 40, b: 58, a: 245),
    cornerRadius: 8
)
```

The radius is in pixels, and a shape too small for it uses the largest radius that
fits. Clicks still land on the whole rectangle, including just outside a corner.

### Building controls in code

Every control also works on its own, which suits something small or a layout your
game works out at runtime, such as a form with a varying number of fields:

```swift
import Hudini
import Raylib

InitWindow(800, 600, "Game")
SetExitKey(.null)

let theme = InterfaceTheme(
    accent: Color(r: 120, g: 180, b: 240, a: 255)
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
    playerName.draw()
    EndDrawing()
}

CloseWindow()
```

### More examples

See [`Sources/hudini-demo`](Sources/hudini-demo) for a runnable example: a
property chat window over a control panel with live, statistics, and options modes,
all loaded from UIScript XML. Click the lemonade stand on the lot to open its panel,
read from an original `.uis` file, which can sit in the live panel or in its own
window. An auto-hiding debug bar, also from a `.uis` file, waits at the top of the
screen. The demo host owns all the game state and images, and it generates
placeholder art because Hudini ships no game assets.

See [the documentation](doc/README.md) for the format, roadmap, and where Hudini
came from.

## Supported Versions

| Hudini | Minimum Swift version |
| --- | --- |
| Current | 6.2 |

## License

I license the source code under the BSD-3-Clause license. See [LICENSE](LICENSE)
for details.
