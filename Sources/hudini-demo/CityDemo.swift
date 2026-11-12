// The CityLimits-style demo: a city map under HUD panels, with windows run by a WindowManager.
//
// It shows how a game like CityLimits could be built on Hudini:
//
// - HUD panels that never stack, outside the WindowManager: the tool palette (city/tools.uix), the
//   overview with its minimap (city/overview.uix), and the status bar with its news ticker
//   (city/status.uix). The host draws them under the windows and keeps clicks on them off the map.
// - Windows run by a WindowManager, each a small class with its own handler, so its logic lives with
//   it rather than in one big switch in the game loop:
//   - BudgetWindow (city/budget.uix) is modal, and the city pauses while any modal window is open.
//   - ConfirmWindow (city/confirm.uix) is modal, dims what's behind it, and stacks over the budget.
//     One window answers every yes-or-no question: whoever asks passes what to do with the answer,
//     which is how play and an editor could share a window without mode checks.
//   - DemandWindow, HelpWindow, and CityPanelWindow stay open beside the map and minimize to a row
//     of icons the host draws above the status bar. The city panel's title is the city's name,
//     edited in place, and its toolbar items are tabs.
//
// Scenes for screenshots: city (windows open, help minimized), citybudget (the budget open), and
// cityconfirm (a confirm stacked over the budget).

import Foundation
import Hudini
import Raylib

/// Loads one of the city demo's documents from `Resources/city`.
@MainActor
func loadCityScript(named name: String) -> UIScript {
    do {
        guard let url = Bundle.module.url(forResource: name, withExtension: "uix", subdirectory: "city") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let script = try UIScript(contentsOf: url)
        logProblems(in: script, file: "city/\(name).uix")
        return script
    } catch {
        fail("Unable to load city/\(name).uix: \(error.localizedDescription)")
    }
}

/// Writes a whole number with thousands separators, such as 20,000.
func grouped(_ number: Int) -> String {
    let digits = String(abs(number))
    var result = ""
    for (index, digit) in digits.enumerated() {
        if index > 0, (digits.count - index) % 3 == 0 {
            result.append(",")
        }
        result.append(digit)
    }
    return number < 0 ? "-" + result : result
}

// MARK: - The city

/// What one square of the map holds.
enum Tile: Equatable {
    case water, land, trees, residential, commercial, industrial, road, park

    var color: Color {
        switch self {
        case .water: Color(r: 60, g: 90, b: 170, a: 255)
        case .land: Color(r: 150, g: 128, b: 96, a: 255)
        case .trees: Color(r: 70, g: 128, b: 70, a: 255)
        case .residential: Color(r: 90, g: 170, b: 95, a: 255)
        case .commercial: Color(r: 80, g: 130, b: 210, a: 255)
        case .industrial: Color(r: 205, g: 175, b: 80, a: 255)
        case .road: Color(r: 70, g: 70, b: 74, a: 255)
        case .park: Color(r: 120, g: 196, b: 110, a: 255)
        }
    }

    var letter: String? {
        switch self {
        case .residential: "R"
        case .commercial: "C"
        case .industrial: "I"
        default: nil
        }
    }

    var isZone: Bool {
        self == .residential || self == .commercial || self == .industrial
    }
}

/// A tool in the palette. Its raw value is its button's name in city/tools.uix.
enum Tool: String, CaseIterable {
    case residential, commercial, industrial, road, park, bulldoze

    var tile: Tile {
        switch self {
        case .residential: .residential
        case .commercial: .commercial
        case .industrial: .industrial
        case .road: .road
        case .park: .park
        case .bulldoze: .land
        }
    }

    var cost: Int {
        switch self {
        case .residential, .commercial, .industrial: 100
        case .road: 10
        case .park: 50
        case .bulldoze: 1
        }
    }

    var label: String {
        switch self {
        case .residential: "Homes, $\(cost)"
        case .commercial: "Shops, $\(cost)"
        case .industrial: "Industry, $\(cost)"
        case .road: "Road, $\(cost)"
        case .park: "Park, $\(cost)"
        case .bulldoze: "Bulldoze, $\(cost)"
        }
    }
}

/// A small city: its map, money, people, and calendar. The model is only meant to make the
/// interface move, not to be a fair city simulation.
@MainActor
final class City {
    static let width = 64
    static let height = 45
    static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    static let defaultTaxRate: Float = 7

