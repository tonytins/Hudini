import Raylib

/// The colors, font, and text sizes used to draw Hudini components.
///
/// Pass the same theme to every component in a screen, and to functions that measure as well as
/// draw, such as `ButtonRow.buttonIndex`, so what they measure matches what is drawn.
public struct InterfaceTheme: Sendable {
    /// Highlights focused and selected interface elements.
    public let accent: Color
    /// Fills text fields and other editable controls.
    public let inputBackground: Color
    /// Fills window close controls.
    public let closeButton: Color
    /// Marks a hovered close control.
    public let closeMark: Color
    /// Dims the content behind a modal panel.
    public let overlay: Color
    /// Marks invalid values or validation messages.
    public let error: Color
    /// Fills windows and panels.
    public let panel: Color
    /// Outlines windows, controls, and buttons.
    public let border: Color
    /// Draws primary labels and content.
    public let text: Color
    /// Draws secondary or inactive content.
    public let secondaryText: Color
    /// Fills window title bars.
    public let titleBar: Color
    /// Fills selected tabs and toolbar items.
    public let selectedItem: Color
    /// The font every component draws with, or `nil` for raylib's default font.
    ///
    /// The host owns the font: load it after `InitWindow`, keep it loaded while the theme is in
    /// use, and unload it before `CloseWindow`. Load it at the size it is mostly drawn at, since
    /// raylib scales its one atlas for other sizes. raylib's text filter is the host's to set too.
    ///
    /// Marked unsafe because `Font` holds pointers. The theme never changes them, and raylib
    /// draws from one thread, so only draw with a theme on the thread that owns the window.
    public nonisolated(unsafe) let font: Font?
    /// The pixels between characters when drawing with `font`. raylib's default font sets its own
    /// spacing, so this has no effect without a `font`.
    public let fontSpacing: Float
    /// The sizes components draw their text at.
    public let textSizes: TextSizes

    /// The sizes components draw their text at, in pixels.
    ///
    /// Title bars, buttons, and panels keep their heights, so a size much larger than the default
    /// can outgrow them. `TextField`, `TextArea`, `TextList`, and a UIScript `<Style>` can each
    /// set their own size, which wins over these.
    public struct TextSizes: Sendable {
        /// Window titles.
        public let title: Int
        /// Form labels.
        public let label: Int
        /// Lists, panel messages, toolbar items, the notice button, and UIScript text and buttons.
        public let body: Int
        /// `ButtonRow` and `ConfirmPanel` buttons.
        public let button: Int
        /// `TextField` and `TextArea`.
        public let input: Int
        /// UIScript tooltips.
        public let tooltip: Int
        /// The message shown when a window title fails validation.
        public let problem: Int

        /// Creates a set of sizes, all positive. Unspecified sizes use Hudini's standard ones.
        public init(
            title: Int = 16,
            label: Int = 16,
            body: Int = 14,
            button: Int = 20,
            input: Int = 20,
            tooltip: Int = 12,
            problem: Int = 10
        ) {
            precondition(
                [title, label, body, button, input, tooltip, problem].allSatisfy { $0 > 0 },
                "text sizes must be positive"
            )
            self.title = title
            self.label = label
            self.body = body
            self.button = button
            self.input = input
            self.tooltip = tooltip
            self.problem = problem
        }
    }

    /// Creates a theme. Anything unspecified uses Hudini's standard look.
    public init(
        accent: Color = Color(r: 240, g: 190, b: 90, a: 255),
        inputBackground: Color = Color(r: 0, g: 0, b: 0, a: 255),
        closeButton: Color = Color(r: 236, g: 95, b: 86, a: 255),
        closeMark: Color = Color(r: 90, g: 20, b: 16, a: 255),
        overlay: Color = Color(r: 0, g: 0, b: 0, a: 140),
        error: Color = Color(r: 232, g: 106, b: 96, a: 255),
        panel: Color = Color(r: 22, g: 26, b: 32, a: 225),
        border: Color = Color(r: 72, g: 80, b: 92, a: 255),
        text: Color = Color(r: 228, g: 232, b: 238, a: 255),
        secondaryText: Color = Color(r: 150, g: 158, b: 170, a: 255),
        titleBar: Color = Color(r: 38, g: 43, b: 52, a: 245),
        selectedItem: Color = Color(r: 58, g: 66, b: 80, a: 255),
        font: Font? = nil,
        fontSpacing: Float = 1,
        textSizes: TextSizes = TextSizes()
    ) {
        self.accent = accent
        self.inputBackground = inputBackground
        self.closeButton = closeButton
        self.closeMark = closeMark
        self.overlay = overlay
        self.error = error
        self.panel = panel
        self.border = border
        self.text = text
        self.secondaryText = secondaryText
        self.titleBar = titleBar
        self.selectedItem = selectedItem
        self.font = font
        self.fontSpacing = fontSpacing
        self.textSizes = textSizes
    }

    /// Hudini's default dark palette with a warm accent.
    public static let standard = InterfaceTheme()

    /// Draws text the way every Hudini control does.
    func drawText(_ text: String, x: Int, y: Int, size: Int, color: Color) {
        guard let font = loadedFont else {
            DrawText(text, x, y, size, color)
            return
        }
        DrawTextEx(font, text, Vector2(x: Float(x), y: Float(y)), Float(size), fontSpacing, color)
    }

    /// Returns how wide `drawText` draws `text`.
    func textWidth(of text: String, size: Int) -> Int {
        guard let font = loadedFont else {
            return MeasureText(text, size)
        }
        return Int(clamping: MeasureTextEx(font, text, Float(size), fontSpacing).x.rounded(.up))
    }

    /// Wraps `text` into lines that fit `maximumWidth` when drawn with `drawText`.
    func wrappedLines(for text: String, size: Int, maximumWidth: Int) -> [String] {
        TextWrapper.lines(for: text, maximumWidth: maximumWidth) { textWidth(of: $0, size: size) }
    }

    // raylib draws a font with no texture in its default font but measures it as empty, so such a
    // font counts as none, which keeps drawing and measuring in step.
    private var loadedFont: Font? {
        guard let font, font.texture.id != 0 else {
            return nil
        }
        return font
    }
}
