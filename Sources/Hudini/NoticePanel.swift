import Foundation
import Raylib

/// A movable notice with a title, message, and dismiss button.
public final class NoticePanel: MovableWindow {
    private static let fontSize: Int = 14

    private static let padding: Int = 12

    private static let width: Int = 340

    private static let lineHeight: Int = 18

    private static let top: Int = WindowFrame.titleHeight + 8

    private static let buttonWidth: Int = 90

    private static let buttonHeight: Int = 28

    private static let buttonText: String = "Okay"

    private let frame: WindowFrame

    private var lines: [String] = []

    private let theme: InterfaceTheme

    /// Whether the notice is currently visible.
    public private(set) var isOpen: Bool = false

    /// Whether the notice is being dragged by its title bar.
    public var isDragging: Bool {
        frame.isDragging
    }

    /// The notice's screen bounds.
    public var bounds: Rectangle {
        let size = Vector2(x: Float(Self.width), y: Float(height))
        return frame.place(
            size: size,
            at: Vector2(x: (Float(Int(GetScreenWidth())) - size.x) / 2, y: (Float(Int(GetScreenHeight())) - size.y) / 2)
        )
    }

    /// Presents the notice with a title and message.
    public func show(title: String, message: String) {
        precondition(!title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "title must not be blank")
        precondition(!message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "message must not be blank")
        frame.title = title
        lines.removeAll()
        lines.append(contentsOf: TextWrapper.lines(
            for: message,
            fontSize: Self.fontSize,
            maximumWidth: Self.width - (Self.padding * 2)
        ))
        isOpen = true
    }

    /// Starts moving the notice when a press lands on its title bar.
    public func beginDragging(at point: Vector2) -> Bool {
        isOpen && frame.beginDragging(at: point, within: bounds)
    }

    /// Moves the notice with the pointer while the button is held.
    public func drag(to point: Vector2, isHeld: Bool) {
        frame.drag(to: point, isHeld: isHeld, windowSize: Vector2(x: Float(Self.width), y: Float(height)))
    }

    /// Handles input for this frame and reports whether the notice was dismissed.
    ///
    /// Escape dismisses. raylib also closes the window on Escape by default, so
    /// call `SetExitKey(.null)` after `InitWindow` when using this panel.
    public func update() -> Bool {
        if !isOpen {
            return false
        }
        let closed = IsKeyPressed(KeyboardKey.enter) || IsKeyPressed(KeyboardKey.kpEnter) || IsKeyPressed(KeyboardKey.escape) || (IsMouseButtonPressed(MouseButton.left) && CheckCollisionPointRec(GetMousePosition(), Self.buttonBounds(bounds))) || frame.update(in: bounds) == .close
        isOpen = !closed
        return closed
    }

    /// Draws the notice when it is open.
    public func draw() {
        if !isOpen {
            return
        }
        let bounds = bounds
        frame.draw(in: bounds)
        let x = Int(clamping: bounds.x) + Self.padding
        var y = Int(clamping: bounds.y) + Self.top
        for line in lines {
            DrawText(line, x, y, Self.fontSize, theme.secondaryText)
            y += Self.lineHeight
        }
        let button = Self.buttonBounds(bounds)
        let hovered = CheckCollisionPointRec(GetMousePosition(), button)
        DrawRectangleRec(button, hovered ? theme.border : theme.panel)
        DrawRectangleLinesEx(button, 1.0, theme.accent)
        let textX = Int(clamping: button.x + Float((Self.buttonWidth - MeasureText(Self.buttonText, Self.fontSize)) / 2))
        DrawText(Self.buttonText, textX, Int(clamping: button.y) + ((Self.buttonHeight - Self.fontSize) / 2), Self.fontSize, hovered ? theme.accent : theme.text)
    }

    private var height: Int {
        Self.top + (max(lines.count, 1) * Self.lineHeight) + Self.padding + Self.buttonHeight + Self.padding
    }

    private static func buttonBounds(_ bounds: Rectangle) -> Rectangle {
        Rectangle(x: bounds.x + ((bounds.width - Float(buttonWidth)) / 2), y: bounds.y + bounds.height - Float(padding) - Float(buttonHeight), width: Float(buttonWidth), height: Float(buttonHeight))
    }

    /// Creates a notice panel using `theme`.
    public init(theme: InterfaceTheme = .standard) {
        self.theme = theme
        frame = WindowFrame(title: "", theme: theme)
    }
}
