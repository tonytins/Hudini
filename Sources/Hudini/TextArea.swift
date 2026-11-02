import Foundation
import Raylib

/// A multiline text box that wraps input to its width and keeps the caret at the end.
/// The built-in raylib font draws printable ASCII, so other characters are ignored.
public final class TextArea {
    private static let padding: Int = 6

    private static let lineGap: Int = 4

    private var _text: String = ""

    private let maxLength: Int

    private let fontSize: Int

    private let width: Int

    private var lines: [String] = []

    private let theme: InterfaceTheme

    /// Creates a box with a character limit, font size, and wrapping width.
    public init(
        text: String = "",
        maximumLength: Int,
        fontSize: Int = 20,
        width: Int,
        theme: InterfaceTheme = .standard
    ) {
        precondition(maximumLength > 0, "maximumLength must be positive")
        precondition(fontSize > 0, "fontSize must be positive")
        precondition(width > TextArea.padding * 2, "width must be more than TextArea.padding * 2")
        self.maxLength = maximumLength
        self.fontSize = fontSize
        self.width = width
        self.theme = theme
        self.text = text
    }

    /// The text in the box.
    public var text: String {
        get {
            _text
        }
        set {
            _text.removeAll()
            for c in newValue {
                add(c)
            }
            wrap()
        }
    }

    /// Returns the height required to display the given number of lines.
    public func height(forLineCount lineCount: Int) -> Int {
        (lineCount * (fontSize + TextArea.lineGap)) - TextArea.lineGap + (TextArea.padding * 2)
    }

    /// Takes this frame's typing and reports whether the text changed.
    public func update() -> Bool {
        let length = _text.count
        var changed = false
        var key = Int(GetCharPressed())
        while key != 0 {
            add(Character(codePoint: key))
            key = Int(GetCharPressed())
        }
        if (IsKeyPressed(KeyboardKey.backspace) || IsKeyPressedRepeat(KeyboardKey.backspace)), _text.count > 0 {
            _text.removeLast()
            changed = true
        }
        changed = _text.count != length || changed
        if changed {
            wrap()
        }
        return changed
    }

    /// Draws the box in its bounds, with a caret at the end when it has focus. Lines past what the
    /// box can show are left out from the top, so the end being typed stays in view.
    public func draw(in bounds: Rectangle, isFocused: Bool) {
        DrawRectangleRec(bounds, theme.inputBackground)
        DrawRectangleLinesEx(bounds, 1.0, isFocused ? theme.accent : theme.border)
        let room = max(1, (Int(clamping: bounds.height) - (TextArea.padding * 2) + TextArea.lineGap) / (fontSize + TextArea.lineGap))
        let first = max(0, lines.count - room)
        let x = Int(clamping: bounds.x) + TextArea.padding
        var y = Int(clamping: bounds.y) + TextArea.padding
        for i in stride(from: first, to: lines.count, by: 1) {
            DrawText(lines[i], x, y, fontSize, theme.text)
            y += fontSize + TextArea.lineGap
        }
        if isFocused, Int(clamping: GetTime() * 2) % 2 == 0 {
            let last = lines.count == 0 ? "" : lines[lines.count - 1]
            let caretY = Int(clamping: bounds.y) + TextArea.padding + ((max(lines.count, 1) - 1 - first) * (fontSize + TextArea.lineGap))
            DrawRectangle(x + MeasureText(last, fontSize) + 2, caretY, 2, fontSize, theme.text)
        }
    }

    private func wrap() {
        lines = _text.isEmpty
            ? []
            : TextWrapper.lines(for: _text, fontSize: fontSize, maximumWidth: width - (TextArea.padding * 2) - 4)
    }

    private func add(_ c: Character) {
        if _text.count < maxLength, (c >= " " && c <= "~") {
            _text.append(c)
        }
    }
}