    private(set) var tiles: [Tile]
    var name = "Bridgeport"
    let founded = "January 1957"
    private(set) var month = 0
    private(set) var year = 1957
    private(set) var funds = 20_000
    private(set) var population = 400
    var taxRate: Float = City.defaultTaxRate
    var roadFunding: Float = 100
    var parkFunding: Float = 100
    private(set) var demand: (residential: Float, commercial: Float, industrial: Float) = (0.6, 0.4, 0.5)

    init() {
        tiles = (0..<(City.width * City.height)).map { index in
            let (x, y) = (Float(index % City.width), Float(index / City.width))
            // A fixed blend of waves, so every run gets the same river and woods.
            let height = sin(x * 0.17) + cos(y * 0.23) + (sin((x + y) * 0.07) * 1.4)
            return height < -1.2 ? .water : height > 1.5 ? .trees : .land
        }
        // A starter town around two crossing roads.
        for x in 12...40 where tile(x, 24) != .water {
            set(.road, x, 24)
        }
        for y in 16...32 where tile(26, y) != .water {
            set(.road, 26, y)
        }
        for x in 20...25 {
            set(.residential, x, 23)
            set(.residential, x, 25)
        }
        for x in 27...31 {
            set(.commercial, x, 23)
        }
        for x in 33...38 {
            set(.industrial, x, 25)
        }
        set(.park, 27, 25)
        set(.park, 28, 25)
        updateDemand()
    }

    func tile(_ x: Int, _ y: Int) -> Tile {
        tiles[(y * City.width) + x]
    }

    private func set(_ tile: Tile, _ x: Int, _ y: Int) {
        tiles[(y * City.width) + x] = tile
    }

    func count(_ tile: Tile) -> Int {
        tiles.reduce(0) { $0 + ($1 == tile ? 1 : 0) }
    }

    var zonedCount: Int {
        tiles.reduce(0) { $0 + ($1.isZone ? 1 : 0) }
    }

    /// Uses `tool` on a square, if the city can afford it and it changes anything.
    @discardableResult
    func apply(_ tool: Tool, _ x: Int, _ y: Int) -> Bool {
        let current = tile(x, y)
        guard current != .water, current != tool.tile, funds >= tool.cost else {
            return false
        }
        set(tool.tile, x, y)
        funds -= tool.cost
        updateDemand()
        return true
    }

    var date: String {
        "\(City.monthNames[month]) \(year)"
    }

    /// What taxes bring in each month.
    var income: Int {
        Int(Float(population) * taxRate / 100 * 3)
    }

    /// What roads and parks cost each month, at their funding.
    var upkeep: Int {
        Int((Float(count(.road)) * roadFunding / 100) + (Float(count(.park)) * 5 * parkFunding / 100))
    }

    func resetBudget() {
        taxRate = City.defaultTaxRate
        roadFunding = 100
        parkFunding = 100
    }

    /// Moves the calendar on a month: money comes and goes, and people move in or out.
    func advanceMonth() {
        funds += income - upkeep
        let homes = count(.residential) * 30
        let jobs = (count(.commercial) + count(.industrial)) * 24
        let taxDrag = 1 - (max(0, taxRate - City.defaultTaxRate) / 30)
        let target = count(.road) > 0 ? Float(min(homes, jobs + 200)) * taxDrag : 0
        population += Int((target - Float(population)) * 0.1)
        population = max(0, population)
        month += 1
        if month == 12 {
            month = 0
            year += 1
        }
        updateDemand()
    }

    private func updateDemand() {
        let homes = Float(count(.residential) * 30)
        let shops = Float(count(.commercial) * 24)
        let industry = Float(count(.industrial) * 24)
        func clamp(_ value: Float) -> Float {
            min(max(value, 0), 1)
        }
        demand = (
            residential: clamp(0.5 + ((shops + industry - homes) / max(homes + shops + industry, 1))),
            commercial: clamp(0.5 + (((Float(population) * 0.4) - shops) / max(Float(population), 1))),
            industrial: clamp(0.5 + (((Float(population) * 0.5) - industry) / max(Float(population), 1)))
        )
    }
}

// MARK: - Windows

