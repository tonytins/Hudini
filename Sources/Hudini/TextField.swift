import Foundation
import Raylib

/// A one-line text box: it takes typed characters while it has focus, and Backspace removes the
/// last one, repeating while held. Raylib's built-in font draws only printable ASCII, so other
/// characters are not taken.
///
/// A field can remember its bounds through `place(in:)`, for example from a `FormLayout`, or
/// receive them on each `update(in:)` and `draw(in:)`.
public final class TextField: FormLayoutControl {
    private static let padding: Int = 6

    private static let caretRoom: Int = 4

    private var _text: String = ""

    private let maxLength: Int

    private let accepts: (Character) -> Bool

    private let fontSize: Int

    private let theme: InterfaceTheme

    private let placeholder: String?

    private let textColor: Color

    private let backgroundColor: Color

    private let borderColor: Color

    /// Whether this field only displays text. A read-only field never takes focus or typing, and
    /// the host can still set its `text`.
    public let isReadOnly: Bool

    /// Whether this field currently receives keyboard input.
    public private(set) var isFocused = false

    /// The field's most recently assigned bounds.
    public private(set) var bounds = Rectangle()

    /// Creates a field that accepts at most `maximumLength` characters.
    public init(
        text: String = "",
        maximumLength: Int,
        accepting characters: @escaping (Character) -> Bool = { _ in true },
        fontSize: Int = 20,
        theme: InterfaceTheme = .standard,
        placeholder: String? = nil,
        textColor: Color? = nil,
        backgroundColor: Color? = nil,
        borderColor: Color? = nil,
        isReadOnly: Bool = false
    ) {
        precondition(maximumLength > 0, "maximumLength must be positive")
        precondition(fontSize > 0, "fontSize must be positive")
        maxLength = maximumLength
        accepts = characters
        self.fontSize = fontSize
        self.theme = theme
        self.placeholder = placeholder
        self.textColor = textColor ?? theme.text
        self.backgroundColor = backgroundColor ?? theme.inputBackground
        self.borderColor = borderColor ?? theme.border
        self.isReadOnly = isReadOnly
        self.text = text
    }

    /// An event produced by this field.
    public enum Event: Equatable, Sendable {
        /// The user submitted a non-empty draft.
        case submitted(String)
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

    func setFocused(_ isFocused: Bool) {
        self.isFocused = isFocused
    }

    /// Takes this frame's typing regardless of focus and reports whether the text changed.
    func takeTyping() -> Bool {
        let length = _text.count
        var key = Int(GetCharPressed())
        while key != 0 {
            add(Character(codePoint: key))
            key = Int(GetCharPressed())
        }
        if (IsKeyPressed(KeyboardKey.backspace) || IsKeyPressedRepeat(KeyboardKey.backspace)), _text.count > 0 {
            _text.removeLast()
        }
        return _text.count != length
    }

    /// Updates focus and keyboard input using the field's most recently assigned bounds.
    public func update() -> Event? {
        update(in: bounds)
    }

    /// Updates focus from pointer input and handles keyboard input while focused.
    ///
    /// Clicking outside the field gives up focus. Enter returns a submission
    /// event for non-empty text and clears the draft.
    public func update(in bounds: Rectangle) -> Event? {
        self.bounds = bounds
        guard !isReadOnly else {
            return nil
        }
        if IsMouseButtonPressed(MouseButton.left) {
            isFocused = CheckCollisionPointRec(GetMousePosition(), bounds)
        }
        guard isFocused else {
            return nil
        }
        _ = takeTyping()
        if IsKeyPressed(KeyboardKey.enter) || IsKeyPressed(KeyboardKey.kpEnter) {
            return submit()
        }
        return nil
    }

    /// Submits and clears the current draft when it contains non-whitespace text.
    ///
    /// The submitted text is preserved exactly. An empty or whitespace-only
    /// draft remains in the field and produces no event, and a read-only field
    /// never submits.
    public func submit() -> Event? {
        guard !isReadOnly, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let submittedText = text
        text = ""
        return .submitted(submittedText)
    }

    /// Draws the field in its most recently assigned bounds.
    public func draw() {
        draw(in: bounds)
    }

    /// Draws the field in `bounds`, showing a caret when it has focus.
    ///
    /// Contents are clipped to the field. Text too wide to fit shifts left so
    /// its end and the caret stay visible.
    public func draw(in bounds: Rectangle) {
        DrawRectangleRec(bounds, backgroundColor)
        DrawRectangleLinesEx(bounds, 1.0, isFocused ? theme.accent : borderColor)
        let text = text
        let left = Int(clamping: bounds.x) + TextField.padding
        let room = max(0, Int(clamping: bounds.width) - (TextField.padding * 2))
        let overflow = max(0, MeasureText(text, fontSize) + TextField.caretRoom - room)
        let x = left - overflow
        let y = Int(clamping: bounds.y) + ((Int(clamping: bounds.height) - fontSize) / 2)
        BeginScissorMode(
            left,
            Int(clamping: bounds.y) + 1,
            room,
            max(0, Int(clamping: bounds.height) - 2)
        )
        defer {
            EndScissorMode()
        }
        if text.isEmpty, let placeholder {
            DrawText(placeholder, x, y, fontSize, theme.secondaryText)
        } else {
            DrawText(text, x, y, fontSize, textColor)
        }
        if isFocused, Int(clamping: GetTime() * 2) % 2 == 0 {
            let caretX = x + MeasureText(text, fontSize) + 2
            DrawRectangle(caretX, y, 2, fontSize, textColor)
        }
    }

    private func add(_ c: Character) {
        if _text.count < maxLength, (c >= " " && c <= "~"), accepts(c) {
            _text.append(c)
        }
    }
}
