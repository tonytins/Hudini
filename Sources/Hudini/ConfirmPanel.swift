import Foundation
import Raylib

/// A movable modal that asks the user to confirm or cancel an action.
public final class ConfirmPanel {
    private static let padding: Int = 16

    private static let width: Int = 480

    private static let leastHeight: Int = 150

    private static let buttonHeight: Int = 30

    private static let buttonPadding: Int = 14

    private let frame: WindowFrame

    private let theme: InterfaceTheme

    private var lines: [String] = []

    private var confirmTitle = "Yes"

    private var cancelTitle = "No"

    /// Whether the panel is currently visible.
    public private(set) var isOpen: Bool = false

    /// The result of updating the panel for the current frame.
    public enum Answer {
        /// No answer was selected.
        case pending
        /// The confirm action was selected.
        case confirmed
        /// The cancel action was selected.
        case cancelled
    }

    /// The panel's screen bounds.
    public var bounds: Rectangle {
        frame.place(
            size: Vector2(x: Float(Self.width), y: Float(height)),
            at: Vector2(
                x: Float((Int(GetScreenWidth()) - Self.width) / 2),
                y: Float((Int(GetScreenHeight()) - height) / 2)
            )
        )
    }

    /// Creates a confirmation panel using `theme`.
    public init(theme: InterfaceTheme = .standard) {
        self.theme = theme
        frame = WindowFrame(title: "", theme: theme)
    }

    /// Presents a question with titles for its confirm and cancel actions.
    public func show(
        title: String,
        message: String,
        confirmTitle: String = "Yes",
        cancelTitle: String = "No"
    ) {
        (frame.title, self.confirmTitle, self.cancelTitle) = (title, confirmTitle, cancelTitle)
        lines = theme.wrappedLines(
            for: message,
            size: theme.textSizes.body,
            maximumWidth: Self.width - (Self.padding * 2)
        )
        isOpen = true
    }

    /// Handles this frame's input, including dragging, and returns the selected action. Any
    /// answer closes the panel.
    ///
    /// Escape cancels. raylib also closes the window on Escape by default, so
    /// call `SetExitKey(.null)` after `InitWindow` when using this panel.
    public func update() -> ConfirmPanel.Answer {
        guard isOpen else {
            return .pending
        }
        let answer = currentAnswer()
        if answer != .pending {
            isOpen = false
        }
        return answer
    }

    /// Draws the panel when it is open, centered on the screen until the user moves it.
    public func draw() {
        guard isOpen else {
            return
        }
        DrawRectangle(0, 0, Int(GetScreenWidth()), Int(GetScreenHeight()), theme.overlay)
        let bounds = bounds
        frame.draw(in: bounds)
        var y = Int(clamping: bounds.y) + WindowFrame.titleHeight + 12
        for line in lines {
            theme.drawText(line, x: Int(clamping: bounds.x) + Self.padding, y: y, size: theme.textSizes.body, color: theme.secondaryText)
            y += lineHeight
        }
        let mouse = GetMousePosition()
        ConfirmPanel.drawButton(confirmBounds(), confirmTitle, mouse, theme: theme)
        ConfirmPanel.drawButton(cancelBounds(), cancelTitle, mouse, theme: theme)
    }

    private func currentAnswer() -> ConfirmPanel.Answer {
        if frame.followPointer(in: bounds) {
            return .pending
        }
        if IsKeyPressed(KeyboardKey.escape) || frame.update(in: bounds) == .close {
            return .cancelled
        }
        if IsKeyPressed(KeyboardKey.enter) || IsKeyPressed(KeyboardKey.kpEnter) {
            return .confirmed
        }
        guard IsMouseButtonPressed(MouseButton.left) else {
            return .pending
        }
        let mouse = GetMousePosition()
        if CheckCollisionPointRec(mouse, confirmBounds()) {
            return .confirmed
        }
        return CheckCollisionPointRec(mouse, cancelBounds()) ? .cancelled : .pending
    }

    private static func drawButton(_ bounds: Rectangle, _ label: String, _ mouse: Vector2, theme: InterfaceTheme) {
        DrawRectangleRec(bounds, theme.border)
        let size = theme.textSizes.button
        let labelWidth = theme.textWidth(of: label, size: size)
        let color = CheckCollisionPointRec(mouse, bounds) ? theme.accent : theme.text
        theme.drawText(label, x: Int(clamping: bounds.x + ((bounds.width - Float(labelWidth)) / 2)), y: Int(clamping: bounds.y) + ((Int(clamping: bounds.height) - size) / 2), size: size, color: color)
    }

    private var lineHeight: Int {
        theme.textSizes.body + 4
    }

    private var height: Int {
        max(Self.leastHeight, WindowFrame.titleHeight + 12 + (lines.count * lineHeight) + 16 + Self.buttonHeight + Self.padding)
    }

    private func cancelBounds() -> Rectangle {
        let bounds = bounds
        let buttonWidth = theme.textWidth(of: cancelTitle, size: theme.textSizes.button) + (Self.buttonPadding * 2)
        return Rectangle(
            x: bounds.x + Float(Self.width - Self.padding - buttonWidth),
            y: bounds.y + Float(height - Self.padding - Self.buttonHeight),
            width: Float(buttonWidth),
            height: Float(Self.buttonHeight)
        )
    }

    private func confirmBounds() -> Rectangle {
        let cancel = cancelBounds()
        let buttonWidth = theme.textWidth(of: confirmTitle, size: theme.textSizes.button) + (Self.buttonPadding * 2)
        return Rectangle(
            x: cancel.x - Float(buttonWidth) - 10,
            y: cancel.y,
            width: Float(buttonWidth),
            height: cancel.height
        )
    }
}
