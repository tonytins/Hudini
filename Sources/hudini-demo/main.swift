// A JSON-driven property-chat example host.
//
// Usage: hudini-demo [--screenshot <file.png>]

import Foundation
import Hudini
import Raylib

let theme = InterfaceTheme(
    panel: Color(r: 25, g: 21, b: 36, a: 255),
    border: Color(r: 83, g: 72, b: 105, a: 255),
    titleBar: Color(r: 43, g: 35, b: 61, a: 255)
)

func loadUIScript() throws -> UIScript {
    guard let url = Bundle.module.url(forResource: "chatdialog", withExtension: "json") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try UIScript(contentsOf: url)
}

func text(in value: UIScript.Text?) -> String {
    guard let value else {
        return ""
    }
    switch value {
    case let .literal(text), let .string(text):
        return text
    }
}

func pixel(_ value: Float) -> Int {
    Int(value)
}

func draw(
    _ script: UIScript,
    at origin: Vector2,
    theme: InterfaceTheme
) {
    for control in script.controls {
        let frame = control.frame.rectangle(at: origin)
        let style = script.style(for: control)
        let textColor = style?.textColor ?? theme.text
        let backgroundColor = style?.backgroundColor ?? theme.panel
        let borderColor = style?.borderColor ?? theme.border
        let fontSize = style?.fontSize ?? 14
        let content = text(in: control.text)

        switch control.type {
        case .text, .formattedText:
            if case .formattedText = control.type {
                DrawRectangleRec(frame, backgroundColor)
            }
            for (line, value) in content.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                DrawText(
                    String(value),
                    pixel(frame.x) + 6,
                    pixel(frame.y) + 6 + (line * (fontSize + 4)),
                    fontSize,
                    textColor
                )
            }
        case .button:
            DrawRectangleRec(frame, backgroundColor)
            DrawRectangleLinesEx(frame, 1, borderColor)
            let width = MeasureText(content, fontSize)
            DrawText(
                content,
                pixel(frame.x + ((frame.width - Float(width)) / 2)),
                pixel(frame.y + ((frame.height - Float(fontSize)) / 2)),
                fontSize,
                textColor
            )
        case .textField:
            DrawRectangleRec(frame, backgroundColor)
            DrawRectangleLinesEx(frame, 1, borderColor)
            DrawText(
                content,
                pixel(frame.x) + 6,
                pixel(frame.y + ((frame.height - Float(fontSize)) / 2)),
                fontSize,
                textColor
            )
        case .list, .slider:
            DrawRectangleRec(frame, backgroundColor)
            DrawRectangleLinesEx(frame, 1, borderColor)
        }
    }
}