/// Closes or minimizes a window that asks, the way most of the city's windows want.
@MainActor
func handleCloseAndMinimize(_ event: WindowFrame.Event, of frame: WindowFrame, in windows: WindowManager) {
    switch event {
    case .closeRequested:
        windows.close(frame)
    case .minimizeRequested:
        windows.minimize(frame)
    default:
        break
    }
}

/// A yes-or-no question in a modal window that dims what's behind it. One window serves every
/// question: whoever asks passes what to do with the answer.
@MainActor
final class ConfirmWindow {
    let frame: WindowFrame
    private let view: UIScriptView
    private var answer: ((Bool) -> Void)?

    init(theme: InterfaceTheme) {
        view = UIScriptView(script: loadCityScript(named: "confirm"), theme: theme)
        frame = WindowFrame(view: view)
        // A question needs an answer, so the window closes only through Yes or No.
        frame.showsCloseButton = false
    }

    func ask(_ title: String, _ question: String, in windows: WindowManager, then answer: @escaping (Bool) -> Void) {
        frame.title = title
        view.setText(question, named: "message")
        self.answer = answer
        windows.open(frame, modal: true, dimsBehind: true) { [unowned self, unowned windows] event in
            switch event {
            case .view(.pressed(control: "yes")):
                finish(true, in: windows)
            case .view(.pressed(control: "no")):
                finish(false, in: windows)
            default:
                break
            }
        }
    }

    private func finish(_ isYes: Bool, in windows: WindowManager) {
        windows.close(frame)
        let answer = self.answer
        self.answer = nil
        answer?(isYes)
    }
}

/// The budget: taxes and funding, in a modal window that pauses the city.
@MainActor
final class BudgetWindow {
    let frame: WindowFrame
    private let view: UIScriptView
    private let city: City
    private let confirm: ConfirmWindow

    init(theme: InterfaceTheme, city: City, confirm: ConfirmWindow) {
        view = UIScriptView(script: loadCityScript(named: "budget"), theme: theme)
        frame = WindowFrame(view: view, title: "Budget")
        self.city = city
        self.confirm = confirm
    }

    func open(in windows: WindowManager) {
        showBudget()
        windows.open(frame, modal: true) { [unowned self, unowned windows] event in
            handle(event, in: windows)
        }
    }

    private func handle(_ event: WindowFrame.Event, in windows: WindowManager) {
        switch event {
        case let .view(.changed(control: "tax", value: value)):
            city.taxRate = value.rounded()
        case let .view(.changed(control: "roads", value: value)):
            city.roadFunding = value.rounded()
        case let .view(.changed(control: "parks", value: value)):
            city.parkFunding = value.rounded()
        case .view(.pressed(control: "reset")):
            // A second modal window stacks on this one, and dims what's behind it.
            confirm.ask("Reset the Budget", "Put taxes back to 7%, and fund\nroads and parks in full?", in: windows) { [unowned self] isYes in
                if isYes {
                    city.resetBudget()
                    showBudget()
                }
            }
        case .view(.pressed(control: "done")), .closeRequested:
            windows.close(frame)
        default:
            break
        }
        showFigures()
    }

    private func showBudget() {
        view.setValue(city.taxRate, named: "tax")
        view.setValue(city.roadFunding, named: "roads")
        view.setValue(city.parkFunding, named: "parks")
        showFigures()
    }

    private func showFigures() {
        view.setText("\(Int(city.taxRate))%", named: "taxValue")
        view.setText("\(Int(city.roadFunding))%", named: "roadsValue")
        view.setText("\(Int(city.parkFunding))%", named: "parksValue")
        view.setText("Taxes bring in $\(grouped(city.income)) a month", named: "income")
        view.setText("Roads and parks cost $\(grouped(city.upkeep)) a month", named: "upkeep")
        let balance = city.income - city.upkeep
        view.setText("Each month: \(balance < 0 ? "-" : "+")$\(grouped(abs(balance)))", named: "balance")
    }
}

/// Demand for each zone, in a window that stays open and minimizes.
@MainActor
final class DemandWindow {
    let frame: WindowFrame
    private let view: UIScriptView

    init(theme: InterfaceTheme) {
        view = UIScriptView(script: loadCityScript(named: "demand"), theme: theme)
        frame = WindowFrame(view: view, title: "Demand")
        frame.showsMinimizeButton = true
    }

