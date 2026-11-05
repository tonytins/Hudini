// An example host: a property chat window over a control panel that swaps between modes, with a
// lemonade stand panel that sits inside the live panel or in its own window, and an auto-hiding
// debug bar. The options panel opens a window for moving to another lot. The chat, mode panels, and
// move window are UIScript XML. The stand and the bar are Maxis' .uis format.
//
// Usage: hudini-demo [--screenshot <file.png>] [--scene <name>] [--pointer <x> <y>] [--font <file>] [--glossy]
//
// Scenes are for checking the interface without input: live, stats, options, stand, standwindow,
// movelot, and accent, which shows the options panel after its Accent Color button is pressed.
// --pointer holds the pointer in place, and a screenshot then waits long enough to show a tooltip.
// --font draws the interface in a font file, such as a .ttf. The demo's own lot art keeps raylib's
// default font, since the theme only reaches Hudini's controls.
// --glossy gives the theme rounded corners and a title bar that fades, and asks for smoother curves.

import Foundation
import Hudini
import Raylib
import SwiftCST


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
    DrawText("EXAMPLE HOST", 20, 36, 16, Color(r: 255, g: 255, b: 255, a: 255))
    let stand = standLotBounds(groundBottom: height)
    DrawRectangleRec(stand, Color(r: 240, g: 214, b: 90, a: 255))
    DrawRectangle(Int32(stand.x) - 4, Int32(stand.y) - 8, Int32(stand.width) + 8, 8, Color(r: 196, g: 74, b: 66, a: 255))
    DrawText("Lemonade", Int32(stand.x) + 4, Int32(stand.y) + 8, 12, Color(r: 28, g: 38, b: 48, a: 255))
    DrawText("Click the stand to use it", Int32(stand.x) - 30, Int32(stand.y) - 26, 12, Color(r: 28, g: 38, b: 48, a: 255))
}