func drawPropertyLot() {
    let width = GetScreenWidth()
    let height = GetScreenHeight()
    ClearBackground(Color(r: 116, g: 173, b: 212, a: 255))
    DrawRectangle(0, height / 2, width, height / 2, Color(r: 91, g: 148, b: 85, a: 255))
    DrawRectangle(0, height - 90, width, 90, Color(r: 177, g: 157, b: 120, a: 255))
    DrawRectangle(0, height - 83, width, 3, Color(r: 219, g: 203, b: 164, a: 255))
    DrawRectangle(70, height - 238, 210, 150, Color(r: 222, g: 206, b: 174, a: 255))
    DrawRectangle(52, height - 251, 246, 20, Color(r: 112, g: 69, b: 58, a: 255))
    DrawRectangle(148, height - 166, 52, 78, Color(r: 92, g: 68, b: 52, a: 255))
    DrawRectangle(91, height - 206, 38, 40, Color(r: 101, g: 165, b: 198, a: 255))
    DrawRectangle(219, height - 206, 38, 40, Color(r: 101, g: 165, b: 198, a: 255))
    DrawCircle(380, height - 107, 18, Color(r: 69, g: 132, b: 75, a: 255))
    DrawRectangle(375, height - 105, 10, 34, Color(r: 112, g: 78, b: 53, a: 255))
    DrawCircle(465, height - 107, 20, Color(r: 75, g: 140, b: 80, a: 255))
    DrawRectangle(460, height - 105, 10, 34, Color(r: 112, g: 78, b: 53, a: 255))
    DrawCircle(530, height - 108, 8, Color(r: 236, g: 197, b: 160, a: 255))
    DrawRectangle(525, height - 100, 10, 29, Color(r: 70, g: 100, b: 176, a: 255))
    DrawText("Maya is visiting", 543, height - 123, 14, Color(r: 28, g: 38, b: 48, a: 255))
    DrawText("PROPERTY CHAT  |  EXAMPLE HOST", 20, 20, 16, Color(r: 255, g: 255, b: 255, a: 255))
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

let script: UIScript
do {
    script = try loadUIScript()
} catch {
    FileHandle.standardError.write(Data("Unable to load chatdialog.json: \(error.localizedDescription)\n".utf8))
    exit(1)
}

guard let historyControl = script.controls.first(where: { $0.name == "chatHistory" }),
      let entryControl = script.controls.first(where: { $0.name == "chatEntry" }),
      let scrollUpControl = script.controls.first(where: { $0.name == "scrollUp" }),
      let scrollDownControl = script.controls.first(where: { $0.name == "scrollDown" }),
      let sliderControl = script.controls.first(where: { $0.name == "chatHistorySlider" }) else {
    FileHandle.standardError.write(Data("chatdialog.json is missing a required property-chat control\n".utf8))
    exit(1)
}

let initialMessages = [
    "Maya: Welcome to the neighborhood!",
    "Jordan: Your garden looks great.",
    "System: Maya is visiting the property.",
    "Maya: I was hoping to meet the new neighbor.",
    "You: Thanks for stopping by!",
    "Jordan: We are having a garden party this weekend.",
    "Maya: Would you like to come?",
    "System: Jordan is online.",
    "You: That sounds like fun!",
    "Maya: I'll tell everyone you are coming."
]
let residentReplies = [
    "That sounds like a lovely idea.",
    "I'll come by again soon!",
    "It's nice having friendly neighbors."
]
let historyStyle = script.style(for: historyControl)
var chatMessages = initialMessages
let history = TextList(
    items: chatMessages,
    fontSize: historyStyle?.fontSize ?? 14,
    theme: theme,
    textColor: historyStyle?.textColor,
    backgroundColor: historyStyle?.backgroundColor,
    borderColor: historyStyle?.borderColor
)
let entryStyle = script.style(for: entryControl)
let entry = TextField(
    maximumLength: 120,
    fontSize: entryStyle?.fontSize ?? 14,
    theme: theme,
    placeholder: text(in: entryControl.placeholder),
    textColor: entryStyle?.textColor,
    backgroundColor: entryStyle?.backgroundColor,
    borderColor: entryStyle?.borderColor
)
var residentReplyIndex = 0

SetTraceLogLevel(.warning)
SetConfigFlags(screenshot == nil ? [.windowResizable, .vsyncHint] : [.windowHidden])
InitWindow(960, 600, "Hudini Chat Dialog")
SetExitKey(.null)
SetTargetFPS(60)

let window = WindowFrame(title: "Maple Street - Property Chat", theme: theme)
var frameCount = 0
var running = true

while running && !WindowShouldClose() {
    let size = Vector2(x: script.window.size.width, y: script.window.size.height)
    let origin = Vector2(
        x: (Float(GetScreenWidth()) - size.x) / 2,
        y: (Float(GetScreenHeight()) - size.y) / 2
    )
    let bounds = window.place(size: size, at: origin)
    _ = window.followPointer(in: bounds)
    if case .close = window.update(in: bounds) {
        running = false
    }
    let controlOrigin = Vector2(x: bounds.x, y: bounds.y)
    let historyBounds = historyControl.frame.rectangle(at: controlOrigin)
    let entryBounds = entryControl.frame.rectangle(at: controlOrigin)
    history.update(
        in: historyBounds,
        scrollUpButton: scrollUpControl.frame.rectangle(at: controlOrigin),
        scrollDownButton: scrollDownControl.frame.rectangle(at: controlOrigin)
    )
    if case let .submitted(message)? = entry.update(in: entryBounds) {
        chatMessages.append("You: \(message)")
        chatMessages.append("Maya: \(residentReplies[residentReplyIndex])")
        history.items = chatMessages
        residentReplyIndex = (residentReplyIndex + 1) % residentReplies.count
    }

    BeginDrawing()
    drawPropertyLot()
    window.draw(in: bounds)
    draw(script, at: controlOrigin, theme: theme)
    history.draw(in: historyBounds)
    DrawRectangleRec(
        history.scrollThumbBounds(in: sliderControl.frame.rectangle(at: controlOrigin)),
        theme.accent
    )
    entry.draw(in: entryBounds, isFocused: entry.isFocused)
    EndDrawing()

    frameCount += 1
    if let screenshot, frameCount == 3 {
        let image = LoadImageFromScreen()
        let saved = ExportImage(image, screenshot)
        UnloadImage(image)
        CloseWindow()
        exit(saved ? 0 : 1)
    }
}

CloseWindow()
