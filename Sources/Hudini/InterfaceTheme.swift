import Raylib

/// Semantic colors used to draw Hudini components.
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

    /// Creates a palette. Unspecified colors use Hudini's standard palette.
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
        selectedItem: Color = Color(r: 58, g: 66, b: 80, a: 255)
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
    }

    /// Hudini's default dark palette with a warm accent.
    public static let standard = InterfaceTheme()
}
