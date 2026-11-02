import Foundation
import Raylib

/// A one-line text box: it takes typed characters while it has focus, and Backspace removes the
/// last one, repeating while held. Raylib's built-in font draws only printable ASCII, so other
/// characters are not taken.
public final class TextField: FormLayoutControl {
    private static let defaultFontSize: Int = 20

    private static let padding: Int = 6

    private var _text: String = ""

    private let maxLength: Int

    private let accepts: (Character) -> Bool

    private let fontSize: Int

    private let theme: InterfaceTheme

    /// The field's most recently assigned bounds.
    public private(set) var bounds = Rectangle()

    /// Creates a field that accepts at most `maximumLength` characters.
    public init(
        text: String = "",
        maximumLength: Int,
        accepting characters: @escaping (Character) -> Bool = { _ in true },
        fontSize: Int = 20,
        theme: InterfaceTheme = .standard
    ) {
        precondition(maximumLength > 0, "maximumLength must be positive")
        precondition(fontSize > 0, "fontSize must be positive")
        maxLength = maximumLength
        accepts = characters
        self.fontSize = fontSize
        self.theme = theme
        self.text = text
    }

    /// The text in the field.
    public var text: String {
        get {
            _text
        }
        set {
            _text.removeAll()
            for c in newValue {
                add(c)
            }
        }
    }

    /// How many characters the field holds, without making its text.
    public var length: Int {
        _text.count
    }

    /// The height a field of the usual size is drawn at.
    public static var defaultHeight: Int {
        defaultFontSize + (padding * 2)
    }

    /// The height this field is drawn at.
    public var height: Int {
        fontSize + (TextField.padding * 2)
    }

    /// The field's default height when used in a `FormLayout`.
    public var formHeight: Float {
        Float(height)
    }

    /// Assigns the field's bounds, for example when placing it in a `FormLayout`.
    public func place(in bounds: Rectangle) {
        self.bounds = bounds
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
        return changed || _text.count != length
    }

    /// Draws the field in its bounds, showing a caret when it has focus.
    public func draw(in bounds: Rectangle, isFocused: Bool) {
        DrawRectangleRec(bounds, theme.inputBackground)
        DrawRectangleLinesEx(bounds, 1.0, isFocused ? theme.accent : theme.border)
        let text = text
        let x = Int(clamping: bounds.x) + TextField.padding
        let y = Int(clamping: bounds.y) + TextField.padding
        DrawText(text, x, y, fontSize, theme.text)
        if isFocused, Int(clamping: GetTime() * 2) % 2 == 0 {
            let caretX = x + MeasureText(text, fontSize) + 2
            DrawRectangle(caretX, y, 2, fontSize, theme.text)
        }
    }

    /// Draws the field in its most recently assigned bounds.
    public func draw(isFocused: Bool) {
        draw(in: bounds, isFocused: isFocused)
    }

    private func add(_ c: Character) {
        if _text.count < maxLength, (c >= " " && c <= "~"), accepts(c) {
            _text.append(c)
        }
    }
}
