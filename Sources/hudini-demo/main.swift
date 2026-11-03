// A JSON-driven chat window preview.
//
// Usage: hudini-demo [--screenshot <file.png>]

import Foundation
import Hudini
import Raylib

func loadUIScript() throws -> UIScript {
    guard let url = Bundle.module.url(forResource: "chatdialog", withExtension: "json") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try UIScript(contentsOf: url)
}

func color(from hex: String?, fallback: Color) -> Color {
    guard let hex else {
        return fallback
    }
    let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard digits.count == 6 || digits.count == 8,
          let value = UInt32(digits, radix: 16) else {
        return fallback
    }
    if digits.count == 6 {
        return Color(
            r: UInt8((value >> 16) & 0xFF),
            g: UInt8((value >> 8) & 0xFF),
            b: UInt8(value & 0xFF),
            a: 255
        )
    }
    return Color(
        r: UInt8((value >> 24) & 0xFF),
        g: UInt8((value >> 16) & 0xFF),
        b: UInt8((value >> 8) & 0xFF),
        a: UInt8(value & 0xFF)
    )
}

func text(in control: UIScript.Control) -> String {
    guard let text = control.text else {
        return ""
    }
    switch text {
    case let .literal(value), let .string(value):
        return value
    }
}

func pixel(_ value: Float) -> Int {
    Int(value)
}

func draw(_ script: UIScript, at origin: Vector2, theme: InterfaceTheme) {
    for control in script.controls {
        let frame = Rectangle(
            x: origin.x + control.frame.x,
            y: origin.y + control.frame.y,
            width: control.frame.width,
            height: control.frame.height
        )
        let style = control.style.flatMap { script.styles[$0] }
        let textColor = color(from: style?.textColor, fallback: theme.text)
        let backgroundColor = color(from: style?.backgroundColor, fallback: theme.panel)
        let borderColor = color(from: style?.borderColor, fallback: theme.border)
        let fontSize = style?.fontSize ?? 14
        let content = text(in: control)

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
        case .list:
            DrawRectangleRec(frame, backgroundColor)
            DrawRectangleLinesEx(frame, 1, borderColor)
        case .slider:
            DrawRectangleRec(frame, backgroundColor)
            DrawRectangleLinesEx(frame, 1, borderColor)
            let thumb = Rectangle(
                x: frame.x + 1,
                y: frame.y + (frame.height * 0.35),
                width: max(0, frame.width - 2),
                height: max(6, frame.height * 0.2)
            )
            DrawRectangleRec(thumb, theme.accent)
        }
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

let script: UIScript
do {
    script = try loadUIScript()
} catch {
    FileHandle.standardError.write(Data("Unable to load chatdialog.json: \(error.localizedDescription)\n".utf8))
    exit(1)
}

SetTraceLogLevel(.warning)
SetConfigFlags(screenshot == nil ? [.windowResizable, .vsyncHint] : [.windowHidden])
InitWindow(960, 600, "Hudini Chat Dialog")
SetTargetFPS(60)

let theme = InterfaceTheme(
    panel: Color(r: 25, g: 21, b: 36, a: 255),
    border: Color(r: 83, g: 72, b: 105, a: 255),
    titleBar: Color(r: 43, g: 35, b: 61, a: 255)
)
let window = WindowFrame(title: "Chat", theme: theme)
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

    BeginDrawing()
    ClearBackground(Color(r: 54, g: 84, b: 120, a: 255))
    window.draw(in: bounds)
    draw(script, at: Vector2(x: bounds.x, y: bounds.y), theme: theme)
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