func standLotBounds(groundBottom height: Int32) -> Rectangle {
    Rectangle(x: 720, y: Float(height) - 130, width: 70, height: 56)
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
            // These buttons carry their own labels.
            if !path.contains("eod") {
                let mark = sliceSize / 3
                ImageDrawRectangle(&image, x + mark, mark, mark, mark, Color(r: 255, g: 249, b: 157, a: 255))
            }
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
    if path.contains("standOpen") {
        return Color(r: 240, g: 214, b: 90, a: 255)
    }
    if path.contains("standClosed") {
        return Color(r: 110, g: 110, b: 116, a: 255)
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
    if path.contains("stand") {
        return (90, 104)
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

// The host's game state.

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
var scene = "live"
var heldPointer: Vector2?
var fontPath: String?
var isGlossy = false
var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
    case "--screenshot":
        guard let path = arguments.popFirst() else {
            fail("--screenshot needs a file")
        }
        screenshot = path
    case "--scene":
        guard let name = arguments.popFirst() else {
            fail("--scene needs a name")
        }
        scene = name
    case "--pointer":
        guard let x = arguments.popFirst().flatMap(Float.init), let y = arguments.popFirst().flatMap(Float.init) else {
            fail("--pointer needs an x and a y")
        }
        heldPointer = Vector2(x: x, y: y)
    case "--font":
        guard let path = arguments.popFirst() else {
            fail("--font needs a file")
        }
        fontPath = path
    case "--glossy":
        isGlossy = true
    default:
        fail("usage: hudini-demo [--screenshot <file.png>] [--scene <name>] [--pointer <x> <y>] [--font <file>] [--glossy]")
    }
}
guard ["live", "stats", "options", "stand", "standwindow", "movelot", "accent"].contains(scene) else {
    fail("Unknown scene '\(scene)'.")
}

// The host's localized text, in the same kind of tables The Sims Online uses, read with SwiftCST.
// Hudini leaves text to the host, which hands each view a closure that looks strings up.
guard let textDirectory = Bundle.module.url(forResource: "uitext", withExtension: nil) else {
    fail("The demo's text is missing.")
}
let demoText = UIText(directory: textDirectory)

/// Returns the text a document's string refers to, or `nil` so the view reports it as missing.
/// The table ID is the number at the end of the string's table, such as `DemoText:6`.
@MainActor
func demoString(_ resource: UIScript.StringResource) -> String? {
    guard let id = resource.table.split(separator: ":").last.flatMap({ Int($0) }) else {
        return nil
    }
    do {
        return try demoText.textIfPresent(for: id, key: resource.index)
    } catch {
        log("Unable to read text table \(id): \(error.localizedDescription)")
        return nil
    }
}

let chatScript = loadUIScript(named: "chatdialog")
let panelScript = loadUIScript(named: "livepanel1024")
let statsScript = loadUIScript(named: "statspanel")
let optionsScript = loadUIScript(named: "optionspanel")
let moveLotScript = loadUIScript(named: "movelot")
let barScript = loadUIS(named: "debugbar")
let standScript = loadUIS(named: "lemonadestand")

SetTraceLogLevel(.warning)
var windowFlags: ConfigFlags = screenshot == nil ? [.windowResizable, .vsyncHint] : [.windowHidden]
if isGlossy {
    windowFlags.insert(.msaa4xHint)
}
SetConfigFlags(windowFlags)
InitWindow(1024, 768, "Hudini Live Mode")
// The host owns the font: it loads after InitWindow and unloads before CloseWindow.
let font: Font? = fontPath.map { path in
    let font = LoadFontEx(path, 32, nil, 0)
    guard IsFontValid(font) else {
        fail("Couldn't load the font at '\(path)'.")
    }
    SetTextureFilter(font.texture, .bilinear)
    return font
}
// The accents the options panel's Accent Color button steps through, starting with Hudini's own.
let accents = [
    InterfaceTheme.standard.accent,
    Color(r: 110, g: 180, b: 240, a: 255),
    Color(r: 130, g: 205, b: 120, a: 255),
    Color(r: 235, g: 115, b: 165, a: 255),
]
var accentIndex = 0

@MainActor
func makeTheme(accent: Color) -> InterfaceTheme {
    InterfaceTheme(
        accent: accent,
        titleBar: isGlossy ? Color(r: 92, g: 112, b: 142, a: 245) : InterfaceTheme.standard.titleBar,
        titleBarBottom: isGlossy ? Color(r: 30, g: 40, b: 58, a: 245) : nil,
        font: font,
        cornerRadius: isGlossy ? 8 : 0
    )
}

var theme = makeTheme(accent: accents[accentIndex])
SetExitKey(.null)
SetTargetFPS(60)

var placeholderTextures: [Texture2D] = []
@MainActor
func makeView(_ script: UIScript) -> UIScriptView {
    let view = UIScriptView(
        script: script,
        theme: theme,
        resolveString: demoString,
        loadImage: { resource in
            let texture = makePlaceholderTexture(for: resource)
            placeholderTextures.append(texture)
            return texture
        }
    )
    for name in view.missingStrings {
        log("No text for string '\(name)'")
    }
    return view
}

let chat = makeView(chatScript)
let panel = makeView(panelScript)
let stats = makeView(statsScript)
let options = makeView(optionsScript)
let moveLot = makeView(moveLotScript)
let bar = makeView(barScript)
let stand = makeView(standScript)
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
guard requiredBarControls.allSatisfy({ barScript.control(named: $0) != nil }),
      barScript.visual(named: "BarBackground") != nil else {
    fail("debugbar.uis is missing a required control")
}
bar.setHidden(false, named: "BarBackground")

let requiredStandControls = ["PriceSlider", "PriceValue", "StockBar", "Earnings", "ServeButton", "RestockButton", "SignEntry"]
guard requiredStandControls.allSatisfy({ standScript.control(named: $0) != nil }),
      let standPanelPosition = standScript.setting(named: "PanelPosition")?.position,
      standScript.visual(named: "StandOpenArt") != nil,
      standScript.visual(named: "StandClosedArt") != nil else {
    fail("lemonadestand.uis is missing a required control or setting")
}

statusMessage.items = ["Maya is visiting"]

guard let standMessage = panel.list(named: "messageWindow") else {
    fail("livepanel1024.xml is missing a required live-panel control")
}

// The control panel shows one mode's panel at a time, chosen from the icon toolbar.
enum Mode: Int, CaseIterable {
    case live, stats, options

    var icon: String {
        switch self {
        case .live: "L"
        case .stats: "S"
        case .options: "O"
        }
    }
}

var mode = Mode.live

@MainActor
func showMode(_ newMode: Mode) {
    guard newMode != mode else {
        return
    }
    panel.clearFocus()
    stats.clearFocus()
    options.clearFocus()
    stand.clearFocus()
    mode = newMode
}

// The stand is one document in either place, and the live panel changes around it.
enum StandPlacement {
    case closed, inPanel, inWindow
}

var standPlacement = StandPlacement.closed
let panelControlsBesideStand = ["eodHelp", "eodClose", "eodExpand", "timerEntry", "messageWindow"]
let panelControlsWithoutStand = [
    "needsLabel", "motives", "previousPage", "nextPage", "peopleList", "peopleListBackgroundImage",
    "dividerImage", "statusBarTimerEntry", "statusBarMessageWindow"
]

@MainActor
func placeStand(_ placement: StandPlacement) {
    standPlacement = placement
    let isInPanel = placement == .inPanel
    for name in panelControlsBesideStand {
        panel.setHidden(!isInPanel, named: name)
    }
    for name in panelControlsWithoutStand {
        panel.setHidden(isInPanel, named: name)
    }
    if placement == .closed {
        stand.clearFocus()
    }
}

panel.setHidden(true, named: "eodContract")
placeStand(.closed)

let standCapacity: Float = 10
var standCups = standCapacity
var standEarnings: Float = 0

@MainActor
func showStand() {
    let price = stand.value(named: "PriceSlider") ?? 1
    stand.setText(String(format: "$%.2f", price), named: "PriceValue")
    stand.setText(String(format: "$%.2f", standEarnings), named: "Earnings")
    stand.setValue(standCups, named: "StockBar")
    stand.setDisabled(standCups == 0, named: "ServeButton")
    stand.setHidden(standCups == 0, named: "StandOpenArt")
    stand.setHidden(standCups > 0, named: "StandClosedArt")
    standMessage.items = [standCups > 0 ? "Thirsty customers are waiting." : "The jug is empty."]
}

stand.setValue(3, named: "PriceSlider")
showStand()

for (name, score) in [("garden", 72), ("kitchen", 45), ("livingRoom", 88), ("bedroom", 30)] as [(String, Float)] {
    stats.setValue(score, named: name)
}

@MainActor
func showVolume(_ value: Float, of slider: String) {
    options.setText("\(Int(value + 0.5))%", named: "\(slider)Value")
}

for (name, volume) in [("music", 60), ("sound", 80)] as [(String, Float)] {
    options.setValue(volume, named: name)
    showVolume(volume, of: name)
}

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
// A choice the player has to make or cancel on purpose, so the window has no close button.
let moveLotWindow = WindowFrame(title: (try? demoText.textIfPresent(for: 6, key: 1)) ?? "Move", theme: theme)
moveLotWindow.showsCloseButton = false
guard let lotChoices = moveLot.list(named: "lotChoices"),
      let lotKey = moveLot.textField(named: "lotKey") else {
    fail("movelot.xml is missing a required control")
}
lotChoices.items = [
    "Maple Street",
    "Oak Avenue",
    "Birch Lane",
    "Harbor Road",
    "Sunset Drive",
    "Willow Court",
    "Cedar Hill",
    "Lakeshore Way",
]
var isMoveLotOpen = false

@MainActor
func openMoveLot() {
    chat.clearFocus()
    stand.clearFocus()
    options.clearFocus()
    lotChoices.selectedIndex = nil
    lotKey.text = ""
    lotKey.setFocused(true)
    moveLot.setDisabled(true, named: "moveConfirm")
    isMoveLotOpen = true
}

@MainActor
func closeMoveLot() {
    moveLot.clearFocus()
    isMoveLotOpen = false
}

// The demo takes any key. A real host would check it.
@MainActor
func confirmMoveLot() {
    guard let selected = lotChoices.selectedIndex else {
        return
    }
    window.title = "\(lotChoices.items[selected]) - Property Chat"
    closeMoveLot()
}

let standWindow = WindowFrame(title: "Lemonade Stand", theme: theme)
standWindow.toolbarItems = ["Dock"]

/// Gives every window, panel, and view the next accent. Nothing is rebuilt, so text, focus, and
/// where the player moved each window all stay.
@MainActor
func showNextAccent() {
    accentIndex = (accentIndex + 1) % accents.count
    theme = makeTheme(accent: accents[accentIndex])
    for view in [chat, panel, stats, options, moveLot, bar, stand] {
        view.theme = theme
    }
    for frame in [window, moveLotWindow, standWindow] {
        frame.theme = theme
    }
    notice.theme = theme
}

switch scene {
case "stats":
    showMode(.stats)
case "options":
    showMode(.options)
case "stand":
    placeStand(.inPanel)
case "standwindow":
    placeStand(.inWindow)
case "accent":
    showMode(.options)
    showNextAccent()
case "movelot":
    showMode(.options)
    openMoveLot()
    lotChoices.selectedIndex = 2
    moveLot.setDisabled(false, named: "moveConfirm")
    lotKey.text = "maple"
default:
    break
}

var frameCount = 0
var running = true
var screenshotSaved = true

while running && !WindowShouldClose() {
    if let heldPointer {
        SetMousePosition(Int(heldPointer.x), Int(heldPointer.y))
    }
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
    let lotArea = Rectangle(x: 0, y: 0, width: screenSize.x, height: panelTop)
    let toolbarItemCount = Mode.allCases.count
    let toolbarBounds = IconToolbar.bounds(itemCount: toolbarItemCount, in: lotArea)
    let isOverToolbar = CheckCollisionPointRec(pointer, toolbarBounds)

    let standPadding: Float = 8
    let standSize = Vector2(
        x: standScript.window.size.width + standPadding,
        y: standScript.window.size.height + standPadding + Float(WindowFrame.titleHeight)
    )
    let standWindowBounds = standWindow.place(size: standSize, at: Vector2(x: screenSize.x - standSize.x - 24, y: 60))
    let standWindowContent = WindowFrame.content(in: standWindowBounds)
    let isStandShown = standPlacement == .inWindow || (standPlacement == .inPanel && mode == .live)
    let standOrigin = standPlacement == .inWindow
        ? Vector2(x: standWindowContent.x + (standPadding / 2), y: standWindowContent.y + (standPadding / 2))
        : Vector2(x: panelOrigin.x + standPanelPosition.x, y: panelOrigin.y + standPanelPosition.y)
    let isOverStandWindow = standPlacement == .inWindow && CheckCollisionPointRec(pointer, standWindowBounds)
    let moveLotSize = Vector2(
        x: moveLotScript.window.size.width,
        y: moveLotScript.window.size.height + Float(WindowFrame.titleHeight)
    )
    let moveLotBounds = moveLotWindow.place(
        size: moveLotSize,
        at: Vector2(x: screenSize.x - moveLotSize.x - 24, y: 60)
    )
    let moveLotContent = WindowFrame.content(in: moveLotBounds)
    let moveLotOrigin = Vector2(x: moveLotContent.x, y: moveLotContent.y)
    let modePanel = switch mode {
    case .live: panel
    case .stats: stats
    case .options: options
    }

    // The bar slides in from above while the pointer is at the top of the screen or over it.
    let isPointerNearBar = pointer.y < (barReveal > 0 ? barHeight : barHotStripHeight)
    let shouldReveal = isPointerNearBar || GetTime() < barHeldOpenUntil
    barReveal = min(max(barReveal + ((shouldReveal ? 1 : -1) * barSlideSpeed * frameTime), 0), 1)
    let barOrigin = Vector2(x: 0, y: -barHeight * (1 - barReveal))
    bar.setWindowSize(Vector2(x: screenSize.x, y: barHeight))
    let isOverBar = barReveal > 0 && bar.containsPoint(pointer, origin: barOrigin)

    if notice.isOpen {
        _ = notice.update()
    } else if isMoveLotOpen {
        _ = moveLotWindow.followPointer(in: moveLotBounds)
        for event in moveLot.update(at: moveLotOrigin) {
            switch event {
            case .selected(control: "lotChoices", index: _):
                moveLot.setDisabled(false, named: "moveConfirm")
            case .pressed(control: "moveCancel"):
                closeMoveLot()
            case .pressed(control: "moveConfirm"), .submitted(control: "lotKey", text: _):
                confirmMoveLot()
            default:
                break
            }
        }
    } else {
        // The bar draws over everything but the notice, and the stand's window over the chat
        // window, which draws over the panel. Each gets the pointer before what is beneath it.
        if standPlacement == .inWindow, !isOverBar || standWindow.isDragging {
            _ = standWindow.followPointer(in: standWindowBounds)
            switch standWindow.update(in: standWindowBounds) {
            case .close:
                placeStand(.closed)
            case .toolbarItemSelected:
                placeStand(.inPanel)
                showMode(.live)
            default:
                break
            }
        }
        if isOverStandWindow, IsMouseButtonPressed(MouseButton.left) {
            chat.clearFocus()
        }
        if (!isOverBar && !isOverStandWindow) || window.isDragging {
            _ = window.followPointer(in: bounds)
            if window.update(in: bounds) == .close {
                running = false
            }
        }
        if !isOverStandWindow {
            for case let .submitted(control: "chatEntry", text: message) in chat.update(at: chatOrigin) {
                chatMessages.append("You: \(message)")
                chatMessages.append("Maya: \(residentReplies[residentReplyIndex])")
                history.items = chatMessages
                residentReplyIndex = (residentReplyIndex + 1) % residentReplies.count
            }
        }

        if IsMouseButtonPressed(MouseButton.left), !isOverBar, !isOverStandWindow, !CheckCollisionPointRec(pointer, bounds) {
            if let index = IconToolbar.buttonIndex(at: pointer, itemCount: toolbarItemCount, in: lotArea),
               let selected = Mode(rawValue: index) {
                showMode(selected)
            }
        }

        if isStandShown {
            for event in stand.update(at: standOrigin) {
                switch event {
                case .pressed(control: "ServeButton") where standCups > 0:
                    standCups -= 1
                    standEarnings += stand.value(named: "PriceSlider") ?? 1
                    showStand()
                case .pressed(control: "RestockButton"):
                    standCups = standCapacity
                    showStand()
                case .changed(control: "PriceSlider", value: _):
                    showStand()
                case let .submitted(control: "SignEntry", text: sign):
                    standMessage.items = ["The sign now reads: \(sign)"]
                default:
                    break
                }
            }
        }

        if !CheckCollisionPointRec(pointer, bounds), !isOverBar, !isOverStandWindow, !isOverToolbar {
            for event in modePanel.update(at: panelOrigin) {
                switch event {
                case .pressed(control: "moveLot"):
                    openMoveLot()
                case .pressed(control: "accent"):
                    showNextAccent()
                case .pressed(control: "previousPage"):
                    showPeoplePage(peoplePage - 1)
                case .pressed(control: "nextPage"):
                    showPeoplePage(peoplePage + 1)
                case .pressed(control: "eodClose"):
                    placeStand(.closed)
                case .pressed(control: "eodExpand"):
                    placeStand(.inWindow)
                case .pressed(control: "eodHelp"):
                    notice.show(title: "Lemonade Stand", message: "Set a price, then serve customers until the jug runs out.")
                case let .changed(control: name, value: value):
                    showVolume(value, of: name)
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
        || isOverStandWindow
        || isOverToolbar
        || CheckCollisionPointRec(pointer, bounds)
        || modePanel.containsPoint(pointer, origin: panelOrigin)
        || pointer.y >= panelTop

    if !notice.isOpen, !isMoveLotOpen, !isOverInterface, IsMouseButtonPressed(MouseButton.left),
       CheckCollisionPointRec(pointer, standLotBounds(groundBottom: Int32(panelTop))), standPlacement == .closed {
        placeStand(.inPanel)
        showMode(.live)
    }

    gameMinutes += Double(frameTime) * speedRates[speedIndex]
    let totalMinutes = Int(gameMinutes)
    let clock = String(format: "%02d:%02d", (totalMinutes / 60) % 24, totalMinutes % 60)
    panel.setText(clock, named: "statusBarTimerEntry")
    panel.setText(clock, named: "timerEntry")
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
    DrawRectangle(0, Int32(panelTop), Int32(screenSize.x), Int32(panelHeight), theme.titleBarBottom ?? theme.titleBar)
    modePanel.draw(at: panelOrigin) { name, regionBounds in
        switch name {
        case "motives":
            drawNeeds(in: regionBounds)
        case "peopleList":
            drawPeople(in: regionBounds)
        default:
            break
        }
    }
    if standPlacement == .inPanel, mode == .live {
        stand.draw(at: standOrigin)
    }
    IconToolbar.draw(
        itemCount: toolbarItemCount,
        selectedIndex: mode.rawValue,
        mousePosition: pointer,
        in: lotArea,
        theme: theme
    ) { index, iconBounds, color in
        DrawText(
            Mode.allCases[index].icon,
            Int(iconBounds.x) + 15,
            Int(iconBounds.y) + 11,
            20,
            color
        )
    }
    window.draw(in: bounds)
    chat.draw(at: chatOrigin)
    if standPlacement == .inWindow {
        standWindow.draw(in: standWindowBounds)
        stand.draw(at: standOrigin)
    }
    if barReveal > 0 {
        bar.draw(at: barOrigin)
    }
    if isMoveLotOpen {
        moveLotWindow.draw(in: moveLotBounds)
        moveLot.draw(at: moveLotOrigin)
        moveLot.drawTooltip(at: moveLotOrigin)
    }
    modePanel.drawTooltip(at: panelOrigin)
    chat.drawTooltip(at: chatOrigin)
    stand.drawTooltip(at: standOrigin)
    bar.drawTooltip(at: barOrigin)
    notice.draw()
    EndDrawing()

    frameCount += 1
    if let screenshot, frameCount == (heldPointer == nil ? 3 : 45) {
        let image = LoadImageFromScreen()
        screenshotSaved = ExportImage(image, screenshot)
        UnloadImage(image)
        running = false
    }
}

for texture in placeholderTextures {
    UnloadTexture(texture)
}
if let font {
    UnloadFont(font)
}
CloseWindow()
if !screenshotSaved {
    exit(1)
}
