import Raylib

/// The colors, font, text sizes, and corners used to draw Hudini components.
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
    /// The color a title bar fades to at its bottom edge, for a glossy look, or `nil` for a flat
    /// `titleBar`.
    public let titleBarBottom: Color?
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
    /// The radius of the corners of windows, panels, buttons, fields, and lists, in pixels, or
    /// zero for square ones. A shape too small for it uses the largest radius that fits.
    ///
    /// Clicks still land on the whole rectangle, including just outside a rounded corner. raylib
    /// leaves curves jagged unless the host sets `.msaa4xHint` before `InitWindow`.
    public let cornerRadius: Float

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
        titleBarBottom: Color? = nil,
        selectedItem: Color = Color(r: 58, g: 66, b: 80, a: 255),
        font: Font? = nil,
        fontSpacing: Float = 1,
        textSizes: TextSizes = TextSizes(),
        cornerRadius: Float = 0
    ) {
        precondition(cornerRadius.isFinite && cornerRadius >= 0, "cornerRadius must not be negative")
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
        self.titleBarBottom = titleBarBottom
        self.selectedItem = selectedItem
        self.font = font
        self.fontSpacing = fontSpacing
        self.textSizes = textSizes
        self.cornerRadius = cornerRadius
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

    // raylib's automatic count falls to one segment per corner at small radii, which draws a
    // straight diagonal, so a slider thumb would come out as a diamond.
    private static let cornerSegments = 8

    /// Fills a shape with the theme's corners.
    func fillRectangle(_ bounds: Rectangle, _ color: Color) {
        let radius = cornerRadius(for: bounds)
        guard radius > 0 else {
            DrawRectangleRec(bounds, color)
            return
        }
        DrawRectangleRounded(bounds, radius * 2 / min(bounds.width, bounds.height), Self.cornerSegments, color)
    }

    /// Outlines a shape with the theme's corners, drawing inside `bounds`.
    func outlineRectangle(_ bounds: Rectangle, _ color: Color, thickness: Float = 1) {
        // raylib draws a rounded outline outside its rectangle and a square one inside.
        let inner = Rectangle(
            x: bounds.x + thickness,
            y: bounds.y + thickness,
            width: bounds.width - (thickness * 2),
            height: bounds.height - (thickness * 2)
        )
        let radius = cornerRadius(for: bounds) - thickness
        guard radius > 0, inner.width > 0, inner.height > 0 else {
            DrawRectangleLinesEx(bounds, thickness, color)
            return
        }
        DrawRectangleRoundedLinesEx(inner, radius * 2 / min(inner.width, inner.height), Self.cornerSegments, thickness, color)
    }

    /// Fills a title bar, rounding only its top corners, from `titleBar` to `titleBarBottom`.
    func fillTitleBar(_ bar: Rectangle) {
        let radius = cornerRadius(for: bar)
        guard radius > 0 || titleBarBottom != nil else {
            DrawRectangleRec(bar, titleBar)
            return
        }
        // raylib has no rounded gradient, so each row is its own rectangle, inset to follow the corner.
        let rowCount = Int(clamping: bar.height)
        for row in 0..<max(rowCount, 0) {
            let inset = Self.cornerInset(ofRow: row, radius: radius)
            DrawRectangleRec(
                Rectangle(x: bar.x + inset, y: bar.y + Float(row), width: bar.width - (inset * 2), height: 1),
                titleBarColor(ofRow: row, rowCount: rowCount)
            )
        }
    }

    /// The radius to draw a shape with: the theme's, or the largest that fits it.
    func cornerRadius(for bounds: Rectangle) -> Float {
        max(0, min(cornerRadius, min(bounds.width, bounds.height) / 2))
    }

    /// How far a row of pixels starts inside the edge of a shape whose corner has this radius.
    static func cornerInset(ofRow row: Int, radius: Float) -> Float {
        guard Float(row) < radius else {
            return 0
        }
        let distance = radius - (Float(row) + 0.5)
        return radius - ((radius * radius) - (distance * distance)).squareRoot()
    }

    /// The color of one row of a title bar, reaching `titleBarBottom` on the last row.
    func titleBarColor(ofRow row: Int, rowCount: Int) -> Color {
        guard let titleBarBottom, rowCount > 1 else {
            return titleBar
        }
        let progress = Float(row) / Float(rowCount - 1)
        func mixed(_ top: UInt8, _ bottom: UInt8) -> UInt8 {
            UInt8((Float(top) + ((Float(bottom) - Float(top)) * progress)).rounded())
        }
        return Color(
            r: mixed(titleBar.r, titleBarBottom.r),
            g: mixed(titleBar.g, titleBarBottom.g),
            b: mixed(titleBar.b, titleBarBottom.b),
            a: mixed(titleBar.a, titleBarBottom.a)
        )
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