    func open(in windows: WindowManager, at start: Vector2? = nil) {
        windows.open(frame, at: start) { [unowned self, unowned windows] event in
            handleCloseAndMinimize(event, of: frame, in: windows)
        }
    }

    func show(_ city: City) {
        view.setValue(city.demand.residential, named: "residential")
        view.setValue(city.demand.commercial, named: "commercial")
        view.setValue(city.demand.industrial, named: "industrial")
    }
}

/// How to play, in a read-only text area that scrolls.
@MainActor
final class HelpWindow {
    let frame: WindowFrame

    init(theme: InterfaceTheme) {
        let view = UIScriptView(script: loadCityScript(named: "help"), theme: theme)
        view.setText(
            """
            Pick a tool on the left, then click or drag on the map to build. Zones need roads before \
            anyone moves in.

            R zones are homes, C zones are shops, and I zones are industry. The Demand window shows \
            which the city wants.

            Click the funds in the status bar for the budget. The city pauses while it's open, as it \
            does for every modal window.

            The City, Demand, and Help windows stay open beside the map. Drag them by their title bars, \
            and minimize them with the orange button. They wait as icons above the status bar.

            Press Escape to leave for the demo menu.
            """,
            named: "helpText"
        )
        frame = WindowFrame(view: view, title: "Help")
        frame.showsMinimizeButton = true
    }

    func open(in windows: WindowManager, at start: Vector2? = nil) {
        windows.open(frame, at: start) { [unowned self, unowned windows] event in
            handleCloseAndMinimize(event, of: frame, in: windows)
        }
    }
}

/// The city's name, edited in its title, with tabs for its stats and notes.
@MainActor
final class CityPanelWindow {
    private static let statsControls = [
        "foundedLabel", "founded", "populationLabel", "population",
        "zonesLabel", "zones", "roadsLabel", "roads",
    ]

    let frame: WindowFrame
    private let view: UIScriptView
    private let city: City

    init(theme: InterfaceTheme, city: City) {
        view = UIScriptView(script: loadCityScript(named: "citypanel"), theme: theme)
        frame = WindowFrame(view: view)
        frame.showsMinimizeButton = true
        self.city = city
        view.setText(city.name, named: "cityName")
        showTab("statsTab")
    }

    /// Whether the player is typing in the panel, so keys shouldn't reach the game.
    var isTyping: Bool {
        frame.isEditingTitle || view.textArea(named: "notes")?.isFocused == true
    }

    func open(in windows: WindowManager, at start: Vector2? = nil) {
        windows.open(frame, at: start) { [unowned self, unowned windows] event in
            switch event {
            case let .view(.submitted(control: "cityName", text: name)):
                if name.isEmpty {
                    view.setText(city.name, named: "cityName")
                } else {
                    city.name = name
                }
            case let .view(.pressed(control: tab)) where tab == "statsTab" || tab == "notesTab":
                showTab(tab)
            default:
                handleCloseAndMinimize(event, of: frame, in: windows)
            }
        }
    }

    func show(_ city: City) {
        view.setText(city.founded, named: "founded")
        view.setText(grouped(city.population), named: "population")
        view.setText(grouped(city.zonedCount), named: "zones")
        view.setText(grouped(city.count(.road)), named: "roads")
    }

    private func showTab(_ tab: String) {
        let showsStats = tab == "statsTab"
        view.setSelected(showsStats, named: "statsTab")
        view.setSelected(!showsStats, named: "notesTab")
        for name in Self.statsControls {
            view.setHidden(!showsStats, named: name)
        }
        view.setHidden(showsStats, named: "notes")
    }
}

// MARK: - The demo

/// How the city demo ended.
enum CityDemoEnding {
    /// The player chose to go back to the demo menu.
    case menu

    /// The window closed, or a screenshot was taken.
    case quit
}

/// The city demo's HUD, windows, and loop.
@MainActor
final class CityDemo {
    private static let tileSize: Float = 16
    private static let statusHeight: Float = 48
    private static let iconSize = Vector2(x: 110, y: 22)
    private static let headlines = [
        "Council Votes To Paint Every Fire Hydrant A Different Color",
        "Local Pigeon Elected Honorary Traffic Warden",
        "Residents Report Suspiciously Punctual Buses",
        "Mayor Promises Parks, Delivers Several Benches",
        "Bridgeport Bakery Sells Out Of Bread Shaped Like Bridges",
    ]

