import Foundation
import Raylib

/// A multi-line text box. It takes typing while it has focus: Enter adds a line break, and
/// Backspace removes the last character, repeating while held. Text wraps at spaces, and the area
/// scrolls with the wheel and through `scroll(byLines:)` and `scroll(toFraction:)`, which a
/// scrollbar or buttons can drive.
///
/// The caret stays at the end of the text, and typing scrolls it back into view. The built-in
/// raylib font draws printable ASCII, so other characters are ignored.
///
/// An area can remember its bounds through `place(in:)`, for example from a `FormLayout`, or
/// receive them on each `update(in:)` and `draw(in:)`.
public final class TextArea: FormLayoutControl {
    private static let padding: Int = 6
    private static let lineGap: Int = 4
    private static let caretRoom: Int = 4
    private static let linesPerWheelNotch: Float = 3
    private static let minimumThumbHeight: Float = 6

    private var _text: String = ""

    private let maxLength: Int

    private let placeholder: String?

    // What the caller asked for. Anything left out comes from the theme when drawing.
    private let fontSizeOverride: Int?
    private let textColorOverride: Color?
    private let backgroundColorOverride: Color?
    private let borderColorOverride: Color?

    // The theme's size this area uses without a fontSize: `input`, or another for an area that a
    // document owns.
    private let themeSize: KeyPath<InterfaceTheme.TextSizes, Int>

    private var fontSize: Int {
        fontSizeOverride ?? theme.textSizes[keyPath: themeSize]
    }

    private var textColor: Color {
        textColorOverride ?? theme.text
    }

    private var backgroundColor: Color {
        backgroundColorOverride ?? theme.inputBackground
    }

    private var borderColor: Color {
        borderColorOverride ?? theme.border
    }

    private var lines: [String] = []
    // The width `lines` was wrapped to, or nil when the text has changed since.
    private var wrappedWidth: Int?
    private var visibleLineCount = 1
    // The line at the top of the area.
    private var firstLine = 0
    // Whether the next layout moves to the last line, after typing or a followed change.
    private var movesToEnd: Bool
    private var pendingWheelLines: Float = 0

    /// The colors and size the area draws with. Setting it takes effect from the next draw, and keeps
    /// the area's text and focus. Colors and a size passed when creating the area still win.
    public var theme: InterfaceTheme {
        didSet {
            wrappedWidth = nil
        }
    }

    /// Whether this area only displays text. A read-only area never takes focus or typing, still
    /// scrolls, and the host can still set its `text`.
    public let isReadOnly: Bool

    /// Whether the area stays at its last line when its text changes while it shows that line, as
    /// a terminal or a log does. Scrolled back, it stays put. An area that follows opens at its
    /// last line, and one that doesn't opens at its first.
    public let follows: Bool

    /// Whether this area currently receives keyboard input.
    public private(set) var isFocused = false

    /// The area's most recently assigned bounds.
    public private(set) var bounds = Rectangle()

    /// Creates an area that accepts at most `maximumLength` characters, counting line breaks.
    /// Without a `fontSize`, it uses the theme's `input` size.
    public convenience init(
        text: String = "",
        maximumLength: Int,
        fontSize: Int? = nil,
        theme: InterfaceTheme = .standard,
        placeholder: String? = nil,
        textColor: Color? = nil,
        backgroundColor: Color? = nil,
        borderColor: Color? = nil,
        isReadOnly: Bool = false,
        follows: Bool = false
    ) {
        self.init(
            text: text,
            maximumLength: maximumLength,
            fontSize: fontSize,
            themeSize: \.input,
            theme: theme,
            placeholder: placeholder,
            textColor: textColor,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            isReadOnly: isReadOnly,
            follows: follows
        )
    }

    /// Creates an area whose size, without a `fontSize`, is `themeSize` from the theme.
    init(
        text: String,
        maximumLength: Int,
        fontSize: Int?,
        themeSize: KeyPath<InterfaceTheme.TextSizes, Int>,
        theme: InterfaceTheme,
        placeholder: String?,
        textColor: Color?,
        backgroundColor: Color?,
        borderColor: Color?,
        isReadOnly: Bool,
        follows: Bool
    ) {
        precondition(maximumLength > 0, "maximumLength must be positive")
        precondition(fontSize.map { $0 > 0 } ?? true, "fontSize must be positive")
        maxLength = maximumLength
        fontSizeOverride = fontSize
        self.themeSize = themeSize
        self.theme = theme
        self.placeholder = placeholder
        textColorOverride = textColor
        backgroundColorOverride = backgroundColor
        borderColorOverride = borderColor
        self.isReadOnly = isReadOnly
        self.follows = follows
        movesToEnd = follows
        self.text = text
    }

