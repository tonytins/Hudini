// A window with the interface's controls, to look at them and try them by hand.
//
// Usage: hudini-demo [--screenshot <file.png>]
//
// With --screenshot it draws a few frames in a hidden window, saves the last one, and quits,
// so a change can be checked without anyone at the screen.

import Foundation
import Hudini
import Raylib

func drawHudIcon(_ index: Int, _ bounds: Rectangle, _ color: Color) {
    let centerX = Int(bounds.x + (bounds.width / 2))
    let centerY = Int(bounds.y + (bounds.height / 2))
    switch index {
    case 0:
        DrawRectangle(centerX - 4, centerY - 12, 8, 8, color)
        DrawRectangle(centerX - 7, centerY - 2, 14, 12, color)
        DrawRectangle(centerX - 6, centerY + 12, 5, 6, color)
        DrawRectangle(centerX + 1, centerY + 12, 5, 6, color)
    case 1:
        DrawRectangle(centerX - 12, centerY - 10, 24, 4, color)
        DrawRectangle(centerX - 8, centerY - 14, 16, 4, color)
        DrawRectangle(centerX - 4, centerY - 18, 8, 4, color)
        DrawRectangleLinesEx(
            Rectangle(x: Float(centerX - 9), y: Float(centerY - 6), width: 18, height: 20),
            2,
            color
        )
        DrawRectangle(centerX - 3, centerY + 5, 6, 9, color)
    case 2:
        DrawRectangle(centerX - 13, centerY - 2, 8, 16, color)
        DrawRectangle(centerX - 3, centerY - 11, 8, 25, color)
        DrawRectangle(centerX + 7, centerY - 6, 8, 20, color)
    case 3:
        DrawText("$", centerX - 7, centerY - 14, 28, color)
    default:
        DrawRectangle(centerX - 12, centerY - 3, 6, 6, color)
        DrawRectangle(centerX - 3, centerY - 3, 6, 6, color)
        DrawRectangle(centerX + 6, centerY - 3, 6, 6, color)
    }
}

var screenshot: String?
var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    guard argument == "--screenshot", let path = arguments.popFirst() else {
        FileHandle.standardError.write(Data("usage: hudini-demo [--screenshot <file.png>]\n".utf8))
        exit(2)
    }
    screenshot = path
}

SetTraceLogLevel(.warning)
SetConfigFlags(screenshot == nil ? [.windowResizable, .vsyncHint] : [.windowHidden])
InitWindow(960, 600, "Interface Demo")
SetTargetFPS(60)

let theme = InterfaceTheme(
    accent: Color(r: 190, g: 145, b: 255, a: 255),
    panel: Color(r: 25, g: 21, b: 36, a: 235),
    border: Color(r: 83, g: 72, b: 105, a: 255),
    titleBar: Color(r: 43, g: 35, b: 61, a: 245),
    selectedItem: Color(r: 66, g: 52, b: 91, a: 255)
)
let frame = WindowFrame(title: "Settings", theme: theme)
frame.allowsTitleEditing = true
frame.toolbarItems = ["General", "Details"]
frame.selectedToolbarIndex = 0
let name = TextField(text: "Blazing Falls", maximumLength: 32, theme: theme)
let description = TextArea(
    text: "A peaceful place with room to make it your own.",
    maximumLength: 200,
    fontSize: 16,
    width: 380,
    theme: theme
)
// ConfirmPanel keeps no open state: it's updated and drawn only while it asks something.
enum Question { case close, apply }
let confirm = ConfirmPanel(theme: theme)
var asking: Question?
let notice = NoticePanel(theme: theme)
let buttons = ["Cancel", "Apply"]
let hudModeCount = 5
var selectedHudMode = 0
let hudPanelHeight: Float = 84
let hudPanelInset: Float = 12
let form = FormLayout(
    fields: [
        .init(label: "Name", control: name),
        .init(label: "Description", control: description)
    ],
    footerHeight: Float(ButtonRow.rowHeight + 10)
)
var focusOnName = true

var frames = 0
var running = true
while running && !WindowShouldClose() {
    let bounds = frame.place(size: Vector2(x: 420, y: 300), at: Vector2(x: 60, y: 60))
    let content = WindowFrame.content(in: bounds)
    form.layout(in: content)
    let mouse = GetMousePosition()
    let screenBounds = Rectangle(
        x: 0,
        y: 0,
        width: Float(GetScreenWidth()),
        height: Float(GetScreenHeight())
    )
    let hudPanelBounds = Rectangle(
        x: hudPanelInset,
        y: screenBounds.height - hudPanelHeight - hudPanelInset,
        width: max(0, screenBounds.width - (hudPanelInset * 2)),
        height: hudPanelHeight
    )

    if let question = asking {
        switch confirm.update() {
        case .confirmed:
            asking = nil
            if question == .close {
                running = false
            } else {
                notice.show(title: "Saved", message: "\(name.text) is saved.")
            }
        case .cancelled:
            asking = nil
        default:
            break
        }
    } else if !notice.isOpen {
        let clickedHudMode = IsMouseButtonPressed(.left)
            ? IconToolbar.buttonIndex(at: mouse, itemCount: hudModeCount, in: hudPanelBounds)
            : nil
        if let clickedHudMode {
            selectedHudMode = clickedHudMode
        } else {
            _ = frame.followPointer(in: bounds)
            switch frame.update(in: bounds) {
            case .close:
                confirm.ask(title: "Close", message: "Close settings without saving?", confirmTitle: "Close", cancelTitle: "Keep")
                asking = .close
            case .toolbarItemSelected: frame.selectedToolbarIndex = frame.clickedToolbarIndex
            default: break
            }
            if IsMouseButtonPressed(.left) {
                if CheckCollisionPointRec(mouse, name.bounds) { focusOnName = true }
                if CheckCollisionPointRec(mouse, description.bounds) { focusOnName = false }
                if ButtonRow.buttonIndex(at: mouse, endingAt: form.buttonRowCorner, labels: buttons) == 1 {
                    confirm.ask(title: "Apply", message: "Save the changes to \(name.text)?", confirmTitle: "Save", cancelTitle: "Back")
                    asking = .apply
                }
            }
            _ = focusOnName ? name.update() : description.update()
        }
    }
    _ = notice.update()

    BeginDrawing()
    ClearBackground(Color(r: 54, g: 84, b: 120, a: 255))
    DrawRectangleRec(hudPanelBounds, theme.panel)
    DrawRectangleLinesEx(hudPanelBounds, 1, theme.border)
    frame.draw(in: bounds)
    form.drawLabels(theme: theme)
    name.draw(isFocused: focusOnName)
    description.draw(isFocused: !focusOnName)
    ButtonRow.draw(labels: buttons, endingAt: form.buttonRowCorner, mousePosition: mouse, theme: theme)
    IconToolbar.draw(
        itemCount: hudModeCount,
        selectedIndex: selectedHudMode,
        mousePosition: mouse,
        in: hudPanelBounds,
        theme: theme,
        showsBackground: false,
        drawIcon: drawHudIcon
    )
    if asking != nil { confirm.draw() }
    notice.draw()
    EndDrawing()

    frames += 1
    if let screenshot, frames == 3 {
        // TakeScreenshot only writes into the working directory; this takes any path.
        let image = LoadImageFromScreen()
        let saved = ExportImage(image, screenshot)
        UnloadImage(image)
        CloseWindow()
        exit(saved ? 0 : 1)
    }
}
CloseWindow()
