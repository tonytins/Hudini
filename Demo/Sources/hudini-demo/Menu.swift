import Hudini
import Raylib

/// The demos the opening menu offers.
enum DemoChoice: String, CaseIterable {
    /// The Sims Online-style demo in `main.swift`: a property chat, a control panel, and Maxis'
    /// `.uis` and CST formats.
    case sims

    /// The CityLimits-style demo in `CityDemo.swift`: a city map with HUD panels, and windows run
    /// by a `WindowManager`.
    case city
}

/// Shows the opening menu until the player picks a demo, and returns it, or `nil` to quit.
///
/// With a `screenshot` path, it draws a few frames, saves the screen there, and returns `nil`.
@MainActor
func showMenu(theme: InterfaceTheme, screenshot: String?) -> DemoChoice? {
    SetWindowTitle("Hudini Demos")
    let script = loadUIScript(named: "menu")
    let view = UIScriptView(script: script, theme: theme)
    let size = Vector2(x: script.window.size.width, y: script.window.size.height)
    var frameCount = 0
    while !WindowShouldClose() {
        let origin = Vector2(
            x: ((Float(GetScreenWidth()) - size.x) / 2).rounded(),
            y: ((Float(GetScreenHeight()) - size.y) / 2).rounded()
        )
        for event in view.update(at: origin) {
            switch event {
            case .pressed(control: "simsDemo"):
                return .sims
            case .pressed(control: "cityDemo"):
                return .city
            case .pressed(control: "quit"):
                return nil
            default:
                break
            }
        }
        if IsKeyPressed(.escape) {
            return nil
        }

        BeginDrawing()
        ClearBackground(Color(r: 30, g: 42, b: 58, a: 255))
        theme.fillRectangle(Rectangle(x: origin.x, y: origin.y, width: size.x, height: size.y), theme.panel)
        theme.outlineRectangle(Rectangle(x: origin.x, y: origin.y, width: size.x, height: size.y), theme.border)
        view.draw(at: origin)
        EndDrawing()

        frameCount += 1
        if let screenshot, frameCount == 3 {
            saveScreenshot(to: screenshot)
            return nil
        }
    }
    return nil
}

/// Whether a `--screenshot` failed to save, so the demo can exit with an error.
@MainActor
var screenshotFailed = false

/// Saves the screen as an image for the demos' `--screenshot`, noting a failure in
/// `screenshotFailed`.
@MainActor
func saveScreenshot(to path: String) {
    let image = LoadImageFromScreen()
    defer {
        UnloadImage(image)
    }
    if !ExportImage(image, path) {
        screenshotFailed = true
    }
}
