import Foundation
import Raylib

/// A movable modal that asks the user to confirm or cancel an action.
public final class ConfirmPanel {
    private static let fontSize: Int = 20

    private static let textSize: Int = 14

    private static let padding: Int = 16

    private static let width: Int = 480

    private static let leastHeight: Int = 150

    private static let lineHeight: Int = textSize + 4

    private static let buttonHeight: Int = 30

    private static let buttonPadding: Int = 14

    private let frame: WindowFrame

    private let theme: InterfaceTheme

    private var lines: [String] = []

    private var confirmTitle = "Yes"

    private var cancelTitle = "No"

    /// The result of updating the panel for the current frame.
    public enum Answer {
        /// No answer was selected.
        case pending
        /// The confirm action was selected.
        case confirmed
        /// The cancel action was selected.
        case cancelled
    }

    /// Presents a question with custom titles for its confirm and cancel actions.
    public func ask(title: String, message: String, confirmTitle: String, cancelTitle: String) {
        (frame.title, self.confirmTitle, self.cancelTitle) = (title, confirmTitle, cancelTitle)
        lines = TextWrapper.lines(
            for: message,
            fontSize: Self.textSize,
            maximumWidth: Self.width - (Self.padding * 2)
        )
    }

    /// Handles this frame's input and returns the selected action.
    ///
    /// Escape cancels. raylib also closes the window on Escape by default, so
    /// call `SetExitKey(.null)` after `InitWindow` when using this panel.
    public func update() -> ConfirmPanel.Answer {
        if frame.followPointer(in: bounds()) {
            return .pending
        }
        if IsKeyPressed(KeyboardKey.escape) || frame.update(in: bounds()) == .close {
            return .cancelled
        }
        if IsKeyPressed(KeyboardKey.enter) || IsKeyPressed(KeyboardKey.kpEnter) {
            return .confirmed
        }
        if !IsMouseButtonPressed(MouseButton.left) {
            return .pending
        }
        let mouse = GetMousePosition()
        return CheckCollisionPointRec(mouse, yesBounds()) ? .confirmed : CheckCollisionPointRec(mouse, noBounds()) ? .cancelled : .pending
    }

    /// Draws the panel centered on the screen until the user moves it.
    public func draw() {
        DrawRectangle(0, 0, Int(GetScreenWidth()), Int(GetScreenHeight()), theme.overlay)
        let bounds = bounds()
        frame.draw(in: bounds)
        var y = Int(clamping: bounds.y) + WindowFrame.titleHeight + 12
        for line in lines {
            DrawText(line, Int(clamping: bounds.x) + Self.padding, y, Self.textSize, theme.secondaryText)
            y += Self.lineHeight
        }
        let mouse = GetMousePosition()
        ConfirmPanel.drawButton(yesBounds(), confirmTitle, mouse, theme: theme)
        ConfirmPanel.drawButton(noBounds(), cancelTitle, mouse, theme: theme)
    }

    private static func drawButton(_ bounds: Rectangle, _ label: String, _ mouse: Vector2, theme: InterfaceTheme) {
        DrawRectangleRec(bounds, theme.border)
        let labelWidth = MeasureText(label, fontSize)
        let color = CheckCollisionPointRec(mouse, bounds) ? theme.accent : theme.text
        DrawText(label, Int(clamping: bounds.x + ((bounds.width - Float(labelWidth)) / 2)), Int(clamping: bounds.y) + 5, fontSize, color)
    }

    private var height: Int {
        max(Self.leastHeight, WindowFrame.titleHeight + 12 + (lines.count * Self.lineHeight) + 16 + Self.buttonHeight + Self.padding)
    }

    private func bounds() -> Rectangle {
        frame.place(
            size: Vector2(x: Float(Self.width), y: Float(height)),
            at: Vector2(
                x: Float((Int(GetScreenWidth()) - Self.width) / 2),
                y: Float((Int(GetScreenHeight()) - height) / 2)
            )
        )
    }

    private func noBounds() -> Rectangle {
        let bounds = bounds()
        let buttonWidth = MeasureText(cancelTitle, Self.fontSize) + (Self.buttonPadding * 2)
        return Rectangle(
            x: bounds.x + Float(Self.width - Self.padding - buttonWidth),
            y: bounds.y + Float(height - Self.padding - Self.buttonHeight),
            width: Float(buttonWidth),
            height: Float(Self.buttonHeight)
        )
    }

    private func yesBounds() -> Rectangle {
        let cancelBounds = noBounds()
        let buttonWidth = MeasureText(confirmTitle, Self.fontSize) + (Self.buttonPadding * 2)
        return Rectangle(
            x: cancelBounds.x - Float(buttonWidth) - 10,
            y: cancelBounds.y,
            width: Float(buttonWidth),
            height: cancelBounds.height
        )
    }

    /// Creates a confirmation panel using `theme`.
    public init(theme: InterfaceTheme = .standard) {
        self.theme = theme
        frame = WindowFrame(title: "", theme: theme)
    }
}
