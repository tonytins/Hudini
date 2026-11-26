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
    /// Fills window minimize controls.
    public let minimizeButton: Color
    /// Marks a hovered minimize control.
    public let minimizeMark: Color
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
    /// A fixed-width font for text a UIScript `<Style>` marks `font="monospace"`, such as code or
    /// a terminal, or `nil` to draw that text in `font`.
    ///
    /// The host owns it the same way as `font`, and it draws with the same `fontSpacing`.
    public nonisolated(unsafe) let monospaceFont: Font?
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
    /// Whether this is a dark look, with light text on a dark `panel`. A UIScript style's `dark`
    /// color twins apply on a dark theme. Unless the theme is told, it goes by how dark `panel` is.
    public let isDark: Bool

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
        /// UIScript tooltips, and text in the `caption` size role.
        public let tooltip: Int
        /// The message shown when a window title fails validation.
        public let problem: Int
        /// Text in the UIScript `largeTitle` size role.
        public let largeTitle: Int

        /// Creates a set of sizes, all positive. Unspecified sizes use Hudini's standard ones.
        public init(
            title: Int = 16,
            label: Int = 16,
            body: Int = 14,
            button: Int = 20,
            input: Int = 20,
            tooltip: Int = 12,
            problem: Int = 10,
            largeTitle: Int = 22
        ) {
            precondition(
                [title, label, body, button, input, tooltip, problem, largeTitle].allSatisfy { $0 > 0 },
                "text sizes must be positive"
            )
            self.title = title
            self.label = label
            self.body = body
            self.button = button
            self.input = input
            self.tooltip = tooltip
            self.problem = problem
            self.largeTitle = largeTitle
        }
    }

    /// Creates a theme. Anything unspecified uses Hudini's standard look.
    public init(
        accent: Color = Color(r: 240, g: 190, b: 90, a: 255),
        inputBackground: Color = Color(r: 0, g: 0, b: 0, a: 255),
        closeButton: Color = Color(r: 236, g: 95, b: 86, a: 255),
        closeMark: Color = Color(r: 90, g: 20, b: 16, a: 255),
        minimizeButton: Color = Color(r: 245, g: 170, b: 60, a: 255),
        minimizeMark: Color = Color(r: 100, g: 60, b: 10, a: 255),
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
        monospaceFont: Font? = nil,
        fontSpacing: Float = 1,
        textSizes: TextSizes = TextSizes(),
        cornerRadius: Float = 0,
        isDark: Bool? = nil
    ) {
        precondition(cornerRadius.isFinite && cornerRadius >= 0, "cornerRadius must not be negative")
        self.accent = accent
        self.inputBackground = inputBackground
        self.closeButton = closeButton
        self.closeMark = closeMark
        self.minimizeButton = minimizeButton
        self.minimizeMark = minimizeMark
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
        self.monospaceFont = monospaceFont
        self.fontSpacing = fontSpacing
        self.textSizes = textSizes
        self.cornerRadius = cornerRadius
        self.isDark = isDark ?? Self.isDark(panel)
    }

    // Whether a background reads as dark: its brightness, weighted the way the eye sees each
    // channel, is below the middle.
    static func isDark(_ background: Color) -> Bool {
        let brightness = (0.299 * Float(background.r)) + (0.587 * Float(background.g)) + (0.114 * Float(background.b))
        return brightness < 128
    }

    /// Hudini's default dark palette with a warm accent.
    public static let standard = InterfaceTheme()

    /// The look Depot, the UIScript designer, gives new documents: the standard look's slate and
    /// amber, made softer after GNOME's Adwaita, by way of VentureOS's HIG.
    ///
    /// Panels and title bars are opaque, so overlapping windows don't show through. Borders and
    /// quieter text are the text color at 20% and 58% over the panel rather than colors of their
    /// own (58% rather than Adwaita's 55%, so quieter text reads on the title bar too), fields sit a little darker than the panel instead of black, corners are rounded, and the
    /// title bar is flat. `depotLight` is its light twin.
    public static let depot = InterfaceTheme(
        inputBackground: Color(r: 18, g: 21, b: 27, a: 255),
        minimizeButton: Color(r: 245, g: 178, b: 50, a: 255),
        panel: Color(r: 26, g: 30, b: 38, a: 255),
        border: Color(r: 66, g: 70, b: 78, a: 255),
        secondaryText: Color(r: 143, g: 147, b: 154, a: 255),
        titleBar: Color(r: 38, g: 43, b: 52, a: 255),
        cornerRadius: 6
    )

    /// The light twin of `depot`: Adwaita's neutral surfaces, with the amber accent darkened until
    /// it stands out from white.
    ///
    /// Quieter text is the text color at 68% rather than `depot`'s 58%, so small text on a light
    /// panel stays readable.
    public static let depotLight = InterfaceTheme(
        accent: Color(r: 176, g: 122, b: 14, a: 255),
        inputBackground: Color(r: 255, g: 255, b: 255, a: 255),
        minimizeButton: Color(r: 245, g: 178, b: 50, a: 255),
        overlay: Color(r: 0, g: 0, b: 0, a: 90),
        error: Color(r: 192, g: 28, b: 40, a: 255),
        panel: Color(r: 250, g: 250, b: 251, a: 255),
        border: Color(r: 210, g: 210, b: 212, a: 255),
        text: Color(r: 51, g: 51, b: 56, a: 255),
        secondaryText: Color(r: 115, g: 115, b: 118, a: 255),
        titleBar: Color(r: 255, g: 255, b: 255, a: 255),
        selectedItem: Color(r: 218, g: 218, b: 220, a: 255),
        cornerRadius: 6
    )

    /// This theme drawing its text in `monospaceFont`, or the theme itself when it has none. A
    /// monospace font with no texture counts as none, as for `font`, so the text stays in `font`.
    var monospaced: InterfaceTheme {
        guard let monospaceFont, monospaceFont.texture.id != 0 else {
            return self
        }
        return replacingFonts(font: monospaceFont, monospaceFont: monospaceFont)
    }

    /// This theme drawing its text in `font`, for a style that names an appearance font. Its
    /// monospace font stays.
    func drawing(in font: Font) -> InterfaceTheme {
        replacingFonts(font: font, monospaceFont: monospaceFont)
    }

    /// Returns this theme with the fonts `appearance`'s `<Fonts>` names in place of its own.
    ///
    /// `loadFont` is called for each font `<Fonts>` names, after `InitWindow`. As with the theme's
    /// own fonts, the host owns them: it caches them, so a font a `UIView` also loads isn't loaded
    /// twice, and unloads them before `CloseWindow`. A font `<Fonts>` leaves out, or that
    /// `loadFont` can't supply, keeps the theme's, so the host's `loadFont` is the place to report
    /// a font that didn't load.
    ///
    /// Pass the result to every component the game draws, including `WindowFrame`, `ButtonRow`,
    /// and `NoticePanel`, and call this again on a new theme, such as when switching to dark mode.
    /// See `docs/design/2026-11-25-fonts.md`.
    public func withFonts(from appearance: Appearance, loadFont: (UIScript.FontResource) -> Font?) -> InterfaceTheme {
        guard let fonts = appearance.themeFonts else {
            return self
        }
        func load(_ name: String?) -> Font? {
            guard let name, let resource = appearance.fonts[name], let font = loadFont(resource),
                  font.texture.id != 0 else {
                return nil
            }
            return font
        }
        return replacingFonts(
            font: load(fonts.default) ?? font,
            monospaceFont: load(fonts.monospace) ?? monospaceFont
        )
    }

    private func replacingFonts(font: Font?, monospaceFont: Font?) -> InterfaceTheme {
        InterfaceTheme(
            accent: accent,
            inputBackground: inputBackground,
            closeButton: closeButton,
            closeMark: closeMark,
            minimizeButton: minimizeButton,
            minimizeMark: minimizeMark,
            overlay: overlay,
            error: error,
            panel: panel,
            border: border,
            text: text,
            secondaryText: secondaryText,
            titleBar: titleBar,
            titleBarBottom: titleBarBottom,
            selectedItem: selectedItem,
            font: font,
            monospaceFont: monospaceFont,
            fontSpacing: fontSpacing,
            textSizes: textSizes,
            cornerRadius: cornerRadius,
            isDark: isDark
        )
    }

    /// Draws text in the theme's font, the way every Hudini control does, so a game's own drawing
    /// matches its controls.
    ///
    /// Call it while drawing, between `BeginDrawing` and `EndDrawing`.
    public func drawText(_ text: String, x: Int, y: Int, size: Int, color: Color) {
        guard let font = loadedFont else {
            DrawText(text, x, y, size, color)
            return
        }
        DrawTextEx(font, text, Vector2(x: Float(x), y: Float(y)), Float(size), fontSpacing, color)
    }

    /// Returns how wide `drawText(_:x:y:size:color:)` draws `text`, in pixels.
    ///
    /// Measuring needs raylib's window, and returns zero before `InitWindow`.
    public func textWidth(of text: String, size: Int) -> Int {
        guard let font = loadedFont else {
            return MeasureText(text, size)
        }
        return Int(clamping: MeasureTextEx(font, text, Float(size), fontSpacing).x.rounded(.up))
    }

    /// Wraps `text` into lines that fit `maximumWidth` pixels when drawn with
    /// `drawText(_:x:y:size:color:)`, breaking between words where it can. See `TextWrapper`.
    public func wrappedLines(for text: String, size: Int, maximumWidth: Int) -> [String] {
        TextWrapper.lines(for: text, maximumWidth: maximumWidth) { textWidth(of: $0, size: size) }
    }

    // raylib's automatic count falls to one segment per corner at small radii, which draws a
    // straight diagonal, so a slider thumb would come out as a diamond.
    private static let cornerSegments = 8

    /// Fills a shape with the theme's corners, or a plain rectangle when `cornerRadius` is zero.
    public func fillRectangle(_ bounds: Rectangle, _ color: Color) {
        let radius = cornerRadius(for: bounds)
        guard radius > 0 else {
            DrawRectangleRec(bounds, color)
            return
        }
        DrawRectangleRounded(bounds, radius * 2 / min(bounds.width, bounds.height), Self.cornerSegments, color)
    }

    /// Outlines a shape with the theme's corners, drawing inside `bounds` as a square outline does.
    public func outlineRectangle(_ bounds: Rectangle, _ color: Color, thickness: Float = 1) {
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

    /// Fills a title bar, rounding only its top corners, from `titleBar` to `titleBarBottom`, the way
    /// `WindowFrame` does.
    public func fillTitleBar(_ bar: Rectangle) {
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

    /// Returns the radius `fillRectangle(_:_:)` draws `bounds` with: `cornerRadius`, or the largest
    /// that fits a smaller shape.
    public func cornerRadius(for bounds: Rectangle) -> Float {
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
