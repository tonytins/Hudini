// An example host: a property chat window over a live mode panel, both described by UIScript.
//
// Usage: hudini-demo [--screenshot <file.png>]

import Foundation
import Hudini
import Raylib

let theme = InterfaceTheme.standard

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

func loadUIScript(named name: String) -> UIScript {
    do {
        guard let url = Bundle.module.url(forResource: name, withExtension: "xml") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try UIScript(contentsOf: url)
    } catch {
        fail("Unable to load \(name).xml: \(error.localizedDescription)")
    }
}

func drawPropertyLot(groundBottom height: Int32) {
    let width = GetScreenWidth()
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
    DrawText("LIVE MODE  |  EXAMPLE HOST", 20, 20, 16, Color(r: 255, g: 255, b: 255, a: 255))
}

/// Generates original placeholder art, because Hudini ships no game assets.
///
/// Controls without a size take it from these images, so their sizes shape the panel.
/// A four-state image holds its slices left to right: normal, pressed, hovered, disabled.
func makePlaceholderTexture(for resource: UIScript.ImageResource) -> Texture2D {
    let path = resource.path ?? ""
    guard resource.stateCount == 4 else {
        let (width, height) = placeholderSize(forPath: path)
        var image = GenImageColor(width, height, placeholderColor(forPath: path))
        defer { UnloadImage(image) }
        ImageDrawRectangle(&image, 0, 0, width, 2, Color(r: 255, g: 255, b: 255, a: 60))
        return LoadTextureFromImage(image)
    }
    let sliceSize = placeholderSliceSize(forPath: path)
    let markSize = sliceSize / 3
    let stateColors = [
        Color(r: 74, g: 104, b: 142, a: 255),
        Color(r: 40, g: 62, b: 92, a: 255),
        Color(r: 112, g: 150, b: 196, a: 255),
        Color(r: 70, g: 72, b: 78, a: 255)
    ]
    var image = GenImageColor(sliceSize * 4, sliceSize, .black)
    defer { UnloadImage(image) }
    for (slice, color) in stateColors.enumerated() {
        let x = Int32(slice) * sliceSize
        ImageDrawRectangle(&image, x, 0, sliceSize, sliceSize, color)
        ImageDrawRectangle(&image, x + markSize, markSize, markSize, markSize, Color(r: 255, g: 249, b: 157, a: 255))
    }
    return LoadTextureFromImage(image)
}

func placeholderSize(forPath path: String) -> (width: Int32, height: Int32) {
    if path.contains("mood") {
        return (30, 30)
    }
    if path.contains("divider") {
        return (2, 100)
    }
    return (490, 60)
}

func placeholderSliceSize(forPath path: String) -> Int32 {
    if path.contains("moodpanel") {
        return 48
    }
    return path.contains("PageBtn") ? 24 : 23
}

func placeholderColor(forPath path: String) -> Color {
    if path.contains("moodPositive") {
        return Color(r: 76, g: 175, b: 96, a: 255)
    }
    if path.contains("moodNegative") {
        return Color(r: 201, g: 82, b: 74, a: 255)
    }
    if path.contains("divider") {
        return Color(r: 96, g: 118, b: 148, a: 255)
    }
    return Color(r: 45, g: 62, b: 84, a: 255)
}

// The host's own localized text and game state.

let panelStrings = [3: "Needs"]
let needNames = ["Hunger", "Comfort", "Hygiene", "Bladder", "Energy", "Fun", "Social", "Room"]
let needLevels: [Float] = [0.8, 0.55, 0.9, 0.35, 0.65, 0.5, 0.75, 0.6]
let residents = [
    "Maya", "Jordan", "Sam", "Riley", "Alex", "Casey", "Drew", "Taylor", "Morgan", "Quinn",
    "Avery", "Parker", "Reese", "Rowan", "Skyler", "Emery", "Finley", "Harper", "Jules", "Kai"
]
let peoplePerPage = 16
let peopleMarginX: Float = 12
let peopleMarginY: Float = 11
let lastPeoplePage = (residents.count - 1) / peoplePerPage
var peoplePage = 0

@MainActor
func drawNeeds(in bounds: Rectangle) {
    let columnWidth = bounds.width / 2
    let rowHeight = bounds.height / 4
    for (index, name) in needNames.enumerated() {
        let x = bounds.x + (Float(index % 2) * columnWidth)
        let y = bounds.y + (Float(index / 2) * rowHeight)
        DrawText(name, Int(x), Int(y), 10, Color(r: 255, g: 249, b: 157, a: 255))
        let bar = Rectangle(x: x, y: y + 11, width: columnWidth - 10, height: 7)
        DrawRectangleRec(bar, Color(r: 23, g: 33, b: 42, a: 255))
        var level = bar
        level.width *= needLevels[index]
        DrawRectangleRec(level, needLevels[index] < 0.4 ? theme.error : Color(r: 76, g: 175, b: 96, a: 255))
    }
}

