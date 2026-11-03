// An example host: a property chat window over a live mode panel, both described by UIScript XML,
// with an auto-hiding debug bar read from a Maxis-format .uis file.
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

func log(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}

func logProblems(in script: UIScript, file: String) {
    for ignored in script.ignoredAttributes {
        log("\(file) line \(ignored.line): \(ignored.element) ignores '\(ignored.attribute)'")
    }
    for note in script.conversionNotes {
        log("\(file) line \(note.line): \(note.message)")
    }
}

func loadUIScript(named name: String) -> UIScript {
    do {
        guard let url = Bundle.module.url(forResource: name, withExtension: "xml") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let script = try UIScript(contentsOf: url)
        logProblems(in: script, file: "\(name).xml")
        return script
    } catch {
        fail("Unable to load \(name).xml: \(error.localizedDescription)")
    }
}

func loadUIS(named name: String) -> UIScript {
    do {
        guard let url = Bundle.module.url(forResource: name, withExtension: "uis") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let script = try UIScript(uisContentsOf: url)
        logProblems(in: script, file: "\(name).uis")
        return script
    } catch {
        fail("Unable to load \(name).uis: \(error.localizedDescription)")
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
    DrawText("LIVE MODE  |  EXAMPLE HOST", 20, 36, 16, Color(r: 255, g: 255, b: 255, a: 255))
}

/// Generates original placeholder art for a resource, because Hudini ships no game assets.
///
/// Controls without a size take it from these images, so their sizes shape the interface.
/// A multi-state image holds its slices left to right: normal, pressed, hovered, disabled.
func makePlaceholderTexture(for resource: UIScript.ImageResource) -> Texture2D {
    let path = resource.path ?? ""
    if resource.stateCount >= 4 {
        return makeButtonPlaceholder(path: path, stateCount: Int32(resource.stateCount))
    }
    let (width, height) = placeholderSize(forPath: path)
    var image = GenImageColor(width, height, placeholderColor(forPath: path))
    defer { UnloadImage(image) }
    if height > 2 {
        ImageDrawRectangle(&image, 0, 0, width, 2, Color(r: 255, g: 255, b: 255, a: 60))
    }
    return LoadTextureFromImage(image)
}

func makeButtonPlaceholder(path: String, stateCount: Int32) -> Texture2D {
    let sliceSize = placeholderSliceSize(forPath: path)
    var image = GenImageColor(sliceSize * stateCount, sliceSize, placeholderColor(forPath: "bar"))
    defer { UnloadImage(image) }
    for (slice, color) in placeholderStateColors(forPath: path).enumerated() {
        let x = Int32(slice) * sliceSize
        if path.contains("debugSpeedArrow") {
            // A right-pointing triangle, drawn a column at a time.
            for column in 0..<sliceSize {
                let inset = (column * sliceSize) / (2 * sliceSize)
                ImageDrawRectangle(&image, x + column, inset, 1, sliceSize - (inset * 2), color)
            }
        } else if path.contains("debugHelp") {
            ImageDrawCircle(&image, x + (sliceSize / 2), sliceSize / 2, sliceSize / 2, color)
        } else {
            ImageDrawRectangle(&image, x, 0, sliceSize, sliceSize, color)
            let mark = sliceSize / 3
            ImageDrawRectangle(&image, x + mark, mark, mark, mark, Color(r: 255, g: 249, b: 157, a: 255))
        }
    }
    return LoadTextureFromImage(image)
}

func placeholderStateColors(forPath path: String) -> [Color] {
    if path.contains("debugSpeedArrow") {
        return [
            Color(r: 217, g: 217, b: 217, a: 255),
            Color(r: 62, g: 110, b: 190, a: 255),
            Color(r: 255, g: 255, b: 255, a: 255),
            Color(r: 120, g: 120, b: 120, a: 255)
        ]
    }
    if path.contains("debugHelp") {
        return [
            Color(r: 74, g: 138, b: 66, a: 255),
            Color(r: 50, g: 100, b: 44, a: 255),
            Color(r: 100, g: 170, b: 90, a: 255),
            Color(r: 90, g: 90, b: 90, a: 255)
        ]
    }
    return [
        Color(r: 74, g: 104, b: 142, a: 255),
        Color(r: 40, g: 62, b: 92, a: 255),
        Color(r: 112, g: 150, b: 196, a: 255),
        Color(r: 70, g: 72, b: 78, a: 255)
    ]
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
    if path.contains("debugBackground") || path == "bar" {
        return Color(r: 59, g: 59, b: 59, a: 255)
    }
    return Color(r: 45, g: 62, b: 84, a: 255)
}

func placeholderSize(forPath path: String) -> (width: Int32, height: Int32) {
    if path.contains("mood") {
        return (30, 30)
    }
    if path.contains("divider") {
        return (2, 100)
    }
    if path.contains("debugBackground") {
        return (2, 2)
    }
    return (490, 60)
}

func placeholderSliceSize(forPath path: String) -> Int32 {
    if path.contains("moodPanel") {
        return 48
    }
    if path.contains("debugSpeedArrow") {
        return 14
    }
    if path.contains("debugHelp") {
        return 20
    }
    return path.contains("Page") ? 24 : 23
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
let barScript = loadUIS(named: "debugbar")

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
let bar = UIScriptView(
    script: barScript,
    theme: theme,
    loadImage: { resource in
        let texture = makePlaceholderTexture(for: resource)
        placeholderTextures.append(texture)
        return texture
    }
)
let notice = NoticePanel(theme: theme)

guard let history = chat.list(named: "chatHistory"),
      chat.textField(named: "chatEntry") != nil else {
    fail("chatdialog.xml is missing a required property-chat control")
}
guard let statusMessage = panel.list(named: "statusBarMessageWindow"),
      panel.textField(named: "statusBarTimerEntry") != nil,
      panelScript.control(named: "previousPage") != nil,
      panelScript.control(named: "nextPage") != nil else {
    fail("livepanel1024.xml is missing a required live-panel control")
}
let barSpeedButtons = ["SpeedSlow", "SpeedMedium", "SpeedFast"]
let requiredBarControls = barSpeedButtons + ["LotName", "GameClock", "FloorName", "ObjectCount", "ErrorCount", "HelpButton"]
guard requiredBarControls.allSatisfy({ barScript.control(named: $0) != nil }) else {
    fail("debugbar.uis is missing a required control")
}

// The panel's work-session controls overlap its status bar, so only one set shows at a time.
for name in ["eodHelp", "eodClose", "eodExpand", "eodContract", "timerEntry", "messageWindow"] {
    panel.setHidden(true, named: name)
}
statusMessage.items = ["Maya is visiting"]

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

// The debug bar's state. One real second is one game minute at the slowest speed.
let speedRates: [Double] = [1, 2, 4]
var speedIndex = 0
var gameMinutes: Double = 8 * 60
var simulatedErrors: [String] = []
var nextSimulatedError: Double = 60

// How far the bar has slid into view, from 0 to 1, and when a new error stops holding it open.
let barHeight = barScript.window.size.height
let barHotStripHeight: Float = 6
let barSlideSpeed: Float = 6
let errorRevealSeconds: Double = 3
var barReveal: Float = 1
var barHeldOpenUntil: Double = 0

@MainActor
func showSpeed(_ index: Int) {
    speedIndex = index
    for (button, name) in barSpeedButtons.enumerated() {
        bar.setSelected(button <= index, named: name)
    }
}

@MainActor
func showErrorCount() {
    let count = simulatedErrors.count
    bar.setHidden(count == 0, named: "ErrorCount")
    bar.setText("\(count) \(count == 1 ? "Error" : "Errors")", named: "ErrorCount")
}

@MainActor
func reportSimulatedError(_ message: String) {
    simulatedErrors.append(message)
    showErrorCount()
    barHeldOpenUntil = GetTime() + errorRevealSeconds
}

showSpeed(0)
bar.setText("1st Floor", named: "FloorName")
bar.setText("\(residents.count) Objects", named: "ObjectCount")
reportSimulatedError("A simulated error, so the demo can show the bar opening by itself.")

let window = WindowFrame(title: "Maple Street - Property Chat", theme: theme)
var frameCount = 0
var running = true
var screenshotSaved = true

while running && !WindowShouldClose() {
    let frameTime = GetFrameTime()
    let screenSize = Vector2(x: Float(GetScreenWidth()), y: Float(GetScreenHeight()))
    let pointer = GetMousePosition()

    let panelHeight = panelScript.window.size.height
    let panelTop = screenSize.y - panelHeight
    let chatSize = Vector2(x: chatScript.window.size.width, y: chatScript.window.size.height)
    let bounds = window.place(
        size: chatSize,
        at: Vector2(x: (screenSize.x - chatSize.x) / 2, y: (panelTop - chatSize.y) / 2)
    )
    let chatOrigin = Vector2(x: bounds.x, y: bounds.y)
    let panelOrigin = Vector2(x: 0, y: panelTop)

    // The bar slides in from above while the pointer is at the top of the screen or over it.
    let isPointerNearBar = pointer.y < (barReveal > 0 ? barHeight : barHotStripHeight)
    let shouldReveal = isPointerNearBar || GetTime() < barHeldOpenUntil
    barReveal = min(max(barReveal + ((shouldReveal ? 1 : -1) * barSlideSpeed * frameTime), 0), 1)
    let barOrigin = Vector2(x: 0, y: -barHeight * (1 - barReveal))
    bar.setWindowSize(Vector2(x: screenSize.x, y: barHeight))
    let isOverBar = barReveal > 0 && bar.containsPoint(pointer, origin: barOrigin)

    if notice.isOpen {
        _ = notice.update()
    } else {
        // The bar draws over the chat window, and the chat window over the panel, so each gets
        // the pointer before what is beneath it.
        if !isOverBar || window.isDragging {
            _ = window.followPointer(in: bounds)
            if window.update(in: bounds) == .close {
                running = false
            }
        }
        for case let .submitted(control: "chatEntry", text: message) in chat.update(at: chatOrigin) {
            chatMessages.append("You: \(message)")
            chatMessages.append("Maya: \(residentReplies[residentReplyIndex])")
            history.items = chatMessages
            residentReplyIndex = (residentReplyIndex + 1) % residentReplies.count
        }

        if !CheckCollisionPointRec(pointer, bounds), !isOverBar {
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
        }

        if barReveal == 1 {
            for event in bar.update(at: barOrigin) {
                switch event {
                case .pressed(control: "ErrorCount"):
                    notice.show(title: "Errors", message: simulatedErrors.joined(separator: " "))
                    simulatedErrors.removeAll()
                    showErrorCount()
                case .pressed(control: "HelpButton"):
                    notice.show(title: "Help", message: "Move the pointer to the top of the screen to show this bar. The arrows set the speed of the clock.")
                case let .pressed(control: name):
                    if let speed = barSpeedButtons.firstIndex(of: name) {
                        showSpeed(speed)
                    }
                default:
                    break
                }
            }
        }
    }

    let isOverInterface = isOverBar
        || CheckCollisionPointRec(pointer, bounds)
        || panel.containsPoint(pointer, origin: panelOrigin)

    gameMinutes += Double(frameTime) * speedRates[speedIndex]
    let totalMinutes = Int(gameMinutes)
    let clock = String(format: "%02d:%02d", (totalMinutes / 60) % 24, totalMinutes % 60)
    panel.setText(clock, named: "statusBarTimerEntry")
    bar.setText(clock, named: "GameClock")

    if GetTime() > nextSimulatedError {
        nextSimulatedError += 60
        reportSimulatedError("Another simulated error.")
    }

    BeginDrawing()
    drawPropertyLot(groundBottom: Int32(panelTop))
    DrawText(
        isOverInterface ? "Pointer: interface" : "Pointer: lot",
        20,
        58,
        14,
        Color(r: 255, g: 255, b: 255, a: 255)
    )
    DrawRectangle(0, Int32(panelTop), Int32(screenSize.x), Int32(panelHeight), theme.titleBar)
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
    if barReveal > 0 {
        bar.draw(at: barOrigin)
    }
    notice.draw()
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
