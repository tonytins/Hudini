import Foundation
import Raylib

/// A multiline text box that wraps input to its bounds and keeps the caret at the end.
/// The built-in raylib font draws printable ASCII, so other characters are ignored.
///
/// An area can remember its bounds through `place(in:)`, for example from a `FormLayout`, or
/// receive them on each `update(in:)` and `draw(in:)`.
public final class TextArea: FormLayoutControl {
    private static let padding: Int = 6

    private static let lineGap: Int = 4

    private var _text: String = ""

    private let maxLength: Int

    private let fontSize: Int

    private var lines: [String] = []

    // The width `lines` was wrapped to, or nil when the text has changed since.
    private var wrappedWidth: Int?

    private let theme: InterfaceTheme

    /// Whether this area currently receives keyboard input.
    public private(set) var isFocused = false

    /// The area's most recently assigned bounds.
    public private(set) var bounds = Rectangle()

    /// Creates a box with a character limit. Without a `fontSize`, it uses the theme's `input` size.
    public init(
        text: String = "",
        maximumLength: Int,
        fontSize: Int? = nil,
        theme: InterfaceTheme = .standard
    ) {
        precondition(maximumLength > 0, "maximumLength must be positive")
        precondition(fontSize.map { $0 > 0 } ?? true, "fontSize must be positive")
        self.maxLength = maximumLength
        self.fontSize = fontSize ?? theme.textSizes.input
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
            wrappedWidth = nil
        }
    }

    /// Returns the height required to display the given number of lines.
    public func height(forLineCount lineCount: Int) -> Int {
        (lineCount * (fontSize + TextArea.lineGap)) - TextArea.lineGap + (TextArea.padding * 2)
    }

    /// The area's default four-line height when used in a `FormLayout`.
    public var formHeight: Float {
        Float(height(forLineCount: 4))
    }

    /// Assigns the area's bounds, for example when placing it in a `FormLayout`.
    public func place(in bounds: Rectangle) {
        self.bounds = bounds
    }

    /// Updates focus and typing using the area's most recently assigned bounds, and reports
    /// whether the text changed.
    public func update() -> Bool {
        update(in: bounds)
    }

    /// Updates focus from pointer input, takes typing while focused, and reports whether the
    /// text changed. Clicking outside the area gives up focus.
    public func update(in bounds: Rectangle) -> Bool {
        self.bounds = bounds
        if IsMouseButtonPressed(MouseButton.left) {
            isFocused = CheckCollisionPointRec(GetMousePosition(), bounds)
        }
        guard isFocused else {
            return false
        }
        let length = _text.count
        var key = Int(GetCharPressed())
        while key != 0 {
            add(Character(codePoint: key))
            key = Int(GetCharPressed())
        }
        if (IsKeyPressed(KeyboardKey.backspace) || IsKeyPressedRepeat(KeyboardKey.backspace)), _text.count > 0 {
            _text.removeLast()
        }
        guard _text.count != length else {
            return false
        }
        wrappedWidth = nil
        return true
    }

    /// Draws the box in its most recently assigned bounds.
    public func draw() {
        draw(in: bounds)
    }

    /// Draws the box in `bounds`, with a caret at the end when it has focus. Lines past what the
    /// box can show are left out from the top, so the end being typed stays in view.
    public func draw(in bounds: Rectangle) {
        wrap(toFit: bounds)
        DrawRectangleRec(bounds, theme.inputBackground)
        DrawRectangleLinesEx(bounds, 1.0, isFocused ? theme.accent : theme.border)
        let room = max(1, (Int(clamping: bounds.height) - (TextArea.padding * 2) + TextArea.lineGap) / (fontSize + TextArea.lineGap))
        let first = max(0, lines.count - room)
        let x = Int(clamping: bounds.x) + TextArea.padding
        var y = Int(clamping: bounds.y) + TextArea.padding
        for i in stride(from: first, to: lines.count, by: 1) {
            theme.drawText(lines[i], x: x, y: y, size: fontSize, color: theme.text)
            y += fontSize + TextArea.lineGap
        }
        if isFocused, Int(clamping: GetTime() * 2) % 2 == 0 {
            let last = lines.last ?? ""
            let caretY = Int(clamping: bounds.y) + TextArea.padding + ((max(lines.count, 1) - 1 - first) * (fontSize + TextArea.lineGap))
            DrawRectangle(x + theme.textWidth(of: last, size: fontSize) + 2, caretY, 2, fontSize, theme.text)
        }
    }

    private func wrap(toFit bounds: Rectangle) {
        let width = max(1, Int(clamping: bounds.width) - (TextArea.padding * 2) - 4)
        guard wrappedWidth != width else {
            return
        }
        lines = theme.wrappedLines(for: _text, size: fontSize, maximumWidth: width)
        wrappedWidth = width
    }

    private func add(_ c: Character) {
        if _text.count < maxLength, (c >= " " && c <= "~") {
            _text.append(c)
        }
    }
}