@MainActor
func drawPeople(in bounds: Rectangle) {
    let first = peoplePage * peoplePerPage
    let onPage = residents[first..<min(first + peoplePerPage, residents.count)]
    let spacing = (bounds.width - peopleMarginX) / Float(peoplePerPage)
    for (offset, resident) in onPage.enumerated() {
        let hue = Float((first + offset) * 47 % 360)
        DrawCircle(
            Int(bounds.x + peopleMarginX + (Float(offset) * spacing)),
            Int(bounds.y + peopleMarginY),
            10,
            ColorFromHSV(hue, 0.45, 0.85)
        )
        DrawText(
            String(resident.prefix(1)),
            Int(bounds.x + peopleMarginX + (Float(offset) * spacing)) - 3,
            Int(bounds.y + peopleMarginY) - 5,
            10,
            Color(r: 23, g: 33, b: 42, a: 255)
        )
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

let chatScript = loadUIScript(named: "chatdialog")
let panelScript = loadUIScript(named: "livepanel1024")

SetTraceLogLevel(.warning)
SetConfigFlags(screenshot == nil ? [.windowResizable, .vsyncHint] : [.windowHidden])
InitWindow(1024, 768, "Hudini Live Mode")
SetExitKey(.null)
SetTargetFPS(60)

var placeholderTextures: [Texture2D] = []
let chat = UIScriptView(script: chatScript, theme: theme)
let panel = UIScriptView(
    script: panelScript,
    theme: theme,
    resolveString: { panelStrings[$0.index] ?? "" },
    loadImage: { resource in
        let texture = makePlaceholderTexture(for: resource)
        placeholderTextures.append(texture)
        return texture
    }
)

guard let history = chat.list(named: "chatHistory"),
      chat.textField(named: "chatEntry") != nil else {
    fail("chatdialog.xml is missing a required property-chat control")
}
guard let statusMessage = panel.list(named: "statusBarMessageWindow"),
      let statusTimer = panel.textField(named: "statusBarTimerEntry"),
      panelScript.control(named: "previousPage") != nil,
      panelScript.control(named: "nextPage") != nil else {
    fail("livepanel1024.xml is missing a required live-panel control")
}

// The panel's work-session controls overlap its status bar, so only one set shows at a time.
for name in ["eodHelp", "eodClose", "eodExpand", "eodContract", "timerEntry", "messageWindow"] {
    panel.setHidden(true, named: name)
}
statusMessage.items = ["Maya is visiting"]
statusTimer.text = "08:00"

@MainActor
func showPeoplePage(_ page: Int) {
    peoplePage = min(max(page, 0), lastPeoplePage)
    panel.setDisabled(peoplePage == 0, named: "previousPage")
    panel.setDisabled(peoplePage == lastPeoplePage, named: "nextPage")
}
showPeoplePage(0)

var chatMessages = [
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
history.items = chatMessages
var residentReplyIndex = 0

let window = WindowFrame(title: "Maple Street - Property Chat", theme: theme)
var frameCount = 0
var running = true
var screenshotSaved = true

while running && !WindowShouldClose() {
    let panelHeight = panelScript.window.size.height
    let panelTop = Float(GetScreenHeight()) - panelHeight
    let chatSize = Vector2(x: chatScript.window.size.width, y: chatScript.window.size.height)
    let bounds = window.place(
        size: chatSize,
        at: Vector2(x: (Float(GetScreenWidth()) - chatSize.x) / 2, y: (panelTop - chatSize.y) / 2)
    )
    _ = window.followPointer(in: bounds)
    if case .close = window.update(in: bounds) {
        running = false
    }

    let chatOrigin = Vector2(x: bounds.x, y: bounds.y)
    for case let .submitted(control: "chatEntry", text: message) in chat.update(at: chatOrigin) {
        chatMessages.append("You: \(message)")
        chatMessages.append("Maya: \(residentReplies[residentReplyIndex])")
        history.items = chatMessages
        residentReplyIndex = (residentReplyIndex + 1) % residentReplies.count
    }

    let panelOrigin = Vector2(x: 0, y: panelTop)
    for event in panel.update(at: panelOrigin) {
        switch event {
        case .pressed(control: "previousPage"):
            showPeoplePage(peoplePage - 1)
        case .pressed(control: "nextPage"):
            showPeoplePage(peoplePage + 1)
        default:
            break
        }
    }

    BeginDrawing()
    drawPropertyLot(groundBottom: Int32(panelTop))
    DrawRectangle(0, Int32(panelTop), GetScreenWidth(), Int32(panelHeight), theme.titleBar)
    panel.draw(at: panelOrigin) { name, regionBounds in
        switch name {
        case "motives":
            drawNeeds(in: regionBounds)
        case "peopleList":
            drawPeople(in: regionBounds)
        default:
            break
        }
    }
    window.draw(in: bounds)
    chat.draw(at: chatOrigin)
    EndDrawing()

    frameCount += 1
    if let screenshot, frameCount == 3 {
        let image = LoadImageFromScreen()
        screenshotSaved = ExportImage(image, screenshot)
        UnloadImage(image)
        running = false
    }
}

for texture in placeholderTextures {
    UnloadTexture(texture)
}
CloseWindow()
if !screenshotSaved {
    exit(1)
}