    private let theme: InterfaceTheme
    private let city = City()
    private let windows = WindowManager()
    private let tools: UIScriptView
    private let overview: UIScriptView
    private let status: UIScriptView
    private let confirm: ConfirmWindow
    private let budget: BudgetWindow
    private let demand: DemandWindow
    private let help: HelpWindow
    private let cityPanel: CityPanelWindow

    private var tool = Tool.residential
    private var speed = 1
    private var monthClock: Float = 0
    private var isPainting = false
    private var isLeaving = false
    private var tickerOffset: Float = 0

    init(theme demoTheme: InterfaceTheme) {
        // Opaque panels, so windows that overlap don't show through each other.
        let theme = InterfaceTheme(
            accent: demoTheme.accent,
            panel: Color(r: 26, g: 30, b: 38, a: 255),
            titleBar: demoTheme.titleBar,
            titleBarBottom: demoTheme.titleBarBottom,
            font: demoTheme.font,
            monospaceFont: demoTheme.monospaceFont,
            fontSpacing: demoTheme.fontSpacing,
            textSizes: demoTheme.textSizes,
            cornerRadius: demoTheme.cornerRadius
        )
        self.theme = theme
        tools = UIScriptView(script: loadCityScript(named: "tools"), theme: theme)
        overview = UIScriptView(script: loadCityScript(named: "overview"), theme: theme)
        status = UIScriptView(script: loadCityScript(named: "status"), theme: theme)
        confirm = ConfirmWindow(theme: theme)
        budget = BudgetWindow(theme: theme, city: city, confirm: confirm)
        demand = DemandWindow(theme: theme)
        help = HelpWindow(theme: theme)
        cityPanel = CityPanelWindow(theme: theme, city: city)
        choose(.residential)
        setSpeed(1)
    }

    /// Runs the demo until the player leaves or the window closes. A `scene` sets up what a
    /// screenshot shows: city, citybudget, or cityconfirm.
    func run(scene: String?, screenshot: String?) -> CityDemoEnding {
        SetWindowTitle("Hudini Demo - CityLimits Style")
        setUp(scene: scene)
        var frameCount = 0
        while !WindowShouldClose() {
            update()
            if isLeaving {
                return .menu
            }
            draw()
            frameCount += 1
            if let screenshot, frameCount == 3 {
                saveScreenshot(to: screenshot)
                return .quit
            }
        }
        return .quit
    }

    private func setUp(scene: String?) {
        let width = Float(GetScreenWidth())
        cityPanel.open(in: windows, at: Vector2(x: 130, y: 70))
        demand.open(in: windows, at: Vector2(x: width - 216, y: 200))
        help.open(in: windows, at: Vector2(x: width - 336, y: 340))
        switch scene {
        case "citybudget":
            budget.open(in: windows)
        case "cityconfirm":
            budget.open(in: windows)
            confirm.ask("Reset the Budget", "Put taxes back to 7%, and fund\nroads and parks in full?", in: windows) { _ in }
        default:
            windows.minimize(help.frame)
        }
    }

    // MARK: Layout

    private var screen: Vector2 {
        Vector2(x: Float(GetScreenWidth()), y: Float(GetScreenHeight()))
    }

    private var toolsOrigin: Vector2 {
        Vector2(x: 8, y: 8)
    }

    private var overviewOrigin: Vector2 {
        Vector2(x: screen.x - 216, y: 8)
    }

    private var statusOrigin: Vector2 {
        Vector2(x: 0, y: screen.y - Self.statusHeight)
    }

    private func panelBounds(_ view: UIScriptView, at origin: Vector2) -> Rectangle {
        Rectangle(x: origin.x, y: origin.y, width: view.windowSize.x, height: view.windowSize.y)
    }

    private func isOverHUD(_ point: Vector2) -> Bool {
        CheckCollisionPointRec(point, panelBounds(tools, at: toolsOrigin))
            || CheckCollisionPointRec(point, panelBounds(overview, at: overviewOrigin))
            || point.y >= statusOrigin.y
            || minimizedIcon(at: point) != nil
    }

