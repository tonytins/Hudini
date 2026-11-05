import Foundation
import Raylib

/// A movable notice with a title, message, and dismiss button.
public final class NoticePanel {
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
        frame.title = title
        lines.removeAll()
        lines.append(contentsOf: theme.wrappedLines(
            for: message,
            size: Self.fontSize,
            maximumWidth: Self.width - (Self.padding * 2)
        ))
        isOpen = true
    }

    /// Handles input for this frame, including dragging, and reports whether the notice was
    /// dismissed.
    ///
    /// Escape dismisses. raylib also closes the window on Escape by default, so
    /// call `SetExitKey(.null)` after `InitWindow` when using this panel.
    public func update() -> Bool {
        if !isOpen || frame.followPointer(in: bounds) {
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
            theme.drawText(line, x: x, y: y, size: Self.fontSize, color: theme.secondaryText)
            y += Self.lineHeight
        }
        let button = Self.buttonBounds(bounds)
        let hovered = CheckCollisionPointRec(GetMousePosition(), button)
        DrawRectangleRec(button, hovered ? theme.border : theme.panel)
        DrawRectangleLinesEx(button, 1.0, theme.accent)
        let textX = Int(clamping: button.x + Float((Self.buttonWidth - theme.textWidth(of: Self.buttonText, size: Self.fontSize)) / 2))
        theme.drawText(Self.buttonText, x: textX, y: Int(clamping: button.y) + ((Self.buttonHeight - Self.fontSize) / 2), size: Self.fontSize, color: hovered ? theme.accent : theme.text)
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