    /// The text in the area, with `\n` between lines. Setting it keeps the scroll position, or
    /// stays at the last line when the area `follows` and shows it.
    public var text: String {
        get {
            _text
        }
        set {
            if follows, isAtEnd {
                movesToEnd = true
            }
            _text.removeAll()
            for c in newValue {
                add(c)
            }
            wrappedWidth = nil
        }
    }

    /// Gives or removes keyboard focus, for example so a window opens with its area ready for
    /// typing. A read-only area stays unfocused.
    ///
    /// `update` still applies the current frame's click, so a click outside the area takes focus
    /// away again if this is called before `update` in that frame. Focus is not shared between
    /// controls: remove it from the others first, or they all react to the same keys.
    public func setFocused(_ isFocused: Bool) {
        self.isFocused = isFocused && !isReadOnly
    }

    /// Returns the height required to display the given number of lines.
    public func height(forLineCount lineCount: Int) -> Int {
        (lineCount * lineHeight) - TextArea.lineGap + (TextArea.padding * 2)
    }

    /// The area's default four-line height when used in a `FormLayout`.
    public var formHeight: Float {
        Float(height(forLineCount: 4))
    }

    /// Assigns the area's bounds, for example when placing it in a `FormLayout`.
    public func place(in bounds: Rectangle) {
        self.bounds = bounds
    }

    /// Updates focus, typing, and wheel scrolling using the area's most recently assigned bounds,
    /// and reports whether typing changed the text.
    public func update() -> Bool {
        update(in: bounds)
    }

    /// Updates focus from pointer input, scrolls with the wheel while the pointer is over the area,
    /// takes typing while focused, and reports whether typing changed the text. Clicking outside
    /// the area gives up focus.
    public func update(in bounds: Rectangle) -> Bool {
        self.bounds = bounds
        prepareLines(for: bounds)
        let mouse = GetMousePosition()
        if CheckCollisionPointRec(mouse, bounds) {
            scroll(byWheelMovement: GetMouseWheelMove())
        }
        guard !isReadOnly else {
            return false
        }
        if IsMouseButtonPressed(MouseButton.left) {
            isFocused = CheckCollisionPointRec(mouse, bounds)
        }
        guard isFocused else {
            return false
        }
        return takeTyping()
    }

    /// Takes this frame's typing regardless of focus and reports whether the text changed.
    func takeTyping() -> Bool {
        let before = _text
        var key = Int(GetCharPressed())
        while key != 0 {
            add(Character(codePoint: key))
            key = Int(GetCharPressed())
        }
        for enter in [KeyboardKey.enter, KeyboardKey.kpEnter]
        where IsKeyPressed(enter) || IsKeyPressedRepeat(enter) {
            add("\n")
        }
        if (IsKeyPressed(KeyboardKey.backspace) || IsKeyPressedRepeat(KeyboardKey.backspace)), !_text.isEmpty {
            _text.removeLast()
        }
        return typed(changing: before)
    }

    /// Records that typing replaced `before`, so the caret comes back into view, and reports
    /// whether anything changed.
    func typed(changing before: String) -> Bool {
        guard _text != before else {
            return false
        }
        wrappedWidth = nil
        movesToEnd = true
        return true
    }

    /// Adds typed text at the caret, as typing does, and reports whether the text changed.
    func type(_ typed: String) -> Bool {
        let before = _text
        for c in typed {
            add(c)
        }
        return self.typed(changing: before)
    }

    // MARK: Scrolling

    private var lineHeight: Int {
        fontSize + TextArea.lineGap
    }

    private var lastFirstLine: Int {
        max(0, lines.count - visibleLineCount)
    }

    private var isAtEnd: Bool {
        firstLine >= lastFirstLine
    }

    /// The scrollbar position, where zero shows the first line and one shows the last.
    public var scrollFraction: Float {
        guard lastFirstLine > 0 else {
            return 1
        }
        return Float(firstLine) / Float(lastFirstLine)
    }

    /// The fraction of the text's lines the area shows at once.
    public var scrollThumbFraction: Float {
        guard !lines.isEmpty else {
            return 1
        }
        return min(1, Float(visibleLineCount) / Float(lines.count))
    }