    private func iconBounds(_ index: Int) -> Rectangle {
        Rectangle(
            x: 8 + (Float(index) * (Self.iconSize.x + 6)),
            y: statusOrigin.y - Self.iconSize.y - 6,
            width: Self.iconSize.x,
            height: Self.iconSize.y
        )
    }

    private func minimizedIcon(at point: Vector2) -> WindowFrame? {
        windows.minimizedWindows.enumerated().first { CheckCollisionPointRec(point, iconBounds($0.offset)) }?.element
    }

    private func iconTitle(_ frame: WindowFrame) -> String {
        frame === cityPanel.frame ? city.name : frame.title
    }

    private func tile(at point: Vector2) -> (x: Int, y: Int)? {
        let (x, y) = (Int(point.x / Self.tileSize), Int(point.y / Self.tileSize))
        guard point.x >= 0, point.y >= 0, x < City.width, y < City.height, point.y < statusOrigin.y else {
            return nil
        }
        return (x, y)
    }

    // MARK: Input and simulation

    private func update() {
        status.setWindowSize(Vector2(x: screen.x, y: Self.statusHeight))
        let pointer = GetMousePosition()
        let isPressed = IsMouseButtonPressed(.left)
        let wasTyping = cityPanel.isTyping
        let isOverWindow = windows.contains(pointer)

        // Windows sit above the HUD, so they take the pointer first. Their handlers do the work.
        windows.update()

        // The HUD and the map wait while a modal window is open, or while the pointer is over a window.
        let hudTakesInput = !windows.hasModal && !isOverWindow
        if hudTakesInput {
            updateHUD()
            if isPressed, let icon = minimizedIcon(at: pointer) {
                windows.restore(icon)
            }
        }
        if isPressed, hudTakesInput, !isOverHUD(pointer), tile(at: pointer) != nil {
            isPainting = true
        }
        if !IsMouseButtonDown(.left) {
            isPainting = false
        }
        if isPainting, let square = tile(at: pointer) {
            city.apply(tool, square.x, square.y)
        }

        if IsKeyPressed(.escape), !windows.hasModal, !wasTyping {
            confirm.ask("Leave the City", "Go back to the demo menu?\nThe city isn't saved.", in: windows) { [unowned self] isYes in
                isLeaving = isYes
            }
        }

        // Every modal window pauses the city, as in CityLimits.
        let monthLength: Float? = windows.hasModal ? nil : [nil, 1.5, 0.5][speed]
        if let monthLength {
            monthClock += GetFrameTime()
            while monthClock >= monthLength {
                monthClock -= monthLength
                city.advanceMonth()
            }
            tickerOffset += GetFrameTime() * 60
        }
        showCity()
    }

    private func updateHUD() {
        for case let .pressed(control: name) in tools.update(at: toolsOrigin) {
            if let chosen = Tool(rawValue: name) {
                choose(chosen)
            }
        }
        for case let .pressed(control: name) in overview.update(at: overviewOrigin) {
            switch name {
            case "openCity": cityPanel.open(in: windows)
            case "openDemand": demand.open(in: windows)
            case "openHelp": help.open(in: windows)
            default: break
            }
        }
        for case let .pressed(control: name) in status.update(at: statusOrigin) {
            switch name {
            case "pause": setSpeed(0)
            case "normal": setSpeed(1)
            case "fast": setSpeed(2)
            case "funds": budget.open(in: windows)
            default: break
            }
        }
    }

    private func choose(_ chosen: Tool) {
        tool = chosen
        for each in Tool.allCases {
            tools.setSelected(each == chosen, named: each.rawValue)
        }
        tools.setText(chosen.label, named: "toolName")
    }

    private func setSpeed(_ chosen: Int) {
        speed = chosen
        for (index, name) in ["pause", "normal", "fast"].enumerated() {
            status.setSelected(index == chosen, named: name)
        }
    }

    private func showCity() {
        status.setText(city.date, named: "date")
        status.setText(city.name, named: "cityName")
        status.setText("$\(grouped(city.funds))", named: "funds")
        status.setText("Pop \(grouped(city.population))", named: "population")
        status.setText(windows.hasModal ? "Paused" : ["Paused", "Normal", "Fast"][speed], named: "state")
        demand.show(city)
        cityPanel.show(city)
    }

    // MARK: Drawing

