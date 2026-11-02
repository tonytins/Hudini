// A window with the interface's controls, to look at them and try them by hand.
//
// Usage: hudini-demo [--screenshot <file.png>]
//
// With --screenshot it draws a few frames in a hidden window, saves the last one, and quits,
// so a change can be checked without anyone at the screen.

import Foundation
import Hudini
import Raylib

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
let formFields = [
    FormLayout.Field(label: "Name", controlHeight: Float(name.height)),
    FormLayout.Field(label: "Description", controlHeight: Float(description.height(forLineCount: 4)))
]
let form = FormLayout(
    fields: formFields,
    footerHeight: Float(ButtonRow.rowHeight + 10)
)
var focusOnName = true

var frames = 0
var running = true
while running && !WindowShouldClose() {
    let bounds = frame.place(size: Vector2(x: 420, y: 300), at: Vector2(x: 60, y: 60))
    let content = WindowFrame.content(in: bounds)
    form.layout(in: content)
    let nameBounds = form.fields[0].controlBounds
    let descriptionBounds = form.fields[1].controlBounds
    let mouse = GetMousePosition()

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
        _ = frame.followPointer(in: bounds)
        switch frame.update(in: bounds) {
        case .close:
            confirm.ask(title: "Close", message: "Close settings without saving?", confirmTitle: "Close", cancelTitle: "Keep")
            asking = .close
        case .toolbarItemSelected: frame.selectedToolbarIndex = frame.clickedToolbarIndex
        default: break
        }
        if IsMouseButtonPressed(.left) {
            if CheckCollisionPointRec(mouse, nameBounds) { focusOnName = true }
            if CheckCollisionPointRec(mouse, descriptionBounds) { focusOnName = false }
            if ButtonRow.buttonIndex(at: mouse, endingAt: form.buttonRowCorner, labels: buttons) == 1 {
                confirm.ask(title: "Apply", message: "Save the changes to \(name.text)?", confirmTitle: "Save", cancelTitle: "Back")
                asking = .apply
            }
        }
        _ = focusOnName ? name.update() : description.update()
    }
    _ = notice.update()

    BeginDrawing()
    ClearBackground(Color(r: 54, g: 84, b: 120, a: 255))
    frame.draw(in: bounds)
    form.drawLabels(theme: theme)
    name.draw(in: nameBounds, isFocused: focusOnName)
    description.draw(in: descriptionBounds, isFocused: !focusOnName)
    ButtonRow.draw(labels: buttons, endingAt: form.buttonRowCorner, mousePosition: mouse, theme: theme)
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