    /// Returns the scrollbar thumb's bounds inside `track`. Call this after `update(in:)` or
    /// `draw(in:)` so it reflects the current text.
    public func scrollThumbBounds(in track: Rectangle) -> Rectangle {
        let innerHeight = max(0, track.height - 2)
        let thumbHeight = min(innerHeight, max(Self.minimumThumbHeight, innerHeight * scrollThumbFraction))
        return Rectangle(
            x: track.x + 1,
            y: track.y + 1 + ((innerHeight - thumbHeight) * scrollFraction),
            width: max(0, track.width - 2),
            height: thumbHeight
        )
    }

    /// Moves through the text. Positive values reveal earlier lines, as for `TextList`.
    public func scroll(byLines lineCount: Int) {
        firstLine = min(max(firstLine - lineCount, 0), lastFirstLine)
    }

    /// Moves to a scrollbar position, where zero shows the first line and one shows the last.
    public func scroll(toFraction fraction: Float) {
        guard fraction.isFinite else {
            return
        }
        firstLine = Int((min(max(fraction, 0), 1) * Float(lastFirstLine)) + 0.5)
    }

    /// Moves through the text by a mouse wheel reading. Positive values reveal earlier lines.
    ///
    /// Partial lines carry over to later calls, so the small steps a trackpad reports still add up
    /// to movement.
    public func scroll(byWheelMovement movement: Float) {
        guard movement.isFinite else {
            return
        }
        pendingWheelLines += movement * Self.linesPerWheelNotch
        let lineCount = Int(clamping: pendingWheelLines)
        pendingWheelLines -= Float(lineCount)
        if lineCount != 0 {
            scroll(byLines: lineCount)
        }
    }

    /// Wraps the text to `bounds` and keeps the scroll position within it.
    func prepareLines(for bounds: Rectangle) {
        let width = max(1, Int(clamping: bounds.width) - (TextArea.padding * 2) - TextArea.caretRoom)
        if wrappedWidth != width {
            lines = _text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .flatMap { paragraph -> [String] in
                    let wrapped = theme.wrappedLines(for: String(paragraph), size: fontSize, maximumWidth: width)
                    return wrapped.isEmpty ? [""] : wrapped
                }
            wrappedWidth = width
        }
        visibleLineCount = max(1, (Int(clamping: bounds.height) - (TextArea.padding * 2) + TextArea.lineGap) / lineHeight)
        if movesToEnd {
            firstLine = lastFirstLine
            movesToEnd = false
        } else {
            firstLine = min(firstLine, lastFirstLine)
        }
    }

    /// The first line the area shows, after the last `update(in:)` or `draw(in:)`.
    var firstVisibleLine: Int {
        firstLine
    }

    // MARK: Drawing

    /// Draws the area in its most recently assigned bounds.
    public func draw() {
        draw(in: bounds)
    }

    /// Draws the area in `bounds`, with a caret at the end of the text when it has focus and the
    /// end is in view. Contents are clipped to the area.
    public func draw(in bounds: Rectangle) {
        prepareLines(for: bounds)
        theme.fillRectangle(bounds, backgroundColor)
        theme.outlineRectangle(bounds, isFocused ? theme.accent : borderColor)
        BeginScissorMode(
            Int(clamping: bounds.x) + 1,
            Int(clamping: bounds.y) + 1,
            max(0, Int(clamping: bounds.width) - 2),
            max(0, Int(clamping: bounds.height) - 2)
        )
        defer {
            EndScissorMode()
        }
        let x = Int(clamping: bounds.x) + TextArea.padding
        let top = Int(clamping: bounds.y) + TextArea.padding
        if _text.isEmpty, let placeholder {
            theme.drawText(placeholder, x: x, y: top, size: fontSize, color: theme.secondaryText)
        } else {
            let end = min(lines.count, firstLine + visibleLineCount)
            for index in firstLine..<end {
                theme.drawText(lines[index], x: x, y: top + ((index - firstLine) * lineHeight), size: fontSize, color: textColor)
            }
        }
        let caretLine = max(lines.count, 1) - 1
        if isFocused, Int(clamping: GetTime() * 2) % 2 == 0,
           caretLine >= firstLine, caretLine < firstLine + visibleLineCount {
            let last = lines.last ?? ""
            DrawRectangle(
                x + theme.textWidth(of: last, size: fontSize) + 2,
                top + ((caretLine - firstLine) * lineHeight),
                2,
                fontSize,
                textColor
            )
        }
    }

    private func add(_ c: Character) {
        // "\r\n" is one Character in Swift, so it never equals "\n".
        let c: Character = c == "\r\n" || c == "\r" ? "\n" : c
        if _text.count < maxLength, c == "\n" || (c >= " " && c <= "~") {
            _text.append(c)
        }
    }
}