    private func draw() {
        BeginDrawing()
        ClearBackground(Color(r: 12, g: 14, b: 18, a: 255))
        drawMap()

        // HUD panels go under every window.
        for (view, origin) in [(tools, toolsOrigin), (overview, overviewOrigin)] {
            let bounds = panelBounds(view, at: origin)
            theme.fillRectangle(bounds, theme.panel)
            theme.outlineRectangle(bounds, theme.border)
        }
        tools.draw(at: toolsOrigin)
        overview.draw(at: overviewOrigin) { _, bounds in
            drawMinimap(in: bounds)
        }
        let statusBounds = panelBounds(status, at: statusOrigin)
        DrawRectangleRec(statusBounds, theme.panel)
        DrawLine(0, Int32(statusBounds.y), Int32(statusBounds.width), Int32(statusBounds.y), theme.border)
        status.draw(at: statusOrigin) { _, bounds in
            drawTicker(in: bounds)
        }
        drawMinimizedIcons()

        windows.draw()
        windows.drawTooltip()
        EndDrawing()
    }

    private func drawMap() {
        for y in 0..<City.height {
            for x in 0..<City.width {
                let tile = city.tile(x, y)
                let left = Int32(Float(x) * Self.tileSize)
                let top = Int32(Float(y) * Self.tileSize)
                DrawRectangle(left, top, Int32(Self.tileSize), Int32(Self.tileSize), tile.color)
                if tile.isZone || tile == .road || tile == .park {
                    DrawRectangleLines(left, top, Int32(Self.tileSize), Int32(Self.tileSize), Color(r: 0, g: 0, b: 0, a: 60))
                }
                if let letter = tile.letter {
                    theme.drawText(letter, x: Int(left) + 5, y: Int(top) + 3, size: 10, color: Color(r: 20, g: 24, b: 30, a: 255))
                }
            }
        }
        let pointer = GetMousePosition()
        if !windows.hasModal, !windows.contains(pointer), !isOverHUD(pointer), let square = tile(at: pointer) {
            DrawRectangleLinesEx(
                Rectangle(x: Float(square.x) * Self.tileSize, y: Float(square.y) * Self.tileSize, width: Self.tileSize, height: Self.tileSize),
                2,
                theme.accent
            )
        }
    }

    private func drawMinimap(in bounds: Rectangle) {
        let width = bounds.width / Float(City.width)
        let height = bounds.height / Float(City.height)
        for y in 0..<City.height {
            for x in 0..<City.width {
                DrawRectangleRec(
                    Rectangle(x: bounds.x + (Float(x) * width), y: bounds.y + (Float(y) * height), width: width.rounded(.up), height: height.rounded(.up)),
                    city.tile(x, y).color
                )
            }
        }
        theme.outlineRectangle(bounds, theme.border)
    }

    private func drawTicker(in bounds: Rectangle) {
        let text = Self.headlines.joined(separator: "   *   ") + "   *   "
        let size = theme.textSizes.body
        let width = Float(max(1, theme.textWidth(of: text, size: size)))
        let start = bounds.x - tickerOffset.truncatingRemainder(dividingBy: width)
        BeginScissorMode(Int32(bounds.x), Int32(bounds.y), Int32(bounds.width), Int32(bounds.height))
        var x = start
        while x < bounds.x + bounds.width {
            theme.drawText(text, x: Int(x), y: Int(bounds.y) + 1, size: size, color: theme.secondaryText)
            x += width
        }
        EndScissorMode()
    }

    // Minimized windows wait as icons above the status bar, as The Sims Online kept its minimized
    // message windows at the screen's edge. A click restores one.
    private func drawMinimizedIcons() {
        let pointer = GetMousePosition()
        for (index, frame) in windows.minimizedWindows.enumerated() {
            let bounds = iconBounds(index)
            let isHovered = CheckCollisionPointRec(pointer, bounds)
            theme.fillRectangle(bounds, isHovered ? theme.selectedItem : theme.titleBar)
            theme.outlineRectangle(bounds, theme.border)
            theme.drawText(
                iconTitle(frame),
                x: Int(bounds.x) + 8,
                y: Int(bounds.y + ((bounds.height - Float(theme.textSizes.body)) / 2)),
                size: theme.textSizes.body,
                color: isHovered ? theme.accent : theme.text
            )
        }
    }
}
